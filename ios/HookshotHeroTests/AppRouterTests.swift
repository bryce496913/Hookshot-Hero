import XCTest

@testable import HookshotHero

@MainActor final class AppRouterTests: XCTestCase {
  private var directory: URL!
  private var progression: ProgressionStore!
  private var router: AppRouter!
  override func setUp() {
    directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    progression = ProgressionStore(
      repository: ProgressionRepository(fileURL: directory.appending(path: "save.json")))
    router = AppRouter(progressionStore: progression)
  }
  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
  }
  func testStartingSecondGameDisposesFirstAndUsesLatestConfiguration() {
    router.startNewGame(configuration: .init(reducedMotion: false, controlHintsEnabled: true))
    let first = router.activeSession!
    router.startNewGame(configuration: .init(reducedMotion: true, controlHintsEnabled: false))
    XCTAssertEqual(first.state, .disposed)
    XCTAssertEqual(
      router.activeSession?.configuration, .init(reducedMotion: true, controlHintsEnabled: false))
    XCTAssertEqual(router.path, [.gameplay])
  }
  func testReturnToMenuDisposesActiveSession() {
    router.startNewGame()
    let session = router.activeSession!
    router.returnToMenu()
    router.returnToMenu()
    XCTAssertEqual(session.state, .disposed)
    XCTAssertNil(router.activeSession)
    XCTAssertTrue(router.path.isEmpty)
  }
  func testWinCreatesSingleImmutableResultAndUpdatesProgression() {
    let coin = WorldEntity(id: EntityID(), kind: .coin, position: .init(row: 49, column: 27))
    let simulation: LevelOneSimulation
    do { simulation = try LevelOneSimulation(entities: [coin]) } catch {
      return XCTFail("fixture failed: \(error)")
    }
    let session = GameSession(simulation: simulation)
    router.startGame(session: session)
    session.simulation.inputController.send(.move(.up))
    session.advance(by: 2)
    session.win()
    session.win()
    guard case .results(let result) = router.path.first else { return XCTFail("Missing results") }
    XCTAssertEqual(router.path.count, 1)
    XCTAssertNil(router.activeSession)
    XCTAssertEqual(result.sessionID, session.identifier)
    XCTAssertEqual(result.levelID, session.levelID)
    XCTAssertEqual(result.score, 10)
    XCTAssertEqual(result.elapsedTime, 2)
    XCTAssertEqual(result.outcome, .won)
    XCTAssertEqual(progression.progression.highScore, 10)
    XCTAssertTrue(progression.progression.completedLevelIDs.contains(session.levelID))
  }
  func testLossCreatesOneResultWithoutCompletion() {
    router.startNewGame()
    let session = router.activeSession!
    _ = session.initializeWorld()
    _ = session.start()
    session.lose()
    guard case .results(let result) = router.path.first else { return XCTFail("Missing results") }
    XCTAssertEqual(result.outcome, .lost)
    XCTAssertTrue(progression.progression.completedLevelIDs.isEmpty)
  }
  func testStaleTerminalEventIsIgnored() {
    router.startNewGame()
    let old = router.activeSession!
    router.startNewGame()
    let current = router.activeSession!
    router.finishGame(sessionID: old.identifier, outcome: .won)
    XCTAssertTrue(router.activeSession === current)
    XCTAssertEqual(router.path, [.gameplay])
  }

  func testStartNewGameAndExplicitStartForwardRequestedLevel() {
    let factory = RecordingSimulationFactory()
    router = AppRouter(
      progressionStore: progression, simulationFactory: factory, levelSeed: 496_913)
    router.startNewGame()
    XCTAssertEqual(factory.requests.map(\.levelID), [.levelOne])

    let unsupported = LevelID(rawValue: "future-level")
    router.startGame(levelID: unsupported)
    XCTAssertEqual(factory.requests.last?.levelID, unsupported)
    guard case .gameLoadingFailure(let failure) = router.path.first else {
      return XCTFail("Expected a visible loading failure")
    }
    XCTAssertEqual(failure.requestedLevelID, unsupported)
    XCTAssertEqual(failure.diagnosticCode, "unsupported-level")
    XCTAssertNil(router.activeSession)
  }

  func testRetryPreservesLevelAndSuccessReplacesFailure() {
    let factory = RecordingSimulationFactory(failuresBeforeSuccess: 1)
    let logger = RecordingLoadingLogger()
    router = AppRouter(progressionStore: progression, simulationFactory: factory, logger: logger)
    let requested = LevelID(rawValue: "requested-level")
    router.startGame(levelID: requested)
    guard case .gameLoadingFailure(let failure) = router.path.first else {
      return XCTFail("Expected failure")
    }
    XCTAssertEqual(failure.diagnosticCode, "unsupported-level")
    XCTAssertEqual(logger.errors.first?.0, requested)
    factory.supportedLevel = requested
    router.retryLoading(failure)
    XCTAssertEqual(factory.requests.map(\.levelID), [requested, requested])
    XCTAssertEqual(router.path, [.gameplay])
    XCTAssertNotNil(router.activeSession)
  }

  func testReturnToMenuClearsLoadingFailure() {
    let factory = RecordingSimulationFactory()
    router = AppRouter(progressionStore: progression, simulationFactory: factory)
    router.startGame(levelID: .init(rawValue: "missing"))
    XCTAssertFalse(router.path.isEmpty)
    router.returnToMenu()
    XCTAssertTrue(router.path.isEmpty)
    XCTAssertNil(router.activeSession)
  }
}

@MainActor private final class RecordingSimulationFactory: GameSimulationFactory {
  struct Request {
    let levelID: LevelID
    let configuration: GameConfiguration
    let seed: UInt64?
    let entryPosition: LevelEntryPosition
    let carryover: PlayerCarryoverState?
  }
  var requests: [Request] = []
  var supportedLevel: LevelID = .levelOne
  var failuresBeforeSuccess: Int
  init(failuresBeforeSuccess: Int = 0) { self.failuresBeforeSuccess = failuresBeforeSuccess }
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> any GameSimulation
  {
    try makeSimulation(levelID: levelID, configuration: configuration, seed: seed, entryPosition: .bottom, carryover: nil)
  }
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?, entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?) throws -> any GameSimulation {
    requests.append(.init(levelID: levelID, configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover))
    if failuresBeforeSuccess > 0 {
      failuresBeforeSuccess -= 1
      throw GameLoadingError.unsupportedLevel(levelID)
    }
    guard levelID == supportedLevel else { throw GameLoadingError.unsupportedLevel(levelID) }
    return try LevelOneSimulation(configuration: configuration, seed: seed ?? 1, entryPosition: entryPosition, carryover: carryover)
  }
}

private final class RecordingLoadingLogger: GameLoadingLogging {
  var errors: [(LevelID, GameLoadingError, Bool)] = []
  func loadingFailed(levelID: LevelID, error: GameLoadingError, isRetry: Bool) {
    errors.append((levelID, error, isRetry))
  }
}
