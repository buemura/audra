import XCTest
@testable import ScreenReaderCore

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
        let suiteName = "ScreenReaderTests.\(UUID().uuidString)"
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
            .speak(text: "Olá mundo", voiceID: "pt.luciana", rate: SpeechSpeed.double.utteranceRate),
        ])
        XCTAssertEqual(speech.state, .speaking)
    }

    func testTrimsSurroundingWhitespace() async {
        let coordinator = makeCoordinator(selection: "\n  Hello there \t", detectedLanguage: "en")
        await coordinator.toggle()
        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "Hello there", voiceID: "en.samantha", rate: SpeechSpeed.normal.utteranceRate),
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
        speech.speak("Earlier", voiceID: nil, rate: 0.5)

        await coordinator.toggle()

        XCTAssertEqual(speech.state, .idle)
        XCTAssertEqual(textSource.callCount, 0)
        XCTAssertEqual(synthesizer.calls.last, .stop)
    }

    func testToggleWhilePausedStops() async {
        let coordinator = makeCoordinator(selection: "Hello", detectedLanguage: "en")
        speech.speak("Earlier", voiceID: nil, rate: 0.5)
        speech.pause()

        await coordinator.toggle()

        XCTAssertEqual(speech.state, .idle)
        XCTAssertEqual(textSource.callCount, 0)
    }

    func testReadSelectionWhileSpeakingReplacesSpeech() async {
        let coordinator = makeCoordinator(selection: "New text", detectedLanguage: "en")
        speech.speak("Earlier", voiceID: nil, rate: 0.5)

        await coordinator.readSelection()

        XCTAssertEqual(synthesizer.calls.suffix(2), [
            .stop,
            .speak(text: "New text", voiceID: "en.samantha", rate: SpeechSpeed.normal.utteranceRate),
        ])
        XCTAssertEqual(speech.state, .speaking)
    }

    func testAutoDetectOffUsesDefaultVoice() async {
        let coordinator = makeCoordinator(selection: "Olá mundo", detectedLanguage: "pt")
        settings.autoDetectLanguage = false
        settings.defaultVoiceID = english.id

        await coordinator.toggle()

        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "Olá mundo", voiceID: "en.samantha", rate: SpeechSpeed.normal.utteranceRate),
        ])
    }

    func testLanguageOverrideIsUsed() async {
        let coordinator = makeCoordinator(selection: "Hello", detectedLanguage: "en")
        settings.setVoiceOverride(portuguese.id, forLanguage: "en")

        await coordinator.toggle()

        XCTAssertEqual(synthesizer.calls, [
            .speak(text: "Hello", voiceID: "pt.luciana", rate: SpeechSpeed.normal.utteranceRate),
        ])
    }

    func testChangingSpeedWhileSpeakingAppliesImmediately() async {
        let coordinator = makeCoordinator(selection: "Hello there", detectedLanguage: "en")
        await coordinator.toggle()

        settings.speed = .double

        XCTAssertEqual(synthesizer.calls.last, .speak(
            text: "Hello there", voiceID: "en.samantha", rate: SpeechSpeed.double.utteranceRate
        ))
        XCTAssertEqual(speech.state, .speaking)
    }
}
