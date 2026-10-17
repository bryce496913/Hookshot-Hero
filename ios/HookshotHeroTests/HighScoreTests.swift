import Foundation
import XCTest

@testable import HookshotHero

final class HighScorePolicyTests: XCTestCase {
  func testTimeBonusExamplesAndCeilingPolicy() {
    let examples: [(Double, Int)] = [
      (3600, 0), (3000, 300), (2400, 600), (1800, 900), (1200, 1200),
      (600, 1500), (300, 1650), (4000, 0), (-1, 1800), (0, 1800),
      (3000.1, 299), (3599.1, 0), (.infinity, 0), (.nan, 0),
    ]
    for (elapsed, bonus) in examples {
      XCTAssertEqual(HighScoreScoring.timeBonus(for: elapsed), bonus)
    }
    XCTAssertEqual(HighScoreScoring.maximumTimeBonus, 1800)
  }

  func testTotalThenTimeThenRawScoreThenUUIDDetermineRanking() {
    let totalWinner = scoreEntry(4, raw: 100, elapsed: 100, total: 1000)
    let faster = scoreEntry(3, raw: 40, elapsed: 90, total: 900)
    let rawWinner = scoreEntry(2, raw: 80, elapsed: 100, total: 900)
    let tieLowID = scoreEntry(1, raw: 70, elapsed: 100, total: 900)
    let tieHighID = scoreEntry(5, raw: 70, elapsed: 100, total: 900)
    let expected = [totalWinner, faster, rawWinner, tieLowID, tieHighID]
    XCTAssertEqual(HighScoreScoring.topEntries(Array(expected.reversed())), expected)
    XCTAssertEqual(HighScoreScoring.topEntries([tieHighID, rawWinner, totalWinner, tieLowID, faster]), expected)
  }

  func testFasterEqualRawScoreWinsAndOnlyTenUniqueEntriesRemain() throws {
    let slow = try XCTUnwrap(HighScoreEntry.completedRun(scoreResult(id: scoreID(1), score: 100, time: 3600)))
    let fast = try XCTUnwrap(HighScoreEntry.completedRun(scoreResult(id: scoreID(2), score: 100, time: 3000)))
    XCTAssertEqual(HighScoreScoring.topEntries([slow, fast]), [fast, slow])
    let entries = (1...11).map { scoreEntry($0, raw: $0, elapsed: 60, total: $0) }
    let ranked = HighScoreScoring.topEntries(entries + [entries[10]])
    XCTAssertEqual(ranked.count, 10)
    XCTAssertEqual(ranked.map(\.rawScore), Array((2...11).reversed()))
  }

  func testEntryRoundTripsAndInvalidTimeIsRejected() throws {
    let entry = try XCTUnwrap(HighScoreEntry.completedRun(scoreResult(score: 123, time: 300)))
    XCTAssertEqual(entry.rawScore, 123)
    XCTAssertEqual(entry.timeBonus, 1650)
    XCTAssertEqual(entry.totalScore, 1773)
    XCTAssertEqual(try JSONDecoder().decode(HighScoreEntry.self, from: JSONEncoder().encode(entry)), entry)
    XCTAssertNil(HighScoreEntry.completedRun(scoreResult(time: .nan)))
    XCTAssertEqual(HighScoreEntry.completedRun(scoreResult(score: Int.max, time: 0))?.totalScore, Int.max)
  }
}

@MainActor final class HighScorePersistenceTests: XCTestCase {
  private var directory: URL!
  private var repository: ProgressionRepository!
  override func setUp() {
    directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    repository = ProgressionRepository(fileURL: directory.appending(path: "progression-v1.json"))
  }
  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
  }

  func testOnlyEligibleTerminalWinRecordsAndRawHighScoreKeepsItsMeaning() {
    let store = ProgressionStore(repository: repository)
    store.record(result: scoreResult(score: 100)) // Direct entry.
    store.record(result: scoreResult(score: 100, outcome: .lost), leaderboardEligible: true)
    for level in [LevelID.levelOne, .levelTen, .countryRoad] {
      store.record(result: scoreResult(level: level, score: 100), leaderboardEligible: true)
    }
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    let result = scoreResult(score: 100, time: 300)
    store.record(result: result, leaderboardEligible: true)
    store.record(result: result, leaderboardEligible: true)
    XCTAssertEqual(store.progression.highScore, 100)
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
    XCTAssertEqual(store.progression.highScoreEntries.first?.totalScore, 1750)
    let reloaded = ProgressionStore(repository: repository)
    reloaded.record(result: result, leaderboardEligible: true)
    XCTAssertEqual(reloaded.progression.highScoreEntries, store.progression.highScoreEntries)
  }

  func testStorePersistsOnlyTopTenAndDiscardsLowerEleventh() {
    let store = ProgressionStore(repository: repository)
    for index in (1...11).reversed() {
      store.record(result: scoreResult(id: scoreID(index), score: index, time: 3600), leaderboardEligible: true)
    }
    XCTAssertEqual(store.progression.highScoreEntries.map(\.rawScore), Array((2...11).reversed()))
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testRepositoryCanonicalSaveBoundsAndSortsEntries() throws {
    var value = Progression.defaults
    value.highScoreEntries = (1...11).map { scoreEntry($0, raw: $0, elapsed: 100, total: $0) }
    try repository.save(value)
    let bytes = try Data(contentsOf: repository.fileURL)
    let decoded = try JSONDecoder().decode(Progression.self, from: bytes)
    XCTAssertEqual(decoded.highScoreEntries.map(\.rawScore), Array((2...11).reversed()))
    XCTAssertEqual(repository.load(), .loaded(decoded))
  }

  func testV1MigrationPreservesEveryLegacyFieldAndUnlockAndSavesV2() throws {
    let legacy = LegacyProgressionV1()
    try write(JSONEncoder().encode(legacy))
    let store = ProgressionStore(repository: repository)
    XCTAssertEqual(store.progression.schemaVersion, 2)
    XCTAssertEqual(store.progression.highScore, legacy.highScore)
    XCTAssertEqual(store.progression.completedLevelIDs, legacy.completedLevelIDs)
    XCTAssertEqual(store.progression.completedMissionIDs, legacy.completedMissionIDs)
    XCTAssertEqual(store.progression.unlockedContentIDs, legacy.unlockedContentIDs)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    XCTAssertTrue(AppRouter(progressionStore: store).isLevelSelectUnlocked)
    XCTAssertEqual(store.loadResult, .migrated(store.progression, fromVersion: 1))
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testV0MigratesThroughV1ToV2AndKeepsLevelTenUnlock() throws {
    try write(Data(#"{"schemaVersion":0,"highScore":22,"completedLevelIDs":["level-10"]}"#.utf8))
    let store = ProgressionStore(repository: repository)
    XCTAssertEqual(store.progression.schemaVersion, 2)
    XCTAssertEqual(store.progression.highScore, 22)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    XCTAssertTrue(AppRouter(progressionStore: store).isLevelSelectUnlocked)
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testFailedLeaderboardSaveRetainsEntryAndRetriesWithoutDuplicate() throws {
    var attempts = 0
    let retrying = ProgressionRepository(fileURL: repository.fileURL, saveOverride: { value in
      attempts += 1
      if attempts == 1 { throw ScoreTestError.expected }
      try self.repository.save(value)
    })
    let store = ProgressionStore(repository: retrying)
    let result = scoreResult()
    store.record(result: result, leaderboardEligible: true)
    XCTAssertTrue(store.hasUnsavedChanges)
    XCTAssertNotNil(store.lastSaveError)
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
    store.record(result: result, leaderboardEligible: true)
    XCTAssertEqual(attempts, 2)
    XCTAssertFalse(store.hasUnsavedChanges)
    XCTAssertNil(store.lastSaveError)
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testExplicitFlushRetriesLeaderboardWithoutAddingAnotherEntry() {
    var fails = true
    let retrying = ProgressionRepository(fileURL: repository.fileURL, saveOverride: { value in
      if fails { throw ScoreTestError.expected }
      try self.repository.save(value)
    })
    let store = ProgressionStore(repository: retrying)
    store.record(result: scoreResult(), leaderboardEligible: true)
    let entries = store.progression.highScoreEntries
    XCTAssertTrue(store.hasUnsavedChanges)
    fails = false
    store.flushPendingSave()
    XCTAssertFalse(store.hasUnsavedChanges)
    XCTAssertEqual(store.progression.highScoreEntries, entries)
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testFailedMigrationSaveRemainsDirtyAndFlushRetries() throws {
    try write(JSONEncoder().encode(LegacyProgressionV1()))
    var fails = true
    let retrying = ProgressionRepository(fileURL: repository.fileURL, saveOverride: { value in
      if fails { throw ScoreTestError.expected }
      try self.repository.save(value)
    })
    let store = ProgressionStore(repository: retrying)
    XCTAssertTrue(store.hasUnsavedChanges)
    XCTAssertNotNil(store.lastSaveError)
    XCTAssertTrue(AppRouter(progressionStore: store).isLevelSelectUnlocked)
    fails = false
    store.flushPendingSave()
    XCTAssertFalse(store.hasUnsavedChanges)
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testCorruptAndFutureFilesAreQuarantinedBeforeLeaderboardSave() throws {
    for (text, suffix) in [("invalid", "corrupt"), (#"{"schemaVersion":99}"#, "unsupported-v99")] {
      let bytes = Data(text.utf8)
      try write(bytes)
      let store = ProgressionStore(repository: repository)
      store.record(result: scoreResult(), leaderboardEligible: true)
      XCTAssertEqual(try Data(contentsOf: directory.appending(path: "progression-v1.\(suffix).json")), bytes)
      XCTAssertEqual(store.progression.highScoreEntries.count, 1)
      XCTAssertEqual(repository.load(), .loaded(store.progression))
    }
  }

  func testFailedQuarantineCannotOverwriteOriginalWithLeaderboard() throws {
    let original = Data("unreadable".utf8)
    try write(original)
    let protected = ProgressionRepository(fileURL: repository.fileURL,
      quarantineOverride: { _ in throw ScoreTestError.expected })
    let store = ProgressionStore(repository: protected)
    store.record(result: scoreResult(), leaderboardEligible: true)
    XCTAssertTrue(store.hasUnsavedChanges)
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
    XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
  }

  private func write(_ data: Data) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: repository.fileURL)
  }
}

private struct LegacyProgressionV1: Encodable {
  let schemaVersion = 1
  let highScore = 400
  let completedLevelIDs: Set<LevelID> = [.levelOne, .levelTen]
  let completedMissionIDs: Set<MissionID> = [.init(rawValue: "mission-1")]
  let unlockedContentIDs: Set<UnlockID> = [.init(rawValue: "unlock-1")]
}
private enum ScoreTestError: Error { case expected }
private func scoreID(_ number: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
}
private func scoreResult(id: UUID = UUID(), level: LevelID = .heroWelcome, score: Int = 100,
                         time: Double = 300, outcome: GameOutcome = .won) -> GameResult {
  GameResult(sessionID: id, levelID: level, missionID: nil, score: score, elapsedTime: time, outcome: outcome)
}
private func scoreEntry(_ number: Int, raw: Int, elapsed: Double, total: Int) -> HighScoreEntry {
  HighScoreEntry(id: scoreID(number), rawScore: raw, elapsedTime: elapsed,
                 timeBonus: total - raw, totalScore: total)
}

@MainActor final class HighScoreEligibilityTests: XCTestCase {
  private var directory: URL!
  private var store: ProgressionStore!
  override func setUp() {
    directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    store = ProgressionStore(repository: ProgressionRepository(fileURL: directory.appending(path: "save.json")))
  }
  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
  }

  func testPlayStartsEligibleButDirectLevelEntriesAndDebugStartsDoNot() throws {
    let router = AppRouter(progressionStore: store)
    router.startNewGame()
    XCTAssertEqual(router.activeSession?.levelID, .levelOne)
    XCTAssertTrue(try XCTUnwrap(router.activeSession).isLeaderboardEligible)
    for level in [LevelID.levelOne, .levelTen, .heroWelcome] {
      router.startGame(levelID: level)
      XCTAssertFalse(try XCTUnwrap(router.activeSession).isLeaderboardEligible)
    }
    let debugRouter = AppRouter(progressionStore: store,
                                startConfiguration: .init(initialLevelID: .heroWelcome))
    debugRouter.startNewGame()
    XCTAssertFalse(try XCTUnwrap(debugRouter.activeSession).isLeaderboardEligible)
    router.returnToMenu()
    debugRouter.returnToMenu()
  }

  func testEligibleOriginSurvivesTransitionAndNaturalTerminalWinRecordsOnce() async throws {
    let router = AppRouter(progressionStore: store)
    router.startNewGame()
    let session = try XCTUnwrap(router.activeSession)
    let id = session.identifier
    session.advance(by: 0.05)
    let elapsed = session.elapsedTime
    // Test-only transition shortcut; production routing and eligibility are not modified.
    session.simulation.onLevelTransition?(.init(
      sourceLevelID: .levelOne, destinationLevelID: .heroWelcome, destinationEntry: .bottom,
      carryover: .init(characterID: EntityID(), health: 3, score: 100, completedLevelIDs: [.levelOne]),
      reason: .completedForward))
    await settle { session.runtimeGeneration == 1 }
    XCTAssertEqual(session.levelID, .heroWelcome)
    XCTAssertEqual(session.identifier, id)
    XCTAssertTrue(session.isLeaderboardEligible)
    XCTAssertEqual(session.elapsedTime, elapsed)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    session.runtimeSceneDidAttach(generation: session.runtimeGeneration, levelID: .heroWelcome)
    let terminal = try XCTUnwrap(session.simulation as? HeroWelcomeSimulation)
    terminal.player.position = .init(row: 1, column: 29)
    session.advance(by: 0.05)
    await settle { store.progression.highScoreEntries.count == 1 }
    let entry = try XCTUnwrap(store.progression.highScoreEntries.first)
    XCTAssertEqual(entry.id, id)
    XCTAssertEqual(entry.elapsedTime, session.elapsedTime)
    XCTAssertEqual(entry.rawScore, session.score)
    XCTAssertEqual(entry.timeBonus, HighScoreScoring.timeBonus(for: session.elapsedTime))
    guard case .results(let presented) = router.path.first else { return XCTFail("Expected Results") }
    XCTAssertEqual(presented.leaderboardEntry, entry)
    XCTAssertEqual(presented.leaderboardRank, 1)
    router.finishGame(sessionID: id, outcome: .won)
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
  }

  func testDirectTerminalVictoryLossAndIntermediateWinAreExcluded() async throws {
    let router = AppRouter(progressionStore: store)
    router.startGame(levelID: .heroWelcome)
    let direct = try XCTUnwrap(router.activeSession)
    let terminal = try XCTUnwrap(direct.simulation as? HeroWelcomeSimulation)
    terminal.player.position = .init(row: 1, column: 29)
    direct.advance(by: 0.05)
    await settle { router.activeSession == nil }
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    guard case .results(let directResult) = router.path.first else { return XCTFail("Expected Results") }
    XCTAssertNil(directResult.leaderboardEntry)
    XCTAssertNil(directResult.leaderboardRank)
    router.startNewGame()
    let loss = try XCTUnwrap(router.activeSession)
    loss.lose()
    router.finishGame(sessionID: loss.identifier, outcome: .lost)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    router.startNewGame()
    let intermediate = try XCTUnwrap(router.activeSession)
    intermediate.win()
    router.finishGame(sessionID: intermediate.identifier, outcome: .won)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
  }

  func testForcedOutcomeCannotRankEvenWithExplicitlyEligibleTestSession() async throws {
    let router = AppRouter(progressionStore: store, forcedOutcome: .won)
    let simulation = try HeroWelcomeSimulation()
    let session = GameSession(simulation: simulation, isLeaderboardEligible: true)
    router.startGame(session: session)
    session.win() // Explicit forced outcome, independent of publisher delivery during startup.
    await settle { router.activeSession == nil }
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
  }

  func testRetryKeepsOriginalCampaignOriginButDirectRetryStaysIneligible() throws {
    for isCampaign in [true, false] {
      let factory = FailFirstScoreRuntimeFactory()
      let router = AppRouter(progressionStore: store, runtimeFactory: factory)
      if isCampaign { router.startNewGame() } else { router.startGame(levelID: .levelOne) }
      guard case .gameLoadingFailure(let failure) = router.path.first else {
        return XCTFail("Expected initial load failure")
      }
      router.retryLoading(failure)
      XCTAssertEqual(try XCTUnwrap(router.activeSession).isLeaderboardEligible, isCampaign)
      router.returnToMenu()
    }
  }

  private func settle(_ condition: @MainActor () -> Bool) async {
    for _ in 0..<100 {
      if condition() { return }
      await Task.yield()
    }
    XCTFail("Router state did not settle")
  }
}

@MainActor private final class FailFirstScoreRuntimeFactory: GameLevelRuntimeFactory {
  private var failed = false
  private let factory = DefaultGameLevelRuntimeFactory()
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws -> GameLevelRuntime {
    if !failed { failed = true; throw GameLoadingError.spawnFailure(levelID) }
    return try factory.makeRuntime(levelID: levelID, configuration: configuration, seed: seed)
  }
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
                   entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?) throws -> GameLevelRuntime {
    try factory.makeRuntime(levelID: levelID, configuration: configuration, seed: seed,
                            entryPosition: entryPosition, carryover: carryover)
  }
}
