import Foundation

public enum VoiceSelector {
    /// Picks the voice for a piece of text. Order of preference:
    /// 1. the user's override for the detected language,
    /// 2. the default voice, if it speaks the detected language,
    /// 3. the best-quality installed voice for the detected language (ties: sortOrder, then name A–Z),
    /// 4. the default voice.
    /// Returns nil to let the system use its own default voice.
    public static func selectVoice(
        detectedLanguage: String?,
        defaultVoiceID: String?,
        languageOverrides: [String: String],
        availableVoices: [VoiceInfo]
    ) -> String? {
        let voicesByID = Dictionary(availableVoices.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let defaultVoice = defaultVoiceID.flatMap { voicesByID[$0] }

        guard let detectedLanguage else { return defaultVoice?.id }
        let code = VoiceInfo.primaryLanguage(of: detectedLanguage)

        if let overrideID = languageOverrides[code], voicesByID[overrideID] != nil {
            return overrideID
        }
        if let defaultVoice, defaultVoice.languageCode == code {
            return defaultVoice.id
        }
        let best = availableVoices
            .filter { $0.languageCode == code }
            .max { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality < rhs.quality }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder > rhs.sortOrder }
                return lhs.name > rhs.name
            }
        return best?.id ?? defaultVoice?.id
    }
}
