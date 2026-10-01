import XCTest
@testable import ScreenReaderCore

@MainActor
final class ClipboardTextSourceTests: XCTestCase {
    func testReturnsCopiedTextAndRestoresOriginalClipboard() async {
        let pasteboard = FakePasteboard(text: "original")
        let original = pasteboard.contents
        let sender = FakeCopySender()
        sender.onSend = { pasteboard.simulateCopy("selected text") }

        let text = await ClipboardTextSource(pasteboard: pasteboard, copySender: sender).selectedText()

        XCTAssertEqual(text, "selected text")
        XCTAssertEqual(sender.sendCount, 1)
        XCTAssertEqual(pasteboard.restoredSnapshots, [original])
        XCTAssertEqual(pasteboard.contents, original)
    }

    func testWaitsForACopyThatLandsLate() async {
        let pasteboard = FakePasteboard(text: "original")
        let sender = FakeCopySender()
        sender.onSend = {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(30))
                pasteboard.simulateCopy("late text")
            }
        }

        let text = await ClipboardTextSource(pasteboard: pasteboard, copySender: sender).selectedText()

        XCTAssertEqual(text, "late text")
    }

    func testReturnsNilAndLeavesClipboardAloneWhenNothingIsCopied() async {
        let pasteboard = FakePasteboard(text: "original")
        let sender = FakeCopySender()

        let source = ClipboardTextSource(pasteboard: pasteboard, copySender: sender, timeout: .milliseconds(30))
        let text = await source.selectedText()

        XCTAssertNil(text)
        XCTAssertEqual(sender.sendCount, 1)
        XCTAssertEqual(pasteboard.restoredSnapshots, [])
    }

    func testRestoresClipboardWhenCopiedContentIsNotText() async {
        let pasteboard = FakePasteboard(text: "original")
        let original = pasteboard.contents
        let sender = FakeCopySender()
        sender.onSend = { pasteboard.simulateCopy(nil) }

        let text = await ClipboardTextSource(pasteboard: pasteboard, copySender: sender).selectedText()

        XCTAssertNil(text)
        XCTAssertEqual(pasteboard.restoredSnapshots, [original])
    }
}
