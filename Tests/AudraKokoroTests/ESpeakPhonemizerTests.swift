import XCTest
@testable import AudraKokoro

final class ESpeakPhonemizerTests: XCTestCase {
    func testMatchesMisakiReferenceOutput() throws {
        // Reference outputs of misaki's EspeakG2P (Kokoro v1.0) with eSpeak NG 1.52.0.
        let cases: [(String, String, String)] = [
            ("es", "Hola, ¿cómo estás?", "ˈola, ¿kˈomo estˈas?"),
            ("es", "Tengo 3 gatos.", "tˈɛŋɡo tɾˈes ɣˈatos."),
            ("pt-br", "Olá, tudo bem?", "olˈa, tˈudʊ bˈAŋ?"),
            ("pt-br", "Eu tenho 3 gatos.", "eʊ tˌeɲʊ trˈez ɡˈatʊs."),
            ("fr-fr", "Bonjour, comment ça va ?", "bɔ̃ʒˈuʁ, kɔmˌɑ̃ sa vˈa ?"),
            ("it", "Ciao, come stai?", "ʧˈao, kˌome stˈaj?"),
            ("hi", "नमस्ते, आप कैसे हैं?", "nəmˈʌsteː, ˌaːp kˈɛːseː hɛ̃?"),
        ]
        for (language, text, phonemes) in cases {
            XCTAssertEqual(try ESpeakPhonemizer(language: language).phonemize(text), phonemes, "\(language): \(text)")
        }
    }

    func testPhonemizersForDifferentLanguagesCanBeInterleaved() throws {
        let spanish = try ESpeakPhonemizer(language: "es")
        let italian = try ESpeakPhonemizer(language: "it")
        XCTAssertEqual(try spanish.phonemize("Hola, ¿cómo estás?"), "ˈola, ¿kˈomo estˈas?")
        XCTAssertEqual(try italian.phonemize("Ciao, come stai?"), "ʧˈao, kˌome stˈaj?")
        XCTAssertEqual(try spanish.phonemize("Hola, ¿cómo estás?"), "ˈola, ¿kˈomo estˈas?")
    }

    func testJapaneseAndChineseFallbacksProduceOutput() throws {
        XCTAssertFalse(try ESpeakPhonemizer(language: "ja").phonemize("こんにちは").isEmpty)
        XCTAssertFalse(try ESpeakPhonemizer(language: "cmn").phonemize("你好").isEmpty)
    }
}
