import Combine
import SpriteKit
import XCTest

@testable import HookshotHero

@MainActor
extension GameSession {
  fileprivate convenience init(
    identifier: UUID = UUID(), levelID: LevelID = .levelOne, missionID: MissionID? = nil,
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64? = nil
  ) {
    do {
      let simulation = try DefaultGameSimulationFactory().makeSimulation(
        levelID: levelID, configuration: configuration, seed: seed)
      self.init(
        identifier: identifier, missionID: missionID, configuration: configuration,
        simulation: simulation, publishesDiagnosticPosition: seed != nil)
    } catch {
      XCTFail("Test simulation construction failed: \(error)")
      self.init(
        identifier: identifier, missionID: missionID, configuration: configuration,
        simulation: TestGameSimulation())
    }
  }
}
@MainActor
final class GameSessionTests: XCTestCase {
  func testInactiveBeforeInitializationRequiresExplicitResume() {
    let session = GameSession()
    session.applicationDidBecomeInactive()

    XCTAssertTrue(session.initializeWorld())
    XCTAssertEqual(session.state, .paused)
    XCTAssertEqual(session.pauseReason, .applicationLifecycle)

    session.applicationDidBecomeActive()
    XCTAssertEqual(session.state, .paused)
    XCTAssertTrue(session.resume())
    XCTAssertEqual(session.state, .running)
  }

  func testRunningSessionLifecyclePauseDoesNotAutoResume() {
    let session = running()
    session.applicationDidBecomeInactive()

    XCTAssertEqual(session.state, .paused)
    XCTAssertFalse(session.resume())

    session.applicationDidBecomeActive()
    XCTAssertEqual(session.state, .paused)
    XCTAssertTrue(session.resume())
  }

  func testInitializedSessionBecomesExplicitLifecyclePause() {
    let session = GameSession()
    XCTAssertTrue(session.initializeWorld())
    XCTAssertEqual(session.state, .initialized)

    session.applicationDidBecomeInactive()
    XCTAssertEqual(session.state, .paused)
    XCTAssertEqual(session.pauseReason, .applicationLifecycle)
    XCTAssertFalse(session.resume())

    session.applicationDidBecomeActive()
    XCTAssertEqual(session.state, .paused)
    XCTAssertTrue(session.resume())
    XCTAssertEqual(session.state, .running)
  }

  func testUserPauseAndTerminalStatesRejectTransitions() {
    let session = running()
    XCTAssertTrue(session.pause())
    XCTAssertEqual(session.pauseReason, .user)
    XCTAssertTrue(session.resume())

    session.win()
    XCTAssertFalse(session.pause())
    XCTAssertFalse(session.resume())
    session.applicationDidBecomeInactive()
    XCTAssertEqual(session.state, .won)
  }

  func testDisposedStateIgnoresLifecycle() {
    let session = running()
    session.dispose()
    session.applicationDidBecomeInactive()
    session.applicationDidBecomeActive()

    XCTAssertEqual(session.state, .disposed)
    XCTAssertFalse(session.resume())
  }

  func testConfigurationSnapshotAndCleanSessions() {
    let configuration = GameConfiguration(reducedMotion: true, controlHintsEnabled: false)
    let first = GameSession(missionID: .init(rawValue: "mission"), configuration: configuration)
    first.dispose()
    let second = GameSession()

    XCTAssertEqual(first.configuration, configuration)
    XCTAssertEqual(second.score, 0)
    XCTAssertEqual(second.health, 3)
    XCTAssertNil(second.missionID)
    XCTAssertNotEqual(first.identifier, second.identifier)
  }

  func testSceneTemporaryDetachmentDoesNotDisposeOrDuplicatePresentation() {
    let session = GameSession()
    XCTAssertTrue(session.initializeWorld())
    XCTAssertTrue(session.start())

    let scene = GameScene(size: CGSize(width: 100, height: 100), session: session)
    let view = SKView()
    scene.didMove(to: view)
    XCTAssertEqual(session.state, .running)

    scene.willMove(from: view)
    XCTAssertEqual(session.state, .running)

    scene.didMove(to: view)
    XCTAssertEqual(session.state, .running)
    XCTAssertFalse(scene.children.isEmpty)
    XCTAssertEqual(scene.clock.delta(at: 100), 0)
  }

  func testIdleFramesAndEmptyMovementDoNotInvalidateSwiftUI() throws {
    let session = GameSession(seed: 496_913)
    _ = session.initializeWorld()
    _ = session.start()
    let simulation = try XCTUnwrap(session.simulation as? LevelOneSimulation)
    var publications = 0
    let observation = session.objectWillChange.sink { publications += 1 }

    for _ in 0..<120 { session.advance(by: 1.0 / 120.0) }
    XCTAssertEqual(publications, 0, "120 idle frames publish no UI changes")

    simulation.input.send(.move(.up))
    session.advance(by: 0.01)
    for _ in 0..<30 { session.advance(by: 1.0 / 120.0) }
    XCTAssertEqual(simulation.renderSnapshot.player.coordinate, .init(row: 49, column: 27))
    XCTAssertEqual(publications, 0, "safe movement changes render state, not UI state")
    withExtendedLifetime(observation) {}
  }

  func testElapsedTimeIsAccurateAndNeverPublishedAtCommonFrameRates() {
    for rate in [30.0, 60.0, 120.0] {
      let session = running()
      var publications = 0
      let observation = session.objectWillChange.sink { publications += 1 }
      for _ in 0..<Int(rate * 2) { session.advance(by: 1 / rate) }
      XCTAssertEqual(session.elapsedTime, 2, accuracy: 0.000_001)
      XCTAssertEqual(publications, 0, "elapsed time at \(Int(rate)) Hz is nonobservable")
      withExtendedLifetime(observation) {}
    }
  }

  func testUIVisibleSimulationChangesPublishOnceAndFeedbackRemovalPublishesOnce() throws {
    let coin = WorldEntity(id: EntityID(), kind: .coin, position: .init(row: 49, column: 27))
    let simulation = try LevelOneSimulation(entities: [coin])
    var snapshots: [GameplayUISnapshot] = []
    simulation.onUISnapshotChange = { snapshots.append($0) }
    simulation.input.send(.move(.up))
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(snapshots.count, 1, "coin score and feedback form one coherent UI snapshot")
    XCTAssertEqual(snapshots.last?.score, 10)
    XCTAssertEqual(snapshots.last?.feedback.count, 1)
    for _ in 0..<24 { simulation.update(deltaTime: 0.1) }
    XCTAssertEqual(snapshots.count, 2, "feedback expiration is the only subsequent publication")
    XCTAssertTrue(snapshots.last?.feedback.isEmpty == true)
  }

  func testGrappleAvailabilityPublishesOnlyOnPhaseChanges() throws {
    let simulation = try LevelOneSimulation(entities: [])
    var snapshots: [GameplayUISnapshot] = []
    simulation.onUISnapshotChange = { snapshots.append($0) }
    simulation.input.send(.fireHook)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(snapshots.count, 1)
    XCTAssertFalse(snapshots[0].canGrapple)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(snapshots.count, 1, "unchanged extending frames do not republish")
  }

  func testFactoryCreatesConfiguredSeededLevelOneAndRejectsUnsupportedLevel() throws {
    let factory = DefaultGameSimulationFactory()
    let configuration = GameConfiguration(reducedMotion: true, controlHintsEnabled: false)
    let made = try factory.makeSimulation(
      levelID: .init(rawValue: "level-1"), configuration: configuration, seed: 496_913)
    let levelOne = try XCTUnwrap(made as? LevelOneSimulation)
    XCTAssertEqual(levelOne.seed, 496_913)
    XCTAssertEqual(levelOne.configuration, configuration)
    XCTAssertEqual(levelOne.presentationDefinition.levelID, .levelOne)
    XCTAssertEqual(levelOne.presentationDefinition.logicalGridSize, .init(rows: 60, columns: 60))
    let staticAssets = Set(levelOne.presentationDefinition.tileLayers.flatMap(\.tiles).map(\.asset))
    XCTAssertTrue(staticAssets.contains(LevelOneRenderAssets.floor))
    XCTAssertTrue(staticAssets.contains(LevelOneRenderAssets.lava))
    XCTAssertTrue(staticAssets.contains(LevelOneRenderAssets.wallFront))
    XCTAssertTrue(
      levelOne.presentationDefinition.staticObjects.contains {
        $0.asset == LevelOneRenderAssets.exitDoor
      })
    XCTAssertTrue(
      levelOne.renderSnapshot.entities.contains { $0.asset == LevelOneRenderAssets.chestClosed })
    XCTAssertThrowsError(
      try factory.makeSimulation(
        levelID: .init(rawValue: "unknown"), configuration: configuration, seed: nil)
    ) {
      XCTAssertEqual($0 as? GameLoadingError, .unsupportedLevel(.init(rawValue: "unknown")))
    }
  }

  func testSessionUsesSharedSimulationLifecycle() {
    let simulation = TestGameSimulation()
    let session = GameSession(simulation: simulation)
    _ = session.initializeWorld()
    _ = session.start()
    XCTAssertTrue(session.pause())
    XCTAssertEqual(simulation.pauses, [false, true])
    XCTAssertTrue(session.resume())
    XCTAssertEqual(simulation.pauses, [false, true, false])
    session.openDialogue("hello")
    XCTAssertTrue(session.continueDialogue())
    XCTAssertEqual(simulation.dialogueContinuations, 1)
    session.dispose()
    session.dispose()
    XCTAssertEqual(simulation.disposeCount, 1)
  }

  func testSceneCachesStaticPresentationAndRequestsOneSnapshotPerActiveFrame() {
    let simulation = TestGameSimulation()
    let session = GameSession(simulation: simulation)
    _ = session.initializeWorld()
    _ = session.start()
    let scene = GameScene(size: .init(width: 100, height: 100), session: session)
    XCTAssertEqual(simulation.presentationRequests, 1)
    scene.update(1)
    XCTAssertEqual(simulation.renderRequests, 1)
    scene.update(2)
    XCTAssertEqual(simulation.renderRequests, 2)
    _ = session.pause()
    scene.update(3)
    XCTAssertEqual(simulation.renderRequests, 2, "Paused frames do not reconstruct render state")
    scene.didChangeSize(.zero)
    XCTAssertEqual(simulation.presentationRequests, 1)
    XCTAssertEqual(simulation.renderRequests, 2)
  }

  private func running() -> GameSession {
    let session = GameSession()
    _ = session.initializeWorld()
    _ = session.start()
    return session
  }
}

@MainActor private final class TestGameSimulation: GameSimulation {
  let levelID = LevelID(rawValue: "test")
  let levelName = "Test"
  private let presentation = LevelOnePresentationDefinition.make(from: LevelOneDefinition.make())
  var presentationRequests = 0
  var renderRequests = 0
  var presentationDefinition: LevelPresentationDefinition {
    presentationRequests += 1
    return presentation
  }
  var outcome: GameOutcome?
  var finalStatus = PlayerStatusSnapshot(health: 3, score: 0)
  let inputController = GameInputController()
  var onUISnapshotChange: ((GameplayUISnapshot) -> Void)?
  var onOutcome: ((GameOutcome) -> Void)?
  var onDialogue: ((String) -> Void)?
  var pauses: [Bool] = []
  var dialogueContinuations = 0
  var disposeCount = 0
  var uiSnapshot: GameplayUISnapshot {
    .init(
      levelID: levelID, levelName: levelName, health: 3, maximumHealth: 5, score: 0, canMove: true,
      canGrapple: true, isPaused: false, dialogue: nil, feedback: [], diagnosticPlayerPosition: nil)
  }
  var renderSnapshot: GameRenderSnapshot {
    renderRequests += 1
      .init(
        player: .init(
          id: EntityID(), asset: LevelOneRenderAssets.lidia, coordinate: .init(row: 50, column: 27),
          renderSize: .init(width: 5.4, height: 4.4), anchor: .center, zPosition: 8,
          orientation: .right, animation: nil, opacity: 1, isHidden: false), entities: [],
        grapple: nil, effects: [])
  }
  func update(deltaTime: TimeInterval) {}
  func continueDialogue() { dialogueContinuations += 1 }
  func setPaused(_ paused: Bool) { pauses.append(paused) }
  func cancelAllInput() { inputController.cancelAllInput() }
  func dispose() { disposeCount += 1 }
}

@MainActor
final class LevelOneConversionTests: XCTestCase {
  func testJavaLevelDefinitionUsesFortyPixelBoundaryTiles() {
    let level = LevelOneDefinition.make()

    XCTAssertEqual(level.grid, GridSize(rows: 60, columns: 60))
    XCTAssertEqual(level.start, GridPosition(row: 50, column: 27))
    XCTAssertEqual(level.exitAnchor, GridPosition(row: 0, column: 27))
    XCTAssertEqual(level.entryAnchor, GridPosition(row: 56, column: 27))
    XCTAssertEqual(level.chestAnchor, GridPosition(row: 44, column: 29))
    XCTAssertEqual(level.internalWallAnchors.map(\.column), [20, 24, 28, 32, 36])

    XCTAssertTrue(level.isWall(GridPosition(row: 0, column: 0)))
    XCTAssertTrue(level.isWall(GridPosition(row: 3, column: 10)))
    XCTAssertTrue(level.isWall(GridPosition(row: 30, column: 0)))
    XCTAssertTrue(level.isWall(GridPosition(row: 30, column: 59)))
    XCTAssertTrue(level.isWall(GridPosition(row: 59, column: 27)))

    XCTAssertFalse(level.isWall(GridPosition(row: 0, column: 27)))
    XCTAssertFalse(level.isWall(GridPosition(row: 3, column: 32)))
    XCTAssertFalse(level.isWall(GridPosition(row: 4, column: 4)))
  }

  func testSpawnIsSafeAndRepeatableByPositionAndKind() throws {
    let level = LevelOneDefinition.make()
    var firstGenerator = SeededRandomNumberGenerator(seed: 42)
    var secondGenerator = SeededRandomNumberGenerator(seed: 42)

    let first = try SpawnService.spawn(in: level, using: &firstGenerator)
    let second = try SpawnService.spawn(in: level, using: &secondGenerator)

    XCTAssertEqual(first.count, 15)
    XCTAssertEqual(first.filter { $0.kind == .mine }.count, 3)
    XCTAssertEqual(first.filter { $0.kind == .cabbage }.count, 2)
    XCTAssertEqual(first.filter { $0.kind == .coin }.count, 10)
    XCTAssertEqual(first.map(\.position), second.map(\.position))
    XCTAssertEqual(Set(first.map(\.position)).count, 15)
    XCTAssertTrue(first.allSatisfy { !level.isWall($0.position) && !level.isLava($0.position) })
  }

  func testMovementHookAndLidiaSpriteCrop() throws {
    let simulation = try LevelOneSimulation(seed: 1)
    simulation.input.send(.move(.up))
    simulation.update(deltaTime: 0.01)

    XCTAssertEqual(simulation.player.position, GridPosition(row: 49, column: 27))
    XCTAssertEqual(simulation.player.facing, .up)

    simulation.input.send(.fireHook)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(simulation.player.hookshot.phase, .extending)
    XCTAssertEqual(HookshotState.maximumRange, 19)

    XCTAssertEqual(
      SpriteSheet.normalizedRect(
        x: 0,
        y: 64,
        width: 64,
        height: 64,
        sheetWidth: 576,
        sheetHeight: 256
      ),
      CGRect(x: 0, y: 0.5, width: 1.0 / 9.0, height: 0.25)
    )
  }

  func testLegacySpriteSheetDimensionsProduceCorrectSlices() {
    XCTAssertEqual(
      SpriteSheet.normalizedRect(
        x: 0,
        y: 0,
        width: 20,
        height: 26,
        sheetWidth: 120,
        sheetHeight: 26
      ),
      CGRect(x: 0, y: 0, width: 1.0 / 6.0, height: 1)
    )
    XCTAssertEqual(
      SpriteSheet.normalizedRect(
        x: 64,
        y: 32,
        width: 32,
        height: 32,
        sheetWidth: 128,
        sheetHeight: 64
      ),
      CGRect(x: 0.5, y: 0, width: 0.25, height: 0.5)
    )
    XCTAssertEqual(
      SpriteSheet.normalizedRect(
        x: 291,
        y: 67,
        width: 25,
        height: 25,
        sheetWidth: 320,
        sheetHeight: 384
      ),
      CGRect(
        x: 291.0 / 320.0,
        y: 1.0 - (92.0 / 384.0),
        width: 25.0 / 320.0,
        height: 25.0 / 384.0
      )
    )
  }

  func testVictoryAwardsJavaCompletionScoreExactlyOnce() throws {
    let simulation = try LevelOneSimulation(
      seed: 7,
      startOverride: GridPosition(row: 4, column: 29)
    )
    simulation.input.send(.move(.up))
    simulation.update(deltaTime: 0.01)

    XCTAssertEqual(simulation.outcome, .won)
    XCTAssertEqual(simulation.player.score, 100)

    simulation.update(deltaTime: 1)
    XCTAssertEqual(simulation.player.score, 100)
  }

  func testBoundaryGeometryIsAuthoritativeAndSixCellsWide() {
    let level = LevelOneDefinition.make()
    XCTAssertEqual(level.boundary.topExitRegion, GridRegion(rows: 0..<4, columns: 27..<33))
    XCTAssertEqual(level.exitRegion, level.boundary.topExitRegion)
    for column in 27...32 { XCTAssertFalse(level.isWall(.init(row: 0, column: column))) }
    XCTAssertTrue(level.isWall(.init(row: 0, column: 26)))
    XCTAssertTrue(level.isWall(.init(row: 0, column: 33)))
    XCTAssertTrue(level.boundary.topWallRegions.allSatisfy { !$0.intersects(level.exitRegion) })
    XCTAssertTrue(level.entryRegion.cells.allSatisfy(level.isWall))
    XCTAssertTrue(level.boundary.wallRegions.flatMap(\.cells).allSatisfy(level.isWall))
  }

  func testCollisionProfilesAndSpawnedFootprintsAreSafe() throws {
    let level = LevelOneDefinition.make()
    XCTAssertFalse(CollisionProfile.player.isEmpty)
    XCTAssertFalse(CollisionProfile.coin.isEmpty)
    XCTAssertFalse(CollisionProfile.cabbage.isEmpty)
    XCTAssertFalse(CollisionProfile.mine.isEmpty)
    let player = CollisionProfile.player.region(at: .init(row: 10, column: 10))
    XCTAssertEqual(player, .init(rows: 9..<12, columns: 9..<12))
    XCTAssertTrue(player.intersects(CollisionProfile.coin.region(at: .init(row: 9, column: 10))))
    var rng = SeededRandomNumberGenerator(seed: 42)
    let entities = try SpawnService.spawn(in: level, using: &rng)
    for entity in entities {
      let footprint = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
      XCTAssertFalse(level.isBlocked(footprint))
      XCTAssertFalse(level.overlapsLava(footprint))
      XCTAssertTrue(footprint.cells.allSatisfy(level.isInside))
      XCTAssertFalse(
        entities.filter { $0.id != entity.id }.contains {
          CollisionProfile.footprint(for: $0.kind).region(at: $0.position).intersects(footprint)
        })
    }
  }

  func testFeedbackExpiresOnlyWhenSimulationAdvances() throws {
    let coin = WorldEntity(id: EntityID(), kind: .coin, position: .init(row: 49, column: 27))
    let simulation = try LevelOneSimulation(seed: 1, entities: [coin])
    simulation.input.send(.move(.up))
    simulation.update(deltaTime: 0.01)
    let event = try XCTUnwrap(simulation.feedbackEvents.first)
    XCTAssertEqual(event.kind, .coinCollected(points: 10))
    XCTAssertEqual(event.message, "Coin: +10 Score")
    XCTAssertTrue(event.accessibilityAnnouncement.contains("Coin collected"))
    simulation.update(deltaTime: 0.1)
    XCTAssertEqual(simulation.feedbackEvents.map(\.id), [event.id])
    for _ in 0..<13 { simulation.update(deltaTime: 0.1) }
    XCTAssertTrue(simulation.feedbackEvents.isEmpty)
  }

  func testDialogueSuspendsTimeAndCancelsHeldInput() throws {
    let session = GameSession(seed: 1)
    _ = session.initializeWorld()
    _ = session.start()
    guard let simulation = session.simulation as? LevelOneSimulation else {
      return XCTFail("missing simulation")
    }
    simulation.input.send(.beginMove(.up))
    session.openDialogue("Chest")
    let position = simulation.player.position
    let elapsed = session.elapsedTime
    session.advance(by: 2)
    XCTAssertEqual(session.state, .dialogue("Chest"))
    XCTAssertEqual(session.elapsedTime, elapsed)
    XCTAssertEqual(simulation.player.position, position)
    XCTAssertNil(simulation.input.heldDirection)
    session.applicationDidBecomeInactive()
    XCTAssertFalse(session.continueDialogue())
    session.applicationDidBecomeActive()
    XCTAssertEqual(session.state, .dialogue("Chest"))
    XCTAssertTrue(session.continueDialogue())
    XCTAssertEqual(session.state, .running)
  }
}
