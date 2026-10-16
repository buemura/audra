//
//  Kokoro-tts-lib
//
import Foundation

/// Utility class for tokenizing the phonemized text.
/// Phonemize the text first before calling this method.
/// Returns tokenized array that can then be passed to TTS system.
final class Tokenizer {
  /// Private constructor to prevent instantiation.
  private init() {}

  /// Tokenize the phonemized text.
  /// - Parameters:
  ///   - phonemizedText: Phonemized text to tokenize
  /// - Returns: Tokenized array that can then be passed to TTS system
  static func tokenize(phonemizedText text: String) -> [Int] {
    guard let vocab = KokoroConfig.config?.vocab else { return [] }
    // One token per Unicode scalar, like Kokoro's Python tokenizer. (Audra patch: mapping
    // Characters looked up clusters such as "ɐ̃" — vowel + combining tilde — which aren't in the
    // vocabulary, silently dropping Portuguese and French nasal vowels.)
    return text.unicodeScalars.compactMap { vocab[String($0)] }
  }
}
