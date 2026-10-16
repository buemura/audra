import Foundation

/// Installed voices for one language, for the per-language voice settings.
public struct LanguageVoiceGroup: Identifiable, Equatable {
    public let languageCode: String
    public let displayName: String
    public let voices: [VoiceInfo]

    public var id: String { languageCode }

    public static func groups(from voices: [VoiceInfo], locale: Locale = .current) -> [LanguageVoiceGroup] {
        Dictionary(grouping: voices, by: \.languageCode)
            .map { code, voices in
                LanguageVoiceGroup(
                    languageCode: code,
                    displayName: locale.localizedString(forLanguageCode: code) ?? code,
                    voices: voices.sorted { ($0.name, $0.language) < ($1.name, $1.language) }
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
