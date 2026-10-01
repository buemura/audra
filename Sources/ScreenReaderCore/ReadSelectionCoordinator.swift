import Combine
import Foundation

/// Glue between the hotkey/menu and the speech engine:
/// capture selection → detect language → choose voice → speak.
@MainActor
public final class ReadSelectionCoordinator {
    private let textSource: any SelectedTextSource
    private let speech: SpeechController
    private let settings: SettingsStore
    private let languageDetector: any LanguageDetecting
    private let availableVoices: () -> [VoiceInfo]
    private let onNoText: () -> Void
    private var isCapturing = false
    private var speedSubscription: AnyCancellable?

    public init(
        textSource: any SelectedTextSource,
        speech: SpeechController,
        settings: SettingsStore,
        languageDetector: any LanguageDetecting,
        availableVoices: @escaping () -> [VoiceInfo],
        onNoText: @escaping () -> Void
    ) {
        self.textSource = textSource
        self.speech = speech
        self.settings = settings
        self.languageDetector = languageDetector
        self.availableVoices = availableVoices
        self.onNoText = onNoText

        // Apply speed changes to speech that is already playing, not just the next read.
        speedSubscription = settings.$speed
            .dropFirst()
            .sink { [weak speech] speed in speech?.changeRate(speed.utteranceRate) }
    }

    /// Hotkey behaviour: stop if anything is playing or paused, otherwise read the selection.
    public func toggle() async {
        if speech.state != .idle {
            speech.stop()
            return
        }
        await readSelection()
    }

    /// Reads the current selection aloud, replacing any speech in progress.
    public func readSelection() async {
        // Ignore repeated presses while a capture (up to ~300 ms with the clipboard fallback) is running.
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        let text = (await textSource.selectedText() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            onNoText()
            return
        }

        let language = settings.autoDetectLanguage ? languageDetector.detectLanguage(of: text) : nil
        let voiceID = VoiceSelector.selectVoice(
            detectedLanguage: language,
            defaultVoiceID: settings.defaultVoiceID,
            languageOverrides: settings.languageVoiceOverrides,
            availableVoices: availableVoices()
        )
        speech.speak(text, voiceID: voiceID, rate: settings.speed.utteranceRate)
    }
}
