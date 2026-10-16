import AudraCore
import XCTest
@testable import AudraKokoro

@MainActor
final class KokoroPhonemizersTests: XCTestCase {
    func testEveryKokoroLanguageHasAPhonemizer() {
        for language in KokoroLanguage.allCases {
            XCTAssertNotNil(KokoroPhonemizers.phonemizer(for: language), "\(language)")
        }
    }

    func testPhonemizersAreReusedAndUseTheRightLanguage() throws {
        XCTAssertEqual(try KokoroPhonemizers.phonemizer(for: .japanese)?.phonemize("学校の先生"), "ɡaʔkoː no seɴseː")
        XCTAssertEqual(try KokoroPhonemizers.phonemizer(for: .spanish)?.phonemize("Hola, ¿cómo estás?"), "ˈola, ¿kˈomo estˈas?")
        XCTAssertEqual(try KokoroPhonemizers.phonemizer(for: .italian)?.phonemize("Ciao, come stai?"), "ʧˈao, kˌome stˈaj?")
        // Back to Spanish after Italian: eSpeak's global voice must be reselected.
        XCTAssertEqual(try KokoroPhonemizers.phonemizer(for: .spanish)?.phonemize("Hola, ¿cómo estás?"), "ˈola, ¿kˈomo estˈas?")
    }
}
