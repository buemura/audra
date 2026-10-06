import XCTest
@testable import ScreenReaderCore

@MainActor
final class KokoroSynthesizerTests: XCTestCase {
    private var engine: FakeKokoroEngine!
    private var output: FakeAudioOutput!
    private var synthesizer: KokoroSynthesizer!
    private var phonemizer = FakePhonemizer()
    private var hasPhonemizer = true
    private var requestedLanguages: [KokoroLanguage] = []
    private var progress: [Int] = []
    private var failures: [Int] = []
    private var finishCount = 0

    private func makeSynthesizer() {
        engine = FakeKokoroEngine()
        output = FakeAudioOutput()
        requestedLanguages = []
        progress = []
        failures = []
        finishCount = 0
        synthesizer = KokoroSynthesizer(engine: engine, output: output, phonemizer: { [unowned self] language in
            self.requestedLanguages.append(language)
            return self.hasPhonemizer ? self.phonemizer : nil
        })
        synthesizer.onProgress = { [unowned self] in self.progress.append($0) }
        synthesizer.onFinish = { [unowned self] in self.finishCount += 1 }
        synthesizer.onEngineFailure = { [unowned self] in self.failures.append($0) }
    }

    /// Lets the synthesis task run until it waits on the engine or for a free buffer slot.
    private func settle() async {
        for _ in 0..<100 { await Task.yield() }
    }

    private func speak(_ text: String, voiceID: String = "kokoro.af_heart", speed: SpeechSpeed = .normal) async {
        synthesizer.speak(text, voiceID: voiceID, speed: speed)
        await settle()
    }

    func testSynthesizesTwoSentencesAheadAndPlaysInOrder() async {
        makeSynthesizer()
        await speak("One. Two. Three. Four. Five.")
        XCTAssertEqual(engine.calls.map(\.phonemes), ["One.", "Two.", "Three."])
        XCTAssertEqual(output.queue.count, 3)
        XCTAssertEqual(progress, [0])

        output.finishCurrent()
        await settle()
        XCTAssertEqual(engine.calls.map(\.phonemes), ["One.", "Two.", "Three.", "Four."])
        XCTAssertEqual(progress, [0, 5])
    }

    func testFinishesAfterTheLastSentencePlays() async {
        makeSynthesizer()
        await speak("One. Two.")
        output.finishCurrent()
        XCTAssertEqual(progress, [0, 5])
        XCTAssertEqual(finishCount, 0)
        output.finishCurrent()
        XCTAssertEqual(finishCount, 1)
    }

    func testEmptyTextFinishesImmediately() async {
        makeSynthesizer()
        await speak("   ")
        XCTAssertEqual(finishCount, 1)
        XCTAssertEqual(engine.calls, [])
    }

    func testUsesTheVoicesLanguageAndSpeed() async {
        makeSynthesizer()
        await speak("Olá.", voiceID: "kokoro.pf_dora", speed: .oneAndHalf)
        XCTAssertEqual(requestedLanguages, [.brazilianPortuguese])
        XCTAssertEqual(engine.calls, [FakeKokoroEngine.Call(phonemes: "Olá.", voiceID: "pf_dora", speed: 1.5)])
    }

    func testStopDropsQueuedAudioAndPendingSentences() async {
        makeSynthesizer()
        await speak("One. Two. Three. Four. Five.")
        synthesizer.stop()
        XCTAssertEqual(output.stopCount, 1)
        XCTAssertTrue(output.queue.isEmpty)
        await settle()
        XCTAssertEqual(engine.calls.count, 3)
        XCTAssertEqual(finishCount, 0)
    }

    func testResultArrivingAfterStopIsDiscarded() async {
        makeSynthesizer()
        engine.holdsCalls = true
        await speak("One.")
        XCTAssertEqual(engine.calls.count, 1)
        synthesizer.stop()
        engine.release()
        await settle()
        XCTAssertEqual(output.scheduledCount, 0)
        XCTAssertEqual(progress, [])
        XCTAssertEqual(finishCount, 0)
    }

    func testSpeakReplacesTheCurrentReading() async {
        makeSynthesizer()
        await speak("Old one. Old two.")
        await speak("New.")
        XCTAssertEqual(output.stopCount, 1)
        XCTAssertEqual(engine.calls.last?.phonemes, "New.")
        XCTAssertEqual(output.queue.count, 1)
        output.finishCurrent()
        XCTAssertEqual(finishCount, 1)
    }

    func testSkipsASentenceThatFailsToPhonemize() async {
        makeSynthesizer()
        phonemizer.failing = ["Two."]
        await speak("One. Two. Three.")
        XCTAssertEqual(engine.calls.map(\.phonemes), ["One.", "Three."])
        output.finishCurrent()
        output.finishCurrent()
        XCTAssertEqual(finishCount, 1)
    }

    func testSkipsASentenceTheEngineFailsOn() async {
        makeSynthesizer()
        engine.failingPhonemes = ["Two."]
        await speak("One. Two. Three.")
        XCTAssertEqual(output.scheduledCount, 2)
        XCTAssertEqual(failures, [])
    }

    func testUnavailableEngineHandsOverFromTheStart() async {
        makeSynthesizer()
        engine.error = KokoroEngineError.unavailable
        await speak("One. Two.")
        XCTAssertEqual(failures, [0])
        XCTAssertEqual(finishCount, 0)
    }

    func testUnavailableEngineHandsOverFromTheSentencePlaying() async {
        makeSynthesizer()
        engine.unavailablePhonemes = ["Four."]
        await speak("One. Two. Three. Four.")
        output.finishCurrent() // "Two." starts playing, "Four." gets synthesized and fails
        await settle()
        XCTAssertEqual(failures, [5])
        XCTAssertGreaterThanOrEqual(output.stopCount, 1)
        XCTAssertEqual(finishCount, 0)
    }

    func testUnknownVoiceOrMissingPhonemizerFailsImmediately() {
        makeSynthesizer()
        synthesizer.speak("Hi.", voiceID: "pt.luciana", speed: .normal)
        XCTAssertEqual(failures, [0])
        hasPhonemizer = false
        synthesizer.speak("Hi.", voiceID: "kokoro.af_heart", speed: .normal)
        XCTAssertEqual(failures, [0, 0])
        XCTAssertEqual(engine.calls, [])
        hasPhonemizer = true
    }

    func testPauseAndResumeGoToTheOutputWhileReading() async {
        makeSynthesizer()
        synthesizer.pause()
        XCTAssertEqual(output.pauseCount, 0)
        await speak("One.")
        synthesizer.pause()
        synthesizer.resume()
        XCTAssertEqual(output.pauseCount, 1)
        XCTAssertEqual(output.resumeCount, 1)
    }

    func testOutputFailingToStartHandsOverToTheSystemVoice() async {
        makeSynthesizer()
        output.failsToStart = true
        await speak("One. Two.")
        XCTAssertEqual(failures, [0])
        XCTAssertEqual(finishCount, 0)
        XCTAssertEqual(output.scheduledCount, 0)
    }

    func testHandOverAfterTheQueueDrainedStartsAtTheFailingSentence() async {
        makeSynthesizer()
        engine.unavailablePhonemes = ["Two."]
        engine.holdsCalls = true
        await speak("One. Two.")
        engine.release()
        engine.holdsCalls = true // hold the "Two." call
        await settle()
        XCTAssertEqual(output.queue.count, 1)
        output.finishCurrent() // queue drained
        XCTAssertTrue(output.queue.isEmpty)
        engine.release()
        await settle()
        XCTAssertEqual(failures, [5])
        XCTAssertEqual(finishCount, 0)
    }

    func testPlaybackFailureHandsOverFromTheSentencePlaying() async {
        makeSynthesizer()
        await speak("One. Two. Three.")
        output.finishCurrent() // "Two." starts playing
        let callsBeforeFailure = engine.calls
        output.failPlayback()
        await settle()
        XCTAssertEqual(failures, [5])
        XCTAssertEqual(finishCount, 0)
        XCTAssertEqual(engine.calls, callsBeforeFailure)
    }

    func testPhonemizesEverySentenceThroughTheEngine() async {
        makeSynthesizer()
        await speak("One. Two. Three.")
        XCTAssertEqual(engine.phonemizedTexts, ["One.", "Two.", "Three."])
    }

    func testOverLongSentenceIsSplitUnderTheTokenLimit() async {
        makeSynthesizer()
        let sentence = Array(repeating: "palavra", count: 100).joined(separator: ", ") + "."
        await speak(sentence)
        XCTAssertEqual(engine.calls.count, 2)
        XCTAssertTrue(engine.calls.allSatisfy { $0.phonemes.unicodeScalars.count <= KokoroSynthesizer.maxPhonemes })
        XCTAssertEqual(output.scheduledCount, 1)
    }
}
