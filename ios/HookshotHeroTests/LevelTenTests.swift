import XCTest

@testable import HookshotHero

@MainActor final class LevelTenTests: XCTestCase {
  private let configuration = GameConfiguration(reducedMotion: false, controlHintsEnabled: true)

  func testFactoryManifestAndFootprintSafeEntries() throws {
    let runtime = try DefaultGameLevelRuntimeFactory().makeRuntime(
      levelID: .levelTen, configuration: configuration, seed: 10,
      entryPosition: .right, carryover: nil)
    let simulation = try XCTUnwrap(runtime.simulation as? LevelTenSimulation)
    XCTAssertEqual(simulation.player.position, LevelTenDefinition.rightStart)
    XCTAssertFalse(
      simulation.level.isBlocked(CollisionProfile.player.region(at: simulation.player.position)))
    XCTAssertTrue(runtime.assetManifest.textureAssetIDs.contains(LevelTenRenderAssets.ghostWizard))

    let levelNine = try LevelNineSimulation(entryPosition: .left)
    XCTAssertEqual(levelNine.player.position, LevelNineDefinition.leftStart)
    XCTAssertFalse(
      levelNine.level.isBlocked(CollisionProfile.player.region(at: levelNine.player.position)))
  }

  func testExitIsLockedUntilBossDefeat() throws {
    let simulation = try LevelTenSimulation()
    simulation.player.position = .init(row: 27, column: 27)
    simulation.update(deltaTime: 0)
    XCTAssertNil(simulation.outcome)
    XCTAssertFalse(simulation.isExitUnlocked)

    simulation.defeatBossForTesting()
    XCTAssertTrue(simulation.isExitUnlocked)
    XCTAssertEqual(simulation.chestStates.count, 1)
    XCTAssertNil(simulation.outcome)
  }

  func testStandardPopulationHasExactDeterministicSeededPositions() throws {
    let first = try LevelTenSimulation(seed: 10)
    let second = try LevelTenSimulation(seed: 10)
    let expected: [(EntityKind, GridPosition)] = [
      (.mine, .init(row: 26, column: 47)),
      (.mine, .init(row: 45, column: 13)),
      (.mine, .init(row: 25, column: 13)),
      (.cabbage, .init(row: 49, column: 29)),
      (.cabbage, .init(row: 19, column: 17)),
      (.coin, .init(row: 54, column: 4)),
      (.coin, .init(row: 40, column: 7)),
      (.coin, .init(row: 18, column: 37)),
      (.coin, .init(row: 42, column: 4)),
      (.coin, .init(row: 14, column: 17)),
      (.coin, .init(row: 26, column: 35)),
      (.coin, .init(row: 38, column: 34)),
      (.coin, .init(row: 51, column: 19)),
      (.coin, .init(row: 22, column: 53)),
      (.coin, .init(row: 13, column: 44)),
    ]

    XCTAssertEqual(first.entities.count, expected.count)
    XCTAssertEqual(second.entities.count, expected.count)
    for ((firstEntity, secondEntity), expectedEntity) in zip(
      zip(first.entities, second.entities), expected)
    {
      XCTAssertEqual(firstEntity.kind, expectedEntity.0)
      XCTAssertEqual(firstEntity.position, expectedEntity.1)
      XCTAssertEqual(secondEntity.kind, expectedEntity.0)
      XCTAssertEqual(
        secondEntity.position, expectedEntity.1,
        "A fixed seed must reproduce the full ordered population")
    }
    XCTAssertEqual(first.entities.filter { $0.kind == .mine }.count, 3)
    XCTAssertEqual(first.entities.filter { $0.kind == .cabbage }.count, 2)
    XCTAssertEqual(first.entities.filter { $0.kind == .coin }.count, 10)
  }

  func testPopulationFootprintsAvoidAllProtectedRegionsAndRemainReachable() throws {
    let simulation = try LevelTenSimulation(seed: 10)
    let bossRegion = try XCTUnwrap(simulation.boss).archetype.footprint.region(
      at: LevelTenDefinition.bossStart)
    let protected = [
      CollisionProfile.player.region(at: LevelTenDefinition.rightStart),
      LevelTenDefinition.rightDoorRegion, LevelTenDefinition.endingExitRegion,
      CollisionProfile.chest.region(at: LevelTenDefinition.chestAnchor),
      LevelTenDefinition.chestRenderRegion, bossRegion,
    ]

    for entity in simulation.entities {
      let footprint = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
      XCTAssertTrue(footprint.cells.allSatisfy(simulation.level.isInside))
      XCTAssertFalse(simulation.level.isBlocked(footprint))
      XCTAssertFalse(simulation.level.overlapsLava(footprint))
      XCTAssertFalse(protected.contains(where: footprint.intersects))
      XCTAssertTrue(isCollectable(entity, in: simulation))
    }
    for (index, entity) in simulation.entities.enumerated() {
      let footprint = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
      for other in simulation.entities.dropFirst(index + 1) {
        XCTAssertFalse(
          footprint.intersects(
            CollisionProfile.footprint(for: other.kind).region(at: other.position)))
      }
    }
    XCTAssertTrue(isReachable(.init(row: 30, column: 54), in: simulation))
    XCTAssertTrue(isReachable(LevelTenDefinition.chestAnchor, in: simulation))
    XCTAssertTrue(isReachable(.init(row: 27, column: 27), in: simulation))

    let positionsBeforeDefeat = simulation.entities.map(\.position)
    simulation.defeatBossForTesting()
    XCTAssertEqual(simulation.entities.map(\.position), positionsBeforeDefeat)
    XCTAssertTrue(simulation.entities.allSatisfy { isCollectable($0, in: simulation) })
  }

  func testCollectingStandardItemDoesNotDefeatBossOrCompleteLevel() throws {
    let simulation = try LevelTenSimulation(seed: 10)
    let coin = try XCTUnwrap(simulation.entities.first { $0.kind == .coin })
    simulation.player.position = .init(row: coin.position.row, column: coin.position.column - 2)
    simulation.player.lastSafePosition = simulation.player.position
    simulation.input.send(.move(.right))
    simulation.update(deltaTime: 0)

    XCTAssertFalse(simulation.entities.contains { $0.id == coin.id })
    XCTAssertNotNil(simulation.boss)
    XCTAssertFalse(simulation.isExitUnlocked)
    XCTAssertFalse(simulation.completedLevelIDs.contains(.levelTen))
    XCTAssertNil(simulation.outcome)
  }

  func testChestDialogueThenDeliberatePortalEntryCompletesLevel() throws {
    let simulation = try LevelTenSimulation()
    let session = GameSession(simulation: simulation)
    XCTAssertTrue(session.initializeWorld())
    XCTAssertTrue(session.start())

    simulation.defeatBossForTesting()
    XCTAssertTrue(simulation.isExitUnlocked)
    XCTAssertEqual(simulation.chestStates.count, 1)

    simulation.player.health = 2
    let scoreBeforeChest = simulation.player.score
    simulation.player.position = .init(row: 36, column: 32)
    simulation.input.send(.move(.left))
    session.advance(by: 0)

    XCTAssertTrue(simulation.chestStates.first?.isOpened == true)
    XCTAssertEqual(simulation.player.score, scoreBeforeChest + 100)
    XCTAssertEqual(simulation.player.health, 4)
    XCTAssertEqual(session.state, .dialogue("The Ghost Wizard's treasure is yours."))
    XCTAssertNil(simulation.outcome)

    XCTAssertTrue(session.continueDialogue())
    XCTAssertEqual(session.state, .running)
    session.advance(by: 0)
    XCTAssertEqual(simulation.player.score, scoreBeforeChest + 100)
    XCTAssertEqual(simulation.player.health, 4)
    XCTAssertNil(simulation.outcome)

    simulation.player.position = .init(row: 33, column: 27)
    simulation.input.send(.move(.up))
    session.advance(by: 0)
    XCTAssertEqual(simulation.outcome, .won)
    XCTAssertEqual(session.state, .won)
    XCTAssertTrue(simulation.completedLevelIDs.contains(.levelTen))
    XCTAssertEqual(simulation.player.score, scoreBeforeChest + 200)
  }

  func testChestAndPortalInteractionFootprintsAreDisjointAndReachable() throws {
    let simulation = try LevelTenSimulation()
    let chestRegion = CollisionProfile.chest.region(at: LevelTenDefinition.chestAnchor)
    let legalChestInteractions = (0..<simulation.level.grid.rows).flatMap { row in
      (0..<simulation.level.grid.columns).compactMap { column -> GridPosition? in
        let position = GridPosition(row: row, column: column)
        let playerRegion = CollisionProfile.player.region(at: position)
        return playerRegion.intersects(chestRegion) && !simulation.level.isBlocked(playerRegion)
          ? position : nil
      }
    }

    XCTAssertFalse(legalChestInteractions.isEmpty)
    for position in legalChestInteractions {
      XCTAssertFalse(
        CollisionProfile.player.region(at: position).intersects(
          LevelTenDefinition.endingExitRegion),
        "Chest interaction at \(position) must not overlap the ending portal")
    }
    XCTAssertTrue(isReachable(LevelTenDefinition.chestAnchor, in: simulation))
    XCTAssertTrue(isReachable(.init(row: 27, column: 27), in: simulation))

    simulation.defeatBossForTesting()
    let chest = try XCTUnwrap(simulation.chestStates.first)
    XCTAssertEqual(chest.definition.interactionAnchor, .init(row: 36, column: 29))
    XCTAssertEqual(chest.definition.renderAnchor, chest.definition.interactionAnchor)
    XCTAssertTrue(
      simulation.renderSnapshot.entities.contains {
        $0.asset == LevelTenRenderAssets.specialChest
          && $0.coordinate == LevelTenDefinition.chestAnchor
      })
  }

  func testBossDefeatAndChestPersistAcrossReturnWithoutRepeatedReward() throws {
    let first = try LevelTenSimulation()
    first.defeatBossForTesting()
    first.player.position = LevelTenDefinition.chestAnchor
    first.update(deltaTime: 0)
    let rewarded = first.makeCarryoverState()
    XCTAssertTrue(rewarded.worldState.defeatedBossLevelIDs.contains(.levelTen))
    XCTAssertTrue(
      rewarded.worldState.openedChestIDs.contains(
        .init(
          levelID: .levelTen,
          interactionAnchor: LevelTenDefinition.chestAnchor)))

    let returned = try LevelTenSimulation(carryover: rewarded)
    XCTAssertNil(returned.boss)
    XCTAssertTrue(returned.chestStates.first?.isOpened == true)
    XCTAssertEqual(returned.player.score, rewarded.score)
  }

  func testOpenedDefeatChestAssetPassesManifestPreflight() throws {
    let simulation = try LevelTenSimulation()
    simulation.defeatBossForTesting()
    simulation.player.position = LevelTenDefinition.chestAnchor
    simulation.update(deltaTime: 0)
    XCTAssertTrue(simulation.chestStates.first?.isOpened == true)
    XCTAssertTrue(
      simulation.renderSnapshot.entities.contains { $0.asset == LevelOneRenderAssets.chestOpen })
    XCTAssertTrue(
      LevelAssetManifest.levelTen.textureAssetIDs.contains(LevelOneRenderAssets.chestOpen))

    let textures = TextureCatalog(entries: LevelOneTextureCatalog.entries)
    try DefaultAssetPreflight().validate(
      manifest: .levelTen, textureCatalog: textures,
      animationCatalog: LevelOneAnimationCatalog(textureCatalog: textures))
  }

  func testProjectileAndGrappleInteractions() throws {
    let simulation = try LevelTenSimulation()
    simulation.player.position = .init(row: 10, column: 10)
    simulation.player.lastSafePosition = simulation.player.position
    let health = simulation.player.health
    simulation.fireProjectileForTesting(at: .init(row: 10, column: 6), direction: .right)
    for _ in 0..<6 { simulation.update(deltaTime: 0.12) }
    XCTAssertLessThan(simulation.player.health, health)
    XCTAssertTrue(simulation.projectiles.isEmpty)

    let grapple = try LevelTenSimulation()
    grapple.player.position = .init(row: 25, column: 15)
    grapple.player.facing = .right
    let bossHealth = try XCTUnwrap(grapple.boss?.health)
    grapple.inputController.send(.fireHook)
    for _ in 0..<12 { grapple.update(deltaTime: 0.05) }
    XCTAssertLessThan(try XCTUnwrap(grapple.boss?.health), bossHealth)
  }

  func testLevelTenReturnsToNineWithCarryoverUnchanged() throws {
    let id = EntityID()
    let carry = PlayerCarryoverState(
      characterID: id, health: 2, score: 37,
      completedLevelIDs: [.levelEight, .levelNine])
    let simulation = try LevelTenSimulation(carryover: carry)
    var request: LevelTransitionRequest?
    simulation.onLevelTransition = { request = $0 }
    simulation.player.position = .init(row: 30, column: 54)
    simulation.update(deltaTime: 0)
    XCTAssertEqual(request?.destinationLevelID, .levelNine)
    XCTAssertEqual(request?.destinationEntry, .left)
    XCTAssertEqual(request?.carryover.characterID, id)
    XCTAssertEqual(request?.carryover.health, 2)
    XCTAssertEqual(request?.carryover.score, 37)
  }

  private func isReachable(_ destination: GridPosition, in simulation: LevelTenSimulation) -> Bool {
    var visited: Set<GridPosition> = [LevelTenDefinition.rightStart]
    var pending = [LevelTenDefinition.rightStart]
    while !pending.isEmpty {
      let position = pending.removeFirst()
      if position == destination { return true }
      for direction in GridDirection.allCases {
        let next = position.moved(direction)
        let footprint = CollisionProfile.player.region(at: next)
        guard footprint.cells.allSatisfy(simulation.level.isInside),
          !simulation.level.isBlocked(footprint), !visited.contains(next)
        else { continue }
        visited.insert(next)
        pending.append(next)
      }
    }
    return false
  }

  private func isCollectable(_ entity: WorldEntity, in simulation: LevelTenSimulation) -> Bool {
    let itemRegion = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
    return (0..<simulation.level.grid.rows).contains { row in
      (0..<simulation.level.grid.columns).contains { column in
        let position = GridPosition(row: row, column: column)
        return CollisionProfile.player.region(at: position).intersects(itemRegion)
          && isReachable(position, in: simulation)
      }
    }
  }
}
