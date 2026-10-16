import Foundation

/// Converts text in one language to the phoneme symbols Kokoro was trained on (misaki's set).
public protocol Phonemizer: Sendable {
    func phonemize(_ text: String) throws -> String
}

/// Uses `primary`, and `fallback` for text `primary` throws on.
public struct FallbackPhonemizer: Phonemizer {
    private let primary: any Phonemizer
    private let fallback: (any Phonemizer)?

    public init(primary: any Phonemizer, fallback: (any Phonemizer)?) {
        self.primary = primary
        self.fallback = fallback
    }

    public func phonemize(_ text: String) throws -> String {
        do {
            return try primary.phonemize(text)
        } catch {
            guard let fallback else { throw error }
            return try fallback.phonemize(text)
        }
    }
}

/// Joins per-word phonemes and punctuation the way misaki does for Kokoro: words separated by
/// single spaces, closing punctuation attached to the previous word, opening punctuation to the next.
struct PhonemeJoiner {
    private var result = ""
    private static let opening: Set<Character> = ["\u{201C}", "(", "[", "«", "¿", "¡"]

    mutating func appendWord(_ phonemes: String) {
        guard !phonemes.isEmpty else { return }
        if let last = result.last, last != " ", !Self.opening.contains(last) { result += " " }
        result += phonemes
    }

    mutating func appendPunctuation(_ mark: String) {
        guard let first = mark.first else { return }
        if Self.opening.contains(first) {
            if let last = result.last, last != " " { result += " " }
        } else {
            while result.last == " " { result.removeLast() }
        }
        result += mark
    }

    var text: String {
        result.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }
}
