import XCTest

@testable import HookshotHero

@MainActor final class LevelSevenTests: XCTestCase {
  func testDefinitionMatchesJavaGeometryExactly() {
    let level = LevelSevenDefinition.make()
    XCTAssertEqual(level.grid, .init(rows: 60, columns: 60))
    XCTAssertEqual(LevelSevenDefinition.bottomStart, .init(row: 53, column: 27))
    XCTAssertEqual(LevelSevenDefinition.topStart, .init(row: 5, column: 30))
    XCTAssertEqual(level.exitAnchor, .init(row: 0, column: 27))
    XCTAssertEqual(level.entryAnchor, .init(row: 56, column: 27))
    XCTAssertEqual(level.exitRegion, .init(rows: 0..<4, columns: 27..<33))
    XCTAssertEqual(level.entryRegion, .init(rows: 56..<60, columns: 27..<33))
    XCTAssertEqual(Set(LevelSevenDefinition.wallAnchors), expectedWalls)
    XCTAssertEqual(LevelSevenDefinition.wallAnchors.count, 68)
    XCTAssertTrue(
      LevelSevenDefinition.wallAnchors.allSatisfy {
        $0.row >= 0 && $0.column >= 0 && $0.row + 4 <= 60 && $0.column + 4 <= 60
      })
    XCTAssertEqual(Set(LevelSevenDefinition.lavaAnchors), expectedLava)
    XCTAssertEqual(LevelSevenDefinition.lavaAnchors.count, 49)
    XCTAssertEqual(
      Set(LevelSevenDefinition.lavaAnchors).count, LevelSevenDefinition.lavaAnchors.count)
  }

  func testLavaAnchorsPreserveDeterministicJavaSourceOrder() {
    XCTAssertEqual(LevelSevenDefinition.lavaAnchors, expectedOrderedLava)

    let first = LevelSevenDefinition.make()
    for _ in 0..<10 {
      XCTAssertEqual(LevelSevenDefinition.make().lava, first.lava)
    }
  }

  func testChestsOpenIndependentlyAndPersistWithoutFarming() throws {
    let first = try LevelSevenSimulation(seed: 496_913)
    XCTAssertEqual(first.chestStates.count, 2)
    XCTAssertEqual(
      first.chestStates.map(\.definition.interactionAnchor),
      [.init(row: 4, column: 4), .init(row: 52, column: 4)])
    XCTAssertEqual(
      first.chestStates.map(\.definition.closedAsset),
      [LevelSevenRenderAssets.chestSide, LevelSevenRenderAssets.chestBack])
    first.player.health = 1
    first.player.position = .init(row: 4, column: 4)
    first.activateChestAndExit()
    XCTAssertEqual(first.chestStates.map(\.isOpened), [true, false])
    XCTAssertEqual(first.player.score, 100)
    XCTAssertEqual(first.player.health, 3)
    let returning = try LevelSevenSimulation(seed: 42, carryover: first.makeCarryoverState())
    XCTAssertEqual(returning.chestStates.map(\.isOpened), [true, false])
    returning.player.position = .init(row: 4, column: 4)
    returning.activateChestAndExit()
    XCTAssertEqual(returning.player.score, 100)
    returning.player.position = .init(row: 52, column: 4)
    returning.activateChestAndExit()
    XCTAssertEqual(returning.player.score, 200)
    XCTAssertEqual(returning.player.health, 5)
  }

  func testStandardPopulationIsDeterministicAndEnemiesAreCorrectedSafe() throws {
    let first = try LevelSevenSimulation(seed: 496_913)
    let second = try LevelSevenSimulation(seed: 496_913)
    XCTAssertEqual(first.entities.filter { $0.kind == .mine }.count, 3)
    XCTAssertEqual(first.entities.filter { $0.kind == .cabbage }.count, 2)
    XCTAssertEqual(first.entities.filter { $0.kind == .coin }.count, 10)
    XCTAssertEqual(first.entities.map(\.position), second.entities.map(\.position))
    XCTAssertEqual(first.enemies.map(\.archetype), [.skeleton, .flyingTerror])
    XCTAssertEqual(
      first.enemies.map(\.position),
      [LevelSevenSimulation.skeletonStart, .init(row: 8, column: 50)])
    XCTAssertFalse(
      first.enemies[0].archetype.footprint.region(at: first.enemies[0].position).intersects(
        first.enemies[1].archetype.footprint.region(at: first.enemies[1].position)))
    XCTAssertTrue(
      first.renderSnapshot.entities.contains {
        $0.asset == EnemyArchetype.skeleton.asset && $0.health != nil
      })
    XCTAssertTrue(
      first.renderSnapshot.entities.contains {
        $0.asset == EnemyArchetype.flyingTerror.asset && $0.health != nil
      })
    let protected =
      [first.level.exitRegion, first.level.entryRegion]
      + first.chestStates.map(\.definition.spawnExclusionRegion) + [
        CollisionProfile.player.region(at: LevelSevenDefinition.bottomStart),
        CollisionProfile.player.region(at: LevelSevenDefinition.topStart),
      ]
    for entity in first.entities {
      let footprint = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
      XCTAssertFalse(protected.contains(where: footprint.intersects))
      XCTAssertTrue(footprint.cells.allSatisfy(first.level.isInside))
      XCTAssertFalse(first.level.isBlocked(footprint))
      XCTAssertFalse(first.level.overlapsLava(footprint))
    }
  }

  func testSkeletonStartUsesCompleteProductionWallGeometryAndPermitsLava() throws {
    let simulation = try LevelSevenSimulation(seed: 1)
    let footprint = EnemyArchetype.skeleton.footprint.region(
      at: LevelSevenSimulation.skeletonStart)

    XCTAssertEqual(LevelSevenSimulation.skeletonStart, .init(row: 10, column: 40))
    XCTAssertEqual(footprint, .init(rows: 8..<13, columns: 38..<43))
    XCTAssertTrue(
      footprint.cells.allSatisfy(simulation.level.isInside),
      "Skeleton footprint must remain completely inside the production board")
    XCTAssertFalse(
      simulation.level.isBlocked(footprint),
      "Skeleton footprint collides with production wall geometry")
    XCTAssertTrue(
      simulation.level.overlapsLava(footprint),
      "The restored Java-parity anchor intentionally demonstrates permitted lava overlap")
    XCTAssertTrue(EnemyArchetype.skeleton.allowsLavaOverlap)

    let formerFootprint = EnemyArchetype.skeleton.footprint.region(
      at: .init(row: 9, column: 25))
    XCTAssertTrue(
      simulation.level.isBlocked(formerFootprint),
      "Regression fixture must continue to expose the former anchor's production-wall collision")
  }

  func testEverySupportedEntryConstructsDirectlyForFixedSeeds() throws {
    for seed: UInt64 in [1, 42, 496_913] {
      for (entry, expectedStart) in [
        (LevelEntryPosition.bottom, LevelSevenDefinition.bottomStart),
        (.top, LevelSevenDefinition.topStart),
      ] {
        let simulation = try LevelSevenSimulation(seed: seed, entryPosition: entry)
        XCTAssertEqual(simulation.levelID, .levelSeven)
        XCTAssertEqual(simulation.player.position, expectedStart, "player start invalid")
        assertInitialStateIsSafe(simulation)
      }
    }
  }

  func testPlayerEntriesChestsAndFlyingTerrorAreProductionSafe() throws {
    let simulation = try LevelSevenSimulation(seed: 7)
    let starts = [LevelSevenDefinition.bottomStart, LevelSevenDefinition.topStart]
    for start in starts {
      let region = CollisionProfile.player.region(at: start)
      XCTAssertTrue(region.cells.allSatisfy(simulation.level.isInside), "player start invalid")
      XCTAssertFalse(simulation.level.isBlocked(region), "player start invalid: wall collision")
      XCTAssertFalse(simulation.level.overlapsLava(region), "player start invalid: lava collision")
    }
    XCTAssertFalse(
      CollisionProfile.player.region(at: LevelSevenDefinition.bottomStart).intersects(
        simulation.level.entryRegion),
      "bottom start must not immediately trigger the return door")
    XCTAssertFalse(
      CollisionProfile.player.region(at: LevelSevenDefinition.topStart).intersects(
        simulation.level.exitRegion),
      "top start must not immediately trigger the forward door")

    let flying = try XCTUnwrap(simulation.enemies.first { $0.archetype == .flyingTerror })
    let flyingRegion = flying.archetype.footprint.region(at: flying.position)
    XCTAssertTrue(flyingRegion.cells.allSatisfy(simulation.level.isInside))
    for start in starts {
      XCTAssertFalse(flyingRegion.intersects(CollisionProfile.player.region(at: start)))
    }

    XCTAssertEqual(
      simulation.chestStates.map(\.definition.interactionAnchor),
      [.init(row: 4, column: 4), .init(row: 52, column: 4)])
    for chest in simulation.chestStates {
      let interaction = CollisionProfile.chest.region(at: chest.definition.interactionAnchor)
      XCTAssertTrue(interaction.cells.allSatisfy(simulation.level.isInside))
      XCTAssertTrue(
        chest.definition.spawnExclusionRegion.cells.allSatisfy(simulation.level.isInside))
      XCTAssertFalse(flyingRegion.intersects(interaction), "enemy-chest collision")
      XCTAssertFalse(flyingRegion.intersects(chest.definition.spawnExclusionRegion))
    }
  }

  func testUnsupportedEntriesRemainInvalid() {
    for entry in [LevelEntryPosition.left, .right] {
      XCTAssertThrowsError(try LevelSevenSimulation(seed: 1, entryPosition: entry)) { error in
        XCTAssertEqual(error as? GameLoadingError, .invalidInitialState(.levelSeven))
      }
    }
  }

  func testBothEntriesConstructSafelyThroughRealRuntimeFactoryForFixedSeeds() throws {
    let seeds: [UInt64] = [1, 7, 42, 496_913]
    let entries: [(LevelEntryPosition, GridPosition)] = [
      (.bottom, LevelSevenDefinition.bottomStart), (.top, LevelSevenDefinition.topStart),
    ]
    let factory = DefaultGameLevelRuntimeFactory()

    for seed in seeds {
      for (entry, expectedStart) in entries {
        let runtime = try factory.makeRuntime(
          levelID: .levelSeven,
          configuration: .init(reducedMotion: false, controlHintsEnabled: true), seed: seed,
          entryPosition: entry, carryover: nil)
        let simulation = try XCTUnwrap(runtime.simulation as? LevelSevenSimulation)
        XCTAssertEqual(simulation.player.position, expectedStart)
        assertInitialStateIsSafe(simulation)
        XCTAssertEqual(runtime.presentation.levelID, .levelSeven)
        XCTAssertEqual(runtime.assetManifest, .levelSeven)
      }
    }
  }

  func testLevelFiveForwardTransitionConstructsLevelSevenThroughProductionFactory() throws {
    let five = try LevelFiveSimulation(seed: 496_913)
    var request: LevelTransitionRequest?
    five.onLevelTransition = { request = $0 }
    five.player.position = .init(row: 3, column: 29)
    five.update(deltaTime: 0.01)

    let transition = try XCTUnwrap(request)
    XCTAssertEqual(transition.destinationLevelID, .levelSeven)
    XCTAssertEqual(transition.destinationEntry, .bottom)
    let runtime = try DefaultGameLevelRuntimeFactory().makeRuntime(
      levelID: transition.destinationLevelID,
      configuration: .init(reducedMotion: false, controlHintsEnabled: true), seed: 496_913,
      entryPosition: transition.destinationEntry, carryover: transition.carryover)
    let seven = try XCTUnwrap(runtime.simulation as? LevelSevenSimulation)
    XCTAssertEqual(seven.player.position, LevelSevenDefinition.bottomStart)
    assertInitialStateIsSafe(seven)
  }

  private func assertInitialStateIsSafe(
    _ simulation: LevelSevenSimulation, file: StaticString = #filePath, line: UInt = #line
  ) {
    let playerRegion = CollisionProfile.player.region(at: simulation.player.position)
    XCTAssertTrue(
      playerRegion.cells.allSatisfy(simulation.level.isInside),
      "player start invalid: out of bounds",
      file: file, line: line)
    XCTAssertFalse(
      simulation.level.isBlocked(playerRegion), "player start invalid: wall collision", file: file,
      line: line)
    XCTAssertFalse(
      simulation.level.overlapsLava(playerRegion), "player start invalid: lava collision",
      file: file,
      line: line)

    let enemyRegions = simulation.enemies.map {
      $0.archetype.footprint.region(at: $0.position)
    }
    XCTAssertEqual(
      simulation.enemies.map(\.archetype), [.skeleton, .flyingTerror], file: file, line: line)
    for (enemy, region) in zip(simulation.enemies, enemyRegions) {
      XCTAssertTrue(region.cells.allSatisfy(simulation.level.isInside), file: file, line: line)
      if enemy.archetype == .skeleton {
        XCTAssertFalse(
          simulation.level.isBlocked(region), "Skeleton wall collision", file: file, line: line)
      }
      XCTAssertFalse(
        region.intersects(simulation.level.entryRegion), "enemy-door collision", file: file,
        line: line)
      XCTAssertFalse(
        region.intersects(simulation.level.exitRegion), "enemy-door collision", file: file,
        line: line)
      for start in [LevelSevenDefinition.bottomStart, LevelSevenDefinition.topStart] {
        XCTAssertFalse(
          region.intersects(CollisionProfile.player.region(at: start)), "enemy-entry collision",
          file: file, line: line)
      }
      for chest in simulation.chestStates {
        XCTAssertFalse(
          region.intersects(CollisionProfile.chest.region(at: chest.definition.interactionAnchor)),
          "enemy-chest collision", file: file, line: line)
        XCTAssertFalse(
          region.intersects(chest.definition.spawnExclusionRegion), "enemy-chest collision",
          file: file, line: line)
      }
    }
    XCTAssertFalse(
      enemyRegions[0].intersects(enemyRegions[1]), "enemy-enemy collision", file: file,
      line: line)

    XCTAssertEqual(simulation.entities.filter { $0.kind == .mine }.count, 3, file: file, line: line)
    XCTAssertEqual(
      simulation.entities.filter { $0.kind == .cabbage }.count, 2, file: file, line: line)
    XCTAssertEqual(
      simulation.entities.filter { $0.kind == .coin }.count, 10, file: file, line: line)
    let protected =
      enemyRegions + [
        CollisionProfile.player.region(at: LevelSevenDefinition.bottomStart),
        CollisionProfile.player.region(at: LevelSevenDefinition.topStart),
        simulation.level.entryRegion,
        simulation.level.exitRegion,
      ]
      + simulation.chestStates.map(\.definition.spawnExclusionRegion)
    for entity in simulation.entities {
      let region = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
      XCTAssertTrue(region.cells.allSatisfy(simulation.level.isInside), file: file, line: line)
      XCTAssertFalse(simulation.level.isBlocked(region), file: file, line: line)
      XCTAssertFalse(simulation.level.overlapsLava(region), file: file, line: line)
      XCTAssertFalse(
        protected.contains(where: region.intersects), "SpawnService failure: protected overlap",
        file: file, line: line)
    }
  }

  func testLevelFiveTransitionsToSevenAndSevenReturnsToFive() throws {
    let five = try LevelFiveSimulation(seed: 496_913)
    let identity = five.player.id
    five.player.health = 2
    five.player.score = 41
    var forward: LevelTransitionRequest?
    five.onLevelTransition = { forward = $0 }
    five.player.position = .init(row: 3, column: 29)
    five.update(deltaTime: 0.01)
    XCTAssertNil(five.outcome)
    XCTAssertEqual(forward?.destinationLevelID, .levelSeven)
    XCTAssertEqual(forward?.destinationEntry, .bottom)
    XCTAssertEqual(forward?.reason, .completedForward)
    XCTAssertEqual(forward?.carryover.characterID, identity)
    XCTAssertEqual(forward?.carryover.health, 2)
    XCTAssertEqual(forward?.carryover.score, 141)
    XCTAssertTrue(forward?.carryover.completedLevelIDs.contains(.levelFive) == true)

    let seven = try LevelSevenSimulation(
      seed: 496_913, carryover: try XCTUnwrap(forward?.carryover))
    var backward: LevelTransitionRequest?
    seven.onLevelTransition = { backward = $0 }
    seven.player.position = .init(row: 57, column: 29)
    seven.update(deltaTime: 0.01)
    XCTAssertEqual(backward?.destinationLevelID, .levelFive)
    XCTAssertEqual(backward?.destinationEntry, .top)
    XCTAssertEqual(backward?.reason, .returnedBackward)
    XCTAssertEqual(backward?.carryover.characterID, identity)
  }

  func testTopExitTransitionsToLevelEightOnceRewarded() throws {
    let seven = try LevelSevenSimulation(seed: 496_913)
    var emittedTransition: LevelTransitionRequest?
    seven.onLevelTransition = { request in
      emittedTransition = request
    }
    seven.player.position = .init(row: 3, column: 29)
    seven.update(deltaTime: 0.01)
    XCTAssertNil(seven.outcome)
    XCTAssertEqual(seven.player.score, 100)
    XCTAssertEqual(seven.completedLevelIDs, [.levelSeven])
    XCTAssertEqual(emittedTransition?.sourceLevelID, .levelSeven)
    XCTAssertEqual(emittedTransition?.destinationLevelID, .levelEight)
    XCTAssertEqual(emittedTransition?.destinationEntry, .bottom)
    XCTAssertEqual(emittedTransition?.reason, .completedForward)

    let scoreAfterCompletion = seven.player.score
    let completedLevelIDsAfterCompletion = seven.completedLevelIDs
    seven.update(deltaTime: 1)
    XCTAssertEqual(seven.player.score, scoreAfterCompletion)
    XCTAssertEqual(seven.completedLevelIDs, completedLevelIDsAfterCompletion)
    XCTAssertNil(seven.outcome)
  }

  private var expectedWalls: Set<GridPosition> {
    var result: Set<GridPosition> = []
    func add(_ rows: [Int], _ columns: [Int]) {
      for row in rows { for column in columns { result.insert(.init(row: row, column: column)) } }
    }
    add([20, 24, 28, 32], [12, 16, 20])
    add([48, 52], [48, 52])
    add([40, 44, 48], [20, 24, 28, 32])
    add([4], [12, 16, 20, 24])
    add([12], [4, 8, 12, 16, 20])
    add([16], [28, 32, 36, 40, 44])
    add([24], [36, 40, 44, 48, 52])
    add([40], [4, 8, 12, 16])
    add([48], [36, 40])
    add([44], [48, 52])
    add([32], [24, 28, 32, 36])
    add([48, 52], [12])
    add([20, 24], [28])
    add([8], [4, 28])
    add([36], [4])
    add([28], [36])
    add([44], [36])
    return result
  }
  private var expectedLava: Set<GridPosition> {
    var result: Set<GridPosition> = []
    func add(_ rows: [Int], _ columns: [Int]) {
      for row in rows { for column in columns { result.insert(.init(row: row, column: column)) } }
    }
    add([8], [12, 16, 20])
    add([16], [12, 16, 20])
    add([36], [12, 16, 20])
    add([40], [40, 44])
    add([52], [32, 36, 40])
    add([16], [48, 52])
    add([28, 32], [48])
    add([48, 52], [8])
    add([8, 12], [32, 36, 40, 44, 48, 52])
    add([20, 24, 28], [4, 8])
    add([32, 36, 40], [40, 44])
    add([48], [20, 16, 40])
    add([12], [28])
    add([28], [44])
    add([36, 40], [48])
    return result
  }

  private var expectedOrderedLava: [GridPosition] {
    [
      .init(row: 8, column: 12), .init(row: 8, column: 16), .init(row: 8, column: 20),
      .init(row: 16, column: 12), .init(row: 16, column: 16), .init(row: 16, column: 20),
      .init(row: 36, column: 12), .init(row: 36, column: 16), .init(row: 36, column: 20),
      .init(row: 40, column: 40), .init(row: 40, column: 44),
      .init(row: 52, column: 32), .init(row: 52, column: 36), .init(row: 52, column: 40),
      .init(row: 16, column: 48), .init(row: 16, column: 52),
      .init(row: 28, column: 48), .init(row: 32, column: 48),
      .init(row: 48, column: 8), .init(row: 52, column: 8),
      .init(row: 8, column: 32), .init(row: 8, column: 36), .init(row: 8, column: 40),
      .init(row: 8, column: 44), .init(row: 8, column: 48), .init(row: 8, column: 52),
      .init(row: 12, column: 32), .init(row: 12, column: 36), .init(row: 12, column: 40),
      .init(row: 12, column: 44), .init(row: 12, column: 48), .init(row: 12, column: 52),
      .init(row: 20, column: 4), .init(row: 20, column: 8),
      .init(row: 24, column: 4), .init(row: 24, column: 8),
      .init(row: 28, column: 4), .init(row: 28, column: 8),
      .init(row: 32, column: 40), .init(row: 32, column: 44),
      .init(row: 36, column: 40), .init(row: 36, column: 44),
      .init(row: 48, column: 20), .init(row: 48, column: 16),
      .init(row: 12, column: 28), .init(row: 28, column: 44),
      .init(row: 48, column: 40), .init(row: 36, column: 48), .init(row: 40, column: 48),
    ]
  }
}
