import ScreenReaderCore

/// The phonemizer for each Kokoro language, created on first use (loading eSpeak and Misaki
/// isn't free) and then reused.
public enum KokoroPhonemizers {
    @MainActor private static var cache: [KokoroLanguage: any Phonemizer] = [:]

    @MainActor
    public static func phonemizer(for language: KokoroLanguage) -> (any Phonemizer)? {
        if let cached = cache[language] { return cached }
        guard let phonemizer = make(language) else { return nil }
        cache[language] = phonemizer
        return phonemizer
    }

    private static func make(_ language: KokoroLanguage) -> (any Phonemizer)? {
        switch language {
        case .americanEnglish: return EnglishPhonemizer(british: false)
        case .britishEnglish: return EnglishPhonemizer(british: true)
        case .brazilianPortuguese: return try? ESpeakPhonemizer(language: "pt-br")
        case .spanish: return try? ESpeakPhonemizer(language: "es")
        case .french: return try? ESpeakPhonemizer(language: "fr-fr")
        case .italian: return try? ESpeakPhonemizer(language: "it")
        case .hindi: return try? ESpeakPhonemizer(language: "hi")
        case .japanese: return FallbackPhonemizer(primary: JapanesePhonemizer(), fallback: try? ESpeakPhonemizer(language: "ja"))
        case .mandarinChinese: return FallbackPhonemizer(primary: ChinesePhonemizer(), fallback: try? ESpeakPhonemizer(language: "cmn"))
        }
    }
}
