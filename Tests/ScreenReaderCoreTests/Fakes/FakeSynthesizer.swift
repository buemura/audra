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
    var onProgress: (@MainActor (Int) -> Void)?
    private(set) var calls: [Call] = []

    func speak(_ text: String, voiceID: String?, rate: Float) {
        calls.append(.speak(text: text, voiceID: voiceID, rate: rate))
    }

    func stop() { calls.append(.stop) }
    func pause() { calls.append(.pause) }
    func resume() { calls.append(.resume) }

    /// Simulates the current utterance ending naturally.
    func finish() { onFinish?() }

    /// Simulates the engine starting the word at `offset` (UTF-16) of the current utterance.
    func progress(to offset: Int) { onProgress?(offset) }
}
