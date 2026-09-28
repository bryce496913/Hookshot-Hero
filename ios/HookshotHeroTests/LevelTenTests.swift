import Combine
import SpriteKit
import UIKit
import XCTest

@testable import HookshotHero

@MainActor final class LevelTenTests: XCTestCase {
  private let configuration = GameConfiguration(reducedMotion: false, controlHintsEnabled: true)

  func testGhostWizardUsesJavaDirectionalRowsAndTwoRegisteredFrames() throws {
    let expected: [(RenderOrientation, Int)] = [
      (.down, 0), (.right, 1), (.left, 2), (.up, 3),
    ]

    for (direction, row) in expected {
      let animationID = LevelTenRenderAnimations.ghostWizard(direction)
      let frameIDs = (0..<2).map {
        LevelTenRenderAssets.ghostWizardFrame(row: row, frame: $0)
      }
      XCTAssertEqual(LevelTenRenderAnimations.row(for: direction), row)
      XCTAssertEqual(LevelTenRenderAnimations.frames(direction), frameIDs)
      XCTAssertEqual(RenderAnimationRegistry.assetFrames[animationID], frameIDs)
      XCTAssertTrue(LevelAssetManifest.levelTen.animationIDs.contains(animationID))
      XCTAssertTrue(frameIDs.allSatisfy(LevelAssetManifest.levelTen.textureAssetIDs.contains))
    }
    XCTAssertEqual(LevelTenRenderAnimations.row(for: .none), 0)
  }

  func testGhostWizardTextureCropsCoverTrackedSheetWithoutInvalidRegions() throws {
    let idle = try XCTUnwrap(LevelOneTextureCatalog.entries[LevelTenRenderAssets.ghostWizard])
    XCTAssertEqual(idle.filename, "minotaurWithAxe.png")
    XCTAssertEqual(
      idle.source,
      .init(x: 0, y: 0, width: 45, height: 58, sheetWidth: 90, sheetHeight: 232))

    for row in 0..<4 {
      for frame in 0..<2 {
        let id = LevelTenRenderAssets.ghostWizardFrame(row: row, frame: frame)
        let entry = try XCTUnwrap(LevelOneTextureCatalog.entries[id])
        let source = try XCTUnwrap(entry.source)
        XCTAssertEqual(entry.filename, "minotaurWithAxe.png")
        XCTAssertEqual(
          source,
          .init(
            x: Double(frame * 45), y: Double(row * 58), width: 45, height: 58,
            sheetWidth: 90, sheetHeight: 232))
        XCTAssertGreaterThanOrEqual(source.x, 0)
        XCTAssertGreaterThanOrEqual(source.y, 0)
        XCTAssertLessThanOrEqual(source.x + source.width, source.sheetWidth)
        XCTAssertLessThanOrEqual(source.y + source.height, source.sheetHeight)
      }
    }

    let sheetURL = try XCTUnwrap(
      Bundle.main.url(forResource: "minotaurWithAxe.png", withExtension: nil))
    let sheet = try XCTUnwrap(UIImage(contentsOfFile: sheetURL.path)?.cgImage)
    XCTAssertEqual(sheet.width, 90)
    XCTAssertEqual(sheet.height, 232)

    let textures = TextureCatalog(entries: LevelOneTextureCatalog.entries)
    let animations = LevelOneAnimationCatalog(textureCatalog: textures)
    for direction in [
      RenderOrientation.down, .right, .left, .up,
    ] {
      let frames = try animations.frames(for: LevelTenRenderAnimations.ghostWizard(direction))
      XCTAssertEqual(frames.count, 2)
      XCTAssertTrue(frames.allSatisfy { $0.size() == CGSize(width: 45, height: 58) })
    }
  }

  func testGhostWizardIdleMovementDamageAndDefeatVisualStates() throws {
    let simulation = try LevelTenSimulation()
    let initialBoss = try XCTUnwrap(simulation.boss)
    var rendered = try XCTUnwrap(
      simulation.renderSnapshot.entities.first { $0.id == initialBoss.id })
    XCTAssertEqual(rendered.asset, LevelTenRenderAssets.ghostWizard)
    XCTAssertEqual(rendered.renderSize, .init(width: 4.5, height: 5.8))
    XCTAssertEqual(rendered.animation?.frameIndex, 0)
    XCTAssertEqual(rendered.health, .init(current: 10, maximum: 10))

    simulation.update(deltaTime: 0.1)
    rendered = try XCTUnwrap(
      simulation.renderSnapshot.entities.first { $0.id == initialBoss.id })
    XCTAssertEqual(rendered.animation?.frameIndex, 0)
    simulation.update(deltaTime: 0.1)
    rendered = try XCTUnwrap(
      simulation.renderSnapshot.entities.first { $0.id == initialBoss.id })
    XCTAssertEqual(rendered.animation?.frameIndex, 1)
    simulation.update(deltaTime: 0.1)
    rendered = try XCTUnwrap(
      simulation.renderSnapshot.entities.first { $0.id == initialBoss.id })
    XCTAssertEqual(rendered.animation?.frameIndex, 0)

    let damageSimulation = try LevelTenSimulation()
    damageSimulation.player.position = .init(row: 25, column: 15)
    damageSimulation.player.facing = .right
    damageSimulation.inputController.send(.fireHook)
    for _ in 0..<12 { damageSimulation.update(deltaTime: 0.05) }
    let damaged = try XCTUnwrap(damageSimulation.boss)
    rendered = try XCTUnwrap(
      damageSimulation.renderSnapshot.entities.first { $0.id == damaged.id })
    XCTAssertEqual(rendered.asset, LevelTenRenderAssets.ghostWizard)
    XCTAssertEqual(rendered.health?.current, damaged.health)
    XCTAssertLessThan(damaged.health, damaged.maximumHealth)

    damageSimulation.defeatBossForTesting()
    XCTAssertFalse(
      damageSimulation.renderSnapshot.entities.contains {
        $0.asset == LevelTenRenderAssets.ghostWizard
      })
    XCTAssertTrue(
      damageSimulation.renderSnapshot.effects.contains {
        $0.descriptor == .enemyDefeat(reducedMotion: false)
      })
    XCTAssertTrue(damageSimulation.isExitUnlocked)
  }

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
    var transition: LevelTransitionRequest?
    simulation.onLevelTransition = { transition = $0 }
    simulation.player.position = .init(row: 27, column: 27)
    simulation.update(deltaTime: 0)
    XCTAssertNil(simulation.outcome)
    XCTAssertNil(transition)
    XCTAssertFalse(simulation.completedLevelIDs.contains(.levelTen))
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

  func testChestDialogueDoesNotTransitionAndDeliberatePortalEntryEmitsCarryover() throws {
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
    let request = session.pendingTransitionRequest
    XCTAssertNil(simulation.outcome)
    XCTAssertEqual(session.state, .transitioning(.countryRoad))
    XCTAssertTrue(simulation.completedLevelIDs.contains(.levelTen))
    XCTAssertEqual(simulation.player.score, scoreBeforeChest + 200)
    XCTAssertEqual(request?.sourceLevelID, .levelTen)
    XCTAssertEqual(request?.destinationLevelID, .countryRoad)
    XCTAssertEqual(request?.destinationEntry, .bottom)
    XCTAssertEqual(request?.reason, .completedForward)
    XCTAssertEqual(request?.carryover, simulation.makeCarryoverState())
  }

  func testUnlockedPortalAwardsCompletionOnceAndCarriesCompletePlayerState() throws {
    let characterID = EntityID()
    let priorChest = OpenedChestID(
      levelID: .levelNine, interactionAnchor: .init(row: 12, column: 14))
    let carryover = PlayerCarryoverState(
      characterID: characterID, health: 3, score: 275,
      completedLevelIDs: [.levelEight, .levelNine],
      worldState: .init(openedChestIDs: [priorChest]))
    let simulation = try LevelTenSimulation(carryover: carryover)
    simulation.defeatBossForTesting()
    var requests: [LevelTransitionRequest] = []
    simulation.onLevelTransition = { requests.append($0) }
    simulation.player.position = .init(row: 27, column: 27)

    simulation.update(deltaTime: 0)
    simulation.update(deltaTime: 0)

    XCTAssertEqual(requests.count, 2)
    let request = try XCTUnwrap(requests.first)
    XCTAssertEqual(request.sourceLevelID, .levelTen)
    XCTAssertEqual(request.destinationLevelID, .countryRoad)
    XCTAssertEqual(request.destinationEntry, .bottom)
    XCTAssertEqual(request.reason, .completedForward)
    XCTAssertEqual(request.carryover.characterID, characterID)
    XCTAssertEqual(request.carryover.health, 3)
    XCTAssertEqual(request.carryover.score, 375)
    XCTAssertEqual(
      request.carryover.completedLevelIDs, [.levelEight, .levelNine, .levelTen])
    XCTAssertTrue(request.carryover.worldState.openedChestIDs.contains(priorChest))
    XCTAssertTrue(request.carryover.worldState.defeatedBossLevelIDs.contains(.levelTen))
    XCTAssertEqual(simulation.player.score, 375, "Level completion must only award 100 once")
    XCTAssertNil(simulation.outcome)

    let revisited = try LevelTenSimulation(carryover: request.carryover)
    XCTAssertNil(revisited.boss)
    let scoreBeforeReentry = revisited.player.score
    revisited.player.position = .init(row: 27, column: 27)
    revisited.update(deltaTime: 0)
    XCTAssertEqual(revisited.player.score, scoreBeforeReentry)
  }

  func testCountryRoadBottomEntryConstructsThroughProductionRuntimeAndPreflight() throws {
    let carryover = PlayerCarryoverState(
      characterID: EntityID(), health: 4, score: 500,
      completedLevelIDs: [.levelTen],
      worldState: .init(defeatedBossLevelIDs: [.levelTen]))

    let runtime = try DefaultGameLevelRuntimeFactory(
      simulationFactory: DefaultGameSimulationFactory(), preflight: DefaultAssetPreflight()
    ).makeRuntime(
      levelID: .countryRoad, configuration: configuration, seed: 10,
      entryPosition: .bottom, carryover: carryover)

    let countryRoad = try XCTUnwrap(runtime.simulation as? CountryRoadSimulation)
    XCTAssertEqual(countryRoad.player.position, CountryRoadDefinition.start)
    XCTAssertFalse(
      countryRoad.level.isBlocked(CollisionProfile.player.region(at: countryRoad.player.position)))
    XCTAssertEqual(countryRoad.makeCarryoverState(), carryover)
    XCTAssertEqual(runtime.assetManifest, .countryRoad)
  }

  func testRouterInstallsCountryRoadInSameSessionWithoutResultsAndSceneAttachmentResumesRunning()
    async throws
  {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let progression = ProgressionStore(
      repository: ProgressionRepository(fileURL: directory.appending(path: "save.json")))
    let runtimeFactory = DefaultGameLevelRuntimeFactory()
    let router = AppRouter(
      progressionStore: progression, runtimeFactory: runtimeFactory, levelSeed: 10)
    let runtime = try runtimeFactory.makeRuntime(
      levelID: .levelTen, configuration: configuration, seed: 10,
      entryPosition: .right, carryover: nil)
    let session = GameSession(configuration: configuration, runtime: runtime)
    let sessionID = session.identifier
    var states: [GameSessionState] = []
    let observation = session.$state.sink { states.append($0) }
    defer { observation.cancel() }
    router.startGame(session: session)
    session.advance(by: 1.25)
    let elapsedBeforePortal = session.elapsedTime

    let levelTen = try XCTUnwrap(session.simulation as? LevelTenSimulation)
    levelTen.defeatBossForTesting()
    levelTen.player.position = .init(row: 27, column: 27)
    session.advance(by: 0)

    await waitUntil { session.runtimeGeneration == 1 }
    XCTAssertEqual(session.identifier, sessionID)
    XCTAssertTrue(router.activeSession === session)
    XCTAssertEqual(session.levelID, .countryRoad)
    XCTAssertEqual(session.state, .transitioning(.countryRoad))
    XCTAssertEqual(router.path, [.gameplay])
    XCTAssertFalse(states.contains(.won))
    XCTAssertEqual(session.elapsedTime, elapsedBeforePortal)

    session.runtimeSceneDidAttach(
      generation: session.runtimeGeneration, levelID: session.runtime.presentation.levelID)

    XCTAssertEqual(session.state, .running)
    XCTAssertEqual(session.levelID, .countryRoad)
    XCTAssertEqual(session.simulation.renderSnapshot.player.coordinate, CountryRoadDefinition.start)
    XCTAssertFalse(router.path.contains { if case .results = $0 { true } else { false } })
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

  private func waitUntil(
    timeout: TimeInterval = 2, condition: @escaping @MainActor () -> Bool
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
      await Task.yield()
    }
  }
}
