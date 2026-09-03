import Combine
import XCTest

@testable import HookshotHero

@MainActor final class AppRouterLevelTransitionTests: XCTestCase {
  private let configuration = GameConfiguration(
    reducedMotion: false, controlHintsEnabled: true)
  private let seed: UInt64 = 496_913

  func testLevelFourRightDoorLoadsLevelFiveThroughRouterAndWaitsForSceneAttachment() async throws {
    try await assertLevelFourTransition(
      exit: .init(row: 29, column: 57), destination: .levelFive, entry: .left,
      expectedStart: .init(row: 8, column: 7))
  }

  func testLevelFourTopDoorLoadsLevelSixThroughRouterAndWaitsForSceneAttachment() async throws {
    try await assertLevelFourTransition(
      exit: .init(row: 3, column: 29), destination: .levelSix, entry: .bottom,
      expectedStart: LevelSixDefinition.bottomStart)
  }

  func testRetryRetainsTransitionDestinationEntryAndCarryover() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let progression = ProgressionStore(
      repository: ProgressionRepository(fileURL: directory.appending(path: "save.json")))
    let realFactory = DefaultGameLevelRuntimeFactory()
    let factory = FailFirstTransitionRuntimeFactory(wrapping: realFactory, failing: .levelFive)
    let logger = TransitionLoadingLogger()
    let router = AppRouter(
      progressionStore: progression, runtimeFactory: factory, levelSeed: seed, logger: logger)
    let carryover = PlayerCarryoverState(
      characterID: EntityID(), health: 2, score: 37, completedLevelIDs: [.levelFour])
    let sourceRuntime = try realFactory.makeRuntime(
      levelID: .levelFour, configuration: configuration, seed: seed, entryPosition: .bottom,
      carryover: carryover)
    let session = GameSession(configuration: configuration, runtime: sourceRuntime)
    router.startGame(session: session)

    (session.simulation as? LevelFourSimulation)?.player.position = .init(row: 29, column: 57)
    session.advance(by: 0.01)
    await waitUntil { if case .gameLoadingFailure = router.path.first { true } else { false } }

    guard case .gameLoadingFailure(let failure) = router.path.first else {
      return XCTFail("Expected the injected transition loading failure")
    }
    let retainedRequest = try XCTUnwrap(failure.transitionRequest)
    XCTAssertEqual(retainedRequest.destinationLevelID, .levelFive)
    XCTAssertEqual(retainedRequest.destinationEntry, .left)
    XCTAssertEqual(retainedRequest.carryover, carryover)
    XCTAssertEqual(failure.requestedLevelID, .levelFive)
    XCTAssertEqual(failure.diagnosticCode, GameLoadingError.spawnFailure(.levelFive).diagnosticCode)

    router.retryLoading(failure)
    await waitUntil { session.runtimeGeneration == 1 }

    XCTAssertEqual(factory.transitionRequests.count, 2)
    XCTAssertEqual(factory.transitionRequests[0], retainedRequest)
    XCTAssertEqual(factory.transitionRequests[1], retainedRequest)
    XCTAssertEqual(logger.failures.map(\.isRetry), [false])
    XCTAssertEqual(session.state, .transitioning(.levelFive))
    XCTAssertEqual(router.path, [.gameplay])
  }

  private func assertLevelFourTransition(
    exit: GridPosition, destination: LevelID, entry: LevelEntryPosition,
    expectedStart: GridPosition, file: StaticString = #filePath, line: UInt = #line
  ) async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let progression = ProgressionStore(
      repository: ProgressionRepository(fileURL: directory.appending(path: "save.json")))
    let logger = TransitionLoadingLogger()
    let runtimeFactory = DefaultGameLevelRuntimeFactory(
      simulationFactory: DefaultGameSimulationFactory(), preflight: DefaultAssetPreflight())
    let router = AppRouter(
      progressionStore: progression, runtimeFactory: runtimeFactory, levelSeed: seed,
      logger: logger)

    let characterID = EntityID()
    let sourceCarryover = PlayerCarryoverState(
      characterID: characterID, health: 2, score: 37, completedLevelIDs: [.levelFour])
    let sourceRuntime = try runtimeFactory.makeRuntime(
      levelID: .levelFour, configuration: configuration, seed: seed, entryPosition: .bottom,
      carryover: sourceCarryover)
    let session = GameSession(configuration: configuration, runtime: sourceRuntime)
    let sessionID = session.identifier
    var observedStates: [GameSessionState] = []
    let observation = session.$state.sink { observedStates.append($0) }
    defer { observation.cancel() }

    router.startGame(session: session)
    XCTAssertEqual(session.state, .running, file: file, line: line)
    XCTAssertEqual(router.path, [.gameplay], file: file, line: line)
    XCTAssertTrue(router.activeSession === session, file: file, line: line)

    let source = try XCTUnwrap(session.simulation as? LevelFourSimulation, file: file, line: line)
    source.player.position = exit
    session.advance(by: 0.01)

    XCTAssertEqual(session.state, .transitioning(destination), file: file, line: line)
    let request = try XCTUnwrap(session.pendingTransitionRequest, file: file, line: line)
    XCTAssertEqual(request.sourceLevelID, .levelFour, file: file, line: line)
    XCTAssertEqual(request.destinationLevelID, destination, file: file, line: line)
    XCTAssertEqual(request.destinationEntry, entry, file: file, line: line)
    XCTAssertEqual(request.reason, .completedForward, file: file, line: line)
    XCTAssertEqual(request.carryover, sourceCarryover, file: file, line: line)

    let generationBeforeTransition = session.runtimeGeneration
    await waitUntil {
      session.runtimeGeneration == generationBeforeTransition + 1 || !logger.failures.isEmpty
    }
    if let failure = logger.failures.first {
      XCTFail(
        "Typed loading failure for \(failure.levelID.rawValue): "
          + "\(failure.error.diagnosticCode) — \(failure.error.localizedDescription); "
          + "isRetry=\(failure.isRetry)", file: file, line: line)
      guard case .gameLoadingFailure(let presentation) = router.path.first else { return }
      XCTAssertEqual(presentation.requestedLevelID, destination, file: file, line: line)
      XCTAssertEqual(
        presentation.diagnosticCode, failure.error.diagnosticCode, file: file, line: line)
      XCTAssertEqual(presentation.transitionRequest, request, file: file, line: line)
      return
    }

    XCTAssertEqual(
      session.runtimeGeneration, generationBeforeTransition + 1, file: file, line: line)
    XCTAssertEqual(session.state, .transitioning(destination), file: file, line: line)
    XCTAssertFalse(session.canSimulate, file: file, line: line)
    XCTAssertNil(session.pendingTransitionRequest, file: file, line: line)
    XCTAssertEqual(session.identifier, sessionID, file: file, line: line)
    XCTAssertTrue(router.activeSession === session, file: file, line: line)
    XCTAssertEqual(router.path, [.gameplay], file: file, line: line)
    XCTAssertFalse(
      router.path.contains { if case .gameLoadingFailure = $0 { true } else { false } })
    XCTAssertTrue(logger.failures.isEmpty, file: file, line: line)

    let currentGeneration = session.runtimeGeneration
    session.runtimeSceneDidAttach(generation: currentGeneration - 1, levelID: destination)
    XCTAssertEqual(session.state, .transitioning(destination), file: file, line: line)
    session.runtimeSceneDidAttach(generation: currentGeneration, levelID: .levelFour)
    XCTAssertEqual(session.state, .transitioning(destination), file: file, line: line)
    session.runtimeSceneDidAttach(generation: currentGeneration, levelID: destination)

    XCTAssertEqual(session.state, .running, file: file, line: line)
    XCTAssertEqual(session.levelID, destination, file: file, line: line)
    XCTAssertTrue(session.canSimulate, file: file, line: line)
    XCTAssertEqual(
      session.simulation.renderSnapshot.player.coordinate, expectedStart, file: file, line: line)
    XCTAssertEqual(session.health, sourceCarryover.health, file: file, line: line)
    XCTAssertEqual(session.score, sourceCarryover.score, file: file, line: line)
    XCTAssertEqual(session.simulation.renderSnapshot.player.id, characterID, file: file, line: line)
    XCTAssertEqual(
      (session.simulation as? LevelOneSimulation)?.makeCarryoverState().completedLevelIDs,
      sourceCarryover.completedLevelIDs, file: file, line: line)
    XCTAssertTrue(observedStates.contains(.transitioning(destination)), file: file, line: line)
    XCTAssertEqual(observedStates.last, .running, file: file, line: line)
    XCTAssertEqual(router.path, [.gameplay], file: file, line: line)
  }

  private func waitUntil(
    attempts: Int = 100, condition: @MainActor () -> Bool
  ) async {
    for _ in 0..<attempts {
      if condition() { return }
      await Task.yield()
    }
  }
}

private final class TransitionLoadingLogger: GameLoadingLogging {
  struct Failure {
    let levelID: LevelID
    let error: GameLoadingError
    let isRetry: Bool
  }

  private(set) var failures: [Failure] = []

  func loadingFailed(levelID: LevelID, error: GameLoadingError, isRetry: Bool) {
    failures.append(.init(levelID: levelID, error: error, isRetry: isRetry))
  }
}

@MainActor private final class FailFirstTransitionRuntimeFactory: GameLevelRuntimeFactory {
  private let wrapped: DefaultGameLevelRuntimeFactory
  private let failingLevelID: LevelID
  private var hasFailed = false
  private(set) var transitionRequests: [LevelTransitionRequest] = []

  init(wrapping wrapped: DefaultGameLevelRuntimeFactory, failing levelID: LevelID) {
    self.wrapped = wrapped
    self.failingLevelID = levelID
  }

  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> GameLevelRuntime
  {
    try wrapped.makeRuntime(levelID: levelID, configuration: configuration, seed: seed)
  }

  func makeRuntime(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws -> GameLevelRuntime {
    if let carryover {
      transitionRequests.append(
        .init(
          sourceLevelID: .levelFour, destinationLevelID: levelID,
          destinationEntry: entryPosition, carryover: carryover))
    }
    if levelID == failingLevelID, !hasFailed {
      hasFailed = true
      throw GameLoadingError.spawnFailure(levelID)
    }
    return try wrapped.makeRuntime(
      levelID: levelID, configuration: configuration, seed: seed,
      entryPosition: entryPosition, carryover: carryover)
  }
}
