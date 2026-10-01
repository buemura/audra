import XCTest
@testable import ScreenReaderCore

final class LanguageVoiceGroupTests: XCTestCase {
    private let samantha = VoiceInfo(id: "en.samantha", name: "Samantha", language: "en-US", quality: .standard)
    private let daniel = VoiceInfo(id: "en.daniel", name: "Daniel", language: "en-GB", quality: .enhanced)
    private let luciana = VoiceInfo(id: "pt.luciana", name: "Luciana", language: "pt-BR", quality: .standard)
    private let kyoko = VoiceInfo(id: "ja.kyoko", name: "Kyoko", language: "ja-JP", quality: .premium)

    func testGroupsByPrimaryLanguageSortedByDisplayName() {
        let groups = LanguageVoiceGroup.groups(
            from: [samantha, kyoko, luciana, daniel],
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(groups.map(\.languageCode), ["en", "ja", "pt"])
        XCTAssertEqual(groups.map(\.displayName), ["English", "Japanese", "Portuguese"])
        XCTAssertEqual(groups.map(\.id), ["en", "ja", "pt"])
    }

    func testVoicesWithinGroupSortedByName() {
        let groups = LanguageVoiceGroup.groups(from: [samantha, daniel], locale: Locale(identifier: "en_US"))
        XCTAssertEqual(groups.first?.voices.map(\.name), ["Daniel", "Samantha"])
    }

    func testNoVoicesGivesNoGroups() {
        XCTAssertEqual(LanguageVoiceGroup.groups(from: []), [])
    }

    func testMenuLabelShowsRegionAndNonStandardQuality() {
        XCTAssertEqual(samantha.menuLabel, "Samantha (en-US)")
        XCTAssertEqual(daniel.menuLabel, "Daniel (en-GB, Enhanced)")
        XCTAssertEqual(kyoko.menuLabel, "Kyoko (ja-JP, Premium)")
    }
}
