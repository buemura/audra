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
