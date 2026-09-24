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

  func testExitIsLockedUntilBossDefeatThenEndsAtRenderedPortal() throws {
    let simulation = try LevelTenSimulation()
    simulation.player.position = .init(row: 27, column: 27)
    simulation.update(deltaTime: 0)
    XCTAssertNil(simulation.outcome)
    XCTAssertFalse(simulation.isExitUnlocked)

    simulation.defeatBossForTesting()
    XCTAssertTrue(simulation.isExitUnlocked)
    XCTAssertEqual(simulation.chestStates.count, 1)
    simulation.update(deltaTime: 0)
    XCTAssertEqual(simulation.outcome, .won)
    XCTAssertTrue(simulation.completedLevelIDs.contains(.levelTen))
  }

  func testBossDefeatAndChestPersistAcrossReturnWithoutRepeatedReward() throws {
    let first = try LevelTenSimulation()
    first.defeatBossForTesting()
    first.player.position = LevelTenDefinition.chestAnchor
    first.activateChestAndExit()
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
    simulation.activateChestAndExit()
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
}
