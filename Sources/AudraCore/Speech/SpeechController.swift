import Combine
import Foundation

/// Tracks playback state on top of a `SpeechSynthesizing` engine.
@MainActor
public final class SpeechController: ObservableObject {
    public enum State: Equatable {
        case idle
        case speaking
        case paused
    }

    @Published public private(set) var state: State = .idle
    /// The text of the current (or last) reading, as originally given to `speak`.
    /// Kept in memory only; never persisted.
    @Published public private(set) var currentText: String?
    /// The voice of the current (or last) reading. nil = system default.
    @Published public private(set) var currentVoiceID: String?
    private let synthesizer: any SpeechSynthesizing

    // What is being spoken, so it can be restarted at a new speed.
    private var text = ""
    private var voiceID: String?
    private var speed: SpeechSpeed = .normal
    /// UTF-16 offset in `text` of the last position the engine reported (a word for system voices, a sentence for Kokoro).
    private var spokenOffset = 0
    /// Set when the speed or voice changed while paused: resuming must restart rather than continue.
    private var restartOnResume = false

    public init(synthesizer: any SpeechSynthesizing) {
        self.synthesizer = synthesizer
        synthesizer.onFinish = { [weak self] in
            self?.state = .idle
        }
        synthesizer.onProgress = { [weak self] offset in
            self?.spokenOffset = offset
        }
    }

    /// Speaks `text`, replacing anything currently playing.
    public func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        if state != .idle { synthesizer.stop() }
        currentText = text
        currentVoiceID = voiceID
        self.text = text
        self.voiceID = voiceID
        self.speed = speed
        spokenOffset = 0
        restartOnResume = false
        synthesizer.speak(text, voiceID: voiceID, speed: speed)
        state = .speaking
    }

    /// Applies a new speed to speech in progress. Engines can't change speed mid-utterance,
    /// so the rest of the text is restarted from the last reported position. While paused,
    /// the restart happens on resume.
    public func changeSpeed(_ speed: SpeechSpeed) {
        guard state != .idle, speed != self.speed else { return }
        self.speed = speed
        restartFromCurrentWord()
    }

    /// Applies a new voice to speech in progress, restarting the rest of the text from the
    /// current word like `changeSpeed`. nil = system default.
    public func changeVoice(_ voiceID: String?) {
        guard state != .idle, voiceID != self.voiceID else { return }
        self.voiceID = voiceID
        currentVoiceID = voiceID
        restartFromCurrentWord()
    }

    private func restartFromCurrentWord() {
        let remaining = (text as NSString).substring(from: min(spokenOffset, (text as NSString).length))
        text = remaining
        spokenOffset = 0
        synthesizer.stop()
        if state == .paused {
            restartOnResume = true
        } else {
            synthesizer.speak(remaining, voiceID: voiceID, speed: speed)
        }
    }

    public func stop() {
        guard state != .idle else { return }
        synthesizer.stop()
        state = .idle
    }

    public func pause() {
        guard state == .speaking else { return }
        synthesizer.pause()
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        if restartOnResume {
            restartOnResume = false
            synthesizer.speak(text, voiceID: voiceID, speed: speed)
        } else {
            synthesizer.resume()
        }
        state = .speaking
    }

    public func togglePause() {
        state == .paused ? resume() : pause()
    }
}
