import XCTest

@testable import HookshotHero

@MainActor final class CountryRoadTests: XCTestCase {
  func testGeometryIsDeterministicAndEntryFootprintIsSafe() throws {
    XCTAssertEqual(CountryRoadDefinition.make().walls, CountryRoadDefinition.make().walls)
    let level = CountryRoadDefinition.make()
    XCTAssertFalse(level.isBlocked(CollisionProfile.player.region(at: CountryRoadDefinition.start)))
    XCTAssertTrue(level.walls.contains(CountryRoadDefinition.sceneryWalls[0]))
  }

  func testJavaCollectibleAndNPCPopulationContract() throws {
    let first = try CountryRoadSimulation(seed: 42)
    let second = try CountryRoadSimulation(seed: 42)
    XCTAssertEqual(first.entities.map(\.kind), second.entities.map(\.kind))
    XCTAssertEqual(first.entities.filter { $0.kind == .cabbage }.count, 5)
    XCTAssertEqual(first.entities.filter { $0.kind == .coin }.count, 15)
    XCTAssertEqual(CountryRoadDefinition.population.children, 9)
    XCTAssertEqual(CountryRoadDefinition.population.old, 5)
    XCTAssertEqual(CountryRoadDefinition.population.townfolk, 15)
    XCTAssertFalse(first.entities.contains { $0.kind == .mine })
    XCTAssertTrue(first.enemies.isEmpty)
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
  }

  func testCastleExitIsReachableAndWinsWithoutHeroWelcome() throws {
    let simulation = try CountryRoadSimulation(seed: 7)
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
    XCTAssertEqual(simulation.outcome, .won)
    XCTAssertTrue(simulation.completedLevelIDs.contains(.countryRoad))
  }
}
