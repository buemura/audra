import Foundation

/// Abstraction over the system speech engine so `SpeechController` can be tested.
@MainActor
public protocol SpeechSynthesizing: AnyObject {
    /// Called when the current utterance finishes on its own. Not called after `stop()`.
    var onFinish: (@MainActor () -> Void)? { get set }
    func speak(_ text: String, voiceID: String?, rate: Float)
    func stop()
    func pause()
    func resume()
}
