import XCTest
@testable import ScreenReaderCore

final class LanguageDetectorTests: XCTestCase {
    private let detector = NLLanguageDetector()

    func testDetectsEnglish() {
        let text = "The quick brown fox jumps over the lazy dog while the sun sets behind the hills."
        XCTAssertEqual(detector.detectLanguage(of: text), "en")
    }

    func testDetectsPortuguese() {
        let text = "O rápido cachorro marrom pulou sobre a cerca enquanto o sol se punha atrás das montanhas."
        XCTAssertEqual(detector.detectLanguage(of: text), "pt")
    }

    func testDetectsJapanese() {
        XCTAssertEqual(detector.detectLanguage(of: "今日はとても良い天気ですね。公園に散歩に行きましょう。"), "ja")
    }

    func testEmptyOrWhitespaceTextReturnsNil() {
        XCTAssertNil(detector.detectLanguage(of: ""))
        XCTAssertNil(detector.detectLanguage(of: "   \n\t"))
    }

    func testReturnsNilBelowConfidenceThreshold() {
        let strict = NLLanguageDetector(minimumConfidence: 1.01)
        XCTAssertNil(strict.detectLanguage(of: "The quick brown fox jumps over the lazy dog."))
    }
}
