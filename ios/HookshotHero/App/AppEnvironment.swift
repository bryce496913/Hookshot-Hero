import Foundation

struct AppEnvironment {
  let settingsRepository: UserDefaultsSettingsRepository
  let progressionRepository: ProgressionRepository
  let forcedOutcome: GameOutcome?
  let levelSeed: UInt64?
  let startConfiguration: GameStartConfiguration

  @MainActor
  static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
    #if DEBUG
      if arguments.contains("--ui-testing") {
        let suiteName = "HookshotHero.UITests"
        let defaults = UserDefaults(suiteName: suiteName)!
        let root = FileManager.default.temporaryDirectory.appending(
          path: "HookshotHero-UITests", directoryHint: .isDirectory)
        if arguments.contains("--reset-persistent-state") {
          defaults.removePersistentDomain(forName: suiteName)
          do {
            if FileManager.default.fileExists(atPath: root.path) {
              try FileManager.default.removeItem(at: root)
            }
          } catch {
            AppLog.persistence.error(
              "Could not reset UI-test progression: \(error.localizedDescription, privacy: .public)"
            )
          }
        }
        let outcome: GameOutcome? =
          arguments.contains("--force-game-outcome=win")
          ? .won : (arguments.contains("--force-game-outcome=loss") ? .lost : nil)
        return AppEnvironment(
          settingsRepository: UserDefaultsSettingsRepository(defaults: defaults),
          progressionRepository: ProgressionRepository(
            fileURL: root.appending(path: "progression.json")),
          forcedOutcome: outcome,
          levelSeed: ProcessInfo.processInfo.environment["HOOKSHOT_LEVEL_SEED"].flatMap(
            UInt64.init),
          startConfiguration: .init(initialLevelID: debugStartLevel())
        )
      }
    #endif
    do {
      return AppEnvironment(
        settingsRepository: UserDefaultsSettingsRepository(),
        progressionRepository: try .applicationRepository(), forcedOutcome: nil,
        levelSeed: ProcessInfo.processInfo.environment["HOOKSHOT_LEVEL_SEED"].flatMap(UInt64.init),
        startConfiguration: .current)
    } catch {
      AppLog.persistence.error(
        "Application Support unavailable: \(error.localizedDescription, privacy: .public)")
      let fallback = FileManager.default.temporaryDirectory.appending(
        path: "HookshotHero-progression.json")
      return AppEnvironment(
        settingsRepository: UserDefaultsSettingsRepository(),
        progressionRepository: ProgressionRepository(fileURL: fallback), forcedOutcome: nil,
        levelSeed: ProcessInfo.processInfo.environment["HOOKSHOT_LEVEL_SEED"].flatMap(UInt64.init),
        startConfiguration: .current)
    }
  }

  private static func debugStartLevel() -> LevelID {
    let requested = ProcessInfo.processInfo.environment["HOOKSHOT_START_LEVEL"].map {
      LevelID(rawValue: $0)
    }
    let implemented: Set<LevelID> = [.levelOne, .levelTwo, .levelThree, .levelFour, .levelFive, .levelSix]
    return requested.flatMap { implemented.contains($0) ? $0 : nil } ?? .levelOne
  }
}
