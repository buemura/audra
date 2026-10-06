import Foundation

/// Pinyin syllables → Kokoro phonemes, ported from misaki's `transcription.py` and `ZHG2P.retone`
/// (pinyin-to-ipa, MIT). Tones become arrows: 1 →, 2 ↗, 3 ↓, 4 ↘, neutral nothing.
public enum PinyinTranscriber {
    /// A toneless pinyin syllable ("zhong", "nü") and its tone, 1–5 (5 = neutral).
    public struct Syllable: Equatable, Sendable {
        public let letters: String
        public let tone: Int
        public init(_ letters: String, tone: Int) {
            self.letters = letters
            self.tone = tone
        }
    }

    private static let initials: [String: String] = [
        "b": "p", "c": "ʦʰ", "ch": "ꭧʰ", "d": "t", "f": "f", "g": "k", "h": "x", "j": "ʨ", "k": "kʰ",
        "l": "l", "m": "m", "n": "n", "p": "pʰ", "q": "ʨʰ", "r": "ɻ", "s": "s", "sh": "ʂ", "t": "tʰ",
        "x": "ɕ", "z": "ʦ", "zh": "ꭧ",
    ]

    /// Finals in pypinyin's strict spelling; "0" marks where the tone goes.
    private static let finals: [String: String] = [
        "a": "a0", "ai": "ai0", "an": "a0n", "ang": "a0ŋ", "ao": "au0", "e": "ɤ0", "ei": "ei0",
        "en": "ə0n", "eng": "ə0ŋ", "i": "i0", "ia": "ja0", "ian": "jɛ0n", "iang": "ja0ŋ", "iao": "jau0",
        "ie": "je0", "in": "i0n", "iou": "jou0", "ing": "i0ŋ", "iong": "jʊ0ŋ", "ong": "ʊ0ŋ", "ou": "ou0",
        "u": "u0", "uei": "wei0", "ua": "wa0", "uai": "wai0", "uan": "wa0n", "uen": "wə0n",
        "uang": "wa0ŋ", "ueng": "wə0ŋ", "uo": "wo0", "o": "wo0", "ü": "y0", "üe": "ɥe0", "üan": "ɥɛ0n",
        "ün": "y0n",
    ]

    /// Whole syllables with no initial/final split.
    private static let special: [String: String] = [
        "er": "ɚ0", "io": "jɔ0", "ê": "ɛ0", "o": "ɔ0", "hm": "hm0", "hng": "hŋ0", "m": "m0", "n": "n0", "ng": "ŋ0",
    ]

    private static let toneArrows = [1: "→", 2: "↗", 3: "↓", 4: "↘", 5: ""]

    /// Phonemes for one syllable, or nil if it is not valid pinyin.
    public static func phonemes(for syllable: Syllable) -> String? {
        guard let arrow = toneArrows[syllable.tone] else { return nil }
        let letters = syllable.letters.replacingOccurrences(of: "v", with: "ü")
        let ipa: String
        if let whole = special[letters] {
            ipa = whole
        } else if let (initial, final) = split(letters) {
            let finalIPA: String
            if final == "i" && ["zh", "ch", "sh", "r"].contains(initial) {
                finalIPA = "ɨ0"
            } else if final == "i" && ["z", "c", "s"].contains(initial) {
                finalIPA = "ɨ0"
            } else {
                guard let mapped = finals[final] else { return nil }
                finalIPA = mapped
            }
            ipa = (initial.flatMap { initials[$0] } ?? "") + finalIPA
        } else {
            return nil
        }
        return ipa.replacingOccurrences(of: "0", with: arrow)
    }

    public static func isValid(_ letters: String) -> Bool {
        phonemes(for: Syllable(letters, tone: 5)) != nil
    }

    /// Splits a toneless syllable into (initial, strict final), applying pinyin spelling rules
    /// (y/w, iu → iou, ui → uei, un → uen, u → ü after j/q/x).
    private static func split(_ letters: String) -> (String?, String)? {
        let yw: [String: String] = [
            "yi": "i", "ya": "ia", "ye": "ie", "yao": "iao", "you": "iou", "yan": "ian", "yin": "in",
            "yang": "iang", "ying": "ing", "yong": "iong", "yu": "ü", "yue": "üe", "yuan": "üan", "yun": "ün",
            "wu": "u", "wa": "ua", "wo": "uo", "wai": "uai", "wei": "uei", "wan": "uan", "wen": "uen",
            "wang": "uang", "weng": "ueng",
        ]
        if let final = yw[letters] { return (nil, final) }
        guard let initial = ["zh", "ch", "sh"].first(where: letters.hasPrefix)
            ?? letters.first.map(String.init).flatMap({ initials[$0] != nil ? $0 : nil })
        else {
            return finals[letters] != nil ? (nil, letters) : nil
        }
        var final = String(letters.dropFirst(initial.count))
        if ["j", "q", "x"].contains(initial) {
            final = ["u": "ü", "ue": "üe", "uan": "üan", "un": "ün"][final] ?? final
        }
        final = ["iu": "iou", "ui": "uei", "un": "uen", "ue": "üe"][final] ?? final
        return finals[final] != nil ? (initial, final) : nil
    }

    /// Splits tone-marked pinyin for `count` syllables, e.g. ("jīntiān", 2) → [jin1, tian1].
    /// Returns nil when the text can't be split into exactly `count` valid syllables.
    public static func syllables(in pinyin: String, count: Int) -> [Syllable]? {
        var letters: [Character] = []
        var tones: [Int] = []
        var boundaries: Set<Int> = []
        for scalar in pinyin.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars {
            switch scalar.value {
            case 0x0304: if !tones.isEmpty { tones[tones.count - 1] = 1 }
            case 0x0301: if !tones.isEmpty { tones[tones.count - 1] = 2 }
            case 0x030C: if !tones.isEmpty { tones[tones.count - 1] = 3 }
            case 0x0300: if !tones.isEmpty { tones[tones.count - 1] = 4 }
            case 0x0308: if letters.last == "u" { letters[letters.count - 1] = "v" }
            case 0x61...0x7A:
                letters.append(Character(scalar))
                tones.append(0)
            default:
                boundaries.insert(letters.count)
            }
        }
        func search(from start: Int, remaining: Int) -> [Range<Int>]? {
            if remaining == 0 { return start == letters.count ? [] : nil }
            let maxLength = min(6, letters.count - start)
            guard maxLength > 0 else { return nil }
            for length in stride(from: maxLength, through: 1, by: -1) {
                let end = start + length
                if (start + 1..<end).contains(where: boundaries.contains) { continue }
                guard isValid(String(letters[start..<end])) else { continue }
                if let rest = search(from: end, remaining: remaining - 1) { return [start..<end] + rest }
            }
            return nil
        }
        guard count > 0, let ranges = search(from: 0, remaining: count) else { return nil }
        return ranges.map { range in
            Syllable(String(letters[range]), tone: tones[range].first(where: { $0 > 0 }) ?? 5)
        }
    }
}
