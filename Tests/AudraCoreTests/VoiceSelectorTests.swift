import XCTest
@testable import AudraCore

final class VoiceSelectorTests: XCTestCase {
    private let samantha = VoiceInfo(id: "en.samantha", name: "Samantha", language: "en-US", quality: .standard)
    private let daniel = VoiceInfo(id: "en.daniel", name: "Daniel", language: "en-GB", quality: .enhanced)
    private let luciana = VoiceInfo(id: "pt.luciana", name: "Luciana", language: "pt-BR", quality: .standard)
    private let joana = VoiceInfo(id: "pt.joana", name: "Joana", language: "pt-PT", quality: .standard)
    private let kyoko = VoiceInfo(id: "ja.kyoko", name: "Kyoko", language: "ja-JP", quality: .premium)

    private func select(
        _ language: String?,
        default defaultVoiceID: String? = nil,
        overrides: [String: String] = [:]
    ) -> String? {
        VoiceSelector.selectVoice(
            detectedLanguage: language,
            defaultVoiceID: defaultVoiceID,
            languageOverrides: overrides,
            availableVoices: [samantha, daniel, luciana, joana, kyoko]
        )
    }

    func testPrimaryLanguageStripsRegionAndScriptAndLowercases() {
        XCTAssertEqual(VoiceInfo.primaryLanguage(of: "en-US"), "en")
        XCTAssertEqual(VoiceInfo.primaryLanguage(of: "zh-Hans"), "zh")
        XCTAssertEqual(VoiceInfo.primaryLanguage(of: "pt_BR"), "pt")
        XCTAssertEqual(VoiceInfo.primaryLanguage(of: "JA"), "ja")
        XCTAssertEqual(daniel.languageCode, "en")
    }

    func testNoDetectedLanguageUsesDefaultVoice() {
        XCTAssertEqual(select(nil, default: "pt.luciana"), "pt.luciana")
    }

    func testNoDetectedLanguageAndNoDefaultLetsSystemChoose() {
        XCTAssertNil(select(nil))
    }

    func testUninstalledDefaultVoiceIsIgnored() {
        XCTAssertNil(select(nil, default: "gone"))
    }

    func testOverrideForDetectedLanguageWins() {
        XCTAssertEqual(select("en", default: "en.samantha", overrides: ["en": "en.daniel"]), "en.daniel")
    }

    func testOverrideIgnoredWhenVoiceNoLongerInstalled() {
        XCTAssertEqual(select("pt", overrides: ["pt": "pt.removed"]), "pt.joana")
    }

    func testDefaultVoiceUsedWhenItSpeaksDetectedLanguage() {
        XCTAssertEqual(select("en", default: "en.samantha"), "en.samantha")
    }

    func testBestQualityVoiceForLanguageWhenDefaultSpeaksAnotherLanguage() {
        XCTAssertEqual(select("en", default: "pt.luciana"), "en.daniel")
    }

    func testQualityTieBreaksAlphabeticallyByName() {
        XCTAssertEqual(select("pt"), "pt.joana")
    }

    func testRegionalDetectedLanguageMatchesByPrimarySubtag() {
        XCTAssertEqual(select("ja-JP"), "ja.kyoko")
    }

    func testFallsBackToDefaultWhenNoVoiceForLanguage() {
        XCTAssertEqual(select("fr", default: "en.samantha"), "en.samantha")
    }

    func testNoVoiceForLanguageAndNoDefaultLetsSystemChoose() {
        XCTAssertNil(select("fr"))
    }

    private let kokoroAlpha = VoiceInfo(id: "kokoro.jf_alpha", name: "Alpha", language: "ja-JP", quality: .natural, sortOrder: 40)
    private let kokoroHeart = VoiceInfo(id: "kokoro.af_heart", name: "Heart", language: "en-US", quality: .natural, sortOrder: 0)
    private let kokoroBella = VoiceInfo(id: "kokoro.af_bella", name: "Bella", language: "en-US", quality: .natural, sortOrder: 1)

    private func selectWithNatural(
        _ language: String?,
        default defaultVoiceID: String? = nil,
        overrides: [String: String] = [:],
        voices: [VoiceInfo]
    ) -> String? {
        VoiceSelector.selectVoice(
            detectedLanguage: language,
            defaultVoiceID: defaultVoiceID,
            languageOverrides: overrides,
            availableVoices: voices
        )
    }

    func testNaturalVoiceOutranksPremium() {
        XCTAssertEqual(selectWithNatural("ja", voices: [kyoko, kokoroAlpha]), "kokoro.jf_alpha")
    }

    func testEqualQualityPrefersLowerSortOrderOverName() {
        // "Bella" sorts before "Heart" by name, but Heart is first in catalog order.
        XCTAssertEqual(selectWithNatural("en", voices: [samantha, kokoroBella, kokoroHeart]), "kokoro.af_heart")
    }

    func testDefaultSystemVoiceInDetectedLanguageStillBeatsNaturalVoice() {
        XCTAssertEqual(selectWithNatural("ja", default: "ja.kyoko", voices: [kyoko, kokoroAlpha]), "ja.kyoko")
    }

    func testOverrideToUnavailableNaturalVoiceFallsThrough() {
        XCTAssertEqual(selectWithNatural("ja", overrides: ["ja": "kokoro.jf_alpha"], voices: [kyoko]), "ja.kyoko")
    }

    func testNaturalMenuLabel() {
        XCTAssertEqual(kokoroAlpha.menuLabel, "Alpha (ja-JP, Natural)")
    }

    func testSortOrderDefaultsToZero() {
        XCTAssertEqual(samantha.sortOrder, 0)
    }
}
