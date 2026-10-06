import Foundation

/// Japanese text → Kokoro phonemes. Kanji readings come from the system tokenizer
/// (`CFStringTokenizer`), then misaki's cutlet rules turn kana into phonemes. No pitch accent.
public struct JapanesePhonemizer: Phonemizer {
    public init() {}

    public func phonemize(_ text: String) throws -> String {
        var joiner = PhonemeJoiner()
        let normalized = text.precomposedStringWithCompatibilityMapping
        for segment in Self.numberSegments(normalized) {
            switch segment {
            case let .number(digits, counter):
                let kana = counter.map { JapaneseNumberReader.reading(of: digits, counter: $0) }
                    ?? JapaneseNumberReader.reading(of: digits)
                joiner.appendWord(Self.phonemes(forKana: kana))
            case let .text(part):
                Self.appendTokens(of: part, to: &joiner)
            }
        }
        return Self.mergeSokuonSpaces(joiner.text)
    }

    // MARK: - Numbers

    enum Segment: Equatable {
        case number(String, counter: String?)
        case text(String)
    }

    private static let numberPattern = try! NSRegularExpression(
        pattern: "(\\d+(?:\\.\\d+)?)(" + JapaneseNumberReader.counters.sorted().joined(separator: "|") + ")?"
    )

    static func numberSegments(_ text: String) -> [Segment] {
        let ns = text as NSString
        var segments: [Segment] = []
        var cursor = 0
        for match in numberPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                segments.append(.text(ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))))
            }
            let digits = ns.substring(with: match.range(at: 1))
            let counterRange = match.range(at: 2)
            let counter = counterRange.location == NSNotFound ? nil : ns.substring(with: counterRange)
            segments.append(.number(digits, counter: digits.contains(".") ? nil : counter))
            if counter != nil && digits.contains(".") {
                segments.append(.text(ns.substring(with: counterRange)))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length { segments.append(.text(ns.substring(from: cursor))) }
        return segments
    }

    // MARK: - Tokens

    private static let punctuationMap: [Character: String] = [
        "。": ".", "、": ",", "，": ",", "？": "?", "?": "?", "！": "!", "!": "!", "：": ":", ":": ":",
        "；": ";", ";": ";", ".": ".", ",": ",", "「": "\u{201D}", "」": "\u{201D}", "『": "\u{201D}", "』": "\u{201D}",
        "（": "(", "）": ")", "(": "(", ")": ")", "《": "(", "》": ")", "【": "[", "】": "]",
        "«": "\u{201D}", "»": "\u{201D}", "～": "—", "〜": "—", "—": "—", "…": "…",
    ]

    /// Particles whose pronunciation differs from their spelling.
    private static let particles: [String: String] = ["は": "わ", "へ": "え", "を": "お"]

    private static func appendTokens(of text: String, to joiner: inout PhonemeJoiner) {
        let cf = text as CFString
        let tokenizer = CFStringTokenizerCreate(
            nil, cf, CFRangeMake(0, CFStringGetLength(cf)), kCFStringTokenizerUnitWordBoundary,
            Locale(identifier: "ja") as CFLocale
        )
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let surface = (text as NSString).substring(with: NSRange(location: range.location, length: range.length))
            if surface.allSatisfy({ punctuationMap[$0] != nil }) {
                surface.forEach { joiner.appendPunctuation(punctuationMap[$0]!) }
                continue
            }
            if surface.allSatisfy(\.isWhitespace) { continue }
            let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            guard let kana = reading(surface: surface, latin: latin) else { continue }
            joiner.appendWord(phonemes(forKana: kana))
        }
    }

    /// Hiragana pronunciation of one token.
    static func reading(surface: String, latin: String?) -> String? {
        if let particle = particles[surface] { return particle }
        if surface.unicodeScalars.allSatisfy(isKana) {
            return hiragana(fromKatakana: surface)
        }
        guard let latin, !latin.isEmpty else { return nil }
        let converted = NSMutableString(string: latin)
        CFStringTransform(converted, nil, kCFStringTransformLatinHiragana, false)
        let kana = converted as String
        guard kana.unicodeScalars.allSatisfy(isKana) else { return nil }
        // Okurigana (trailing kana of the surface) keep their spelling; the kanji part gets long vowels.
        let trailingKana = surface.reversed().prefix { $0.unicodeScalars.allSatisfy(isKana) }.count
        return lengthenVowels(kana, keepingLast: trailingKana)
    }

    private static func isKana(_ scalar: Unicode.Scalar) -> Bool {
        (0x3041...0x309F).contains(scalar.value) || (0x30A0...0x30FF).contains(scalar.value)
    }

    /// Katakana → hiragana by code point (ァ…ヶ → ぁ…ゖ). ー and ヷ…ヺ are kept: the system
    /// transform would turn ー into a vowel.
    static func hiragana(fromKatakana text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            (0x30A1...0x30F6).contains(scalar.value) ? Unicode.Scalar(scalar.value - 0x60)! : scalar
        }))
    }

    /// Dictionary pronunciations write long vowels as ー: とうきょう → とーきょー, せんせい → せんせー.
    static func lengthenVowels(_ kana: String, keepingLast keep: Int) -> String {
        var characters = Array(kana)
        let limit = characters.count - keep
        guard limit > 1 else { return kana }
        for index in 1..<limit {
            guard let previous = JapaneseKanaTable.table[String(characters[index - 1])]?.last else { continue }
            switch characters[index] {
            case "う" where "oɯɨ".contains(previous), "お" where previous == "o", "い" where previous == "e":
                characters[index] = "ー"
            default:
                break
            }
        }
        return String(characters)
    }

    // MARK: - Kana → phonemes (cutlet's _get_single_mapping)

    private static let smallKana: Set<Character> = ["ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ"]

    static func phonemes(forKana kana: String) -> String {
        let table = JapaneseKanaTable.table
        let characters = Array(hiragana(fromKatakana: kana))
        var out = ""
        for (index, character) in characters.enumerated() {
            let current = String(character)
            let previous = index > 0 ? String(characters[index - 1]) : nil
            let next = index + 1 < characters.count ? String(characters[index + 1]) : nil
            if let previous, let digraph = table[previous + current] {
                out += digraph
            } else if let next, table[current + next] != nil {
                continue
            } else if let next, smallKana.contains(Character(next)) {
                if current == "っ" { continue }
                out += String((table[current] ?? "").dropLast()) + (table[next] ?? "")
            } else if smallKana.contains(character) {
                continue
            } else if current == "ー" {
                out += "ː"
            } else if current == "っ" {
                out += "ʔ"
            } else if current == "ん" {
                out += moraicNasal(before: next.flatMap { table[$0] })
            } else {
                out += table[current] ?? ""
            }
        }
        return out
    }

    private static func moraicNasal(before next: String?) -> String {
        guard let next, let first = next.first else { return "ɴ" }
        if "mpb".contains(first) { return "m" }
        if "kɡ".contains(first) { return "ŋ" }
        if ["ɲ", "ʨ", "ʥ"].contains(where: next.hasPrefix) { return "ɲ" }
        if "ntdɾz".contains(first) { return "n" }
        return "ɴ"
    }

    /// cutlet joins a sokuon to its neighbours: "ʔ" never has spaces around it.
    static func mergeSokuonSpaces(_ phonemes: String) -> String {
        phonemes
            .replacingOccurrences(of: "(?<![!\",.:;?»—…\u{201D}]) (?=ʔ)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?<=ʔ) (?![\"«\u{201D}])", with: "", options: .regularExpression)
    }
}
