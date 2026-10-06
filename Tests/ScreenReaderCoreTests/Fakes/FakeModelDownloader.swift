import Foundation
@testable import ScreenReaderCore

final class FakeModelDownloader: ModelDownloading, @unchecked Sendable {
    var files: [URL: Data] = [:]
    var error: (any Error)?
    private(set) var requested: [URL] = []

    func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        requested.append(url)
        if let error { throw error }
        guard let data = files[url] else { throw URLError(.fileDoesNotExist) }
        progress(0.5)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: file)
        return file
    }
}