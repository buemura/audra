import Combine
import CryptoKit
import XCTest
@testable import ScreenReaderCore

@MainActor
final class KokoroModelStoreTests: XCTestCase {
    private var directory: URL!
    private var downloader: FakeModelDownloader!
    private let modelData = Data("model weights".utf8)
    private let voicesData = Data("voice styles".utf8)
    private let modelURL = URL(string: "https://example.com/model.safetensors")!
    private let voicesURL = URL(string: "https://example.com/voices.npz")!

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeStore(modelChecksum: String? = nil) -> KokoroModelStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KokoroModelStoreTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        self.directory = directory
        downloader = FakeModelDownloader()
        downloader.files = [modelURL: modelData, voicesURL: voicesData]
        return KokoroModelStore(directory: directory, assets: [
            .init(fileName: "model.safetensors", url: modelURL, sha256: modelChecksum ?? sha256(modelData), byteCount: Int64(modelData.count)),
            .init(fileName: "voices.npz", url: voicesURL, sha256: sha256(voicesData), byteCount: Int64(voicesData.count)),
        ], downloader: downloader)
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out", file: file, line: line)
    }

    func testStartDownloadsVerifiesAndBecomesReady() async throws {
        let store = makeStore()
        store.start()
        XCTAssertEqual(store.state, .downloading(progress: 0))
        try await waitUntil { store.state == .ready }
        XCTAssertEqual(try Data(contentsOf: store.url(for: "model.safetensors")), modelData)
        XCTAssertEqual(try Data(contentsOf: store.url(for: "voices.npz")), voicesData)
        XCTAssertEqual(downloader.requested, [modelURL, voicesURL])
    }

    func testStartWithFilesPresentIsReadyWithoutDownloading() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try modelData.write(to: store.url(for: "model.safetensors"))
        try voicesData.write(to: store.url(for: "voices.npz"))
        store.start()
        XCTAssertEqual(store.state, .ready)
        XCTAssertEqual(downloader.requested, [])
    }

    func testChecksumMismatchFailsAndKeepsNoFile() async throws {
        let store = makeStore(modelChecksum: String(repeating: "0", count: 64))
        store.start()
        try await waitUntil { if case .failed = store.state { return true } else { return false } }
        guard case let .failed(message) = store.state else { return XCTFail() }
        XCTAssertTrue(message.contains("model.safetensors"), message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: "model.safetensors").path))
    }

    func testFailedDownloadCanBeRetried() async throws {
        let store = makeStore()
        downloader.error = URLError(.notConnectedToInternet)
        store.start()
        try await waitUntil { if case .failed = store.state { return true } else { return false } }
        downloader.error = nil
        store.download()
        try await waitUntil { store.state == .ready }
    }

    func testRemoveDeletesTheFiles() async throws {
        let store = makeStore()
        store.start()
        try await waitUntil { store.state == .ready }
        store.remove()
        XCTAssertEqual(store.state, .notDownloaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testTotalBytesAndStatusText() {
        let store = makeStore()
        XCTAssertEqual(store.totalBytes, Int64(modelData.count + voicesData.count))
        XCTAssertEqual(KokoroModelStore.State.notDownloaded.statusText(totalBytes: 0), "Not downloaded")
        XCTAssertEqual(KokoroModelStore.State.downloading(progress: 0.427).statusText(totalBytes: 0), "Downloading… 42%")
        XCTAssertEqual(KokoroModelStore.State.failed("x").statusText(totalBytes: 0), "Download failed")
        XCTAssertTrue(KokoroModelStore.State.ready.statusText(totalBytes: 190_000_000).hasPrefix("Ready ("))
    }

    func testShippedAssetsArePinned() {
        XCTAssertEqual(KokoroModelAssets.all.map(\.fileName), ["kokoro-v1_0-fp16.safetensors", "voices.npz"])
        XCTAssertEqual(KokoroModelAssets.all.map(\.byteCount), [163_587_908, 26_645_914])
        XCTAssertTrue(KokoroModelAssets.all.allSatisfy {
            $0.url.absoluteString.hasPrefix("https://github.com/buemura/screen-reader-models/releases/download/kokoro-model-v1/")
                && $0.sha256.count == 64
        })
    }

    func testRemoveDuringDownloadCancelsItAndKeepsNoFiles() async throws {
        let store = makeStore()
        downloader.holds = true
        store.start()
        try await waitUntil { downloader.requested.count == 1 }
        store.remove()
        try await waitUntil { downloader.cancelledCount == 1 }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(store.state, .notDownloaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testDownloadAfterRemoveCompletesAndOnlyOneRunIsActive() async throws {
        let store = makeStore()
        downloader.holds = true
        store.start()
        try await waitUntil { downloader.requested.count == 1 }
        store.remove()
        downloader.holds = false
        store.download()
        store.download()
        try await waitUntil { store.state == .ready }
        XCTAssertEqual(downloader.requested.count, 3)
    }

    func testReportsDownloadProgress() async throws {
        let store = makeStore()
        var states: [KokoroModelStore.State] = []
        let cancellable = store.$state.sink { states.append($0) }
        addTeardownBlock { _ = cancellable }
        store.start()
        try await waitUntil { store.state == .ready }
        let downloadingStates = states.compactMap { state -> Double? in
            if case let .downloading(progress) = state { return progress }
            return nil
        }
        XCTAssertTrue(downloadingStates.contains { $0 > 0 && $0 < 1 })
    }

    func testPublishesProgressOnlyWhenTheWholePercentChanges() async throws {
        let store = makeStore()
        downloader.progressSteps = [0.5, 0.5001, 0.5002, 0.9]
        var percents: [Int] = []
        let cancellable = store.$state.sink { state in
            if case let .downloading(progress) = state { percents.append(Int(progress * 100)) }
        }
        addTeardownBlock { _ = cancellable }
        store.start()
        try await waitUntil { store.state == .ready }
        XCTAssertGreaterThan(percents.count, 1)
        XCTAssertFalse(zip(percents, percents.dropFirst()).contains { $0 == $1 }, "\(percents)")
    }
}
