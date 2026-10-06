import Foundation

/// Mandarin text → Kokoro phonemes (beta). Word segmentation and context-aware pinyin come from
/// the system tokenizer (`CFStringTokenizer`); pinyin → phonemes follows misaki.
public struct ChinesePhonemizer: Phonemizer {
    public init() {}

    private static let punctuationMap: [Character: String] = [
        "、": ",", "，": ",", ",": ",", "。": ".", "．": ".", ".": ".", "！": "!", "!": "!", "：": ":", ":": ":",
        "；": ";", ";": ";", "？": "?", "?": "?", "«": "\u{201D}", "»": "\u{201D}", "《": "\u{201D}", "》": "\u{201D}", "「": "\u{201D}",
        "」": "\u{201D}", "【": "\u{201D}", "】": "\u{201D}", "（": "(", "）": ")", "(": "(", ")": ")", "…": "…", "—": "—",
    ]

    private static let numberPattern = try! NSRegularExpression(pattern: "\\d+(?:\\.\\d+)?(年)?")

    public func phonemize(_ text: String) throws -> String {
        let withNumerals = Self.replacingNumbers(in: text.precomposedStringWithCompatibilityMapping)
        var joiner = PhonemeJoiner()
        let cf = withNumerals as CFString
        let tokenizer = CFStringTokenizerCreate(
            nil, cf, CFRangeMake(0, CFStringGetLength(cf)), kCFStringTokenizerUnitWordBoundary,
            Locale(identifier: "zh-Hans") as CFLocale
        )
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let surface = (withNumerals as NSString).substring(with: NSRange(location: range.location, length: range.length))
            if surface.allSatisfy({ Self.punctuationMap[$0] != nil }) {
                surface.forEach { joiner.appendPunctuation(Self.punctuationMap[$0]!) }
                continue
            }
            let hanCount = surface.unicodeScalars.filter(Self.isHan).count
            guard hanCount > 0 else {
                // Latin words pass through as misaki does; anything else is dropped.
                let latin = surface.filter { $0.isASCII && $0.isLetter }
                if !latin.isEmpty { joiner.appendWord(latin.lowercased()) }
                continue
            }
            let pinyin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
            joiner.appendWord(Self.phonemes(surface: surface, pinyin: pinyin, hanCount: hanCount))
        }
        return joiner.text
    }

    static func phonemes(surface: String, pinyin: String?, hanCount: Int) -> String {
        if let pinyin, let syllables = PinyinTranscriber.syllables(in: pinyin, count: hanCount) {
            return syllables.compactMap(PinyinTranscriber.phonemes(for:)).joined()
        }
        // Fall back to character-by-character pinyin when the word's transcription can't be split.
        return surface.unicodeScalars.filter(isHan).compactMap { scalar -> String? in
            let converted = NSMutableString(string: String(Character(scalar)))
            CFStringTransform(converted, nil, kCFStringTransformMandarinLatin, false)
            return PinyinTranscriber.syllables(in: converted as String, count: 1)?
                .first.flatMap(PinyinTranscriber.phonemes(for:))
        }.joined()
    }

    static func replacingNumbers(in text: String) -> String {
        let ns = text as NSString
        var result = ""
        var cursor = 0
        for match in numberPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let token = ns.substring(with: match.range)
            if token.hasSuffix("年") {
                let digits = String(token.dropLast())
                result += (digits.count == 4 ? ChineseNumberReader.digitByDigit(digits) : ChineseNumberReader.reading(of: digits)) + "年"
            } else {
                result += ChineseNumberReader.reading(of: token)
            }
            cursor = match.range.location + match.range.length
        }
        return result + ns.substring(from: cursor)
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }
}
