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

    let scene = GameScene(
      size: CGSize(width: 100, height: 100), session: session, runtime: session.runtime,
      generation: session.runtimeGeneration)
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
    let scene = GameScene(
      size: .init(width: 100, height: 100), session: session, runtime: session.runtime,
      generation: session.runtimeGeneration)
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

  func testLevelTransitionWaitsForReplacementSceneBeforeRunningLevelTwo() throws {
    let session = GameSession(levelID: .levelOne, seed: 42)
    XCTAssertTrue(session.initializeWorld())
    XCTAssertTrue(session.start())
    let oldScene = GameScene(
      size: .init(width: 100, height: 100), session: session, runtime: session.runtime,
      generation: session.runtimeGeneration)
    let view = SKView()
    oldScene.didMove(to: view)
    XCTAssertEqual(oldScene.levelID, .levelOne)
    XCTAssertTrue(oldScene.staticAssetIDs.contains(LevelOneRenderAssets.exitDoor))

    let carryover = PlayerCarryoverState(
      characterID: session.simulation.renderSnapshot.player.id, health: session.health, score: 25,
      completedLevelIDs: [.levelOne])
    session.simulation.onLevelTransition?(
      LevelTransitionRequest(
        sourceLevelID: .levelOne, destinationLevelID: .levelTwo, destinationEntry: .bottom,
        carryover: carryover))
    XCTAssertEqual(session.state, .transitioning(.levelTwo))

    let runtime = try DefaultGameLevelRuntimeFactory().makeRuntime(
      levelID: .levelTwo, configuration: session.configuration, seed: 99, entryPosition: .bottom,
      carryover: carryover)
    let generationBeforeInstall = session.runtimeGeneration
    session.installRuntime(runtime)

    XCTAssertEqual(session.runtimeGeneration, generationBeforeInstall + 1)
    XCTAssertEqual(session.state, .transitioning(.levelTwo))
    XCTAssertFalse(session.canSimulate)
    let positionBeforeAttachment = session.simulation.renderSnapshot.player.coordinate
    oldScene.update(10)
    XCTAssertEqual(session.simulation.renderSnapshot.player.coordinate, positionBeforeAttachment)

    oldScene.willMove(from: view)
    XCTAssertTrue(oldScene.children.isEmpty)
    XCTAssertTrue(oldScene.staticAssetIDs.isEmpty)

    let replacementScene = GameScene(
      size: .init(width: 100, height: 100), session: session, runtime: session.runtime,
      generation: session.runtimeGeneration)
    replacementScene.didMove(to: view)

    XCTAssertEqual(replacementScene.levelID, .levelTwo)
    XCTAssertEqual(session.state, .running)
    XCTAssertTrue(session.canSimulate)
    XCTAssertEqual(session.health, carryover.health)
    XCTAssertEqual(session.score, carryover.score)
    XCTAssertEqual(session.simulation.renderSnapshot.player.id, carryover.characterID)
    XCTAssertTrue(replacementScene.staticAssetIDs.contains(LevelTwoRenderAssets.lava))
    XCTAssertTrue(replacementScene.staticAssetIDs.contains(LevelTwoRenderAssets.exitDoor))
    XCTAssertTrue(replacementScene.staticAssetIDs.contains(LevelTwoRenderAssets.entryDoor))
    XCTAssertTrue(replacementScene.staticAssetIDs.contains(LevelTwoRenderAssets.smoke))
    XCTAssertFalse(replacementScene.staticAssetIDs.contains(LevelOneRenderAssets.exitDoor))
    XCTAssertTrue(
      session.simulation.renderSnapshot.entities.contains {
        $0.asset == EnemyArchetype.skeleton.asset
      })
    XCTAssertTrue(
      session.simulation.renderSnapshot.entities.contains {
        $0.asset == EnemyArchetype.flyingTerror.asset
      })
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
  var onLevelTransition: ((LevelTransitionRequest) -> Void)?
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
    return .init(
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

@MainActor
final class LevelTwoDefinitionTests: XCTestCase {
  func testLevelTwoGeometryMatchesJavaAnchors() throws {
    let level = LevelTwoDefinition.make()
    XCTAssertEqual(level.grid, GridSize(rows: 60, columns: 60))
    XCTAssertEqual(level.start, GridPosition(row: 50, column: 27))
    XCTAssertEqual(level.exitAnchor, GridPosition(row: 0, column: 27))
    XCTAssertEqual(level.entryAnchor, GridPosition(row: 56, column: 27))
    XCTAssertEqual(level.boundary.topExitRegion.columns, 27..<33)
    XCTAssertEqual(level.boundary.bottomDoorRegion.columns, 27..<33)
    XCTAssertEqual(
      LevelTwoDefinition.internalWallAnchors,
      [4, 8, 12, 16, 20, 24, 28, 32, 36, 40].map { GridPosition(row: 16, column: $0) }
        + [8, 12].map { GridPosition(row: 24, column: $0) }
        + [20, 24].flatMap { r in [36, 40].map { GridPosition(row: r, column: $0) } })
    XCTAssertEqual(LevelTwoDefinition.lavaAnchors.count, 63)
    XCTAssertTrue((0..<level.grid.rows).contains(level.exitAnchor.row))
    XCTAssertFalse(level.isBlocked(CollisionProfile.player.region(at: level.start)))
  }

  func testLevelTwoPresentationMatchesJavaDoorAndBoundaryLayout() throws {
    let level = LevelTwoDefinition.make()
    let presentation = LevelTwoPresentationDefinition.make(from: level)
    let walls = try XCTUnwrap(presentation.tileLayers.first { $0.id.rawValue == "walls" })

    XCTAssertTrue(
      walls.tiles.contains {
        $0.coordinate == GridPosition(row: 0, column: 0)
          && $0.sizeInCells == LogicalRenderSize(width: 60, height: 4)
      })
    XCTAssertTrue(
      walls.tiles.contains {
        $0.coordinate == GridPosition(row: 56, column: 0)
          && $0.sizeInCells == LogicalRenderSize(width: 60, height: 4)
      })

    let exitDoor = try XCTUnwrap(
      presentation.staticObjects.first { $0.asset == LevelTwoRenderAssets.exitDoor })
    let entryDoor = try XCTUnwrap(
      presentation.staticObjects.first { $0.asset == LevelTwoRenderAssets.entryDoor })
    XCTAssertEqual(exitDoor.coordinate, GridPosition(row: 0, column: 28))
    XCTAssertEqual(exitDoor.renderSize, LogicalRenderSize(width: 4, height: 4))
    XCTAssertEqual(entryDoor.coordinate, GridPosition(row: 56, column: 28))
    XCTAssertEqual(entryDoor.renderSize, LogicalRenderSize(width: 4, height: 4))

    let smokeObjects = presentation.staticObjects.filter { $0.asset == LevelTwoRenderAssets.smoke }
    XCTAssertEqual(
      smokeObjects.map(\.coordinate),
      [GridPosition(row: 39, column: 5), GridPosition(row: 55, column: 50)])
    XCTAssertTrue(smokeObjects.allSatisfy { $0.anchor == .bottomLeft })
  }

  func testLevelTwoManifestDoesNotPreflightUnrelatedFutureLevelAssets() {
    XCTAssertFalse(
      LevelAssetManifest.levelTwo.textureAssetIDs.contains(
        RenderAssetID(rawValue: "level-four.door.open.side")))
    XCTAssertFalse(
      LevelAssetManifest.levelTwo.textureAssetIDs.contains(
        RenderAssetID(rawValue: "enemy.minotaur")))
    XCTAssertTrue(
      LevelAssetManifest.levelTwo.textureAssetIDs.contains(LevelTwoRenderAssets.entryDoor))
    XCTAssertTrue(
      LevelAssetManifest.levelTwo.textureAssetIDs.contains(EnemyArchetype.skeleton.asset))
    XCTAssertTrue(
      LevelAssetManifest.levelTwo.textureAssetIDs.contains(EnemyArchetype.flyingTerror.asset))
    XCTAssertTrue(
      LevelAssetManifest.levelTwo.animationIDs.contains(
        LevelTwoRenderAnimations.enemy(.skeleton, .right)))
    XCTAssertTrue(
      LevelAssetManifest.levelTwo.animationIDs.contains(
        LevelTwoRenderAnimations.enemy(.flyingTerror, .right)))
  }

}

@MainActor
final class LevelTwoSpawnAndEnemyTests: XCTestCase {
  func testLevelTwoSpawnsItemsAndEnemiesDeterministically() throws {
    let first = try LevelTwoSimulation(seed: 496_913)
    let second = try LevelTwoSimulation(seed: 496_913)
    XCTAssertEqual(first.entities.filter { $0.kind == .mine }.count, 3)
    XCTAssertEqual(first.entities.filter { $0.kind == .cabbage }.count, 2)
    XCTAssertEqual(first.entities.filter { $0.kind == .coin }.count, 10)
    XCTAssertEqual(first.entities.map(\.position), second.entities.map(\.position))
    XCTAssertEqual(
      Set(first.renderSnapshot.entities.map(\.asset))
        .intersection([EnemyArchetype.skeleton.asset, EnemyArchetype.flyingTerror.asset]),
      Set([EnemyArchetype.skeleton.asset, EnemyArchetype.flyingTerror.asset]))
  }

  func testLevelTwoEnemyConstants() throws {
    XCTAssertEqual(EnemyArchetype.skeleton.maximumHealth, 3)
    XCTAssertEqual(EnemyArchetype.skeleton.sight, 19)
    XCTAssertEqual(EnemyArchetype.skeleton.patrolInterval, 0.7)
    XCTAssertEqual(EnemyArchetype.skeleton.seekInterval, 0.5)
    XCTAssertEqual(EnemyArchetype.flyingTerror.maximumHealth, 5)
    XCTAssertEqual(EnemyArchetype.flyingTerror.sight, 39)
    XCTAssertEqual(EnemyArchetype.flyingTerror.patrolInterval, 0.3)
    XCTAssertEqual(EnemyArchetype.flyingTerror.seekInterval, 0.3)
    XCTAssertEqual(EnemyArchetype.flyingTerror.footprint.rowOffsets, -3..<5)
  }
}

@MainActor
final class LevelThreeLoadingTests: XCTestCase {
  func testLevelThreeManifestAndSceneContainDynamicAssets() throws {
    let simulation = try LevelThreeSimulation(seed: 496_913)
    let renderedAssets = Set(simulation.renderSnapshot.entities.map(\.asset))

    XCTAssertTrue(
      LevelAssetManifest.levelThree.textureAssetIDs.contains(LevelOneRenderAssets.chestClosed))
    XCTAssertTrue(
      LevelAssetManifest.levelThree.textureAssetIDs.contains(LevelOneRenderAssets.chestOpen))
    XCTAssertTrue(renderedAssets.contains(EnemyArchetype.skeleton.asset))
    XCTAssertTrue(renderedAssets.contains(EnemyArchetype.flyingTerror.asset))
  }
}

@MainActor
final class LevelFourLoadingTests: XCTestCase {
  func testLevelFourManifestContainsOnlyItsRequiredCombatAndDoorAssets() {
    let manifest = LevelAssetManifest.levelFour

    XCTAssertTrue(manifest.textureAssetIDs.contains(LevelFourRenderAssets.doorOpenSide))
    XCTAssertTrue(manifest.textureAssetIDs.contains(LevelFourRenderAssets.doorClosedRight))
    XCTAssertTrue(manifest.textureAssetIDs.contains(EnemyArchetype.minotaur.asset))
    XCTAssertTrue(
      manifest.textureAssetIDs.contains(RenderAssetID(rawValue: "enemy.minotaur.3-2")))
    XCTAssertFalse(manifest.textureAssetIDs.contains(LevelOneRenderAssets.chestClosed))
    XCTAssertFalse(manifest.textureAssetIDs.contains(EnemyArchetype.skeleton.asset))
    XCTAssertFalse(manifest.textureAssetIDs.contains(EnemyArchetype.flyingTerror.asset))
  }

  func testLevelFourSimulationCanBeConstructedAtBottomEntry() throws {
    let simulation = try LevelFourSimulation(seed: 496_913)

    XCTAssertEqual(simulation.levelID, .levelFour)
    XCTAssertEqual(simulation.player.position, GridPosition(row: 50, column: 27))
    XCTAssertEqual(simulation.presentationDefinition.levelID, .levelFour)
    XCTAssertTrue(
      simulation.renderSnapshot.entities.contains { $0.asset == EnemyArchetype.minotaur.asset })
  }

  func testReturningFromLevelFiveUsesRightEntryAndRestoresDefeatedBoss() throws {
    let carryover = PlayerCarryoverState(
      characterID: EntityID(), health: 4, score: 500,
      completedLevelIDs: [.levelOne, .levelTwo, .levelThree, .levelFour])
    let simulation = try LevelFourSimulation(entryPosition: .right, carryover: carryover)

    XCTAssertEqual(simulation.player.position, .init(row: 29, column: 52))
    XCTAssertFalse(
      simulation.renderSnapshot.entities.contains { $0.asset == EnemyArchetype.minotaur.asset })
    XCTAssertTrue(
      simulation.renderSnapshot.entities.contains { $0.asset == LevelFourRenderAssets.doorOpenSide }
    )
  }
}

@MainActor final class LevelFiveLoadingTests: XCTestCase {
  func testLevelFiveGeometryMatchesJavaDesign() throws {
    let level = LevelFiveDefinition.make()
    XCTAssertEqual(level.displayName, "Level 5")
    XCTAssertEqual(level.grid, .init(rows: 60, columns: 60))
    XCTAssertEqual(LevelFiveDefinition.wallAnchors.count, 52)
    XCTAssertEqual(LevelFiveDefinition.lavaAnchors.count, 61)
    XCTAssertEqual(level.chestAnchor, .init(row: 52, column: 4))
    XCTAssertEqual(level.entryRegion, .init(rows: 8..<12, columns: 0..<4))
  }

  func testLevelFiveCanBeConstructedAndUsesItsManifest() throws {
    let simulation = try LevelFiveSimulation(seed: 496_913)
    XCTAssertEqual(simulation.levelID, .levelFive)
    XCTAssertEqual(simulation.presentationDefinition.levelID, .levelFive)
    XCTAssertTrue(LevelAssetManifest.levelFive.textureAssetIDs.contains(LevelFiveRenderAssets.lava))
    XCTAssertEqual(
      simulation.renderSnapshot.entities.filter { $0.asset == LevelOneRenderAssets.coin }.count, 10)
    XCTAssertTrue(
      simulation.renderSnapshot.entities.contains { $0.asset == EnemyArchetype.skeleton.asset })
    XCTAssertTrue(
      simulation.renderSnapshot.entities.contains { $0.asset == EnemyArchetype.flyingTerror.asset })
    XCTAssertEqual(
      simulation.presentationDefinition.staticObjects.filter {
        $0.asset == LevelFiveRenderAssets.chest
      }.count, 0)
  }

  func testLevelFiveChestAndRightDoorReturn() throws {
    let simulation = try LevelFiveSimulation(seed: 496_913)
    simulation.player.position = simulation.level.chestAnchor
    simulation.update(deltaTime: 0.01)
    XCTAssertTrue(simulation.chestOpen)
    XCTAssertEqual(simulation.player.score, 100)
    XCTAssertTrue(
      simulation.renderSnapshot.entities.contains { $0.asset == LevelFiveRenderAssets.chest })

    var transition: LevelTransitionRequest?
    simulation.onLevelTransition = { transition = $0 }
    simulation.player.position = .init(row: 9, column: 3)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(transition?.destinationLevelID, .levelFour)
    XCTAssertEqual(transition?.destinationEntry, .right)
  }

  func testLevelFiveTopEntryAndEnemySimulationAreActive() throws {
    let simulation = try LevelFiveSimulation(seed: 496_913, entryPosition: .top)
    XCTAssertEqual(simulation.player.position, .init(row: 5, column: 29))
    for enemy in simulation.enemies {
      let enemyRegion = enemy.archetype.footprint.region(at: enemy.position)
      for entry in [GridPosition(row: 5, column: 29), .init(row: 8, column: 7)] {
        XCTAssertFalse(enemyRegion.intersects(CollisionProfile.player.region(at: entry)))
      }
    }
    let before = simulation.enemies.map(\.position)
    for _ in 0..<7 { simulation.update(deltaTime: 0.1) }
    XCTAssertNotEqual(simulation.enemies.map(\.position), before)

    let contactSimulation = try LevelFiveSimulation(seed: 496_913, entryPosition: .top)
    contactSimulation.player.position = contactSimulation.enemies[0].position
    let health = contactSimulation.player.health
    contactSimulation.update(deltaTime: 0.01)
    XCTAssertEqual(contactSimulation.player.health, health - 1)
  }
}

@MainActor final class LevelSixLoadingTests: XCTestCase {
  func testGeometryMatchesEveryJavaGroupAndCounts() throws {
    let level = LevelSixDefinition.make()
    XCTAssertEqual(level.grid, .init(rows: 60, columns: 60))
    XCTAssertEqual(level.displayName, "Level 6")
    XCTAssertEqual(LevelSixDefinition.wallAnchors.count, 54)
    XCTAssertEqual(LevelSixDefinition.lavaAnchors.count, 49)
    XCTAssertEqual(LevelSixDefinition.bottomStart, .init(row: 50, column: 27))
    XCTAssertEqual(LevelSixDefinition.topStart, .init(row: 5, column: 23))
    XCTAssertEqual(level.entryAnchor, .init(row: 56, column: 27))
    XCTAssertEqual(level.exitAnchor, .init(row: 0, column: 51))
    XCTAssertEqual(level.entryRegion, .init(rows: 56..<60, columns: 27..<33))
    XCTAssertEqual(level.exitRegion, .init(rows: 0..<4, columns: 51..<57))
    for anchor in [GridPosition(row: 20, column: 8), .init(row: 48, column: 48), .init(row: 12, column: 4), .init(row: 32, column: 20), .init(row: 24, column: 36), .init(row: 52, column: 8), .init(row: 44, column: 16), .init(row: 52, column: 32), .init(row: 16, column: 36), .init(row: 4, column: 48), .init(row: 24, column: 24)] {
      XCTAssertTrue(LevelSixDefinition.wallAnchors.contains(anchor))
    }
    for anchor in [GridPosition(row: 4, column: 8), .init(row: 16, column: 28), .init(row: 28, column: 48), .init(row: 48, column: 28), .init(row: 28, column: 52), .init(row: 24, column: 4), .init(row: 40, column: 8), .init(row: 48, column: 12), .init(row: 44, column: 4), .init(row: 52, column: 24), .init(row: 32, column: 48)] {
      XCTAssertTrue(LevelSixDefinition.lavaAnchors.contains(anchor))
    }
  }

  func testTwoChestsRenderAndOpenIndependently() throws {
    let simulation = try LevelSixSimulation(seed: 496_913)
    XCTAssertEqual(simulation.chestStates.count, 2)
    XCTAssertEqual(simulation.chestStates.map(\.definition.interactionAnchor), [.init(row: 4, column: 24), .init(row: 44, column: 8)])
    XCTAssertEqual(simulation.chestStates.map(\.definition.renderAnchor), [.init(row: 4, column: 24), .init(row: 44, column: 8)])
    XCTAssertEqual(simulation.renderSnapshot.entities.filter { [LevelSixRenderAssets.chestSide, LevelSixRenderAssets.chestFront].contains($0.asset) }.count, 2)
    simulation.player.health = 2
    simulation.player.position = .init(row: 4, column: 24)
    simulation.activateChestAndExit()
    XCTAssertEqual(simulation.player.score, 100)
    XCTAssertEqual(simulation.player.health, 4)
    XCTAssertEqual(simulation.chestStates.map(\.isOpened), [true, false])
    simulation.activateChestAndExit()
    XCTAssertEqual(simulation.player.score, 100)
    simulation.player.position = .init(row: 44, column: 8)
    simulation.activateChestAndExit()
    XCTAssertEqual(simulation.player.score, 200)
    XCTAssertEqual(simulation.player.health, 5)
    XCTAssertEqual(simulation.chestStates.map(\.isOpened), [true, true])
  }

  func testDeterministicSpawnsAndSafeCorrectedEnemies() throws {
    let first = try LevelSixSimulation(seed: 496_913)
    let second = try LevelSixSimulation(seed: 496_913)
    XCTAssertEqual(first.entities.map(\.kind).filter { $0 == .mine }.count, 3)
    XCTAssertEqual(first.entities.map(\.kind).filter { $0 == .cabbage }.count, 2)
    XCTAssertEqual(first.entities.map(\.kind).filter { $0 == .coin }.count, 10)
    XCTAssertEqual(first.entities.map(\.position), second.entities.map(\.position))
    XCTAssertEqual(first.enemies.map(\.position), [.init(row: 22, column: 53), .init(row: 10, column: 52)])
    XCTAssertEqual(first.enemies.map(\.position), second.enemies.map(\.position))
    XCTAssertEqual(first.enemies.map(\.health), [3, 5])
    XCTAssertTrue(first.renderSnapshot.entities.contains { $0.asset == EnemyArchetype.skeleton.asset && $0.health != nil })
    XCTAssertTrue(first.renderSnapshot.entities.contains { $0.asset == EnemyArchetype.flyingTerror.asset && $0.health != nil })
  }

  func testBackwardAndForwardDestinationsStayOnJavaBranch() throws {
    let returning = try LevelSixSimulation(seed: 496_913)
    var request: LevelTransitionRequest?
    returning.onLevelTransition = { request = $0 }
    returning.player.position = .init(row: 55, column: 29)
    returning.update(deltaTime: 0.01)
    XCTAssertEqual(request?.destinationLevelID, .levelFour)
    XCTAssertEqual(request?.destinationEntry, .top)
    XCTAssertEqual(request?.reason, .returnedBackward)

    let completing = try LevelSixSimulation(seed: 496_913)
    completing.player.position = .init(row: 4, column: 53)
    completing.input.send(.move(.up))
    completing.update(deltaTime: 0.01)
    XCTAssertEqual(completing.outcome, .won)
    XCTAssertEqual(completing.player.score, 100)
    XCTAssertTrue(completing.completedLevelIDs.contains(.levelSix))
    completing.update(deltaTime: 1)
    XCTAssertEqual(completing.player.score, 100)
  }
}
