import XCTest
@testable import ScreenReaderCore

final class JapanesePhonemizerTests: XCTestCase {
    private let phonemizer = JapanesePhonemizer()

    func testMatchesMisakiReferenceSentence() throws {
        // Reference output of misaki's JAG2P (cutlet) for the same sentence.
        XCTAssertEqual(
            try phonemizer.phonemize("スクリーンリーダーは、書かれた文章を音声に変換します。"),
            "sɨkɯɾʲiːɴ ɾʲiːdaː βa, kaka ɾe ta bɯɴɕoː o oɴseː ɲi heŋkaɴ ɕi masɨ."
        )
    }

    func testParticlesAndLongVowels() throws {
        XCTAssertEqual(try phonemizer.phonemize("東京へ行きます。本を読んでください。"),
                       "toːkʲoː e ikʲi masɨ. hoɴ o joɴ de kɯdasai.")
        XCTAssertEqual(try phonemizer.phonemize("学校の先生"), "ɡaʔkoː no seɴseː")
    }

    func testSokuonAndExclamation() throws {
        XCTAssertEqual(try phonemizer.phonemize("ちょっと待って！"), "ʨoʔto maʔte!")
    }

    func testNumbersWithCounters() throws {
        XCTAssertEqual(try phonemizer.phonemize("今日は2026年10月1日です。"),
                       "kʲoː βa ɲiseɲɲiʥɨːɾokɯneɴ ʥɨːɡaʦɨ ʦɨitaʨi desɨ.")
    }

    func testKanaToPhonemes() {
        XCTAssertEqual(JapanesePhonemizer.phonemes(forKana: "さんま"), "samma")
        XCTAssertEqual(JapanesePhonemizer.phonemes(forKana: "こんにちわ"), "koɲɲiʨiβa")
        XCTAssertEqual(JapanesePhonemizer.phonemes(forKana: "りーだー"), "ɾʲiːdaː")
    }

    func testLengthenVowelsOnlyInKanjiPart() {
        XCTAssertEqual(JapanesePhonemizer.lengthenVowels("とうきょう", keepingLast: 0), "とーきょー")
        XCTAssertEqual(JapanesePhonemizer.lengthenVowels("せんせい", keepingLast: 0), "せんせー")
        XCTAssertEqual(JapanesePhonemizer.lengthenVowels("おもう", keepingLast: 1), "おもう")
    }

    func testReadings() {
        XCTAssertEqual(JapanesePhonemizer.reading(surface: "は", latin: "ha"), "わ")
        XCTAssertEqual(JapanesePhonemizer.reading(surface: "東京", latin: "toukyou"), "とーきょー")
        XCTAssertEqual(JapanesePhonemizer.reading(surface: "思う", latin: "omou"), "おもう")
        XCTAssertNil(JapanesePhonemizer.reading(surface: "東京", latin: nil))
        XCTAssertEqual(JapanesePhonemizer.hiragana(fromKatakana: "リーダー"), "りーだー")
    }

    func testNumberSegments() {
        XCTAssertEqual(JapanesePhonemizer.numberSegments("今日は2026年と3.5キロ"), [
            .text("今日は"), .number("2026", counter: "年"), .text("と"), .number("3.5", counter: nil), .text("キロ"),
        ])
    }
}
