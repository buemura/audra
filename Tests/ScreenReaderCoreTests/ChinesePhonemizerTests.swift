import XCTest
@testable import ScreenReaderCore

final class ChinesePhonemizerTests: XCTestCase {
    private let phonemizer = ChinesePhonemizer()

    func testMatchesMisakiReferenceSentences() throws {
        // Reference outputs of misaki's ZHG2P (Kokoro v1.0) for the same sentences.
        XCTAssertEqual(try phonemizer.phonemize("我们今天去银行。"), "wo↓mən ʨi→ntʰjɛ→n ʨʰy↘ i↗nxa↗ŋ.")
        XCTAssertEqual(try phonemizer.phonemize("女儿喜欢绿色的衣服。"), "ny↓ɚ↗ ɕi↓xwa→n ly↘sɤ↘ tɤ i→fu↗.")
        XCTAssertEqual(try phonemizer.phonemize("你好，世界！"), "ni↓xau↓, ʂɨ↘ʨje↘!")
    }

    func testPunctuationBetweenClauses() throws {
        XCTAssertEqual(try phonemizer.phonemize("我是学生，他是老师。"), "wo↓ ʂɨ↘ ɕɥe↗ʂə→ŋ, tʰa→ ʂɨ↘ lau↓ʂɨ→.")
    }

    func testNumbersBecomeChineseNumerals() {
        XCTAssertEqual(ChinesePhonemizer.replacingNumbers(in: "我有3本书"), "我有三本书")
        XCTAssertEqual(ChinesePhonemizer.replacingNumbers(in: "2026年"), "二零二六年")
        XCTAssertEqual(ChinesePhonemizer.replacingNumbers(in: "15年"), "十五年")
    }
}
