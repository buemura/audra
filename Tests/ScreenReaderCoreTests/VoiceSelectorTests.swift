import XCTest
@testable import ScreenReaderCore

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
}
