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
    private let synthesizer: any SpeechSynthesizing

    public init(synthesizer: any SpeechSynthesizing) {
        self.synthesizer = synthesizer
        synthesizer.onFinish = { [weak self] in
            self?.state = .idle
        }
    }

    /// Speaks `text`, replacing anything currently playing.
    public func speak(_ text: String, voiceID: String?, rate: Float) {
        if state != .idle { synthesizer.stop() }
        synthesizer.speak(text, voiceID: voiceID, rate: rate)
        state = .speaking
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
        synthesizer.resume()
        state = .speaking
    }

    public func togglePause() {
        state == .paused ? resume() : pause()
    }
}
