import Foundation

/// The Kokoro neural network. The real implementation (MLX) lives in ScreenReaderKokoro.
public protocol KokoroEngine: AnyObject, Sendable {
    /// 24 kHz mono samples of `phonemes` spoken by the Kokoro voice `voiceID` (e.g. "af_heart").
    func synthesize(phonemes: String, voiceID: String, speed: Float) async throws -> [Float]
    /// Runs the phonemizer where the engine runs, so MLX-based phonemizers never run concurrently
    /// with synthesis (and stay off the main thread).
    func phonemize(_ text: String, using phonemizer: any Phonemizer) async throws -> String
}

public enum KokoroEngineError: Error, Equatable {
    /// The model or voice files can't be loaded; readings should fall back to system voices.
    case unavailable
    /// More than `KokoroSynthesizer.maxPhonemes` phonemes.
    case tooManyTokens
}
