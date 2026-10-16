import CryptoKit
import Foundation

/// Downloads a file to a temporary location (which the caller moves), reporting progress 0…1.
public protocol ModelDownloading: Sendable {
    func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

/// Keeps the Kokoro model files in Application Support: downloads and verifies them, or removes them.
@MainActor
public final class KokoroModelStore: ObservableObject {
    public enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)

        /// Short status for Settings, e.g. "Downloading… 42%".
        public func statusText(totalBytes: Int64) -> String {
            switch self {
            case .notDownloaded:
                return "Not downloaded"
            case let .downloading(progress):
                return "Downloading… \(Int((progress * 100).rounded(.down)))%"
            case .ready:
                return "Ready (\(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)))"
            case .failed:
                return "Download failed"
            }
        }
    }

    public struct Asset: Equatable, Sendable {
        public let fileName: String
        public let url: URL
        /// Lowercase hex SHA-256 of the file.
        public let sha256: String
        public let byteCount: Int64

        public init(fileName: String, url: URL, sha256: String, byteCount: Int64) {
            self.fileName = fileName
            self.url = url
            self.sha256 = sha256
            self.byteCount = byteCount
        }
    }

    enum Failure: LocalizedError {
        case checksumMismatch(String)

        var errorDescription: String? {
            switch self {
            case let .checksumMismatch(fileName): return "\(fileName) is corrupt (checksum mismatch)"
            }
        }
    }

    @Published public private(set) var state: State = .notDownloaded
    public let directory: URL
    private let assets: [Asset]
    private let downloader: any ModelDownloading
    private var downloadTask: Task<Void, Never>?
    private var runID = 0

    public init(directory: URL, assets: [Asset], downloader: any ModelDownloading) {
        self.directory = directory
        self.assets = assets
        self.downloader = downloader
    }

    public func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    public var totalBytes: Int64 {
        assets.reduce(0) { $0 + $1.byteCount }
    }

    /// On launch: ready if every file is present, otherwise start downloading.
    public func start() {
        let present = assets.allSatisfy { FileManager.default.fileExists(atPath: url(for: $0.fileName).path) }
        if present {
            state = .ready
        } else {
            download()
        }
    }

    /// Downloads whatever is missing. Also used to retry after a failure.
    public func download() {
        guard downloadTask == nil, state != .ready else { return }
        runID += 1
        let id = runID
        state = .downloading(progress: 0)
        downloadTask = Task { [weak self] in
            await self?.performDownload(runID: id)
            if let self, self.runID == id {
                self.downloadTask = nil
            }
        }
    }

    /// Deletes the files. They are downloaded again on the next launch, or with `download()`.
    public func remove() {
        runID += 1
        downloadTask?.cancel()
        downloadTask = nil
        try? FileManager.default.removeItem(at: directory)
        state = .notDownloaded
    }

    private func performDownload(runID id: Int) async {
        let total = Double(max(totalBytes, 1))
        var completed: Int64 = 0
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for asset in assets {
                let destination = url(for: asset.fileName)
                if FileManager.default.fileExists(atPath: destination.path) {
                    completed += asset.byteCount
                    continue
                }
                let done = Double(completed)
                let temporary = try await downloader.download(asset.url) { fraction in
                    Task { @MainActor [weak self] in
                        guard let self, self.runID == id, case let .downloading(current) = self.state else { return }
                        let progress = (done + fraction * Double(asset.byteCount)) / total
                        // Publish only whole-percent changes; the downloader reports far more often.
                        guard Int(progress * 100) != Int(current * 100) else { return }
                        self.state = .downloading(progress: progress)
                    }
                }
                defer { try? FileManager.default.removeItem(at: temporary) }
                try Task.checkCancellation()
                guard try await Self.sha256(of: temporary) == asset.sha256 else {
                    throw Failure.checksumMismatch(asset.fileName)
                }
                try Task.checkCancellation()
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporary, to: destination)
                completed += asset.byteCount
            }
            try Task.checkCancellation()
            guard id == runID else { return }
            state = .ready
        } catch {
            guard id == runID, !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private nonisolated static func sha256(of file: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }
}