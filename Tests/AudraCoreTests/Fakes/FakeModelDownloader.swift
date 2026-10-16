import Foundation
@testable import AudraCore

final class FakeModelDownloader: ModelDownloading, @unchecked Sendable {
    var files: [URL: Data] = [:]
    var error: (any Error)?
    var holds = false
    /// Progress fractions reported by each download.
    var progressSteps: [Double] = [0.5]
    private(set) var requested: [URL] = []
    private(set) var cancelledCount = 0

    private let lock = NSLock()
    private var heldContinuations: [(CheckedContinuation<URL, Error>, URL, Data)] = []

    func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        requested.append(url)
        if let error { throw error }
        guard let data = files[url] else { throw URLError(.fileDoesNotExist) }

        if holds {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                    lock.lock()
                    heldContinuations.append((continuation, url, data))
                    lock.unlock()
                }
            } onCancel: {
                lock.lock()
                if let index = heldContinuations.firstIndex(where: { _ in true }) {
                    let (continuation, _, _) = heldContinuations.remove(at: index)
                    cancelledCount += 1
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                lock.unlock()
            }
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        progressSteps.forEach(progress)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: file)
        return file
    }

    func release() {
        lock.lock()
        let continuations = heldContinuations
        heldContinuations.removeAll()
        holds = false
        lock.unlock()

        for (continuation, _, data) in continuations {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? data.write(to: file)
            continuation.resume(returning: file)
        }
    }
}