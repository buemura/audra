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
    /// How much of `currentText` has been read, from 0 to 1.
    @Published public private(set) var progress: Double = 0
    private let synthesizer: any SpeechSynthesizing

    // What is being spoken, so it can be restarted at a new speed.
    private var text = ""
    private var voiceID: String?
    private var speed: SpeechSpeed = .normal
    /// UTF-16 offset in `text` of the last position the engine reported (a word for system voices, a sentence for Kokoro).
    private var spokenOffset = 0
    /// UTF-16 length of `currentText` already skipped by restarts, so `progress` spans the whole reading.
    private var restartedOffset = 0
    /// Set when the speed or voice changed while paused: resuming must restart rather than continue.
    private var restartOnResume = false

    public init(synthesizer: any SpeechSynthesizing) {
        self.synthesizer = synthesizer
        synthesizer.onFinish = { [weak self] in
            self?.state = .idle
            self?.progress = 1
        }
        synthesizer.onProgress = { [weak self] offset in
            guard let self else { return }
            spokenOffset = offset
            updateProgress()
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
        restartedOffset = 0
        progress = 0
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
        let consumed = min(spokenOffset, (text as NSString).length)
        let remaining = (text as NSString).substring(from: consumed)
        text = remaining
        restartedOffset += consumed
        spokenOffset = 0
        synthesizer.stop()
        if state == .paused {
            restartOnResume = true
        } else {
            synthesizer.speak(remaining, voiceID: voiceID, speed: speed)
        }
    }

    private func updateProgress() {
        let total = ((currentText ?? "") as NSString).length
        guard total > 0 else { return }
        progress = min(1, Double(restartedOffset + spokenOffset) / Double(total))
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
