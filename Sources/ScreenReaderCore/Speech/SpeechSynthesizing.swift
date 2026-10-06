import Foundation

/// Abstraction over the system speech engine so `SpeechController` can be tested.
@MainActor
public protocol SpeechSynthesizing: AnyObject {
    /// Called when the current utterance finishes on its own. Not called after `stop()`.
    var onFinish: (@MainActor () -> Void)? { get set }
    /// Called when the engine starts a word of the current utterance, with the word's UTF-16 offset.
    var onProgress: (@MainActor (Int) -> Void)? { get set }
    func speak(_ text: String, voiceID: String?, speed: SpeechSpeed)
    func stop()
    func pause()
    func resume()
}

/// A synthesizer that can find out mid-reading that it can't go on, e.g. the Kokoro model is missing.
@MainActor
public protocol FallibleSpeechSynthesizing: SpeechSynthesizing {
    /// Called instead of `onFinish` when the engine can't speak the rest of the text. The argument
    /// is the UTF-16 offset in the text passed to `speak` from which another engine should continue.
    var onEngineFailure: (@MainActor (Int) -> Void)? { get set }
}
