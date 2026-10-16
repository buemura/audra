import Foundation
import NaturalLanguage

/// Splits text into the units Kokoro synthesizes one at a time.
public enum SentenceSplitter {
    public struct Sentence: Equatable, Sendable {
        public let text: String
        /// UTF-16 offset of the sentence's first character in the original text.
        public let offset: Int

        public init(text: String, offset: Int) {
            self.text = text
            self.offset = offset
        }
    }

    /// Sentences of `text`, trimmed, with their UTF-16 offsets. Blank sentences are dropped.
    public static func sentences(in text: String) -> [Sentence] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [Sentence] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let raw = text[range]
            guard let start = raw.firstIndex(where: { !$0.isWhitespace }) else { return true }
            let trimmed = raw[start...].trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(Sentence(text: trimmed, offset: NSRange(start..<range.upperBound, in: text).location))
            return true
        }
        return result
    }

    private static let clausePunctuation: Set<Character> = [",", ";", ":", "、", "，", "；", "："]

    /// Splits an over-long sentence into shorter pieces: after clause punctuation if it has any,
    /// otherwise into two halves at a space, otherwise into two halves by character.
    public static func subdivide(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if clausePunctuation.contains(character) {
                parts.append(current)
                current = ""
            }
        }
        parts.append(current)
        parts = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if parts.count > 1 { return parts }

        let words = text.split(separator: " ")
        if words.count > 1 {
            let middle = words.count / 2
            return [words[..<middle].joined(separator: " "), words[middle...].joined(separator: " ")]
        }
        guard text.count > 1 else { return [text] }
        let middle = text.index(text.startIndex, offsetBy: text.count / 2)
        return [String(text[..<middle]), String(text[middle...])]
    }
}
