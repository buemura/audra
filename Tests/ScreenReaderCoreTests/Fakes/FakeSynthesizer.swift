@testable import ScreenReaderCore

@MainActor
class FakeSynthesizer: SpeechSynthesizing {
    enum Call: Equatable {
        case speak(text: String, voiceID: String?, speed: SpeechSpeed)
        case stop
        case pause
        case resume
    }

    var onFinish: (@MainActor () -> Void)?
    var onProgress: (@MainActor (Int) -> Void)?
    private(set) var calls: [Call] = []

    func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        calls.append(.speak(text: text, voiceID: voiceID, speed: speed))
    }

    func stop() { calls.append(.stop) }
    func pause() { calls.append(.pause) }
    func resume() { calls.append(.resume) }

    /// Simulates the current utterance ending naturally.
    func finish() { onFinish?() }

    /// Simulates the engine starting the word at `offset` (UTF-16) of the current utterance.
    func progress(to offset: Int) { onProgress?(offset) }
}

@MainActor
final class FakeFallibleSynthesizer: FakeSynthesizer, FallibleSpeechSynthesizing {
    var onEngineFailure: (@MainActor (Int) -> Void)?

    /// Simulates the engine giving up; speech should continue from `offset`.
    func failEngine(at offset: Int) { onEngineFailure?(offset) }
}
