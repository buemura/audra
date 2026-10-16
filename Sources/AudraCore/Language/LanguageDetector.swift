import NaturalLanguage

public protocol LanguageDetecting {
    /// BCP-47 language code of `text` (e.g. "en", "pt", "zh-Hans"), or nil when unsure.
    func detectLanguage(of text: String) -> String?
}

/// On-device language detection; never touches the network.
public struct NLLanguageDetector: LanguageDetecting {
    private let minimumConfidence: Double

    public init(minimumConfidence: Double = 0.5) {
        self.minimumConfidence = minimumConfidence
    }

    public func detectLanguage(of text: String) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let top = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value }),
              top.value >= minimumConfidence else { return nil }
        return top.key.rawValue
    }
}
