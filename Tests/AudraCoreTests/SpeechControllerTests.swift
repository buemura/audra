import XCTest
@testable import AudraCore

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
        controller.speak("Hello", voiceID: "v1", speed: .normal)
        XCTAssertEqual(controller.state, .speaking)
        XCTAssertEqual(synthesizer.calls, [.speak(text: "Hello", voiceID: "v1", speed: .normal)])
    }

    func testSpeakWhileSpeakingStopsCurrentSpeechFirst() {
        makeController()
        controller.speak("One", voiceID: nil, speed: .normal)
        controller.speak("Two", voiceID: nil, speed: .normal)
        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "One", voiceID: nil, speed: .normal),
            .stop,
            .speak(text: "Two", voiceID: nil, speed: .normal),
        ])
        XCTAssertEqual(controller.state, .speaking)
    }

    func testNaturalFinishReturnsToIdle() {
        makeController()
        controller.speak("Hello", voiceID: nil, speed: .normal)
        synthesizer.finish()
        XCTAssertEqual(controller.state, .idle)
    }

    func testPauseAndResume() {
        makeController()
        controller.speak("Hello", voiceID: nil, speed: .normal)
        controller.pause()
        XCTAssertEqual(controller.state, .paused)
        controller.resume()
        XCTAssertEqual(controller.state, .speaking)
        XCTAssertEqual(synthesizer.calls.suffix(2), [.pause, .resume])
    }

    func testTogglePause() {
        makeController()
        controller.speak("Hello", voiceID: nil, speed: .normal)
        controller.togglePause()
        XCTAssertEqual(controller.state, .paused)
        controller.togglePause()
        XCTAssertEqual(controller.state, .speaking)
    }

    func testStopFromSpeakingAndPaused() {
        makeController()
        controller.speak("Hello", voiceID: nil, speed: .normal)
        controller.stop()
        XCTAssertEqual(controller.state, .idle)

        controller.speak("Hello", voiceID: nil, speed: .normal)
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
        controller.speak("Hello brave new world", voiceID: "v1", speed: .normal)
        synthesizer.progress(to: 6) // about to say "brave"

        controller.changeSpeed(.double)

        XCTAssertEqual(synthesizer.calls.suffix(2), [
            .stop,
            .speak(text: "brave new world", voiceID: "v1", speed: .double),
        ])
        XCTAssertEqual(controller.state, .speaking)
    }

    func testChangeRateBeforeAnyProgressRestartsWholeText() {
        makeController()
        controller.speak("Hello", voiceID: nil, speed: .normal)

        controller.changeSpeed(.double)

        XCTAssertEqual(synthesizer.calls.last, .speak(text: "Hello", voiceID: nil, speed: .double))
    }

    func testProgressIsTrackedRelativeToRestartedText() {
        makeController()
        controller.speak("Hello brave new world", voiceID: nil, speed: .normal)
        synthesizer.progress(to: 6)
        controller.changeSpeed(.double) // now speaking "brave new world"
        synthesizer.progress(to: 6) // about to say "new"

        controller.changeSpeed(.oneAndHalf)

        XCTAssertEqual(synthesizer.calls.last, .speak(text: "new world", voiceID: nil, speed: .oneAndHalf))
    }

    func testChangeRateWhilePausedAppliesOnResume() {
        makeController()
        controller.speak("Hello brave new world", voiceID: nil, speed: .normal)
        synthesizer.progress(to: 6)
        controller.pause()

        controller.changeSpeed(.double)
        XCTAssertEqual(controller.state, .paused)
        XCTAssertFalse(synthesizer.calls.contains(.speak(text: "brave new world", voiceID: nil, speed: .double)))

        controller.resume()
        XCTAssertEqual(synthesizer.calls.last, .speak(text: "brave new world", voiceID: nil, speed: .double))
        XCTAssertFalse(synthesizer.calls.contains(.resume))
        XCTAssertEqual(controller.state, .speaking)
    }

    func testChangeRateWhileIdleDoesNothing() {
        makeController()
        controller.changeSpeed(.double)
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
        controller.speak("Hello", voiceID: "v1", speed: .normal)
        XCTAssertEqual(controller.currentText, "Hello")
        XCTAssertEqual(controller.currentVoiceID, "v1")

        controller.speak("Bye", voiceID: nil, speed: .normal)
        XCTAssertEqual(controller.currentText, "Bye")
        XCTAssertNil(controller.currentVoiceID)
    }

    func testCurrentTextKeepsOriginalTextAfterRateChangeStopAndFinish() {
        makeController()
        controller.speak("Hello brave new world", voiceID: "v1", speed: .normal)
        synthesizer.progress(to: 6)
        controller.changeSpeed(.double)
        XCTAssertEqual(controller.currentText, "Hello brave new world")

        controller.stop()
        XCTAssertEqual(controller.currentText, "Hello brave new world")
        XCTAssertEqual(controller.currentVoiceID, "v1")

        controller.speak("Again", voiceID: "v1", speed: .normal)
        synthesizer.finish()
        XCTAssertEqual(controller.currentText, "Again")
    }

    func testChangeVoiceWhileSpeakingRestartsFromCurrentWordWithNewVoice() {
        makeController()
        controller.speak("Hello brave new world", voiceID: "v1", speed: .normal)
        synthesizer.progress(to: 6)

        controller.changeVoice("v2")

        XCTAssertEqual(synthesizer.calls.suffix(2), [
            .stop,
            .speak(text: "brave new world", voiceID: "v2", speed: .normal),
        ])
        XCTAssertEqual(controller.state, .speaking)
        XCTAssertEqual(controller.currentVoiceID, "v2")
        XCTAssertEqual(controller.currentText, "Hello brave new world")
    }

    func testChangeVoiceToSameVoiceDoesNothing() {
        makeController()
        controller.speak("Hello", voiceID: "v1", speed: .normal)
        controller.changeVoice("v1")
        XCTAssertEqual(synthesizer.calls, [.speak(text: "Hello", voiceID: "v1", speed: .normal)])
    }

    func testChangeVoiceWhilePausedAppliesOnResume() {
        makeController()
        controller.speak("Hello brave new world", voiceID: "v1", speed: .normal)
        synthesizer.progress(to: 6)
        controller.pause()

        controller.changeVoice(nil)
        XCTAssertEqual(controller.state, .paused)
        XCTAssertNil(controller.currentVoiceID)

        controller.resume()
        XCTAssertEqual(synthesizer.calls.last, .speak(text: "brave new world", voiceID: nil, speed: .normal))
        XCTAssertFalse(synthesizer.calls.contains(.resume))
    }

    func testChangeVoiceWhileIdleDoesNothing() {
        makeController()
        controller.changeVoice("v2")
        XCTAssertEqual(synthesizer.calls, [])
        XCTAssertNil(controller.currentVoiceID)
    }

    func testChangeSpeedToSameSpeedDoesNothing() {
        makeController()
        controller.speak("Hello", voiceID: "v1", speed: .normal)
        controller.changeSpeed(.normal)
        XCTAssertEqual(synthesizer.calls, [.speak(text: "Hello", voiceID: "v1", speed: .normal)])
    }
}
