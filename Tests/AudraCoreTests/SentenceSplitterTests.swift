import XCTest
@testable import AudraCore

final class SentenceSplitterTests: XCTestCase {
    private typealias Sentence = SentenceSplitter.Sentence

    func testSplitsSentencesWithUTF16Offsets() {
        XCTAssertEqual(SentenceSplitter.sentences(in: "Hello there. How are you?"), [
            Sentence(text: "Hello there.", offset: 0),
            Sentence(text: "How are you?", offset: 13),
        ])
    }

    func testOffsetsSkipLeadingWhitespace() {
        XCTAssertEqual(SentenceSplitter.sentences(in: "  First one.\n\nSecond"), [
            Sentence(text: "First one.", offset: 2),
            Sentence(text: "Second", offset: 14),
        ])
    }

    func testJapaneseSentences() {
        XCTAssertEqual(SentenceSplitter.sentences(in: "今日は晴れです。明日は雨です。"), [
            Sentence(text: "今日は晴れです。", offset: 0),
            Sentence(text: "明日は雨です。", offset: 8),
        ])
    }

    func testOffsetsCountUTF16NotCharacters() {
        // "👋" is one Character but two UTF-16 code units.
        XCTAssertEqual(SentenceSplitter.sentences(in: "Hi 👋. Bye.").map(\.offset), [0, 7])
    }

    func testWhitespaceOnlyTextHasNoSentences() {
        XCTAssertEqual(SentenceSplitter.sentences(in: "  \n "), [])
    }

    func testSubdivideAtClausePunctuation() {
        XCTAssertEqual(SentenceSplitter.subdivide("one, two; three"), ["one,", "two;", "three"])
        XCTAssertEqual(SentenceSplitter.subdivide("今日は、晴れ"), ["今日は、", "晴れ"])
    }

    func testSubdivideWithoutPunctuationSplitsWordsInHalf() {
        XCTAssertEqual(SentenceSplitter.subdivide("alpha beta gamma delta"), ["alpha beta", "gamma delta"])
    }

    func testSubdivideWithoutSpacesSplitsCharactersInHalf() {
        XCTAssertEqual(SentenceSplitter.subdivide("あいうえ"), ["あい", "うえ"])
        XCTAssertEqual(SentenceSplitter.subdivide("a"), ["a"])
    }
}
