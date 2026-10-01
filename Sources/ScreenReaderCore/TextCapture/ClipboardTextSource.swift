import Foundation

/// Raw pasteboard contents: one entry per item, mapping type identifier to data.
public struct PasteboardSnapshot: Equatable {
    public var items: [[String: Data]]

    public init(items: [[String: Data]]) {
        self.items = items
    }
}

@MainActor
public protocol PasteboardAccessing: AnyObject {
    var changeCount: Int { get }
    func snapshot() -> PasteboardSnapshot
    func restore(_ snapshot: PasteboardSnapshot)
    func readString() -> String?
}

@MainActor
public protocol CopyCommandSending {
    /// Sends ⌘C to the frontmost application.
    func sendCopyCommand()
}

/// Fallback for apps that don't expose their selection to the Accessibility API:
/// press ⌘C, read the clipboard, then put the user's clipboard back.
@MainActor
public final class ClipboardTextSource: SelectedTextSource {
    private let pasteboard: any PasteboardAccessing
    private let copySender: any CopyCommandSending
    private let timeout: Duration
    private let pollInterval: Duration

    public init(
        pasteboard: any PasteboardAccessing,
        copySender: any CopyCommandSending,
        timeout: Duration = .milliseconds(300),
        pollInterval: Duration = .milliseconds(10)
    ) {
        self.pasteboard = pasteboard
        self.copySender = copySender
        self.timeout = timeout
        self.pollInterval = pollInterval
    }

    public func selectedText() async -> String? {
        let saved = pasteboard.snapshot()
        let initialChangeCount = pasteboard.changeCount
        copySender.sendCopyCommand()

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while pasteboard.changeCount == initialChangeCount, clock.now < deadline {
            try? await Task.sleep(for: pollInterval)
        }
        // Nothing was copied (no selection, or the app ignored ⌘C): the clipboard is untouched.
        guard pasteboard.changeCount != initialChangeCount else { return nil }

        let text = pasteboard.readString()
        pasteboard.restore(saved)
        return text
    }
}
