import AppKit
import XCTest
@testable import ScreenReaderCore

@MainActor
final class SystemPasteboardTests: XCTestCase {
    /// A private, uniquely named pasteboard so tests never touch the user's clipboard.
    private func makePasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("AudraTests.\(UUID().uuidString)"))
        addTeardownBlock { pasteboard.releaseGlobally() }
        return pasteboard
    }

    func testSnapshotAndRestoreRoundTripAllTypes() {
        let nsPasteboard = makePasteboard()
        let customType = NSPasteboard.PasteboardType("com.example.custom")
        let item = NSPasteboardItem()
        item.setString("hello", forType: .string)
        item.setData(Data([0xDE, 0xAD]), forType: customType)
        nsPasteboard.clearContents()
        nsPasteboard.writeObjects([item])

        let pasteboard = SystemPasteboard(pasteboard: nsPasteboard)
        let snapshot = pasteboard.snapshot()
        nsPasteboard.clearContents()
        nsPasteboard.setString("clobbered", forType: .string)
        pasteboard.restore(snapshot)

        XCTAssertEqual(pasteboard.readString(), "hello")
        XCTAssertEqual(nsPasteboard.data(forType: customType), Data([0xDE, 0xAD]))
    }

    func testRestoreMarksContentsAsTransient() {
        let nsPasteboard = makePasteboard()
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        nsPasteboard.clearContents()
        nsPasteboard.setString("hello", forType: .string)

        let pasteboard = SystemPasteboard(pasteboard: nsPasteboard)
        let snapshot = pasteboard.snapshot()
        nsPasteboard.clearContents()
        nsPasteboard.setString("clobbered", forType: .string)
        pasteboard.restore(snapshot)

        XCTAssertNotNil(nsPasteboard.data(forType: transientType))
        XCTAssertEqual(pasteboard.readString(), "hello")
        XCTAssertFalse(pasteboard.snapshot().items.contains { $0.keys.contains(transientType.rawValue) })
    }

    func testRestoringAnEmptySnapshotLeavesPasteboardEmpty() {
        let nsPasteboard = makePasteboard()
        nsPasteboard.clearContents()
        let pasteboard = SystemPasteboard(pasteboard: nsPasteboard)
        let empty = pasteboard.snapshot()

        nsPasteboard.setString("something", forType: .string)
        pasteboard.restore(empty)

        XCTAssertNil(pasteboard.readString())
    }

    func testChangeCountIncreasesWhenContentsChange() {
        let nsPasteboard = makePasteboard()
        let pasteboard = SystemPasteboard(pasteboard: nsPasteboard)
        let before = pasteboard.changeCount
        nsPasteboard.clearContents()
        nsPasteboard.setString("x", forType: .string)
        XCTAssertGreaterThan(pasteboard.changeCount, before)
    }
}
