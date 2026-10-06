import Foundation

/// Downloads with URLSession. A failed download keeps its resume data, so a retry in the same
/// session continues where it stopped.
public final class URLSessionModelDownloader: NSObject, ModelDownloading, URLSessionDownloadDelegate, @unchecked Sendable {
    private struct Pending {
        let url: URL
        let continuation: CheckedContinuation<URL, Error>
        let progress: @Sendable (Double) -> Void
    }

    private let lock = NSLock()
    private var pending: [Int: Pending] = [:]
    private var resumeData: [URL: Data] = [:]
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    public override init() {
        super.init()
    }

    public func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            let task = resumeData.removeValue(forKey: url).map { session.downloadTask(withResumeData: $0) }
                ?? session.downloadTask(with: url)
            pending[task.taskIdentifier] = Pending(url: url, continuation: continuation, progress: progress)
            lock.unlock()
            task.resume()
        }
    }

    private func takePending(_ task: URLSessionTask) -> Pending? {
        lock.lock()
        defer { lock.unlock() }
        return pending.removeValue(forKey: task.taskIdentifier)
    }

    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        lock.lock()
        let progress = pending[downloadTask.taskIdentifier]?.progress
        lock.unlock()
        progress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let pending = takePending(downloadTask) else { return }
        if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            pending.continuation.resume(throwing: URLError(.badServerResponse))
            return
        }
        // `location` is deleted when this method returns, so move it now.
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            pending.continuation.resume(returning: destination)
        } catch {
            pending.continuation.resume(throwing: error)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let pending = takePending(task) else { return }
        if let data = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            lock.lock()
            resumeData[pending.url] = data
            lock.unlock()
        }
        pending.continuation.resume(throwing: error)
    }
}