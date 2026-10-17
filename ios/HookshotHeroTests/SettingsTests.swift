import XCTest

@testable import HookshotHero

@MainActor final class SettingsTests: XCTestCase {
  private var suiteName: String!
  private var defaults: UserDefaults!
  private let key = "settings-test"
  override func setUp() {
    suiteName = "HookshotHeroTests-\(UUID())"
    defaults = UserDefaults(suiteName: suiteName)!
  }
  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    suiteName = nil
  }
  func testDefaultsAndIsolatedPersistence() {
    let repository = UserDefaultsSettingsRepository(defaults: defaults, key: key)
    XCTAssertEqual(repository.load(), .defaults)
    XCTAssertEqual(repository.load().controlLayout, .standard)
    let settings = GameSettings(
      reducedMotion: true, controlHintsEnabled: false, controlLayout: .leftHanded)
    repository.save(settings)
    XCTAssertEqual(repository.load(), settings)
    XCTAssertNil(UserDefaults.standard.data(forKey: key))
  }
  func testMissingAndMalformedFieldsRecoverIndependently() {
    let repository = UserDefaultsSettingsRepository(defaults: defaults, key: key)
    defaults.set(Data(#"{"reducedMotion":true}"#.utf8), forKey: key)
    XCTAssertEqual(
      repository.load(),
      GameSettings(reducedMotion: true, controlHintsEnabled: true, controlLayout: .standard))
    defaults.set(Data(#"{"reducedMotion":true,"controlHintsEnabled":"bad"}"#.utf8), forKey: key)
    XCTAssertEqual(repository.load(), GameSettings(reducedMotion: true, controlHintsEnabled: true))
    defaults.set(Data("not-json".utf8), forKey: key)
    XCTAssertEqual(repository.load(), .defaults)
  }
  func testAudioDefaultsLegacyFieldsAndIndependentPersistence() {
    let repository = UserDefaultsSettingsRepository(defaults: defaults, key: key)
    XCTAssertTrue(repository.load().musicEnabled)
    XCTAssertTrue(repository.load().soundEffectsEnabled)
    defaults.set(Data(#"{"reducedMotion":true,"controlHintsEnabled":false,"controlLayout":"leftHanded"}"#.utf8), forKey: key)
    let legacy = repository.load()
    XCTAssertTrue(legacy.musicEnabled)
    XCTAssertTrue(legacy.soundEffectsEnabled)
    XCTAssertTrue(legacy.reducedMotion)
    XCTAssertFalse(legacy.controlHintsEnabled)
    XCTAssertEqual(legacy.controlLayout, .leftHanded)
    defaults.set(Data(#"{"musicEnabled":"bad","soundEffectsEnabled":false,"reducedMotion":true}"#.utf8), forKey: key)
    XCTAssertTrue(repository.load().musicEnabled)
    XCTAssertFalse(repository.load().soundEffectsEnabled)
    defaults.set(Data(#"{"musicEnabled":false,"soundEffectsEnabled":"bad","controlHintsEnabled":false}"#.utf8), forKey: key)
    XCTAssertFalse(repository.load().musicEnabled)
    XCTAssertTrue(repository.load().soundEffectsEnabled)
    XCTAssertFalse(repository.load().controlHintsEnabled)
    var settings = legacy
    settings.musicEnabled = false
    settings.soundEffectsEnabled = false
    repository.save(settings)
    XCTAssertEqual(UserDefaultsSettingsRepository(defaults: defaults, key: key).load(), settings)
  }

  func testVersionInformationReadsBundleValues() {
    XCTAssertEqual(
      AppVersionInformation.displayText(),
      "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"))"
    )
  }
  func testControlLayoutPlacesControlsOnOppositeSides() {
    XCTAssertTrue(ControlLayout.standard.joystickIsLeading)
    XCTAssertFalse(ControlLayout.leftHanded.joystickIsLeading)
    XCTAssertEqual(ControlLayout.standard.displayName, "Standard")
    XCTAssertEqual(ControlLayout.leftHanded.displayName, "Left-Handed")
  }
  func testCancellingInputForLayoutChangeClearsHeldMovement() {
    let input = GameInputController()
    input.send(.beginMove(.left))
    let generation = input.cancellationGeneration

    input.cancelAllInput()

    XCTAssertNil(input.heldDirection)
    XCTAssertTrue(input.drain().isEmpty)
    XCTAssertEqual(input.cancellationGeneration, generation + 1)
  }
  func testEffectiveReduceMotionAndLatestSessionSnapshot() {
    let repository = UserDefaultsSettingsRepository(defaults: defaults, key: key)
    let store = SettingsStore(repository: repository)
    XCTAssertFalse(store.configuration(systemReduceMotion: false).reducedMotion)
    XCTAssertTrue(store.configuration(systemReduceMotion: true).reducedMotion)
    store.settings.reducedMotion = true
    store.settings.controlHintsEnabled = false
    XCTAssertEqual(
      store.configuration(systemReduceMotion: false),
      .init(reducedMotion: true, controlHintsEnabled: false))
  }
}
