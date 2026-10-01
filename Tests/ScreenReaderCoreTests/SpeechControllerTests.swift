import XCTest
@testable import ScreenReaderCore

@MainActor
final class SpeechControllerTests: XCTestCase {
    private var synthesizer: FakeSynthesizer!
    private var controller: SpeechController!

    private func makeController() {
        synthesizer = FakeSynthesizer()
        controller = SpeechController(synthesizer: synthesizer)
    }

    func testStartsIdle() {
        makeController()
        XCTAssertEqual(controller.state, .idle)
    }

    func testSpeakFromIdle() {
        makeController()
        controller.speak("Hello", voiceID: "v1", rate: 0.5)
        XCTAssertEqual(controller.state, .speaking)
        XCTAssertEqual(synthesizer.calls, [.speak(text: "Hello", voiceID: "v1", rate: 0.5)])
    }

    func testSpeakWhileSpeakingStopsCurrentSpeechFirst() {
        makeController()
        controller.speak("One", voiceID: nil, rate: 0.5)
        controller.speak("Two", voiceID: nil, rate: 0.5)
        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "One", voiceID: nil, rate: 0.5),
            .stop,
            .speak(text: "Two", voiceID: nil, rate: 0.5),
        ])
        XCTAssertEqual(controller.state, .speaking)
    }

    func testNaturalFinishReturnsToIdle() {
        makeController()
        controller.speak("Hello", voiceID: nil, rate: 0.5)
        synthesizer.finish()
        XCTAssertEqual(controller.state, .idle)
    }

    func testPauseAndResume() {
        makeController()
        controller.speak("Hello", voiceID: nil, rate: 0.5)
        controller.pause()
        XCTAssertEqual(controller.state, .paused)
        controller.resume()
        XCTAssertEqual(controller.state, .speaking)
        XCTAssertEqual(synthesizer.calls.suffix(2), [.pause, .resume])
    }

    func testTogglePause() {
        makeController()
        controller.speak("Hello", voiceID: nil, rate: 0.5)
        controller.togglePause()
        XCTAssertEqual(controller.state, .paused)
        controller.togglePause()
        XCTAssertEqual(controller.state, .speaking)
    }

    func testStopFromSpeakingAndPaused() {
        makeController()
        controller.speak("Hello", voiceID: nil, rate: 0.5)
        controller.stop()
        XCTAssertEqual(controller.state, .idle)

        controller.speak("Hello", voiceID: nil, rate: 0.5)
        controller.pause()
        controller.stop()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(synthesizer.calls.last, .stop)
    }

    func testControlsAreNoOpsWhenIdle() {
        makeController()
        controller.stop()
        controller.pause()
        controller.resume()
        controller.togglePause()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(synthesizer.calls, [])
    }

    func testChangeRateWhileSpeakingRestartsFromCurrentWordAtNewRate() {
        makeController()
        controller.speak("Hello brave new world", voiceID: "v1", rate: 0.5)
        synthesizer.progress(to: 6) // about to say "brave"

        controller.changeRate(0.7)

        XCTAssertEqual(synthesizer.calls.suffix(2), [
            .stop,
            .speak(text: "brave new world", voiceID: "v1", rate: 0.7),
        ])
        XCTAssertEqual(controller.state, .speaking)
    }

    func testChangeRateBeforeAnyProgressRestartsWholeText() {
        makeController()
        controller.speak("Hello", voiceID: nil, rate: 0.5)

        controller.changeRate(0.7)

        XCTAssertEqual(synthesizer.calls.last, .speak(text: "Hello", voiceID: nil, rate: 0.7))
    }

    func testProgressIsTrackedRelativeToRestartedText() {
        makeController()
        controller.speak("Hello brave new world", voiceID: nil, rate: 0.5)
        synthesizer.progress(to: 6)
        controller.changeRate(0.7) // now speaking "brave new world"
        synthesizer.progress(to: 6) // about to say "new"

        controller.changeRate(0.6)

        XCTAssertEqual(synthesizer.calls.last, .speak(text: "new world", voiceID: nil, rate: 0.6))
    }

    func testChangeRateWhilePausedAppliesOnResume() {
        makeController()
        controller.speak("Hello brave new world", voiceID: nil, rate: 0.5)
        synthesizer.progress(to: 6)
        controller.pause()

        controller.changeRate(0.7)
        XCTAssertEqual(controller.state, .paused)
        XCTAssertFalse(synthesizer.calls.contains(.speak(text: "brave new world", voiceID: nil, rate: 0.7)))

        controller.resume()
        XCTAssertEqual(synthesizer.calls.last, .speak(text: "brave new world", voiceID: nil, rate: 0.7))
        XCTAssertFalse(synthesizer.calls.contains(.resume))
        XCTAssertEqual(controller.state, .speaking)
    }

    func testChangeRateWhileIdleDoesNothing() {
        makeController()
        controller.changeRate(0.7)
        XCTAssertEqual(synthesizer.calls, [])
        XCTAssertEqual(controller.state, .idle)
    }

    func testCurrentTextAndVoiceAreNilBeforeSpeaking() {
        makeController()
        XCTAssertNil(controller.currentText)
        XCTAssertNil(controller.currentVoiceID)
    }

    func testSpeakRecordsCurrentTextAndVoice() {
        makeController()
        controller.speak("Hello", voiceID: "v1", rate: 0.5)
        XCTAssertEqual(controller.currentText, "Hello")
        XCTAssertEqual(controller.currentVoiceID, "v1")

        controller.speak("Bye", voiceID: nil, rate: 0.5)
        XCTAssertEqual(controller.currentText, "Bye")
        XCTAssertNil(controller.currentVoiceID)
    }

    func testCurrentTextKeepsOriginalTextAfterRateChangeStopAndFinish() {
        makeController()
        controller.speak("Hello brave new world", voiceID: "v1", rate: 0.5)
        synthesizer.progress(to: 6)
        controller.changeRate(0.7)
        XCTAssertEqual(controller.currentText, "Hello brave new world")

        controller.stop()
        XCTAssertEqual(controller.currentText, "Hello brave new world")
        XCTAssertEqual(controller.currentVoiceID, "v1")

        controller.speak("Again", voiceID: "v1", rate: 0.5)
        synthesizer.finish()
        XCTAssertEqual(controller.currentText, "Again")
    }
}
