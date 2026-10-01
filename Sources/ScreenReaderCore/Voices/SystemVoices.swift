import AVFoundation

public enum SystemVoices {
    /// Installed voices, excluding novelty voices, sorted by language then name.
    public static func all() -> [VoiceInfo] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) }
            .map {
                VoiceInfo(
                    id: $0.identifier,
                    name: $0.name,
                    language: $0.language,
                    quality: VoiceInfo.Quality(rawValue: $0.quality.rawValue) ?? .standard
                )
            }
            .sorted { ($0.language, $0.name) < ($1.language, $1.name) }
    }
}
