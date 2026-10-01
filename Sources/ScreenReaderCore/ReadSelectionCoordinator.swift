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
    private var voiceSubscription: AnyCancellable?

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

        // Likewise for voice settings. @Published emits before the property updates, so use the
        // emitted values rather than reading them back from `settings`.
        voiceSubscription = Publishers.CombineLatest3(
            settings.$defaultVoiceID,
            settings.$languageVoiceOverrides,
            settings.$autoDetectLanguage
        )
        .dropFirst()
        .sink { [weak self] defaultVoiceID, overrides, autoDetect in
            self?.reselectVoice(defaultVoiceID: defaultVoiceID, languageOverrides: overrides, autoDetect: autoDetect)
        }
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

        let voiceID = selectVoice(
            for: text,
            defaultVoiceID: settings.defaultVoiceID,
            languageOverrides: settings.languageVoiceOverrides,
            autoDetect: settings.autoDetectLanguage
        )
        speech.speak(text, voiceID: voiceID, rate: settings.speed.utteranceRate)
    }

    /// Switches the voice of the reading in progress if the new settings pick a different one.
    private func reselectVoice(defaultVoiceID: String?, languageOverrides: [String: String], autoDetect: Bool) {
        guard speech.state != .idle, let text = speech.currentText else { return }
        let voiceID = selectVoice(
            for: text,
            defaultVoiceID: defaultVoiceID,
            languageOverrides: languageOverrides,
            autoDetect: autoDetect
        )
        speech.changeVoice(voiceID)
    }

    private func selectVoice(
        for text: String,
        defaultVoiceID: String?,
        languageOverrides: [String: String],
        autoDetect: Bool
    ) -> String? {
        let language = autoDetect ? languageDetector.detectLanguage(of: text) : nil
        return VoiceSelector.selectVoice(
            detectedLanguage: language,
            defaultVoiceID: defaultVoiceID,
            languageOverrides: languageOverrides,
            availableVoices: availableVoices()
        )
    }
}
