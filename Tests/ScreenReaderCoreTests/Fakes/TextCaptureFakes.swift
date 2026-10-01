import Foundation
@testable import ScreenReaderCore

@MainActor
final class StubTextSource: SelectedTextSource {
    private let text: String?
    private(set) var callCount = 0

    init(_ text: String?) { self.text = text }

    func selectedText() async -> String? {
        callCount += 1
        return text
    }
}

@MainActor
final class FakePasteboard: PasteboardAccessing {
    private(set) var changeCount = 0
    private(set) var contents: PasteboardSnapshot
    private(set) var restoredSnapshots: [PasteboardSnapshot] = []
    private var string: String?

    init(text: String) {
        contents = Self.textSnapshot(text)
        string = text
    }

    func snapshot() -> PasteboardSnapshot { contents }

    func restore(_ snapshot: PasteboardSnapshot) {
        restoredSnapshots.append(snapshot)
        contents = snapshot
        changeCount += 1
    }

    func readString() -> String? { string }

    /// Simulates the frontmost app writing to the clipboard. nil = non-text content (e.g. an image).
    func simulateCopy(_ text: String?) {
        string = text
        contents = text.map(Self.textSnapshot) ?? PasteboardSnapshot(items: [["public.png": Data([1, 2, 3])]])
        changeCount += 1
    }

    static func textSnapshot(_ text: String) -> PasteboardSnapshot {
        PasteboardSnapshot(items: [["public.utf8-plain-text": Data(text.utf8)]])
    }
}

@MainActor
final class FakeCopySender: CopyCommandSending {
    var onSend: @MainActor () -> Void = {}
    private(set) var sendCount = 0

    func sendCopyCommand() {
        sendCount += 1
        onSend()
    }
}
