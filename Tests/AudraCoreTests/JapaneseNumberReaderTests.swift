import XCTest
@testable import AudraCore

final class JapaneseNumberReaderTests: XCTestCase {
    func testPlainNumbers() {
        let cases: [(String, String)] = [
            ("0", "ぜろ"), ("300", "さんびゃく"), ("8000", "はっせん"), ("2026", "にせんにじゅーろく"),
            ("10000", "いちまん"), ("123456789", "いちおくにせんさんびゃくよんじゅーごまんろくせんななひゃくはちじゅーきゅー"),
            ("007", "ぜろぜろなな"), ("3.5", "さんてんご"),
        ]
        for (number, reading) in cases {
            XCTAssertEqual(JapaneseNumberReader.reading(of: number), reading, number)
        }
    }

    func testCounters() {
        let cases: [(String, String, String)] = [
            ("1", "日", "ついたち"), ("14", "日", "じゅーよっか"), ("15", "日", "じゅーごにち"), ("20", "日", "はつか"),
            ("4", "月", "しがつ"), ("2024", "年", "にせんにじゅーよねん"), ("9", "時", "くじ"),
            ("1", "分", "いっぷん"), ("3", "分", "さんぷん"), ("5", "分", "ごふん"), ("10", "分", "じゅっぷん"),
            ("1", "人", "ひとり"), ("4", "人", "よにん"), ("100", "円", "ひゃくえん"), ("3", "つ", "みっつ"),
            ("20", "歳", "はたち"), ("8", "回", "はっかい"), ("6", "個", "ろっこ"),
        ]
        for (number, counter, reading) in cases {
            XCTAssertEqual(JapaneseNumberReader.reading(of: number, counter: counter), reading, number + counter)
        }
    }
}
