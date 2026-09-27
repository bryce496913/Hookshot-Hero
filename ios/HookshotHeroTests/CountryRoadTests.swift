import Combine
import SpriteKit
import XCTest

@testable import HookshotHero

@MainActor final class CountryRoadTests: XCTestCase {
  func testGeometryIsDeterministicAndEntryFootprintIsSafe() throws {
    XCTAssertEqual(CountryRoadDefinition.make().walls, CountryRoadDefinition.make().walls)
    let level = CountryRoadDefinition.make()
    XCTAssertFalse(level.isBlocked(CollisionProfile.player.region(at: CountryRoadDefinition.start)))
    XCTAssertTrue(level.walls.contains(CountryRoadDefinition.sceneryWalls[0]))
  }

  func testJavaCollectibleAndRuntimeNPCPopulationContract() throws {
    let first = try CountryRoadSimulation(seed: 42)
    let second = try CountryRoadSimulation(seed: 42)
    XCTAssertEqual(first.entities.map(\.kind), second.entities.map(\.kind))
    XCTAssertEqual(first.entities.filter { $0.kind == .cabbage }.count, 5)
    XCTAssertEqual(first.entities.filter { $0.kind == .coin }.count, 15)
    XCTAssertEqual(first.npcStates.filter { $0.archetype == .child }.count, 9)
    XCTAssertEqual(first.npcStates.filter { $0.archetype == .olderResident }.count, 5)
    XCTAssertEqual(first.npcStates.filter { $0.archetype == .townfolk }.count, 15)
    XCTAssertEqual(first.npcStates.count, 29)
    XCTAssertEqual(Set(first.npcStates.map(\.id)).count, 29)
    XCTAssertEqual(first.npcStates.map(\.position), second.npcStates.map(\.position))
    XCTAssertEqual(first.npcStates.map(\.facing), second.npcStates.map(\.facing))
    XCTAssertFalse(first.entities.contains { $0.kind == .mine })
    XCTAssertTrue(first.enemies.isEmpty)
  }

  func testNPCFootprintsAreSafeAndSeparated() throws {
    let simulation = try CountryRoadSimulation(seed: 496_913)
    let playerStart = CollisionProfile.player.region(at: CountryRoadDefinition.start)
    for (index, npc) in simulation.npcStates.enumerated() {
      let footprint = CollisionProfile.player.region(at: npc.position)
      XCTAssertTrue(footprint.cells.allSatisfy(simulation.level.isInside))
      XCTAssertFalse(simulation.level.isBlocked(footprint))
      XCTAssertFalse(footprint.intersects(playerStart))
      XCTAssertFalse(footprint.intersects(CountryRoadDefinition.exitRegion))
      XCTAssertFalse(footprint.intersects(CountryRoadDefinition.doorwayRegion))
      for other in simulation.npcStates.dropFirst(index + 1) {
        XCTAssertFalse(
          footprint.intersects(CollisionProfile.player.region(at: other.position)),
          "NPC footprints overlap at \(npc.position) and \(other.position)")
      }
    }
  }

  func testNPCsRenderMoveDeterministicallyAndSurviveCollection() throws {
    let first = try CountryRoadSimulation(seed: 73)
    let second = try CountryRoadSimulation(seed: 73)
    let npcIDs = Set(first.npcStates.map(\.id))
    let npcAssets: Set<RenderAssetID> = [
      CountryRoadRenderAssets.child, CountryRoadRenderAssets.olderResident,
      CountryRoadRenderAssets.townfolk,
    ]
    let renderedNPCs = first.renderSnapshot.entities.filter { npcIDs.contains($0.id) }
    XCTAssertEqual(renderedNPCs.count, 29)
    XCTAssertEqual(Set(renderedNPCs.map(\.asset)), npcAssets)

    let startingPositions = first.npcStates.map(\.position)
    for _ in 0..<30 {
      first.update(deltaTime: 0.1)
      second.update(deltaTime: 0.1)
    }
    XCTAssertEqual(first.npcStates.map(\.position), second.npcStates.map(\.position))
    XCTAssertEqual(first.npcStates.map(\.facing), second.npcStates.map(\.facing))
    XCTAssertNotEqual(first.npcStates.map(\.position), startingPositions)

    let collectible = try XCTUnwrap(first.entities.first)
    first.player.position = collectible.position
    first.update(deltaTime: 0)
    XCTAssertEqual(first.npcStates.count, 29)
    XCTAssertEqual(Set(first.npcStates.map(\.id)), npcIDs)
  }

  func testCollectibleFootprintsAvoidGeometryEntryAndExit() throws {
    let simulation = try CountryRoadSimulation(seed: 496_913)
    let protected = [
      CollisionProfile.player.region(at: CountryRoadDefinition.start),
      CountryRoadDefinition.exitRegion, CountryRoadDefinition.doorwayRegion,
    ]
    for entity in simulation.entities {
      let footprint = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
      XCTAssertFalse(simulation.level.isBlocked(footprint))
      XCTAssertFalse(protected.contains(where: footprint.intersects))
    }
  }

  func testManifestPreflightAndFactoryConstruction() throws {
    let runtime = try DefaultGameLevelRuntimeFactory().makeRuntime(
      levelID: .countryRoad,
      configuration: .init(reducedMotion: false, controlHintsEnabled: true), seed: 1)
    XCTAssertTrue(runtime.simulation is CountryRoadSimulation)
    XCTAssertEqual(runtime.assetManifest, .countryRoad)
    XCTAssertTrue(
      runtime.assetManifest.animationIDs.contains(.init(rawValue: "country-road.waterfall")))
    XCTAssertTrue(runtime.assetManifest.textureAssetIDs.contains(CountryRoadRenderAssets.child))
    XCTAssertTrue(
      runtime.assetManifest.textureAssetIDs.contains(CountryRoadRenderAssets.olderResident))
    XCTAssertTrue(runtime.assetManifest.textureAssetIDs.contains(CountryRoadRenderAssets.townfolk))
  }

  func testCastleExitIsReachableAndRequestsHeroWelcome() throws {
    let simulation = try CountryRoadSimulation(seed: 7)
    var transitions: [LevelTransitionRequest] = []
    simulation.onLevelTransition = { transitions.append($0) }
    var visited: Set<GridPosition> = [CountryRoadDefinition.start]
    var pending = [CountryRoadDefinition.start]
    var reached: GridPosition?
    while let current = pending.popLast(), reached == nil {
      for direction in GridDirection.allCases {
        let next = current.moved(direction)
        let footprint = CollisionProfile.player.region(at: next)
        guard !visited.contains(next), footprint.cells.allSatisfy(simulation.level.isInside),
          !simulation.level.isBlocked(footprint)
        else { continue }
        visited.insert(next)
        pending.append(next)
        if footprint.intersects(CountryRoadDefinition.exitRegion) {
          reached = next
          break
        }
      }
    }
    simulation.player.position = try XCTUnwrap(reached)
    simulation.update(deltaTime: 0)
    simulation.update(deltaTime: 0)

    XCTAssertNil(simulation.outcome)
    XCTAssertTrue(simulation.completedLevelIDs.contains(.countryRoad))
    let request = try XCTUnwrap(transitions.first)
    XCTAssertEqual(transitions.count, 1)
    XCTAssertEqual(request.sourceLevelID, .countryRoad)
    XCTAssertEqual(request.destinationLevelID, .heroWelcome)
    XCTAssertEqual(request.destinationEntry, .bottom)
    XCTAssertEqual(request.reason, .completedForward)
    XCTAssertEqual(request.carryover, simulation.makeCarryoverState())
  }

  func testCountryRoadTransitionsThroughRouterAndAttachesHeroWelcome() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let progression = ProgressionStore(
      repository: ProgressionRepository(fileURL: directory.appending(path: "save.json")))
    let runtimeFactory = DefaultGameLevelRuntimeFactory(
      simulationFactory: DefaultGameSimulationFactory(), preflight: DefaultAssetPreflight())
    let router = AppRouter(
      progressionStore: progression, runtimeFactory: runtimeFactory, levelSeed: 496_913)
    let characterID = EntityID()
    let openedChest = OpenedChestID(
      levelID: .levelTwo, interactionAnchor: .init(row: 4, column: 4))
    let carryover = PlayerCarryoverState(
      characterID: characterID, health: 2, score: 37, completedLevelIDs: [.levelTen],
      worldState: .init(openedChestIDs: [openedChest]))
    let sourceRuntime = try runtimeFactory.makeRuntime(
      levelID: .countryRoad,
      configuration: .init(reducedMotion: false, controlHintsEnabled: true), seed: 496_913,
      entryPosition: .bottom, carryover: carryover)
    let session = GameSession(
      configuration: .init(reducedMotion: false, controlHintsEnabled: true),
      runtime: sourceRuntime)
    var observedStates: [GameSessionState] = []
    let observation = session.$state.sink { observedStates.append($0) }
    defer { observation.cancel() }
    router.startGame(session: session)
    session.advance(by: 1.25)

    let countryRoad = try XCTUnwrap(session.simulation as? CountryRoadSimulation)
    countryRoad.player.position = .init(row: 3, column: 29)
    session.advance(by: 0.01)
    let elapsedBeforeTransition = session.elapsedTime

    XCTAssertEqual(session.state, .transitioning(.heroWelcome))
    let request = try XCTUnwrap(session.pendingTransitionRequest)
    XCTAssertEqual(request.destinationLevelID, .heroWelcome)
    XCTAssertEqual(request.destinationEntry, .bottom)
    XCTAssertEqual(request.carryover.characterID, characterID)
    XCTAssertEqual(request.carryover.health, 2)
    XCTAssertEqual(request.carryover.score, 37)
    XCTAssertEqual(request.carryover.completedLevelIDs, [.levelTen, .countryRoad])
    XCTAssertEqual(request.carryover.worldState.openedChestIDs, [openedChest])
    XCTAssertEqual(router.path, [.gameplay])

    await waitUntil { session.runtimeGeneration == 1 }
    XCTAssertTrue(session.simulation is HeroWelcomeSimulation)
    XCTAssertEqual(session.runtime.assetManifest, .heroWelcome)
    XCTAssertEqual(session.levelID, .heroWelcome)
    XCTAssertEqual(session.state, .transitioning(.heroWelcome))
    XCTAssertEqual(router.path, [.gameplay])

    let sceneView = SKView(frame: .init(x: 0, y: 0, width: 600, height: 600))
    let scene = GameScene(
      session: session, runtime: session.runtime, generation: session.runtimeGeneration)
    sceneView.presentScene(scene)
    await waitUntil { session.state == .running }

    XCTAssertTrue(sceneView.scene === scene)
    XCTAssertEqual(session.state, .running)
    XCTAssertEqual(session.levelID, .heroWelcome)
    XCTAssertEqual(
      session.simulation.renderSnapshot.player.coordinate, HeroWelcomeDefinition.start)
    XCTAssertEqual(session.simulation.renderSnapshot.player.id, characterID)
    XCTAssertEqual(session.health, 2)
    XCTAssertEqual(session.score, 37)
    XCTAssertEqual(session.elapsedTime, elapsedBeforeTransition)
    let heroWelcome = try XCTUnwrap(session.simulation as? HeroWelcomeSimulation)
    XCTAssertEqual(heroWelcome.completedLevelIDs, [.levelTen, .countryRoad])
    XCTAssertEqual(heroWelcome.worldState.openedChestIDs, [openedChest])
    XCTAssertTrue(observedStates.contains(.transitioning(.heroWelcome)))
    XCTAssertFalse(observedStates.contains(.won))
    XCTAssertEqual(router.path, [.gameplay])
  }

  private func waitUntil(
    attempts: Int = 100, condition: @MainActor () -> Bool
  ) async {
    for _ in 0..<attempts {
      if condition() { return }
      await Task.yield()
    }
  }
}
