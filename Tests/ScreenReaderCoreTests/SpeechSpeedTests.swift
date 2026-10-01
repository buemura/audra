import AVFoundation
import XCTest
@testable import ScreenReaderCore

final class SpeechSpeedTests: XCTestCase {
    func testOffersExactlyTheSupportedSpeedsInOrder() {
        XCTAssertEqual(SpeechSpeed.allCases.map(\.rawValue), [0.5, 1.0, 1.5, 2.0, 2.5])
    }

    func testLabels() {
        XCTAssertEqual(SpeechSpeed.allCases.map(\.label), ["0.5x", "1x", "1.5x", "2x", "2.5x"])
    }

    func testNormalSpeedUsesSystemDefaultRate() {
        XCTAssertEqual(SpeechSpeed.normal.utteranceRate, AVSpeechUtteranceDefaultSpeechRate)
    }

    func testRatesStrictlyIncreaseAndStayWithinAVSpeechBounds() {
        let rates = SpeechSpeed.allCases.map(\.utteranceRate)
        XCTAssertEqual(rates, rates.sorted())
        XCTAssertEqual(Set(rates).count, rates.count)
        for rate in rates {
            XCTAssertGreaterThanOrEqual(rate, AVSpeechUtteranceMinimumSpeechRate)
            XCTAssertLessThanOrEqual(rate, AVSpeechUtteranceMaximumSpeechRate)
        }
    }

    func testFasterStepsToNextSpeedAndStopsAtTheTop() {
        XCTAssertEqual(SpeechSpeed.half.faster, .normal)
        XCTAssertEqual(SpeechSpeed.normal.faster, .oneAndHalf)
        XCTAssertEqual(SpeechSpeed.double.faster, .twoAndHalf)
        XCTAssertNil(SpeechSpeed.twoAndHalf.faster)
    }

    func testSlowerStepsToPreviousSpeedAndStopsAtTheBottom() {
        XCTAssertEqual(SpeechSpeed.twoAndHalf.slower, .double)
        XCTAssertEqual(SpeechSpeed.normal.slower, .half)
        XCTAssertNil(SpeechSpeed.half.slower)
    }
}
