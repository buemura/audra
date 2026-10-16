import Foundation

/// Languages the Kokoro model speaks. Raw values are the BCP-47 tags shown in voice pickers.
public enum KokoroLanguage: String, CaseIterable, Sendable {
    case americanEnglish = "en-US"
    case britishEnglish = "en-GB"
    case brazilianPortuguese = "pt-BR"
    case spanish = "es-ES"
    case french = "fr-FR"
    case italian = "it-IT"
    case hindi = "hi-IN"
    case japanese = "ja-JP"
    case mandarinChinese = "zh-CN"
}

/// One Kokoro v1.0 voice, e.g. `pf_dora` (Brazilian Portuguese, female).
public struct KokoroVoice: Equatable, Sendable {
    /// Kokoro's voice name, also the key in `voices.npz`.
    public let id: String
    public let language: KokoroLanguage

    /// Identifier used in settings and `SpeechSynthesizing.speak`.
    public var voiceID: String { KokoroVoiceCatalog.voiceIDPrefix + id }

    /// "pf_dora" → "Dora".
    public var name: String {
        let base = id.split(separator: "_").last.map(String.init) ?? id
        return base.prefix(1).uppercased() + base.dropFirst()
    }
}

public enum KokoroVoiceCatalog {
    public static let voiceIDPrefix = "kokoro."

    /// Voices per language, most preferred first. Novelty voices (*_santa) are left out.
    /// Must match the voice list in scripts/prepare-kokoro-assets.py.
    private static let voicesByLanguage: [(KokoroLanguage, [String])] = [
        (.americanEnglish, ["af_heart", "af_bella", "af_nicole", "af_aoede", "af_kore", "af_sarah", "af_nova",
                            "af_sky", "af_alloy", "af_jessica", "af_river", "am_michael", "am_fenrir", "am_puck",
                            "am_echo", "am_eric", "am_liam", "am_onyx", "am_adam"]),
        (.britishEnglish, ["bf_emma", "bf_isabella", "bf_alice", "bf_lily", "bm_george", "bm_fable", "bm_lewis", "bm_daniel"]),
        (.brazilianPortuguese, ["pf_dora", "pm_alex"]),
        (.spanish, ["ef_dora", "em_alex"]),
        (.french, ["ff_siwis"]),
        (.italian, ["if_sara", "im_nicola"]),
        (.hindi, ["hf_alpha", "hf_beta", "hm_omega", "hm_psi"]),
        (.japanese, ["jf_alpha", "jf_gongitsune", "jf_nezumi", "jf_tebukuro", "jm_kumo"]),
        (.mandarinChinese, ["zf_xiaobei", "zf_xiaoni", "zf_xiaoxiao", "zf_xiaoyi", "zm_yunjian", "zm_yunxi",
                            "zm_yunxia", "zm_yunyang"]),
    ]

    /// Every voice in preference order.
    public static let all: [KokoroVoice] = voicesByLanguage.flatMap { language, ids in
        ids.map { KokoroVoice(id: $0, language: language) }
    }

    public static func voice(forVoiceID voiceID: String) -> KokoroVoice? {
        guard voiceID.hasPrefix(voiceIDPrefix) else { return nil }
        let id = String(voiceID.dropFirst(voiceIDPrefix.count))
        return all.first { $0.id == id }
    }

    public static func isKokoroVoiceID(_ voiceID: String?) -> Bool {
        voiceID?.hasPrefix(voiceIDPrefix) ?? false
    }

    public static func defaultVoice(for language: KokoroLanguage) -> KokoroVoice? {
        all.first { $0.language == language }
    }

    /// The catalog as voice-list entries, `sortOrder` = catalog position.
    public static func voiceInfos() -> [VoiceInfo] {
        all.enumerated().map { index, voice in
            VoiceInfo(id: voice.voiceID, name: voice.name, language: voice.language.rawValue, quality: .natural, sortOrder: index)
        }
    }
}
