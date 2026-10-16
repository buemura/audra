import Combine
import XCTest
@testable import AudraCore

@MainActor
final class PlayerViewModelTests: XCTestCase {
    private let portuguese = VoiceInfo(id: "pt.luciana", name: "Luciana", language: "pt-BR", quality: .standard)

    private var synthesizer: FakeSynthesizer!
    private var speech: SpeechController!
    private var settings: SettingsStore!
    private var readSelectionCount = 0

    private func makeModel() -> PlayerViewModel {
        let suiteName = "AudraTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        synthesizer = FakeSynthesizer()
        speech = SpeechController(synthesizer: synthesizer)
        settings = SettingsStore(defaults: defaults)
        readSelectionCount = 0
        let voices = [portuguese]
        return PlayerViewModel(
            speech: speech,
            settings: settings,
            availableVoices: { voices },
            readSelection: { [unowned self] in self.readSelectionCount += 1 }
        )
    }

    // MARK: Play / pause

    func testPlayPauseWhenIdleReadsSelection() async {
        let model = makeModel()
        await model.playPause()
        XCTAssertEqual(readSelectionCount, 1)
        XCTAssertEqual(synthesizer.calls, [])
    }

    func testPlayPauseWhileSpeakingPauses() async {
        let model = makeModel()
        speech.speak("Hello", voiceID: nil, speed: .normal)
        await model.playPause()
        XCTAssertEqual(speech.state, .paused)
        XCTAssertEqual(readSelectionCount, 0)
    }

    func testPlayPauseWhilePausedResumes() async {
        let model = makeModel()
        speech.speak("Hello", voiceID: nil, speed: .normal)
        speech.pause()
        await model.playPause()
        XCTAssertEqual(speech.state, .speaking)
        XCTAssertEqual(readSelectionCount, 0)
    }

    func testIsPlayingOnlyWhileSpeaking() {
        let model = makeModel()
        XCTAssertFalse(model.isPlaying)
        speech.speak("Hello", voiceID: nil, speed: .normal)
        XCTAssertTrue(model.isPlaying)
        speech.pause()
        XCTAssertFalse(model.isPlaying)
    }

    // MARK: Stop

    func testStopStopsSpeechAndIsOnlyEnabledWhileNotIdle() {
        let model = makeModel()
        XCTAssertFalse(model.canStop)
        speech.speak("Hello", voiceID: nil, speed: .normal)
        XCTAssertTrue(model.canStop)
        speech.pause()
        XCTAssertTrue(model.canStop)

        model.stop()
        XCTAssertEqual(speech.state, .idle)
        XCTAssertFalse(model.canStop)
    }

    // MARK: Speed

    func testSlowerAndFasterStepTheSpeedSetting() {
        let model = makeModel()
        settings.speed = .normal
        model.faster()
        XCTAssertEqual(settings.speed, .oneAndHalf)
        model.slower()
        model.slower()
        XCTAssertEqual(settings.speed, .half)
    }

    func testSpeedButtonsAreDisabledAndNoOpsAtTheEnds() {
        let model = makeModel()
        settings.speed = .half
        XCTAssertFalse(model.canGoSlower)
        XCTAssertTrue(model.canGoFaster)
        model.slower()
        XCTAssertEqual(settings.speed, .half)

        settings.speed = .twoAndHalf
        XCTAssertTrue(model.canGoSlower)
        XCTAssertFalse(model.canGoFaster)
        model.faster()
        XCTAssertEqual(settings.speed, .twoAndHalf)
    }

    // MARK: Labels

    func testTitleIsPlaceholderBeforeAnyReading() {
        let model = makeModel()
        XCTAssertEqual(model.title, "Select text and press play")
    }

    func testTitleCollapsesWhitespace() {
        let model = makeModel()
        speech.speak("  Hello\n\n  brave\tworld  ", voiceID: nil, speed: .normal)
        XCTAssertEqual(model.title, "Hello brave world")
    }

    func testTitleKeepsLastTextAfterStop() {
        let model = makeModel()
        speech.speak("Hello", voiceID: nil, speed: .normal)
        speech.stop()
        XCTAssertEqual(model.title, "Hello")
    }

    func testSubtitleIsSpeedOnlyBeforeAnyReading() {
        let model = makeModel()
        settings.speed = .oneAndHalf
        XCTAssertEqual(model.subtitle, "1.5x")
    }

    func testSubtitleShowsSpeedAndInstalledVoice() {
        let model = makeModel()
        settings.speed = .oneAndHalf
        speech.speak("Olá", voiceID: "pt.luciana", speed: .normal)
        XCTAssertEqual(model.subtitle, "1.5x · Luciana (pt-BR)")
    }

    func testSubtitleFallsBackToSystemVoiceForNilOrUnknownVoice() {
        let model = makeModel()
        speech.speak("Hello", voiceID: nil, speed: .normal)
        XCTAssertEqual(model.subtitle, "1x · System voice")
        speech.speak("Hello", voiceID: "not.installed", speed: .normal)
        XCTAssertEqual(model.subtitle, "1x · System voice")
    }

    func testSubtitleFollowsSpeedChanges() {
        let model = makeModel()
        speech.speak("Olá", voiceID: "pt.luciana", speed: .normal)
        model.faster()
        XCTAssertEqual(model.subtitle, "1.5x · Luciana (pt-BR)")
    }

    // MARK: Visibility

    func testShouldBeVisibleWhileSpeakingOrPausedOnly() {
        let model = makeModel()
        XCTAssertFalse(model.shouldBeVisible)
        speech.speak("Hello", voiceID: nil, speed: .normal)
        XCTAssertTrue(model.shouldBeVisible)
        speech.pause()
        XCTAssertTrue(model.shouldBeVisible)
        speech.stop()
        XCTAssertFalse(model.shouldBeVisible)
        speech.speak("Hello", voiceID: nil, speed: .normal)
        synthesizer.finish()
        XCTAssertFalse(model.shouldBeVisible)
    }

    func testShouldBeVisibleWhileIdleWhenAlwaysShowPlayerIsOn() {
        let model = makeModel()
        settings.alwaysShowPlayer = true
        XCTAssertTrue(model.shouldBeVisible)
        settings.alwaysShowPlayer = false
        XCTAssertFalse(model.shouldBeVisible)
    }

    func testShouldBeVisiblePublisherDeliversNewValues() {
        let model = makeModel()
        var received: [Bool] = []
        let subscription = model.$shouldBeVisible.sink { received.append($0) }
        speech.speak("Hello", voiceID: nil, speed: .normal)
        speech.pause()
        speech.stop()
        subscription.cancel()
        XCTAssertEqual(received, [false, true, false])
    }

    // MARK: Change notifications

    func testForwardsChangesFromSpeechAndSettings() {
        let model = makeModel()
        var changes = 0
        let subscription = model.objectWillChange.sink { changes += 1 }
        speech.speak("Hello", voiceID: nil, speed: .normal)
        let afterSpeak = changes
        XCTAssertGreaterThan(afterSpeak, 0)
        settings.speed = .double
        XCTAssertGreaterThan(changes, afterSpeak)
        subscription.cancel()
    }
}
