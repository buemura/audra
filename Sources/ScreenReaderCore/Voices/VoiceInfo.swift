import Foundation

/// An installed speech voice, decoupled from AVFoundation so selection logic is testable.
public struct VoiceInfo: Identifiable, Hashable {
    public enum Quality: Int, Comparable {
        case standard = 1
        case enhanced = 2
        case premium = 3
        /// Kokoro neural voice.
        case natural = 4

        public static func < (lhs: Quality, rhs: Quality) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// `AVSpeechSynthesisVoice.identifier`.
    public let id: String
    public let name: String
    /// BCP-47 tag, e.g. "en-US".
    public let language: String
    public let quality: Quality
    /// Preference among voices of the same quality; lower wins. System voices are all 0;
    /// Kokoro voices use their catalog position.
    public let sortOrder: Int

    public init(id: String, name: String, language: String, quality: Quality, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
        self.sortOrder = sortOrder
    }

    /// Primary language subtag, e.g. "en" for "en-US".
    public var languageCode: String { Self.primaryLanguage(of: language) }

    public static func primaryLanguage(of tag: String) -> String {
        let primary = tag.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? tag
        return primary.lowercased()
    }
}

extension VoiceInfo {
    /// Label for voice pickers, e.g. "Daniel (en-GB, Enhanced)".
    public var menuLabel: String {
        switch quality {
        case .standard: return "\(name) (\(language))"
        case .enhanced: return "\(name) (\(language), Enhanced)"
        case .premium: return "\(name) (\(language), Premium)"
        case .natural: return "\(name) (\(language), Natural)"
        }
    }
}
