import XCTest
@testable import ScreenReaderCore

final class SystemVoicesTests: XCTestCase {
    func testListsInstalledVoicesSortedByLanguageThenName() {
        let voices = SystemVoices.all()
        XCTAssertFalse(voices.isEmpty, "macOS always ships with at least one voice")
        XCTAssertEqual(Set(voices.map(\.id)).count, voices.count)
        let keys = voices.map { [$0.language, $0.name] }
        XCTAssertEqual(keys, keys.sorted { $0.lexicographicallyPrecedes($1) })
    }
}
