import XCTest
@testable import AudraCore

final class PinyinTranscriberTests: XCTestCase {
    private typealias Syllable = PinyinTranscriber.Syllable

    func testSplitsToneMarkedPinyinIntoSyllables() {
        XCTAssertEqual(PinyinTranscriber.syllables(in: "jīntiān", count: 2), [Syllable("jin", tone: 1), Syllable("tian", tone: 1)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "wǒmen", count: 2), [Syllable("wo", tone: 3), Syllable("men", tone: 5)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "nv̌ér", count: 2), [Syllable("nv", tone: 3), Syllable("er", tone: 2)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "lv̀sè", count: 2), [Syllable("lv", tone: 4), Syllable("se", tone: 4)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "xī'ān", count: 2), [Syllable("xi", tone: 1), Syllable("an", tone: 1)])
        XCTAssertEqual(PinyinTranscriber.syllables(in: "xiān", count: 1), [Syllable("xian", tone: 1)])
    }

    func testRejectsTextThatIsNotPinyin() {
        XCTAssertNil(PinyinTranscriber.syllables(in: "bcd", count: 1))
        XCTAssertNil(PinyinTranscriber.syllables(in: "jīntiān", count: 8)) // more syllables than letters
    }

    func testSyllablePhonemesMatchMisaki() {
        let cases: [(Syllable, String)] = [
            (Syllable("zhong", tone: 1), "ꭧʊ→ŋ"), (Syllable("guo", tone: 2), "kwo↗"), (Syllable("shi", tone: 4), "ʂɨ↘"),
            (Syllable("zi", tone: 4), "ʦɨ↘"), (Syllable("yu", tone: 3), "y↓"), (Syllable("jue", tone: 2), "ʨɥe↗"),
            (Syllable("nv", tone: 3), "ny↓"), (Syllable("er", tone: 2), "ɚ↗"), (Syllable("men", tone: 5), "mən"),
            (Syllable("qu", tone: 4), "ʨʰy↘"), (Syllable("tian", tone: 1), "tʰjɛ→n"), (Syllable("huan", tone: 1), "xwa→n"),
            (Syllable("hao", tone: 3), "xau↓"), (Syllable("you", tone: 3), "jou↓"), (Syllable("wo", tone: 3), "wo↓"),
        ]
        for (syllable, phonemes) in cases {
            XCTAssertEqual(PinyinTranscriber.phonemes(for: syllable), phonemes, syllable.letters)
        }
        XCTAssertNil(PinyinTranscriber.phonemes(for: Syllable("xx", tone: 1)))
    }

    func testChineseNumbers() {
        let cases: [(String, String)] = [
            ("0", "零"), ("3", "三"), ("10", "十"), ("15", "十五"), ("100", "一百"), ("105", "一百零五"),
            ("1010", "一千零一十"), ("2026", "二千零二十六"), ("10001", "一万零一"), ("120000", "十二万"),
            ("3.5", "三点五"), ("100000000", "一亿"),
        ]
        for (number, reading) in cases {
            XCTAssertEqual(ChineseNumberReader.reading(of: number), reading, number)
        }
        XCTAssertEqual(ChineseNumberReader.digitByDigit("2026"), "二零二六")
    }
}
