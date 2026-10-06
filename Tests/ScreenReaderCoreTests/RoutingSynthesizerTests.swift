import XCTest
@testable import ScreenReaderCore

@MainActor
final class RoutingSynthesizerTests: XCTestCase {
    private var system: FakeSynthesizer!
    private var kokoro: FakeFallibleSynthesizer!
    private var routing: RoutingSynthesizer!
    private var fallbackTexts: [String] = []
    private var progress: [Int] = []
    private var finishCount = 0

    private func makeRouting() {
        system = FakeSynthesizer()
        kokoro = FakeFallibleSynthesizer()
        fallbackTexts = []
        progress = []
        finishCount = 0
        routing = RoutingSynthesizer(system: system, kokoro: kokoro, fallbackVoiceID: { [unowned self] text in
            self.fallbackTexts.append(text)
            return "fallback.voice"
        })
        routing.onProgress = { [unowned self] in self.progress.append($0) }
        routing.onFinish = { [unowned self] in self.finishCount += 1 }
    }

    func testKokoroVoicesGoToKokoroAndOthersToTheSystem() {
        makeRouting()
        routing.speak("Hi", voiceID: "kokoro.af_heart", speed: .normal)
        XCTAssertEqual(kokoro.calls, [.speak(text: "Hi", voiceID: "kokoro.af_heart", speed: .normal)])
        XCTAssertEqual(system.calls, [])

        routing.speak("Hi", voiceID: "en.samantha", speed: .double)
        XCTAssertEqual(kokoro.calls.last, .stop)
        XCTAssertEqual(system.calls, [.speak(text: "Hi", voiceID: "en.samantha", speed: .double)])

        routing.speak("Hi", voiceID: nil, speed: .normal)
        XCTAssertEqual(system.calls.suffix(2), [.stop, .speak(text: "Hi", voiceID: nil, speed: .normal)])
    }

    func testControlsGoToTheActiveEngine() {
        makeRouting()
        routing.speak("Hi", voiceID: "kokoro.af_heart", speed: .normal)
        routing.pause()
        routing.resume()
        routing.stop()
        routing.pause()
        XCTAssertEqual(kokoro.calls, [.speak(text: "Hi", voiceID: "kokoro.af_heart", speed: .normal), .pause, .resume, .stop])
        XCTAssertEqual(system.calls, [])
    }

    func testOnlyTheActiveEnginesCallbacksAreForwarded() {
        makeRouting()
        routing.speak("Hi", voiceID: "kokoro.af_heart", speed: .normal)
        routing.speak("Hi", voiceID: "en.samantha", speed: .normal)
        kokoro.progress(to: 3)
        kokoro.finish()
        XCTAssertEqual(progress, [])
        XCTAssertEqual(finishCount, 0)

        system.progress(to: 2)
        system.finish()
        XCTAssertEqual(progress, [2])
        XCTAssertEqual(finishCount, 1)
    }

    func testEngineFailureContinuesWithASystemVoiceFromTheOffset() {
        makeRouting()
        routing.speak("Hello brave world", voiceID: "kokoro.af_heart", speed: .double)
        kokoro.failEngine(at: 6)
        XCTAssertEqual(fallbackTexts, ["brave world"])
        XCTAssertEqual(system.calls, [.speak(text: "brave world", voiceID: "fallback.voice", speed: .double)])

        system.progress(to: 6) // "world"
        XCTAssertEqual(progress, [12])
        system.finish()
        XCTAssertEqual(finishCount, 1)
    }

    func testFailureFromAnInactiveEngineIsIgnored() {
        makeRouting()
        routing.speak("Hi", voiceID: "en.samantha", speed: .normal)
        kokoro.failEngine(at: 0)
        XCTAssertEqual(system.calls.count, 1)
    }

    func testEngineFailureAtTheEndFinishesInsteadOfSpeaking() {
        makeRouting()
        routing.speak("Hi", voiceID: "kokoro.af_heart", speed: .normal)
        kokoro.failEngine(at: 2)
        XCTAssertEqual(system.calls, [])
        XCTAssertEqual(finishCount, 1)
    }
}