import XCTest
@testable import AudraCore

@MainActor
final class ReadSelectionCoordinatorTests: XCTestCase {
    private struct FixedLanguageDetector: LanguageDetecting {
        let language: String?
        func detectLanguage(of text: String) -> String? { language }
    }

    private let english = VoiceInfo(id: "en.samantha", name: "Samantha", language: "en-US", quality: .standard)
    private let portuguese = VoiceInfo(id: "pt.luciana", name: "Luciana", language: "pt-BR", quality: .standard)

    private var synthesizer: FakeSynthesizer!
    private var speech: SpeechController!
    private var settings: SettingsStore!
    private var textSource: StubTextSource!
    private var noTextCount = 0

    private func makeCoordinator(selection: String?, detectedLanguage: String? = nil) -> ReadSelectionCoordinator {
        let suiteName = "AudraTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        synthesizer = FakeSynthesizer()
        speech = SpeechController(synthesizer: synthesizer)
        settings = SettingsStore(defaults: defaults)
        textSource = StubTextSource(selection)
        noTextCount = 0
        let voices = [english, portuguese]
        return ReadSelectionCoordinator(
            textSource: textSource,
            speech: speech,
            settings: settings,
            languageDetector: FixedLanguageDetector(language: detectedLanguage),
            availableVoices: { voices },
            onNoText: { [unowned self] in self.noTextCount += 1 }
        )
    }

    func testToggleWhenIdleReadsSelectionWithDetectedLanguageVoiceAndSpeed() async {
        let coordinator = makeCoordinator(selection: "Olá mundo", detectedLanguage: "pt")
        settings.speed = .double

        await coordinator.toggle()

        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "Olá mundo", voiceID: "pt.luciana", speed: .double),
        ])
        XCTAssertEqual(speech.state, .speaking)
    }

    func testTrimsSurroundingWhitespace() async {
        let coordinator = makeCoordinator(selection: "\n  Hello there \t", detectedLanguage: "en")
        await coordinator.toggle()
        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "Hello there", voiceID: "en.samantha", speed: .normal),
        ])
    }

    func testNoSelectionCallsOnNoTextAndStaysSilent() async {
        let coordinator = makeCoordinator(selection: nil)
        await coordinator.toggle()
        XCTAssertEqual(noTextCount, 1)
        XCTAssertEqual(synthesizer.calls, [])
        XCTAssertEqual(speech.state, .idle)
    }

    func testBlankSelectionCallsOnNoText() async {
        let coordinator = makeCoordinator(selection: "   \n ")
        await coordinator.toggle()
        XCTAssertEqual(noTextCount, 1)
        XCTAssertEqual(synthesizer.calls, [])
    }

    func testToggleWhileSpeakingStopsWithoutReadingAgain() async {
        let coordinator = makeCoordinator(selection: "Hello", detectedLanguage: "en")
        speech.speak("Earlier", voiceID: nil, speed: .normal)

        await coordinator.toggle()

        XCTAssertEqual(speech.state, .idle)
        XCTAssertEqual(textSource.callCount, 0)
        XCTAssertEqual(synthesizer.calls.last, .stop)
    }

    func testToggleWhilePausedStops() async {
        let coordinator = makeCoordinator(selection: "Hello", detectedLanguage: "en")
        speech.speak("Earlier", voiceID: nil, speed: .normal)
        speech.pause()

        await coordinator.toggle()

        XCTAssertEqual(speech.state, .idle)
        XCTAssertEqual(textSource.callCount, 0)
    }

    func testReadSelectionWhileSpeakingReplacesSpeech() async {
        let coordinator = makeCoordinator(selection: "New text", detectedLanguage: "en")
        speech.speak("Earlier", voiceID: nil, speed: .normal)

        await coordinator.readSelection()

        XCTAssertEqual(synthesizer.calls.suffix(2), [
            .stop,
            .speak(text: "New text", voiceID: "en.samantha", speed: .normal),
        ])
        XCTAssertEqual(speech.state, .speaking)
    }

    func testAutoDetectOffUsesDefaultVoice() async {
        let coordinator = makeCoordinator(selection: "Olá mundo", detectedLanguage: "pt")
        settings.autoDetectLanguage = false
        settings.defaultVoiceID = english.id

        await coordinator.toggle()

        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "Olá mundo", voiceID: "en.samantha", speed: .normal),
        ])
    }

    func testLanguageOverrideIsUsed() async {
        let coordinator = makeCoordinator(selection: "Hello", detectedLanguage: "en")
        settings.setVoiceOverride(portuguese.id, forLanguage: "en")

        await coordinator.toggle()

        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "Hello", voiceID: "pt.luciana", speed: .normal),
        ])
    }

    func testChangingSpeedWhileSpeakingAppliesImmediately() async {
        let coordinator = makeCoordinator(selection: "Hello there", detectedLanguage: "en")
        await coordinator.toggle()

        settings.speed = .double

        XCTAssertEqual(synthesizer.calls.last, .speak(
            text: "Hello there", voiceID: "en.samantha", speed: .double
        ))
        XCTAssertEqual(speech.state, .speaking)
    }

    func testChangingDefaultVoiceWhileSpeakingAppliesImmediately() async {
        let coordinator = makeCoordinator(selection: "Hello there", detectedLanguage: nil)
        await coordinator.toggle()

        settings.defaultVoiceID = portuguese.id

        XCTAssertEqual(synthesizer.calls.last, .speak(
            text: "Hello there", voiceID: "pt.luciana", speed: .normal
        ))
        XCTAssertEqual(speech.state, .speaking)
    }

    func testChangingOverrideForDetectedLanguageWhileSpeakingAppliesImmediately() async {
        let coordinator = makeCoordinator(selection: "Hello there", detectedLanguage: "en")
        await coordinator.toggle()

        settings.setVoiceOverride(portuguese.id, forLanguage: "en")

        XCTAssertEqual(synthesizer.calls.last, .speak(
            text: "Hello there", voiceID: "pt.luciana", speed: .normal
        ))
    }

    func testChangingVoiceThatDoesNotApplyLeavesSpeechAlone() async {
        let coordinator = makeCoordinator(selection: "Hello there", detectedLanguage: "en")
        await coordinator.toggle()

        settings.setVoiceOverride(english.id, forLanguage: "pt")

        XCTAssertEqual(synthesizer.calls.count, 1)
    }

    func testChangingVoiceWhileIdleDoesNothing() async {
        _ = makeCoordinator(selection: "Hello there", detectedLanguage: "en")
        settings.defaultVoiceID = portuguese.id
        XCTAssertEqual(synthesizer.calls, [])
    }
}
