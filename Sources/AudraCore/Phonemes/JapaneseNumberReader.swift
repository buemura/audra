import Foundation

/// Japanese readings of numbers written in digits, as pronunciation kana (long vowels written ー).
public enum JapaneseNumberReader {
    public static let counters: Set<String> = ["年", "月", "日", "時", "分", "円", "人", "つ", "歳", "回", "個"]

    private static let digitReadings = ["ぜろ", "いち", "に", "さん", "よん", "ご", "ろく", "なな", "はち", "きゅー"]

    /// Reading of a decimal number such as "2026" or "3.5".
    public static func reading(of number: String) -> String {
        let parts = number.split(separator: ".", omittingEmptySubsequences: false)
        let integer = reading(ofInteger: String(parts[0]))
        guard parts.count == 2, !parts[1].isEmpty else { return integer }
        return integer + "てん" + parts[1].compactMap { $0.wholeNumberValue }.map { digitReadings[$0] }.joined()
    }

    /// Reading of a whole number followed by `counter` (one of `counters`), e.g. ("1", "日") → "ついたち".
    public static func reading(of number: String, counter: String) -> String {
        guard let value = Int(number), !number.hasPrefix("0") || number == "0" else {
            return reading(of: number) + counterReading(counter)
        }
        let base = reading(ofInteger: number)
        switch counter {
        case "月":
            return replacingSuffix(of: base, [("よん", "し"), ("なな", "しち"), ("きゅー", "く")]) + "がつ"
        case "日":
            let special = [1: "ついたち", 2: "ふつか", 3: "みっか", 4: "よっか", 5: "いつか", 6: "むいか",
                           7: "なのか", 8: "よーか", 9: "ここのか", 10: "とーか", 14: "じゅーよっか",
                           20: "はつか", 24: "にじゅーよっか"]
            return special[value] ?? base + "にち"
        case "年":
            return replacingSuffix(of: base, [("よん", "よ"), ("きゅー", "く")]) + "ねん"
        case "時":
            return replacingSuffix(of: base, [("よん", "よ"), ("なな", "しち"), ("きゅー", "く")]) + "じ"
        case "分":
            switch value % 10 {
            case 1, 6, 8: return sokuon(base) + "ぷん"
            case 3, 4: return base + "ぷん"
            case 0 where value > 0: return sokuon(base) + "ぷん"
            default: return base + "ふん"
            }
        case "円":
            return replacingSuffix(of: base, [("よん", "よ")]) + "えん"
        case "人":
            if value == 1 { return "ひとり" }
            if value == 2 { return "ふたり" }
            return replacingSuffix(of: base, [("よん", "よ")]) + "にん"
        case "つ":
            let special = [1: "ひとつ", 2: "ふたつ", 3: "みっつ", 4: "よっつ", 5: "いつつ", 6: "むっつ",
                           7: "ななつ", 8: "やっつ", 9: "ここのつ", 10: "とお"]
            return special[value] ?? base
        case "歳":
            if value == 20 { return "はたち" }
            return [1, 8, 0].contains(value % 10) && value > 0 ? sokuon(base) + "さい" : base + "さい"
        case "回":
            return [1, 6, 8, 0].contains(value % 10) && value > 0 ? sokuon(base) + "かい" : base + "かい"
        case "個":
            return [1, 6, 8, 0].contains(value % 10) && value > 0 ? sokuon(base) + "こ" : base + "こ"
        default:
            return base + counter
        }
    }

    private static func counterReading(_ counter: String) -> String {
        ["年": "ねん", "月": "がつ", "日": "にち", "時": "じ", "分": "ふん", "円": "えん", "人": "にん",
         "つ": "つ", "歳": "さい", "回": "かい", "個": "こ"][counter] ?? counter
    }

    private static func reading(ofInteger digits: String) -> String {
        let values = digits.compactMap { $0.wholeNumberValue }
        guard !values.isEmpty else { return "" }
        // Leading zeros (e.g. "007") and very long numbers are read digit by digit.
        if values.count > 16 || (values.count > 1 && values[0] == 0) {
            return values.map { digitReadings[$0] }.joined()
        }
        if values.allSatisfy({ $0 == 0 }) { return digitReadings[0] }
        let units = ["", "まん", "おく", "ちょー"]
        var groups: [Int] = []
        var remaining = values
        while !remaining.isEmpty {
            let group = remaining.suffix(4)
            remaining.removeLast(group.count)
            groups.append(group.reduce(0) { $0 * 10 + $1 })
        }
        var result = ""
        for (index, group) in groups.enumerated().reversed() where group > 0 {
            if index == 3 && group == 1 {
                result += "いっちょー"
            } else {
                result += readingBelow10000(group) + units[index]
            }
        }
        return result
    }

    private static func readingBelow10000(_ value: Int) -> String {
        let thousands = value / 1000, hundreds = value / 100 % 10, tens = value / 10 % 10, ones = value % 10
        var result = ""
        switch thousands {
        case 0: break
        case 1: result += "せん"
        case 3: result += "さんぜん"
        case 8: result += "はっせん"
        default: result += digitReadings[thousands] + "せん"
        }
        switch hundreds {
        case 0: break
        case 1: result += "ひゃく"
        case 3: result += "さんびゃく"
        case 6: result += "ろっぴゃく"
        case 8: result += "はっぴゃく"
        default: result += digitReadings[hundreds] + "ひゃく"
        }
        switch tens {
        case 0: break
        case 1: result += "じゅー"
        default: result += digitReadings[tens] + "じゅー"
        }
        if ones > 0 { result += digitReadings[ones] }
        return result
    }

    private static func sokuon(_ reading: String) -> String {
        replacingSuffix(of: reading, [("いち", "いっ"), ("ろく", "ろっ"), ("はち", "はっ"), ("じゅー", "じゅっ"), ("ひゃく", "ひゃっ")])
    }

    private static func replacingSuffix(of reading: String, _ replacements: [(String, String)]) -> String {
        for (suffix, replacement) in replacements where reading.hasSuffix(suffix) {
            return String(reading.dropLast(suffix.count)) + replacement
        }
        return reading
    }
}
