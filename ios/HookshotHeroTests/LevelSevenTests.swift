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
    XCTAssertEqual(LevelSevenDefinition.lavaAnchors.count, expectedLava.count)
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
      first.enemies.map(\.position), [.init(row: 10, column: 40), .init(row: 8, column: 50)])
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

  func testTopExitCompletesCurrentContentOnceWithoutLevelEight() throws {
    let seven = try LevelSevenSimulation(seed: 496_913)
    var emittedTransition: LevelTransitionRequest?
    seven.onLevelTransition = { request in
      emittedTransition = request
    }
    seven.player.position = .init(row: 3, column: 29)
    seven.update(deltaTime: 0.01)
    XCTAssertEqual(seven.outcome, .won)
    XCTAssertEqual(seven.player.score, 100)
    XCTAssertEqual(seven.completedLevelIDs, [.levelSeven])
    XCTAssertNil(emittedTransition)

    let scoreAfterCompletion = seven.player.score
    let completedLevelIDsAfterCompletion = seven.completedLevelIDs
    seven.update(deltaTime: 1)
    XCTAssertNil(emittedTransition)
    XCTAssertEqual(seven.player.score, scoreAfterCompletion)
    XCTAssertEqual(seven.completedLevelIDs, completedLevelIDsAfterCompletion)
    XCTAssertEqual(seven.outcome, .won)
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
}
