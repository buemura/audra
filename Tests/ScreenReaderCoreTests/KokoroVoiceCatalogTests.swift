import XCTest
@testable import ScreenReaderCore

final class KokoroVoiceCatalogTests: XCTestCase {
    func testCatalogHas51UniqueVoicesCoveringEveryLanguage() {
        let ids = KokoroVoiceCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, 51)
        XCTAssertEqual(Set(ids).count, 51)
        for language in KokoroLanguage.allCases {
            XCTAssertNotNil(KokoroVoiceCatalog.defaultVoice(for: language), "\(language)")
        }
        XCTAssertFalse(ids.contains { $0.hasSuffix("_santa") })
    }

    func testDefaultVoices() {
        let defaults = KokoroLanguage.allCases.map { KokoroVoiceCatalog.defaultVoice(for: $0)?.id }
        XCTAssertEqual(defaults, ["af_heart", "bf_emma", "pf_dora", "ef_dora", "ff_siwis", "if_sara", "hf_alpha", "jf_alpha", "zf_xiaobei"])
    }

    func testVoiceIDsAndNames() {
        let dora = KokoroVoiceCatalog.voice(forVoiceID: "kokoro.pf_dora")
        XCTAssertEqual(dora?.language, .brazilianPortuguese)
        XCTAssertEqual(dora?.name, "Dora")
        XCTAssertEqual(dora?.voiceID, "kokoro.pf_dora")
        XCTAssertEqual(KokoroVoiceCatalog.voice(forVoiceID: "kokoro.jf_gongitsune")?.name, "Gongitsune")
        XCTAssertNil(KokoroVoiceCatalog.voice(forVoiceID: "pt.luciana"))
        XCTAssertNil(KokoroVoiceCatalog.voice(forVoiceID: "kokoro.nobody"))
    }

    func testIsKokoroVoiceID() {
        XCTAssertTrue(KokoroVoiceCatalog.isKokoroVoiceID("kokoro.af_heart"))
        XCTAssertFalse(KokoroVoiceCatalog.isKokoroVoiceID("com.apple.voice.compact.en-US.Samantha"))
        XCTAssertFalse(KokoroVoiceCatalog.isKokoroVoiceID(nil))
    }

    func testVoiceInfosUseNaturalQualityAndCatalogOrder() {
        let infos = KokoroVoiceCatalog.voiceInfos()
        XCTAssertEqual(infos.count, 51)
        XCTAssertEqual(infos.first, VoiceInfo(id: "kokoro.af_heart", name: "Heart", language: "en-US", quality: .natural, sortOrder: 0))
        XCTAssertEqual(infos.map(\.sortOrder), Array(0..<51))
        XCTAssertTrue(infos.allSatisfy { $0.quality == .natural })
        XCTAssertEqual(infos.first { $0.id == "kokoro.pf_dora" }?.language, "pt-BR")
        XCTAssertEqual(infos.first { $0.id == "kokoro.zf_xiaobei" }?.languageCode, "zh")
    }
}
