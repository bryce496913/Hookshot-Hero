import XCTest
@testable import HookshotHero

@MainActor final class SettingsTests: XCTestCase {
    private var suiteName: String!; private var defaults: UserDefaults!
    override func setUp() { super.setUp(); suiteName = "HookshotHeroTests-\(UUID())"; defaults = UserDefaults(suiteName: suiteName)! }
    override func tearDown() { defaults.removePersistentDomain(forName: suiteName); defaults = nil; suiteName = nil; super.tearDown() }
    func testDefaults() { XCTAssertEqual(UserDefaultsSettingsRepository(defaults: defaults).load(), .defaults) }
    func testUpdatedSettingsPersistWithoutSharedDefaults() {
        let repository = UserDefaultsSettingsRepository(defaults: defaults); var settings = GameSettings.defaults; settings.musicEnabled = false
        repository.save(settings); XCTAssertEqual(repository.load(), settings); XCTAssertNil(UserDefaults.standard.data(forKey: "test-only-settings"))
    }
}
