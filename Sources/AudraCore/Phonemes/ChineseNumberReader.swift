import Foundation

/// Arabic numerals → Chinese numerals for reading aloud: "2026" → "二千零二十六", "3.5" → "三点五".
public enum ChineseNumberReader {
    private static let digits: [Character] = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    public static func reading(of number: String) -> String {
        let parts = number.split(separator: ".", omittingEmptySubsequences: false)
        let integer = reading(ofInteger: String(parts[0]))
        guard parts.count == 2, !parts[1].isEmpty else { return integer }
        return integer + "点" + String(parts[1].compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }

    /// Digit by digit, as years are read: "2026" → "二零二六".
    public static func digitByDigit(_ number: String) -> String {
        String(number.compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }

    private static func reading(ofInteger text: String) -> String {
        let values = text.compactMap(\.wholeNumberValue)
        guard !values.isEmpty else { return "" }
        if values.count > 16 || (values.count > 1 && values[0] == 0) { return digitByDigit(text) }
        if values.allSatisfy({ $0 == 0 }) { return "零" }
        var groups: [Int] = []
        var remaining = values
        while !remaining.isEmpty {
            let group = remaining.suffix(4)
            remaining.removeLast(group.count)
            groups.append(group.reduce(0) { $0 * 10 + $1 })
        }
        let units = ["", "万", "亿", "万亿"]
        var result = ""
        var pendingZero = false
        for (index, group) in groups.enumerated().reversed() {
            if group == 0 { pendingZero = !result.isEmpty; continue }
            if pendingZero || (!result.isEmpty && group < 1000) { result += "零" }
            pendingZero = false
            result += readingBelow10000(group) + units[index]
        }
        // 一十X at the very start is read 十X.
        if result.hasPrefix("一十") { result.removeFirst() }
        return result
    }

    private static func readingBelow10000(_ value: Int) -> String {
        let places = [(1000, "千"), (100, "百"), (10, "十"), (1, "")]
        var result = ""
        var zero = false
        for (place, unit) in places {
            let digit = value / place % 10
            if digit == 0 {
                zero = !result.isEmpty
                continue
            }
            if zero { result += "零" }
            zero = false
            result += String(digits[digit]) + unit
        }
        return result
    }
}
