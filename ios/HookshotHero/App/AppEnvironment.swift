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
        let progressionRepository = ProgressionRepository(
          fileURL: root.appending(path: "progression.json"))
        if arguments.contains("--unlock-level-select") {
          // Seed the real persisted milestone, never bypass the production menu gate.
          let progression = ProgressionStore(repository: progressionRepository)
          progression.record(result: GameResult(
            sessionID: UUID(), levelID: .levelTen, missionID: nil,
            score: 0, elapsedTime: 0, outcome: .won))
        }
        let fixtureCount = arguments.contains("--high-scores-fixture=ten") ? 10
          : (arguments.contains("--high-scores-fixture=one") ? 1 : 0)
        if fixtureCount > 0 {
          let progression = ProgressionStore(repository: progressionRepository)
          for index in 1...fixtureCount {
            guard let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) else { continue }
            progression.record(result: GameResult(
              sessionID: id, levelID: .heroWelcome, missionID: nil,
              score: index * 100, elapsedTime: Double((11 - index) * 120), outcome: .won),
              leaderboardEligible: true)
          }
        }
        return AppEnvironment(
          settingsRepository: UserDefaultsSettingsRepository(defaults: defaults),
          progressionRepository: progressionRepository,
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
    let implemented: Set<LevelID> = [
      .levelOne, .levelTwo, .levelThree, .levelFour, .levelFive, .levelSix, .levelSeven,
      .levelEight,
      .levelNine, .levelTen, .countryRoad, .heroWelcome,
    ]
    return requested.flatMap { implemented.contains($0) ? $0 : nil } ?? .levelOne
  }
}
