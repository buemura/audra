import Foundation
import MisakiSwift
import ScreenReaderCore

/// English text → Kokoro phonemes with MisakiSwift, a port of the G2P Kokoro was trained with.
public final class EnglishPhonemizer: Phonemizer, @unchecked Sendable {
    private let g2p: EnglishG2P
    private let lock = NSLock()

    public init(british: Bool) {
        g2p = EnglishG2P(british: british)
    }

    public func phonemize(_ text: String) throws -> String {
        lock.withLock {
            // Misaki marks words it can't pronounce with "❓"; Kokoro can't voice it.
            g2p.phonemize(text: text).0.replacingOccurrences(of: "❓", with: "")
        }
    }
}
