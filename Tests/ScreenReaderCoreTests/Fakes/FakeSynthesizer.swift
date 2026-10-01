@testable import ScreenReaderCore

@MainActor
final class FakeSynthesizer: SpeechSynthesizing {
    enum Call: Equatable {
        case speak(text: String, voiceID: String?, rate: Float)
        case stop
        case pause
        case resume
    }

    var onFinish: (@MainActor () -> Void)?
    private(set) var calls: [Call] = []

    func speak(_ text: String, voiceID: String?, rate: Float) {
        calls.append(.speak(text: text, voiceID: voiceID, rate: rate))
    }

    func stop() { calls.append(.stop) }
    func pause() { calls.append(.pause) }
    func resume() { calls.append(.resume) }

    /// Simulates the current utterance ending naturally.
    func finish() { onFinish?() }
}
