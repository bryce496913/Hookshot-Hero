import XCTest

@testable import HookshotHero

@MainActor final class LevelNineTests: XCTestCase {
  func testJavaGeometryConversionIsDeterministic() {
    XCTAssertEqual(LevelNineDefinition.lavaAnchors.count, 45)
    XCTAssertEqual(LevelNineDefinition.wallAnchors.count, 71)
    XCTAssertEqual(LevelNineDefinition.make().grid, .init(rows: 60, columns: 60))
    XCTAssertEqual(LevelNineDefinition.forwardDoorRegion, .init(rows: 7..<14, columns: 0..<4))
    XCTAssertEqual(LevelNineDefinition.chestAnchor, .init(row: 52, column: 4))
  }

  func testEntryFootprintsAreSafeOnBothSidesOfEightNineRoute() throws {
    for (simulation, start) in [
      (
        try LevelEightSimulation(entryPosition: .top) as LevelOneSimulation,
        LevelEightDefinition.topReturnStart
      ),
      (
        try LevelNineSimulation(entryPosition: .bottom) as LevelOneSimulation,
        LevelNineDefinition.bottomStart
      ),
    ] {
      let footprint = CollisionProfile.player.region(at: start)
      XCTAssertTrue(footprint.cells.allSatisfy(simulation.level.isInside))
      XCTAssertFalse(simulation.level.isBlocked(footprint))
      XCTAssertFalse(simulation.level.overlapsLava(footprint))
    }
    XCTAssertThrowsError(try LevelNineSimulation(entryPosition: .top))
    XCTAssertThrowsError(try LevelNineSimulation(entryPosition: .left))
    XCTAssertThrowsError(try LevelNineSimulation(entryPosition: .right))
  }

  func testSpawnPopulationAndEnemiesAreDeterministic() throws {
    let first = try LevelNineSimulation(seed: 496_913)
    let second = try LevelNineSimulation(seed: 496_913)
    XCTAssertEqual(first.entities.map(\.position), second.entities.map(\.position))
    XCTAssertEqual(first.entities.filter { $0.kind == .mine }.count, 3)
    XCTAssertEqual(first.entities.filter { $0.kind == .cabbage }.count, 2)
    XCTAssertEqual(first.entities.filter { $0.kind == .coin }.count, 10)
    XCTAssertEqual(first.enemies.map(\.archetype), [.skeleton, .flyingTerror])
    XCTAssertEqual(
      first.enemies.map(\.position), [.init(row: 9, column: 9), .init(row: 13, column: 16)])
  }

  func testChestPersistsAcrossLevelNineReconstruction() throws {
    let first = try LevelNineSimulation(seed: 9)
    first.player.position = LevelNineDefinition.chestAnchor
    first.update(deltaTime: 0.01)
    XCTAssertTrue(first.chestStates[0].isOpened)
    let score = first.player.score
    let returning = try LevelNineSimulation(seed: 9, carryover: first.makeCarryoverState())
    XCTAssertTrue(returning.chestStates[0].isOpened)
    returning.player.position = LevelNineDefinition.chestAnchor
    returning.update(deltaTime: 0.01)
    XCTAssertEqual(returning.player.score, score)
  }

  func testLevelNineForwardExitRequestsUnsupportedLevelTenBoundary() throws {
    let simulation = try LevelNineSimulation(seed: 9)
    var request: LevelTransitionRequest?
    simulation.onLevelTransition = { request = $0 }
    simulation.player.position = .init(row: 9, column: 3)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(request?.destinationLevelID, .levelTen)
    XCTAssertEqual(request?.destinationEntry, .right)
    XCTAssertEqual(request?.reason, .completedForward)
    XCTAssertEqual(request?.carryover.completedLevelIDs, [.levelNine])
    XCTAssertThrowsError(try LevelAssetManifest.manifest(for: .levelTen))
  }

  func testRealSessionTransitionsLevelEightToNineAndBackWithCarryover() throws {
    let factory = DefaultGameLevelRuntimeFactory()
    let configuration = GameConfiguration(reducedMotion: false, controlHintsEnabled: true)
    let characterID = EntityID()
    let initial = PlayerCarryoverState(
      characterID: characterID, health: 2, score: 37, completedLevelIDs: [])
    let levelEightRuntime = try factory.makeRuntime(
      levelID: .levelEight, configuration: configuration, seed: 496_913,
      entryPosition: .bottom, carryover: initial)
    let session = GameSession(configuration: configuration, runtime: levelEightRuntime)
    XCTAssertTrue(session.initializeWorld())
    XCTAssertTrue(session.start())
    session.advance(by: 4)

    let levelEight = try XCTUnwrap(session.simulation as? LevelEightSimulation)
    levelEight.player.position = .init(row: 3, column: 50)
    session.advance(by: 0.01)
    let forward = try XCTUnwrap(session.pendingTransitionRequest)
    XCTAssertEqual(forward.destinationLevelID, .levelNine)
    XCTAssertEqual(forward.carryover.completedLevelIDs, [.levelEight])
    XCTAssertEqual(forward.carryover.score, 137)

    let levelNineRuntime = try factory.makeRuntime(
      levelID: .levelNine, configuration: configuration, seed: 496_913,
      entryPosition: forward.destinationEntry, carryover: forward.carryover)
    session.installRuntime(levelNineRuntime)
    session.runtimeSceneDidAttach(generation: session.runtimeGeneration, levelID: .levelNine)
    XCTAssertEqual(session.elapsedTime, 4.01, accuracy: 0.001)
    XCTAssertEqual(session.simulation.renderSnapshot.player.id, characterID)
    XCTAssertEqual(session.health, 2)

    let levelNine = try XCTUnwrap(session.simulation as? LevelNineSimulation)
    levelNine.player.position = .init(row: 57, column: 29)
    session.advance(by: 0.01)
    let backward = try XCTUnwrap(session.pendingTransitionRequest)
    XCTAssertEqual(backward.destinationLevelID, .levelEight)
    XCTAssertEqual(backward.destinationEntry, .top)
    XCTAssertEqual(backward.carryover.completedLevelIDs, [.levelEight])
    let returnedRuntime = try factory.makeRuntime(
      levelID: .levelEight, configuration: configuration, seed: 496_913,
      entryPosition: backward.destinationEntry, carryover: backward.carryover)
    session.installRuntime(returnedRuntime)
    XCTAssertEqual(
      session.simulation.renderSnapshot.player.coordinate, LevelEightDefinition.topReturnStart)
    XCTAssertEqual(session.score, 137)
    XCTAssertEqual(session.elapsedTime, 4.02, accuracy: 0.001)
  }
}
