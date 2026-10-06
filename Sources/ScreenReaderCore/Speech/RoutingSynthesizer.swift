import Foundation

/// Sends Kokoro voices to the Kokoro synthesizer and everything else to the system synthesizer.
/// If Kokoro gives up mid-reading, the rest of the text continues with a system voice.
@MainActor
public final class RoutingSynthesizer: SpeechSynthesizing {
    public var onFinish: (@MainActor () -> Void)?
    public var onProgress: (@MainActor (Int) -> Void)?

    private let system: any SpeechSynthesizing
    private let kokoro: any FallibleSpeechSynthesizing
    private let fallbackVoiceID: @MainActor (String) -> String?
    private var active: (any SpeechSynthesizing)?
    private var text = ""
    private var speed: SpeechSpeed = .normal
    /// Where the active engine's text starts within `text` (non-zero after a fallback).
    private var progressBase = 0
    /// So a fallback that starts while paused stays paused.
    private var isPaused = false

    public init(
        system: any SpeechSynthesizing,
        kokoro: any FallibleSpeechSynthesizing,
        fallbackVoiceID: @escaping @MainActor (String) -> String?
    ) {
        self.system = system
        self.kokoro = kokoro
        self.fallbackVoiceID = fallbackVoiceID
        system.onFinish = { [weak self, weak system] in self?.engineFinished(system) }
        system.onProgress = { [weak self, weak system] offset in self?.engineProgressed(system, to: offset) }
        kokoro.onFinish = { [weak self, weak kokoro] in self?.engineFinished(kokoro) }
        kokoro.onProgress = { [weak self, weak kokoro] offset in self?.engineProgressed(kokoro, to: offset) }
        kokoro.onEngineFailure = { [weak self, weak kokoro] offset in self?.engineFailed(kokoro, at: offset) }
    }

    public func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        let previous = active
        active = nil
        previous?.stop()
        self.text = text
        self.speed = speed
        progressBase = 0
        isPaused = false
        let engine: any SpeechSynthesizing = KokoroVoiceCatalog.isKokoroVoiceID(voiceID) ? kokoro : system
        active = engine
        engine.speak(text, voiceID: voiceID, speed: speed)
    }

    public func stop() {
        let previous = active
        active = nil
        isPaused = false
        previous?.stop()
    }

    public func pause() {
        isPaused = true
        active?.pause()
    }

    public func resume() {
        isPaused = false
        active?.resume()
    }

    private func isActive(_ engine: (any SpeechSynthesizing)?) -> Bool {
        guard let engine, let active else { return false }
        return engine === active
    }

    private func engineFinished(_ engine: (any SpeechSynthesizing)?) {
        guard isActive(engine) else { return }
        active = nil
        onFinish?()
    }

    private func engineProgressed(_ engine: (any SpeechSynthesizing)?, to offset: Int) {
        guard isActive(engine) else { return }
        onProgress?(progressBase + offset)
    }

    private func engineFailed(_ engine: (any SpeechSynthesizing)?, at offset: Int) {
        guard isActive(engine) else { return }
        let length = (text as NSString).length
        let start = min(progressBase + offset, length)
        guard start < length else {
            active = nil
            onFinish?()
            return
        }
        let remaining = (text as NSString).substring(from: start)
        progressBase = start
        active = system
        system.speak(remaining, voiceID: fallbackVoiceID(remaining), speed: speed)
        if isPaused { system.pause() }
    }
}