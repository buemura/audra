import XCTest
@testable import AudraCore

@MainActor
final class FirstAvailableTextSourceTests: XCTestCase {
    func testReturnsFirstNonEmptyResultAndSkipsLaterSources() async {
        let first = StubTextSource("from AX")
        let second = StubTextSource("from clipboard")
        let text = await FirstAvailableTextSource([first, second]).selectedText()
        XCTAssertEqual(text, "from AX")
        XCTAssertEqual(second.callCount, 0)
    }

    func testSkipsNilAndBlankResults() async {
        let sources = [StubTextSource(nil), StubTextSource("  \n"), StubTextSource("found")]
        let text = await FirstAvailableTextSource(sources).selectedText()
        XCTAssertEqual(text, "found")
    }

    func testReturnsNilWhenEverySourceIsEmpty() async {
        let text = await FirstAvailableTextSource([StubTextSource(nil), StubTextSource("")]).selectedText()
        XCTAssertNil(text)
    }
}
