import XCTest
@testable import AudraCore

@MainActor
final class SettingsStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "AudraTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testDefaultsWhenNothingStored() {
        let store = SettingsStore(defaults: makeDefaults())
        XCTAssertEqual(store.speed, .normal)
        XCTAssertNil(store.defaultVoiceID)
        XCTAssertTrue(store.autoDetectLanguage)
        XCTAssertEqual(store.languageVoiceOverrides, [:])
    }

    func testChangesPersistAcrossInstances() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        store.speed = .twoAndHalf
        store.defaultVoiceID = "en.daniel"
        store.autoDetectLanguage = false
        store.setVoiceOverride("pt.luciana", forLanguage: "pt")

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.speed, .twoAndHalf)
        XCTAssertEqual(reloaded.defaultVoiceID, "en.daniel")
        XCTAssertFalse(reloaded.autoDetectLanguage)
        XCTAssertEqual(reloaded.languageVoiceOverrides, ["pt": "pt.luciana"])
    }

    func testClearingDefaultVoicePersistsNil() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        store.defaultVoiceID = "en.daniel"
        store.defaultVoiceID = nil
        XCTAssertNil(SettingsStore(defaults: defaults).defaultVoiceID)
    }

    func testSettingNilOverrideRemovesIt() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        store.setVoiceOverride("pt.luciana", forLanguage: "pt")
        store.setVoiceOverride(nil, forLanguage: "pt")
        XCTAssertEqual(store.languageVoiceOverrides, [:])
        XCTAssertEqual(SettingsStore(defaults: defaults).languageVoiceOverrides, [:])
    }

    func testUnknownStoredSpeedFallsBackToNormal() {
        let defaults = makeDefaults()
        defaults.set(3.7, forKey: "speechSpeed")
        XCTAssertEqual(SettingsStore(defaults: defaults).speed, .normal)
    }

    func testAlwaysShowPlayerDefaultsToFalse() {
        XCTAssertFalse(SettingsStore(defaults: makeDefaults()).alwaysShowPlayer)
    }

    func testAlwaysShowPlayerPersists() {
        let defaults = makeDefaults()
        SettingsStore(defaults: defaults).alwaysShowPlayer = true
        XCTAssertTrue(SettingsStore(defaults: defaults).alwaysShowPlayer)
    }
}
