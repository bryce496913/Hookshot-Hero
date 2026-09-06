import XCTest

@testable import HookshotHero

@MainActor final class LevelEightSimulationTests: XCTestCase {
  func testSharedDesignatedInitializerDoesNotInferChestContentFromDefinition() throws {
    let level = LevelEightDefinition.make()
    let simulation = try LevelOneSimulation(
      configuration: .init(reducedMotion: false, controlHintsEnabled: true), seed: 8,
      entryPosition: .bottom, carryover: nil, levelDefinition: level,
      presentationDefinition: LevelEightPresentationDefinition.make(from: level),
      initialPlayerPosition: LevelEightDefinition.fromLevelSevenStart, entities: [])

    XCTAssertTrue(simulation.chestStates.isEmpty)
    XCTAssertTrue(
      simulation.renderSnapshot.entities.allSatisfy { entity in
        entity.asset != LevelOneRenderAssets.chestClosed
          && entity.asset != LevelOneRenderAssets.chestOpen
      })
  }

  func testEveryLevelExplicitlyOwnsIntentionalChestContent() throws {
    let simulations: [LevelOneSimulation] = [
      try LevelOneSimulation(seed: 1, entities: []),
      try LevelTwoSimulation(seed: 2),
      try LevelThreeSimulation(seed: 3),
      try LevelFourSimulation(seed: 4),
      try LevelFiveSimulation(seed: 5),
      try LevelSixSimulation(seed: 6),
      try LevelSevenSimulation(seed: 7),
      try LevelEightSimulation(seed: 8),
    ]
    XCTAssertEqual(simulations.map { $0.chestStates.count }, [1, 0, 1, 0, 1, 2, 2, 0])

    let levelOneChest = try XCTUnwrap(simulations[0].chestStates.first?.definition)
    XCTAssertEqual(levelOneChest.interactionAnchor, LevelOneDefinition.make().chestAnchor)
    XCTAssertEqual(levelOneChest.renderAnchor, LevelOneDefinition.make().chestAnchor)
    XCTAssertEqual(levelOneChest.closedAsset, LevelOneRenderAssets.chestClosed)
    XCTAssertEqual(levelOneChest.openedAsset, LevelOneRenderAssets.chestOpen)
    XCTAssertEqual(levelOneChest.scoreReward, 100)
    XCTAssertEqual(levelOneChest.healthReward, 2)
    XCTAssertEqual(levelOneChest.message, LevelOneSimulation.chestMessage)

    for simulation in simulations {
      for chest in simulation.chestStates {
        XCTAssertTrue(
          simulation.level.isInside(chest.definition.interactionAnchor),
          "\(simulation.levelID.rawValue) has an off-board chest interaction anchor")
        XCTAssertTrue(
          simulation.level.isInside(chest.definition.renderAnchor),
          "\(simulation.levelID.rawValue) has an off-board chest render anchor")
      }
    }
  }

  func testLevelOneChestRestoresOpenedAndCannotBeFarmed() throws {
    let initial = PlayerCarryoverState(characterID: EntityID(), health: 2, score: 0)
    let first = try LevelOneSimulation(seed: 1, carryover: initial, entities: [])
    XCTAssertEqual(first.chestStates.count, 1)
    XCTAssertFalse(first.chestStates[0].isOpened)
    XCTAssertTrue(
      first.renderSnapshot.entities.contains { $0.asset == LevelOneRenderAssets.chestClosed })

    first.player.position = first.chestStates[0].definition.interactionAnchor
    first.update(deltaTime: 0.01)
    XCTAssertEqual(first.player.health, 4)
    XCTAssertEqual(first.player.score, 100)
    XCTAssertTrue(first.chestStates[0].isOpened)
    XCTAssertTrue(
      first.renderSnapshot.entities.contains { $0.asset == LevelOneRenderAssets.chestOpen })
    let openedID = OpenedChestID(
      levelID: .levelOne, interactionAnchor: first.chestStates[0].definition.interactionAnchor)
    XCTAssertTrue(first.worldState.openedChestIDs.contains(openedID))

    let returning = try LevelOneSimulation(carryover: first.makeCarryoverState(), entities: [])
    XCTAssertTrue(returning.chestStates[0].isOpened)
    returning.player.position = returning.chestStates[0].definition.interactionAnchor
    returning.update(deltaTime: 0.01)
    XCTAssertEqual(returning.player.health, 4)
    XCTAssertEqual(returning.player.score, 100)
    XCTAssertTrue(returning.worldState.openedChestIDs.contains(openedID))
  }

  func testInitialDynamicRenderRequestsAreDeclaredByLevelEightManifest() throws {
    let simulation = try LevelEightSimulation(seed: 496_913)
    let snapshot = simulation.renderSnapshot
    let dynamicEntities = [snapshot.player] + snapshot.entities
    let dynamicAssets = Set(dynamicEntities.map(\.asset))
    let dynamicAnimations = Set(dynamicEntities.compactMap { $0.animation?.animationID })
    let manifest = LevelAssetManifest.levelEight

    XCTAssertTrue(dynamicAssets.isSubset(of: manifest.textureAssetIDs))
    XCTAssertTrue(dynamicAnimations.isSubset(of: manifest.animationIDs))

    let chestAssets: Set<RenderAssetID> = [
      LevelOneRenderAssets.chestClosed, LevelOneRenderAssets.chestOpen,
      LevelFiveRenderAssets.chest, LevelSixRenderAssets.chestSide,
      LevelSixRenderAssets.chestFront, LevelSevenRenderAssets.chestSide,
      LevelSevenRenderAssets.chestBack,
    ]
    XCTAssertTrue(dynamicAssets.isDisjoint(with: chestAssets))
  }

  func testSupportedEntriesUseNamedSafeStartsAndRightIsRejected() throws {
    XCTAssertEqual(
      try LevelEightSimulation(entryPosition: .left).player.position,
      LevelEightDefinition.fromLevelSixStart)
    XCTAssertEqual(
      try LevelEightSimulation(entryPosition: .bottom).player.position,
      LevelEightDefinition.fromLevelSevenStart)
    XCTAssertEqual(
      try LevelEightSimulation(entryPosition: .top).player.position,
      LevelEightDefinition.topReturnStart)
    XCTAssertThrowsError(try LevelEightSimulation(entryPosition: .right))
  }

  func testStandardPopulationIsDeterministicSafeAndRendered() throws {
    let first = try LevelEightSimulation(seed: 496_913)
    let second = try LevelEightSimulation(seed: 496_913)
    XCTAssertEqual(first.entities.filter { $0.kind == .mine }.count, 3)
    XCTAssertEqual(first.entities.filter { $0.kind == .cabbage }.count, 2)
    XCTAssertEqual(first.entities.filter { $0.kind == .coin }.count, 10)
    XCTAssertTrue(first.chestStates.isEmpty)
    XCTAssertEqual(first.entities.map(\.position), second.entities.map(\.position))
    XCTAssertEqual(first.enemies.map(\.archetype), [.skeleton, .flyingTerror])
    XCTAssertEqual(
      first.enemies.map(\.position), [.init(row: 50, column: 33), .init(row: 11, column: 19)])

    let starts = [
      LevelEightDefinition.fromLevelSixStart, LevelEightDefinition.fromLevelSevenStart,
      LevelEightDefinition.topReturnStart,
    ].map { CollisionProfile.player.region(at: $0) }
    let doors = [
      LevelEightDefinition.topDoorRegion, LevelEightDefinition.leftDoorRegion,
      LevelEightDefinition.bottomDoorRegion,
    ]
    let enemyRegions = first.enemies.map { $0.archetype.footprint.region(at: $0.position) }
    XCTAssertFalse(enemyRegions[0].intersects(enemyRegions[1]))
    for region in enemyRegions {
      XCTAssertTrue(region.cells.allSatisfy(first.level.isInside))
      XCTAssertFalse(first.level.isBlocked(region))
      XCTAssertFalse(first.level.overlapsLava(region))
      XCTAssertFalse((starts + doors).contains(where: region.intersects))
    }
    for entity in first.entities {
      let region = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
      XCTAssertTrue(region.cells.allSatisfy(first.level.isInside))
      XCTAssertFalse(first.level.isBlocked(region))
      XCTAssertFalse(first.level.overlapsLava(region))
      XCTAssertFalse((starts + doors + enemyRegions).contains(where: region.intersects))
    }
    for archetype in [EnemyArchetype.skeleton, .flyingTerror] {
      XCTAssertTrue(
        first.renderSnapshot.entities.contains { $0.asset == archetype.asset && $0.health != nil })
    }
  }

  func testSharedEnemyCombatAndLavaDamageRemainActive() throws {
    let combat = try LevelEightSimulation(seed: 1)
    combat.player.position = combat.enemies[0].position
    let combatHealth = combat.player.health
    combat.update(deltaTime: 0.01)
    XCTAssertEqual(combat.player.health, combatHealth - 1)

    let lava = try LevelEightSimulation(seed: 1)
    let directions: [GridDirection] = [.up, .down, .left, .right]
    let approach = try XCTUnwrap(
      (4..<56).lazy.flatMap { row in
        (4..<56).lazy.map { GridPosition(row: row, column: $0) }
      }.first { position in
        let footprint = CollisionProfile.player.region(at: position)
        return !lava.level.isBlocked(footprint) && !lava.level.overlapsLava(footprint)
          && directions.contains { direction in
            lava.level.overlapsLava(CollisionProfile.player.region(at: position.moved(direction)))
          }
      })
    let direction = try XCTUnwrap(
      directions.first {
        lava.level.overlapsLava(CollisionProfile.player.region(at: approach.moved($0)))
      })
    lava.player.position = approach
    lava.player.lastSafePosition = approach
    let lavaHealth = lava.player.health
    lava.attemptMove(direction)
    XCTAssertEqual(lava.player.health, lavaHealth - 1)
    XCTAssertEqual(lava.player.position, approach)
  }

  func testCompletionIsOneShotAndDoesNotTransitionToLevelNine() throws {
    let simulation = try LevelEightSimulation(seed: 8)
    var transition: LevelTransitionRequest?
    simulation.onLevelTransition = { transition = $0 }
    simulation.player.position = .init(row: 3, column: 50)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(simulation.outcome, .won)
    XCTAssertEqual(simulation.player.score, 100)
    XCTAssertEqual(simulation.completedLevelIDs, [.levelEight])
    XCTAssertNil(transition)
    simulation.update(deltaTime: 1)
    XCTAssertEqual(simulation.player.score, 100)
    XCTAssertNil(transition)
  }

  func testPhysicalReverseDoorsReturnToTheirIndependentBranchesWithoutReward() throws {
    for (position, destination) in [
      (GridPosition(row: 29, column: 1), LevelID.levelSix),
      (GridPosition(row: 57, column: 29), LevelID.levelSeven),
    ] {
      let simulation = try LevelEightSimulation(seed: 8)
      var transition: LevelTransitionRequest?
      simulation.onLevelTransition = { transition = $0 }
      simulation.player.position = position
      simulation.update(deltaTime: 0.01)

      XCTAssertEqual(transition?.sourceLevelID, .levelEight)
      XCTAssertEqual(transition?.destinationLevelID, destination)
      XCTAssertEqual(transition?.destinationEntry, .top)
      XCTAssertEqual(transition?.reason, .returnedBackward)
      XCTAssertEqual(transition?.carryover.score, 0)
      XCTAssertFalse(transition?.carryover.completedLevelIDs.contains(.levelEight) == true)
      XCTAssertNil(simulation.outcome)
    }
  }

  func testRuntimeFactorySupportsBothLevelEightEntriesAndRejectsLevelNine() throws {
    let factory = DefaultGameLevelRuntimeFactory()
    let configuration = GameConfiguration(reducedMotion: false, controlHintsEnabled: true)
    let bottom = try factory.makeRuntime(
      levelID: .levelEight, configuration: configuration, seed: 8, entryPosition: .bottom,
      carryover: nil)
    let left = try factory.makeRuntime(
      levelID: .levelEight, configuration: configuration, seed: 8, entryPosition: .left,
      carryover: nil)
    XCTAssertEqual(
      bottom.simulation.renderSnapshot.player.coordinate,
      LevelEightDefinition.fromLevelSevenStart)
    XCTAssertEqual(
      left.simulation.renderSnapshot.player.coordinate, LevelEightDefinition.fromLevelSixStart)
    let levelNine = LevelID(rawValue: "level-9")
    XCTAssertThrowsError(
      try factory.makeRuntime(levelID: levelNine, configuration: configuration, seed: 9)
    ) { XCTAssertEqual($0 as? GameLoadingError, .unsupportedLevel(levelNine)) }
  }

  func testCarryoverRestoresPlayerAndCompletionState() throws {
    let identity = EntityID()
    let carryover = PlayerCarryoverState(
      characterID: identity, health: 2, score: 340,
      completedLevelIDs: [.levelSix, .levelSeven])
    let simulation = try LevelEightSimulation(
      seed: 8, entryPosition: .left, carryover: carryover)
    XCTAssertEqual(simulation.player.id, identity)
    XCTAssertEqual(simulation.player.health, 2)
    XCTAssertEqual(simulation.player.score, 340)
    XCTAssertEqual(simulation.completedLevelIDs, [.levelSix, .levelSeven])
    XCTAssertEqual(simulation.player.position, LevelEightDefinition.fromLevelSixStart)
  }
}
