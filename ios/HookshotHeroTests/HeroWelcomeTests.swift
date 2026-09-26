import XCTest

@testable import HookshotHero

@MainActor final class HeroWelcomeTests: XCTestCase {
  func testCastlePopulationAndNoDungeonPopulation() throws {
    let simulation = try HeroWelcomeSimulation(seed: 42)
    XCTAssertEqual(simulation.royalNPCs.filter { $0.type == .king }.count, 1)
    XCTAssertEqual(simulation.royalNPCs.filter { $0.type == .queen }.count, 1)
    XCTAssertEqual(simulation.royalNPCs.filter { $0.type == .princess }.count, 1)
    XCTAssertEqual(simulation.royalNPCs.filter { $0.type == .prince }.count, 1)
    XCTAssertEqual(simulation.royalNPCs.filter { $0.type == .aristocrat }.count, 5)
    XCTAssertTrue(simulation.entities.isEmpty)
    XCTAssertTrue(simulation.enemies.isEmpty)
  }

  func testThreeChestsHaveIndependentStablePersistenceAndJavaMessage() throws {
    var carryover: PlayerCarryoverState?
    let simulation = try HeroWelcomeSimulation(seed: 7)
    XCTAssertEqual(simulation.chestStates.count, 3)
    XCTAssertEqual(
      simulation.chestStates.map(\.definition.message), ["Well done!", "Well done!", "Well done!"])
    XCTAssertEqual(Set(simulation.chestStates.map(\.definition.interactionAnchor)).count, 3)

    for anchor in HeroWelcomeDefinition.chestAnchors {
      simulation.player.position = anchor
      simulation.activateChestAndExit()
    }
    XCTAssertTrue(simulation.chestStates.allSatisfy(\.isOpened))
    XCTAssertEqual(simulation.worldState.openedChestIDs.count, 3)
    carryover = simulation.makeCarryoverState()

    let restored = try HeroWelcomeSimulation(seed: 8, carryover: carryover)
    XCTAssertTrue(restored.chestStates.allSatisfy(\.isOpened))
    let score = restored.player.score
    for anchor in HeroWelcomeDefinition.chestAnchors {
      restored.player.position = anchor
      restored.activateChestAndExit()
    }
    XCTAssertEqual(restored.player.score, score)
  }

  func testEntryCastleGeometryAndChestFootprintsAreSafe() throws {
    let level = HeroWelcomeDefinition.make()
    XCTAssertFalse(level.isBlocked(CollisionProfile.player.region(at: HeroWelcomeDefinition.start)))
    XCTAssertFalse(level.isBlocked(HeroWelcomeDefinition.doorwayRegion))
    for column in HeroWelcomeDefinition.columnRegions {
      XCTAssertTrue(level.walls.contains(column))
    }
    let simulation = try HeroWelcomeSimulation()
    for chest in simulation.chestStates {
      XCTAssertTrue(chest.definition.spawnExclusionRegion.cells.allSatisfy(level.isInside))
      XCTAssertFalse(level.isBlocked(chest.definition.spawnExclusionRegion))
    }
  }

  func testManifestAndRuntimeFactoryConstructHeroWelcome() throws {
    let manifest = try LevelAssetManifest.manifest(for: .heroWelcome)
    XCTAssertTrue(HeroWelcomeRenderAssets.all.isSubset(of: manifest.textureAssetIDs))
    let runtime = try DefaultGameLevelRuntimeFactory().makeRuntime(
      levelID: .heroWelcome,
      configuration: .init(reducedMotion: false, controlHintsEnabled: true), seed: 99)
    XCTAssertTrue(runtime.simulation is HeroWelcomeSimulation)
    XCTAssertEqual(runtime.presentation.levelID, .heroWelcome)
  }

  func testTopExitIsTerminalResultsOutcomeWithoutTransition() throws {
    let simulation = try HeroWelcomeSimulation()
    var transitions: [LevelTransitionRequest] = []
    simulation.onLevelTransition = { transitions.append($0) }
    simulation.player.position = .init(row: 4, column: 29)
    simulation.input.send(.move(.up))
    simulation.update(deltaTime: 0.016)
    XCTAssertEqual(simulation.outcome, .won)
    XCTAssertTrue(transitions.isEmpty)
    XCTAssertTrue(simulation.completedLevelIDs.contains(.heroWelcome))
  }

  func testRoyalNPCsRetainJavaFollowBehavior() throws {
    let simulation = try HeroWelcomeSimulation(seed: 1)
    simulation.player.position = .init(row: 18, column: 20)
    let before = simulation.royalNPCs.first { $0.type == .aristocrat }!.position
    for _ in 0..<5 { simulation.update(deltaTime: 0.1) }
    let after = simulation.royalNPCs.first { $0.type == .aristocrat }!.position
    XCTAssertNotEqual(
      after, before, "A nearby Java BGC should seek the hero rather than remain decorative")
  }
}
