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
    let leftEntry = try LevelNineSimulation(entryPosition: .left)
    XCTAssertEqual(leftEntry.player.position, LevelNineDefinition.leftStart)
    XCTAssertFalse(
      leftEntry.level.isBlocked(CollisionProfile.player.region(at: leftEntry.player.position)))
    XCTAssertThrowsError(try LevelNineSimulation(entryPosition: .top))
    XCTAssertThrowsError(try LevelNineSimulation(entryPosition: .right))
  }

  func testFactoryBuildsBothLevelNineEntriesWithSeparatedFootprintsAndReachableDoors() throws {
    let factory = DefaultGameLevelRuntimeFactory()
    for entry: LevelEntryPosition in [.bottom, .left] {
      let runtime = try factory.makeRuntime(
        levelID: .levelNine,
        configuration: .init(reducedMotion: false, controlHintsEnabled: true), seed: 9,
        entryPosition: entry, carryover: nil)
      let simulation = try XCTUnwrap(runtime.simulation as? LevelNineSimulation)
      let playerRegion = CollisionProfile.player.region(at: simulation.player.position)
      XCTAssertFalse(simulation.level.isBlocked(playerRegion))
      XCTAssertFalse(simulation.level.overlapsLava(playerRegion))

      let enemyRegions = simulation.enemies.map {
        $0.archetype.footprint.region(at: $0.position)
      }
      for region in enemyRegions {
        XCTAssertFalse(simulation.level.isBlocked(region))
        XCTAssertFalse(region.intersects(playerRegion))
        XCTAssertFalse(region.intersects(LevelNineDefinition.forwardDoorRegion))
        XCTAssertFalse(region.intersects(LevelNineDefinition.bottomDoorRegion))
      }
      XCTAssertFalse(enemyRegions[0].intersects(enemyRegions[1]))
      XCTAssertTrue(
        hasMovementPath(
          from: simulation.player.position, to: LevelNineDefinition.forwardDoorRegion,
          in: simulation.level))
      XCTAssertTrue(
        hasMovementPath(
          from: simulation.player.position, to: LevelNineDefinition.bottomDoorRegion,
          in: simulation.level))
    }
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
      first.enemies.map(\.position), [.init(row: 9, column: 18), .init(row: 11, column: 26)])
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

  func testLevelNineForwardExitRequestsRegisteredLevelTen() throws {
    let simulation = try LevelNineSimulation(seed: 9)
    var request: LevelTransitionRequest?
    simulation.onLevelTransition = { request = $0 }
    simulation.player.position = .init(row: 9, column: 3)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(request?.destinationLevelID, .levelTen)
    XCTAssertEqual(request?.destinationEntry, .right)
    XCTAssertEqual(request?.reason, .completedForward)
    XCTAssertEqual(request?.carryover.completedLevelIDs, [.levelNine])
    XCTAssertEqual(try LevelAssetManifest.manifest(for: .levelTen), .levelTen)
  }

  func testRealSessionTransitionsEightToNineToTenAndBackWithCarryover() throws {
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
    levelNine.player.position = .init(row: 9, column: 3)
    session.advance(by: 0.01)
    let intoTen = try XCTUnwrap(session.pendingTransitionRequest)
    XCTAssertEqual(intoTen.destinationLevelID, .levelTen)
    XCTAssertEqual(intoTen.destinationEntry, .right)
    XCTAssertEqual(intoTen.carryover.completedLevelIDs, [.levelEight, .levelNine])
    XCTAssertEqual(intoTen.carryover.score, 237)

    let levelTenRuntime = try factory.makeRuntime(
      levelID: .levelTen, configuration: configuration, seed: 496_913,
      entryPosition: intoTen.destinationEntry, carryover: intoTen.carryover)
    session.installRuntime(levelTenRuntime)
    session.runtimeSceneDidAttach(generation: session.runtimeGeneration, levelID: .levelTen)
    let levelTen = try XCTUnwrap(session.simulation as? LevelTenSimulation)
    levelTen.player.position = .init(row: 30, column: 54)
    session.advance(by: 0.01)
    let backToNine = try XCTUnwrap(session.pendingTransitionRequest)
    XCTAssertEqual(backToNine.destinationLevelID, .levelNine)
    XCTAssertEqual(backToNine.destinationEntry, .left)
    XCTAssertEqual(backToNine.carryover.completedLevelIDs, [.levelEight, .levelNine])
    let returnedRuntime = try factory.makeRuntime(
      levelID: .levelNine, configuration: configuration, seed: 496_913,
      entryPosition: backToNine.destinationEntry, carryover: backToNine.carryover)
    session.installRuntime(returnedRuntime)
    XCTAssertEqual(
      session.simulation.renderSnapshot.player.coordinate, LevelNineDefinition.leftStart)
    XCTAssertEqual(session.score, 237)
    XCTAssertEqual(session.elapsedTime, 4.03, accuracy: 0.001)
  }

  private func hasMovementPath(
    from start: GridPosition, to target: GridRegion, in level: LevelDefinition
  ) -> Bool {
    var visited: Set<GridPosition> = [start]
    var queue = [start]
    while !queue.isEmpty {
      let position = queue.removeFirst()
      if CollisionProfile.player.region(at: position).intersects(target) { return true }
      for direction in GridDirection.allCases {
        let next = position.moved(direction)
        let footprint = CollisionProfile.player.region(at: next)
        guard !visited.contains(next), footprint.cells.allSatisfy(level.isInside),
          !level.isBlocked(footprint)
        else { continue }
        visited.insert(next)
        queue.append(next)
      }
    }
    return false
  }
}
