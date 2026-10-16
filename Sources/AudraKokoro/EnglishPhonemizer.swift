import Foundation
import MisakiSwift
import AudraCore

/// English text → Kokoro phonemes with MisakiSwift, a port of the G2P Kokoro was trained with.
/// The G2P (dictionaries and an MLX model) is loaded on first use, not on the caller's thread at init.
public final class EnglishPhonemizer: Phonemizer, @unchecked Sendable {
    private let british: Bool
    private var g2p: EnglishG2P?
    private let lock = NSLock()

    public init(british: Bool) {
        self.british = british
    }

    public func phonemize(_ text: String) throws -> String {
        lock.withLock {
            let g2p = self.g2p ?? EnglishG2P(british: british)
            self.g2p = g2p
            // Misaki marks words it can't pronounce with "❓"; Kokoro can't voice it.
            return g2p.phonemize(text: text).0.replacingOccurrences(of: "❓", with: "")
        }
    }
}
