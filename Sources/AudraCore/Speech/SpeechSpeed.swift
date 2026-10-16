import AVFoundation

/// Playback speeds offered to the user. The raw value is the multiplier shown in the UI.
public enum SpeechSpeed: Double, CaseIterable, Identifiable, Codable {
    case half = 0.5
    case normal = 1.0
    case oneAndHalf = 1.5
    case double = 2.0
    case twoAndHalf = 2.5

    public var id: Double { rawValue }

    /// Menu label, e.g. "1x" or "1.5x".
    public var label: String {
        let isWhole = rawValue.truncatingRemainder(dividingBy: 1) == 0
        return (isWhole ? String(Int(rawValue)) : String(rawValue)) + "x"
    }

    /// Value for `AVSpeechUtterance.rate`. AVSpeech rates are perceptually non-linear
    /// (0.5 is normal speech, 1.0 is extremely fast), so this is a table tuned by ear
    /// rather than a multiplication.
    public var utteranceRate: Float {
        switch self {
        case .half: return 0.40
        case .normal: return AVSpeechUtteranceDefaultSpeechRate
        case .oneAndHalf: return 0.57
        case .double: return 0.63
        case .twoAndHalf: return 0.69
        }
    }

    /// The next slower speed, or nil at the slowest.
    public var slower: SpeechSpeed? { neighbor(offset: -1) }

    /// The next faster speed, or nil at the fastest.
    public var faster: SpeechSpeed? { neighbor(offset: 1) }

    private func neighbor(offset: Int) -> SpeechSpeed? {
        let all = Self.allCases
        let index = all.firstIndex(of: self)! + offset
        return all.indices.contains(index) ? all[index] : nil
    }
}
