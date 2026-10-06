import XCTest
@testable import ScreenReaderCore

final class PhonemizerTests: XCTestCase {
    private struct Failing: Phonemizer {
        struct Failure: Error {}
        func phonemize(_ text: String) throws -> String { throw Failure() }
    }

    private struct Echo: Phonemizer {
        let prefix: String
        func phonemize(_ text: String) throws -> String { prefix + text }
    }

    func testJoinerSeparatesWordsAndAttachesClosingPunctuation() {
        var joiner = PhonemeJoiner()
        joiner.appendWord("kono")
        joiner.appendWord("apɯɾʲi")
        joiner.appendPunctuation(",")
        joiner.appendWord("βa")
        joiner.appendPunctuation(".")
        XCTAssertEqual(joiner.text, "kono apɯɾʲi, βa.")
    }

    func testJoinerOpeningPunctuationStartsANewWord() {
        var joiner = PhonemeJoiner()
        joiner.appendWord("a")
        joiner.appendPunctuation("\u{201C}")
        joiner.appendWord("b")
        joiner.appendPunctuation("\u{201D}")
        XCTAssertEqual(joiner.text, "a \u{201C}b\u{201D}")
    }

    func testJoinerIgnoresEmptyWords() {
        var joiner = PhonemeJoiner()
        joiner.appendWord("")
        joiner.appendWord("a")
        XCTAssertEqual(joiner.text, "a")
    }

    func testFallbackUsesPrimaryWhenItSucceeds() throws {
        let phonemizer = FallbackPhonemizer(primary: Echo(prefix: "p:"), fallback: Echo(prefix: "f:"))
        XCTAssertEqual(try phonemizer.phonemize("x"), "p:x")
    }

    func testFallbackUsedWhenPrimaryThrows() throws {
        let phonemizer = FallbackPhonemizer(primary: Failing(), fallback: Echo(prefix: "f:"))
        XCTAssertEqual(try phonemizer.phonemize("x"), "f:x")
    }

    func testFallbackRethrowsWithoutFallback() {
        XCTAssertThrowsError(try FallbackPhonemizer(primary: Failing(), fallback: nil).phonemize("x"))
    }
}
