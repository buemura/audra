import XCTest
@testable import ScreenReaderKokoro

final class EnglishPhonemizerTests: XCTestCase {
    func testAmericanEnglishMatchesMisaki() throws {
        XCTAssertEqual(try EnglishPhonemizer(british: false).phonemize("Hello world!"), "həlˈO wˈɜɹld!")
    }

    func testBritishEnglishProducesPhonemes() throws {
        XCTAssertFalse(try EnglishPhonemizer(british: true).phonemize("Hello world!").isEmpty)
    }
}
