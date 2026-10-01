import Combine
import Foundation

/// User preferences, persisted to UserDefaults on every change.
@MainActor
public final class SettingsStore: ObservableObject {
    private enum Key {
        static let speed = "speechSpeed"
        static let defaultVoiceID = "defaultVoiceID"
        static let autoDetectLanguage = "autoDetectLanguage"
        static let languageVoiceOverrides = "languageVoiceOverrides"
        static let alwaysShowPlayer = "alwaysShowPlayer"
    }

    private let defaults: UserDefaults

    @Published public var speed: SpeechSpeed {
        didSet { defaults.set(speed.rawValue, forKey: Key.speed) }
    }

    /// Voice used when no language-specific voice applies. nil = system default.
    @Published public var defaultVoiceID: String? {
        didSet { defaults.set(defaultVoiceID, forKey: Key.defaultVoiceID) }
    }

    @Published public var autoDetectLanguage: Bool {
        didSet { defaults.set(autoDetectLanguage, forKey: Key.autoDetectLanguage) }
    }

    /// Keep the floating player visible while idle, not only while reading.
    @Published public var alwaysShowPlayer: Bool {
        didSet { defaults.set(alwaysShowPlayer, forKey: Key.alwaysShowPlayer) }
    }

    /// Primary language code ("en", "pt", …) → voice identifier.
    @Published public private(set) var languageVoiceOverrides: [String: String] {
        didSet { defaults.set(languageVoiceOverrides, forKey: Key.languageVoiceOverrides) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        speed = SpeechSpeed(rawValue: defaults.double(forKey: Key.speed)) ?? .normal
        defaultVoiceID = defaults.string(forKey: Key.defaultVoiceID)
        autoDetectLanguage = defaults.object(forKey: Key.autoDetectLanguage) as? Bool ?? true
        alwaysShowPlayer = defaults.bool(forKey: Key.alwaysShowPlayer)
        languageVoiceOverrides = defaults.dictionary(forKey: Key.languageVoiceOverrides) as? [String: String] ?? [:]
    }

    /// Sets (or with nil, removes) the voice used for a language.
    public func setVoiceOverride(_ voiceID: String?, forLanguage code: String) {
        languageVoiceOverrides[code] = voiceID
    }
}
