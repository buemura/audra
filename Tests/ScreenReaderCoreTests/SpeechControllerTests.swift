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
}
