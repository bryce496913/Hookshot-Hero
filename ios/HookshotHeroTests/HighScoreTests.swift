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
      XCTAssertEqual(HighScoreScoring.timeBonus(for: elapsed, outcome: .gameOver), 0)
    }
    XCTAssertEqual(HighScoreScoring.maximumTimeBonus, 1800)
  }

  func testInitialsNormalizeOnlyThreeASCIILetters() {
    XCTAssertEqual(HighScoreInitials.validated("bry"), "BRY")
    XCTAssertEqual(HighScoreInitials.validated("BRY"), "BRY")
    XCTAssertEqual(HighScoreInitials.constrained("abcd"), "ABC")
    XCTAssertEqual(HighScoreInitials.constrained("a1b"), "AB")
    for invalid in ["ab", "abcd", "a1b", "😀", "A B", "   ", "ébc", "ßbc", "---"] {
      XCTAssertNil(HighScoreInitials.validated(invalid))
    }
  }

  func testLossesUseRawScoreAndVictoryRetainsBonusAndInvalidTimeIsRejected() throws {
    for level in [LevelID.levelOne, .levelSeven, .levelTen, .heroWelcome] {
      let loss = try XCTUnwrap(HighScoreCandidate.terminalResult(
        scoreResult(level: level, score: 123, time: 0.1, outcome: .lost), fullCampaignVictory: false))
      XCTAssertEqual(loss.timeBonus, 0)
      XCTAssertEqual(loss.totalScore, 123)
      XCTAssertEqual(loss.levelID, level)
      XCTAssertEqual(loss.outcome, .gameOver)
    }
    let win = try XCTUnwrap(HighScoreCandidate.terminalResult(scoreResult(score: 123, time: 300), fullCampaignVictory: true))
    XCTAssertEqual(win.timeBonus, 1650)
    XCTAssertEqual(win.totalScore, 1773)
    let entry = try XCTUnwrap(win.finalized(initials: "BRY"))
    XCTAssertEqual(try JSONDecoder().decode(HighScoreEntry.self, from: JSONEncoder().encode(entry)), entry)
    XCTAssertNil(HighScoreCandidate.terminalResult(scoreResult(time: .nan), fullCampaignVictory: true))
    XCTAssertEqual(HighScoreScoring.totalScore(rawScore: Int.max, elapsedTime: 0), Int.max)
    XCTAssertEqual(HighScoreCandidate.terminalResult(scoreResult(), fullCampaignVictory: false)?.timeBonus, 0)
    XCTAssertNil(HighScoreCandidate.terminalResult(scoreResult(level: .levelTen), fullCampaignVictory: true))
  }

  func testTotalThenRawThenVictoryTimeThenIDDetermineOneConsistentOrder() {
    let winner = scoreEntry(4, raw: 100, elapsed: 100, total: 1000)
    let rawWinner = scoreEntry(2, raw: 80, elapsed: 100, total: 900)
    let faster = scoreEntry(3, raw: 70, elapsed: 90, total: 900)
    let lowID = scoreEntry(1, raw: 70, elapsed: 100, total: 900)
    let highID = scoreEntry(5, raw: 70, elapsed: 100, total: 900)
    let expected = [winner, rawWinner, faster, lowID, highID]
    XCTAssertEqual(HighScoreScoring.topEntries(Array(expected.reversed())), expected)
    var loss1 = lowID; loss1.outcome = .gameOver
    var loss2 = highID; loss2.outcome = .gameOver
    XCTAssertTrue(HighScoreScoring.precedes(loss1, loss2))
    // Changing initials never changes the ranking; mixed outcomes remain transitive.
    var renamed = highID; renamed.initials = "AAA"
    XCTAssertFalse(HighScoreScoring.precedes(renamed, lowID))
    let mixed = [loss1, faster, loss2, highID]
    for a in mixed { for b in mixed { for c in mixed {
      if HighScoreScoring.precedes(a, b) && HighScoreScoring.precedes(b, c) {
        XCTAssertTrue(HighScoreScoring.precedes(a, c))
      }
    } } }
  }

  func testQualificationForEmptyNineFullAndDeterministicTies() throws {
    func candidate(_ id: Int, _ score: Int) throws -> HighScoreCandidate {
      try XCTUnwrap(HighScoreCandidate.terminalResult(scoreResult(id: scoreID(id),
        score: score, time: 3600, outcome: .lost), fullCampaignVictory: false))
    }
    let board = (1...10).map { scoreEntry($0, raw: 110 - $0 * 10, elapsed: 3600, total: 110 - $0 * 10) }
    XCTAssertEqual(HighScoreScoring.qualifyingRank(candidate: try candidate(20, 0), existingEntries: []), 1)
    XCTAssertEqual(HighScoreScoring.qualifyingRank(candidate: try candidate(20, 0), existingEntries: Array(board.prefix(9))), 10)
    XCTAssertEqual(HighScoreScoring.qualifyingRank(candidate: try candidate(20, 500), existingEntries: board), 1)
    XCTAssertEqual(HighScoreScoring.qualifyingRank(candidate: try candidate(20, 11), existingEntries: board), 10)
    XCTAssertNil(HighScoreScoring.qualifyingRank(candidate: try candidate(20, 0), existingEntries: board))
    var lossBoard = board; lossBoard[9].outcome = .gameOver
    XCTAssertEqual(HighScoreScoring.qualifyingRank(candidate: try candidate(0, 10), existingEntries: lossBoard), 10)
    XCTAssertNil(HighScoreScoring.qualifyingRank(candidate: try candidate(20, 10), existingEntries: lossBoard))
  }

  func testNewFirstAndTenthDisplaceBottomAndEleventhDoesNotMutate() throws {
    let board = (1...10).map { scoreEntry($0, raw: 110 - $0 * 10, elapsed: 3600, total: 110 - $0 * 10) }
    for score in [500, 11] {
      let candidate = try XCTUnwrap(HighScoreCandidate.terminalResult(
        scoreResult(id: scoreID(20), score: score, outcome: .lost), fullCampaignVictory: false))
      let entry = try XCTUnwrap(candidate.finalized(initials: "BRY"))
      let inserted = HighScoreScoring.topEntries(board + [entry, entry])
      XCTAssertEqual(inserted.count, 10)
      XCTAssertFalse(inserted.contains { $0.id == scoreID(10) })
      XCTAssertEqual(inserted.firstIndex { $0.id == entry.id }, score == 500 ? 0 : 9)
      if score == 500 { XCTAssertEqual(Array(inserted.dropFirst()), Array(board.prefix(9))) }
    }
    let low = try XCTUnwrap(HighScoreCandidate.terminalResult(scoreResult(score: 0, outcome: .lost), fullCampaignVictory: false))
    XCTAssertEqual(HighScoreScoring.topEntries(board + [try XCTUnwrap(low.finalized(initials: "BRY"))]), board)
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

  func testOrdinaryProgressionNeverPersistsUnnamedScores() throws {
    let store = ProgressionStore(repository: repository)
    for outcome in [GameOutcome.won, .lost] {
      store.record(result: scoreResult(score: 100, outcome: outcome))
    }
    XCTAssertEqual(store.progression.highScore, 100)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    let candidate = try XCTUnwrap(HighScoreCandidate.terminalResult(scoreResult(), fullCampaignVictory: true))
    XCTAssertNil(store.submit(candidate: candidate, initials: "ab"))
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    XCTAssertNotNil(store.submit(candidate: candidate, initials: "bry"))
    XCTAssertNil(store.submit(candidate: candidate, initials: "XYZ"))
    XCTAssertEqual(store.progression.highScoreEntries.first?.initials, "BRY")
    XCTAssertEqual(store.progression.highScore, 100)
    XCTAssertEqual(repository.load(), .loaded(store.progression))
    let reloaded = ProgressionStore(repository: repository)
    XCTAssertNil(reloaded.submit(candidate: candidate, initials: "XYZ"))
    XCTAssertEqual(reloaded.progression.highScoreEntries, store.progression.highScoreEntries)
  }

  func testStorePersistsOnlyTopTenAndDiscardsLowerEleventh() {
    let store = ProgressionStore(repository: repository)
    for index in (1...11).reversed() {
      store.recordScoreForTest(scoreResult(id: scoreID(index), score: index, time: 3600))
    }
    XCTAssertEqual(store.progression.highScoreEntries.map(\.rawScore), Array((2...11).reversed()))
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testNonQualifyingEleventhNeverMutatesProgressionOrSavedBytes() throws {
    let store = ProgressionStore(repository: repository)
    for index in 1...10 { store.recordScoreForTest(scoreResult(id: scoreID(index), score: index, time: 3600)) }
    let before = store.progression
    let bytes = try Data(contentsOf: repository.fileURL)
    let candidate = try XCTUnwrap(HighScoreCandidate.terminalResult(
      scoreResult(score: 0, outcome: .lost), fullCampaignVictory: false))
    XCTAssertNil(store.submit(candidate: candidate, initials: "BRY"))
    XCTAssertEqual(store.progression, before)
    XCTAssertEqual(try Data(contentsOf: repository.fileURL), bytes)
    XCTAssertFalse(store.hasUnsavedChanges)
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

  func testV1MigrationPreservesEveryLegacyFieldAndUnlockAndSavesV3() throws {
    let legacy = LegacyProgressionV1()
    try write(JSONEncoder().encode(legacy))
    let store = ProgressionStore(repository: repository)
    XCTAssertEqual(store.progression.schemaVersion, 3)
    XCTAssertEqual(store.progression.highScore, legacy.highScore)
    XCTAssertEqual(store.progression.completedLevelIDs, legacy.completedLevelIDs)
    XCTAssertEqual(store.progression.completedMissionIDs, legacy.completedMissionIDs)
    XCTAssertEqual(store.progression.unlockedContentIDs, legacy.unlockedContentIDs)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    XCTAssertTrue(AppRouter(progressionStore: store).isLevelSelectUnlocked)
    XCTAssertEqual(store.loadResult, .migrated(store.progression, fromVersion: 1))
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testV0MigratesThroughV1AndV2ToV3AndKeepsLevelTenUnlock() throws {
    try write(Data(#"{"schemaVersion":0,"highScore":22,"completedLevelIDs":["level-10"]}"#.utf8))
    let store = ProgressionStore(repository: repository)
    XCTAssertEqual(store.progression.schemaVersion, 3)
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
    store.recordScoreForTest(result)
    XCTAssertTrue(store.hasUnsavedChanges)
    XCTAssertNotNil(store.lastSaveError)
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
    let candidate = try XCTUnwrap(HighScoreCandidate.terminalResult(result, fullCampaignVictory: true))
    XCTAssertNil(store.submit(candidate: candidate, initials: "XYZ"))
    XCTAssertEqual(store.progression.highScoreEntries.first?.initials, "TST")
    store.flushPendingSave()
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
    store.recordScoreForTest(scoreResult())
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
      store.recordScoreForTest(scoreResult())
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
    store.recordScoreForTest(scoreResult())
    XCTAssertTrue(store.hasUnsavedChanges)
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
    XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
  }

  func testV2MigratesToV3WithUnknownInitialsAndContextPreservingScoresAndUnlock() throws {
    let id = scoreID(1)
    let json = """
    {"schemaVersion":2,"highScore":400,"completedLevelIDs":["level-10"],
     "completedMissionIDs":["mission-1"],"unlockedContentIDs":["unlock-1"],
     "highScoreEntries":[{"id":"\(id.uuidString)","rawScore":100,"elapsedTime":1200.25,
       "timeBonus":1199,"totalScore":1299}]}
    """
    try write(Data(json.utf8))
    let store = ProgressionStore(repository: repository)
    let entry = try XCTUnwrap(store.progression.highScoreEntries.first)
    XCTAssertEqual(entry.id, id)
    XCTAssertEqual(entry.initials, "---")
    XCTAssertNil(entry.levelID)
    XCTAssertNil(entry.outcome)
    XCTAssertEqual(entry.rawScore, 100)
    XCTAssertEqual(entry.elapsedTime, 1200.25)
    XCTAssertEqual(entry.timeBonus, 1199)
    XCTAssertEqual(entry.totalScore, 1299)
    XCTAssertEqual(store.progression.highScore, 400)
    XCTAssertEqual(store.progression.completedMissionIDs, [.init(rawValue: "mission-1")])
    XCTAssertEqual(store.progression.unlockedContentIDs, [.init(rawValue: "unlock-1")])
    XCTAssertEqual(store.loadResult, .migrated(store.progression, fromVersion: 2))
    XCTAssertTrue(AppRouter(progressionStore: store).isLevelSelectUnlocked)
    XCTAssertEqual(repository.load(), .loaded(store.progression))
  }

  func testV3RoundTripPreservesInitialsAndLossContext() throws {
    let store = ProgressionStore(repository: repository)
    let candidate = try XCTUnwrap(HighScoreCandidate.terminalResult(
      scoreResult(level: .levelSeven, outcome: .lost), fullCampaignVictory: false))
    store.submit(candidate: candidate, initials: "BRY")
    let loaded = ProgressionStore(repository: repository)
    XCTAssertEqual(loaded.progression.highScoreEntries, store.progression.highScoreEntries)
    XCTAssertEqual(loaded.progression.highScoreEntries.first?.levelID, .levelSeven)
    XCTAssertEqual(loaded.progression.highScoreEntries.first?.outcome, .gameOver)
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
                 timeBonus: total - raw, totalScore: total, initials: "TST", outcome: .campaignVictory)
}

@MainActor private extension ProgressionStore {
  func recordScoreForTest(_ result: GameResult) {
    if let candidate = HighScoreCandidate.terminalResult(result, fullCampaignVictory: true) {
      submit(candidate: candidate, initials: "TST")
    }
  }
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

  func testNaturalLossesFromPlayAndLevelSelectQualifyWithoutSavingUntilInitials() async throws {
    let router = AppRouter(progressionStore: store)
    for level in [LevelID.levelOne, .levelSeven, .levelTen] {
      if level == .levelOne { router.startNewGame() } else { router.startGame(levelID: level) }
      let session = try XCTUnwrap(router.activeSession)
      let simulation = try XCTUnwrap(session.simulation as? LevelOneSimulation)
      simulation.player.score = 123
      simulation.player.health = 0
      simulation.checkLoss() // Actual simulation terminal callback, not DEBUG session.lose().
      await settle { router.activeSession == nil }
      guard case .results(let result) = router.path.first else { return XCTFail("Expected Results") }
      let candidate = try XCTUnwrap(result.highScoreCandidate)
      XCTAssertEqual(candidate.outcome, .gameOver)
      XCTAssertEqual(candidate.totalScore, 123)
      XCTAssertEqual(candidate.timeBonus, 0)
      XCTAssertEqual(candidate.levelID, level)
      XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
      XCTAssertNotNil(result.leaderboardRank)
      router.returnToMenu() // Discarding initials never writes a temporary entry.
      XCTAssertNil(router.submitHighScore(sessionID: result.sessionID, initials: "BRY"))
      XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    }
    // A direct Level Select loss can save once, with no unlock side effect.
    router.startGame(levelID: .levelSeven)
    let session = try XCTUnwrap(router.activeSession)
    let simulation = try XCTUnwrap(session.simulation as? LevelOneSimulation)
    simulation.player.health = 0
    simulation.checkLoss()
    await settle { router.activeSession == nil }
    XCTAssertNotNil(router.submitHighScore(sessionID: session.identifier, initials: "bry"))
    XCTAssertNil(router.submitHighScore(sessionID: session.identifier, initials: "XYZ"))
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
    XCTAssertEqual(store.progression.highScoreEntries.first?.initials, "BRY")
    XCTAssertFalse(router.isLevelSelectUnlocked)
  }

  func testCampaignOriginSurvivesTransitionAndNaturalVictoryNeedsInitials() async throws {
    let router = AppRouter(progressionStore: store)
    router.startNewGame()
    let session = try XCTUnwrap(router.activeSession)
    let id = session.identifier
    session.advance(by: 0.05)
    let elapsed = session.elapsedTime
    session.simulation.onLevelTransition?(.init(
      sourceLevelID: .levelOne, destinationLevelID: .heroWelcome, destinationEntry: .bottom,
      carryover: .init(characterID: EntityID(), health: 3, score: 100, completedLevelIDs: [.levelOne]),
      reason: .completedForward))
    await settle { session.runtimeGeneration == 1 }
    XCTAssertEqual(session.identifier, id)
    XCTAssertTrue(session.isLeaderboardEligible)
    XCTAssertEqual(session.elapsedTime, elapsed)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    session.runtimeSceneDidAttach(generation: session.runtimeGeneration, levelID: .heroWelcome)
    let terminal = try XCTUnwrap(session.simulation as? HeroWelcomeSimulation)
    terminal.player.position = .init(row: 1, column: 29)
    session.advance(by: 0.05)
    await settle { router.activeSession == nil }
    guard case .results(let result) = router.path.first else { return XCTFail("Expected Results") }
    let candidate = try XCTUnwrap(result.highScoreCandidate)
    XCTAssertEqual(candidate.timeBonus, HighScoreScoring.timeBonus(for: session.elapsedTime))
    XCTAssertEqual(result.leaderboardRank, 1)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    let entry = try XCTUnwrap(router.submitHighScore(sessionID: id, initials: "BRY"))
    XCTAssertEqual(entry.totalScore, candidate.totalScore)
    XCTAssertEqual(entry.outcome, .campaignVictory)
    router.finishGame(sessionID: id, outcome: .won)
    XCTAssertNil(router.submitHighScore(sessionID: id, initials: "XYZ"))
    XCTAssertEqual(store.progression.highScoreEntries.count, 1)
  }

  func testDirectVictoryUsesRawScoreAndForcedOutcomesDoNotCreateCandidates() async throws {
    let router = AppRouter(progressionStore: store)
    router.startGame(levelID: .heroWelcome)
    let session = try XCTUnwrap(router.activeSession)
    let terminal = try XCTUnwrap(session.simulation as? HeroWelcomeSimulation)
    terminal.player.position = .init(row: 1, column: 29)
    session.advance(by: 0.05)
    await settle { router.activeSession == nil }
    guard case .results(let direct) = router.path.first else { return XCTFail("Expected Results") }
    XCTAssertEqual(direct.highScoreCandidate?.outcome, .victory)
    XCTAssertEqual(direct.highScoreCandidate?.timeBonus, 0)
    XCTAssertEqual(direct.highScoreCandidate?.totalScore, direct.score)
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    for outcome in [GameOutcome.won, .lost] {
      router.startNewGame()
      let forced = try XCTUnwrap(router.activeSession)
      outcome == .won ? forced.win() : forced.lose()
      await settle { router.activeSession == nil }
      guard case .results(let result) = router.path.first else { return XCTFail("Expected Results") }
      XCTAssertNil(result.highScoreCandidate)
    }
    XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
  }

  func testForcedRouterOutcomeExcludedEvenWithEligibleSession() async throws {
    let router = AppRouter(progressionStore: store, forcedOutcome: .lost)
    router.startNewGame()
    await settle { router.activeSession == nil }
    guard case .results(let result) = router.path.first else { return XCTFail("Expected Results") }
    XCTAssertNil(result.highScoreCandidate)
  }

  func testIntermediateLevelAndLevelTenEndingTransitionNeverSubmitScores() async throws {
    for (source, destination) in [(LevelID.levelOne, LevelID.levelTwo), (.levelTen, .countryRoad)] {
      let router = AppRouter(progressionStore: store)
      router.startGame(levelID: source)
      let session = try XCTUnwrap(router.activeSession)
      session.simulation.onLevelTransition?(.init(sourceLevelID: source, destinationLevelID: destination,
        destinationEntry: .bottom,
        carryover: .init(characterID: EntityID(), health: 3, score: 100, completedLevelIDs: [source]),
        reason: .completedForward))
      await settle { session.runtimeGeneration == 1 }
      XCTAssertEqual(router.path, [.gameplay])
      XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
      router.returnToMenu()
      XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
    }
  }

  func testInitialLoadRetryKeepsVictoryOriginAndNeverCreatesCandidate() throws {
    for isCampaign in [true, false] {
      let router = AppRouter(progressionStore: store, runtimeFactory: FailFirstScoreRuntimeFactory())
      if isCampaign { router.startNewGame() } else { router.startGame(levelID: .levelOne) }
      guard case .gameLoadingFailure(let failure) = router.path.first else { return XCTFail("Expected failure") }
      XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
      router.retryLoading(failure)
      XCTAssertEqual(try XCTUnwrap(router.activeSession).isLeaderboardEligible, isCampaign)
      router.returnToMenu()
      XCTAssertTrue(store.progression.highScoreEntries.isEmpty)
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
