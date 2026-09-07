import XCTest

@testable import HookshotHero

enum DestinationMoveSafety {
  static let directionOrder: [GridDirection] = [.up, .right, .down, .left]

  static func isSafePlayerMove(
    from position: GridPosition, direction: GridDirection, in level: LevelDefinition
  ) -> Bool {
    let movedPlayerRegion = CollisionProfile.player.region(at: position.moved(direction))
    return !level.isBlocked(movedPlayerRegion) && !level.overlapsLava(movedPlayerRegion)
  }

  static func safeDirections(
    from position: GridPosition, in level: LevelDefinition
  ) -> [GridDirection] {
    directionOrder.filter { isSafePlayerMove(from: position, direction: $0, in: level) }
  }
}

struct TransitionPlayabilityContract {
  let levelID: LevelID
  let entry: LevelEntryPosition
  let start: GridPosition
  let direction: GridDirection
}

@MainActor final class LevelFourTransitionFixtureTests: XCTestCase {
  private let levelFiveLeftStartUITestContract = GridPosition(row: 8, column: 7)
  private let levelSixBottomStartUITestContract = GridPosition(row: 50, column: 27)

  func testDestinationPlayabilityContractsSelectSafeMoves() {
    let contracts = [
      TransitionPlayabilityContract(
        levelID: .levelFive, entry: .left, start: levelFiveLeftStartUITestContract,
        direction: .right),
      TransitionPlayabilityContract(
        levelID: .levelSix, entry: .bottom, start: levelSixBottomStartUITestContract,
        direction: .right),
    ]

    for contract in contracts {
      let level = destinationLevel(for: contract)
      XCTAssertEqual(level.start, contract.start, "\(contract.levelID.rawValue) \(contract.entry)")
      XCTAssertTrue(
        DestinationMoveSafety.isSafePlayerMove(
          from: contract.start, direction: contract.direction, in: level),
        "Unsafe UI-test move for \(contract.levelID.rawValue) \(contract.entry): \(contract.direction)")
    }
  }

  func testLevelSixBottomStartMatchesUITestContract() {
    XCTAssertEqual(LevelSixDefinition.bottomStart, levelSixBottomStartUITestContract)
  }

  func testLevelSixBottomStartRejectsDownAndAllowsRight() {
    let level = LevelSixDefinition.make()

    XCTAssertFalse(
      DestinationMoveSafety.isSafePlayerMove(
        from: LevelSixDefinition.bottomStart, direction: .down, in: level))
    XCTAssertTrue(
      DestinationMoveSafety.isSafePlayerMove(
        from: LevelSixDefinition.bottomStart, direction: .right, in: level))
  }

  func testPlayerMoveSafetyRejectsWallIntersection() {
    let wall = GridRegion(rows: 1..<4, columns: 2..<5)
    let level = testLevel(walls: [wall])

    XCTAssertFalse(
      DestinationMoveSafety.isSafePlayerMove(
        from: .init(row: 2, column: 2), direction: .right, in: level))
  }

  func testPlayerMoveSafetyRejectsOutOfGridFootprint() {
    let level = testLevel()

    XCTAssertFalse(
      DestinationMoveSafety.isSafePlayerMove(
        from: .init(row: 1, column: 2), direction: .up, in: level))
  }

  func testPlayerMoveSafetyRejectsLavaIntersection() {
    let lava = GridRegion(rows: 1..<4, columns: 2..<5)
    let level = testLevel(lava: [lava])

    XCTAssertFalse(
      DestinationMoveSafety.isSafePlayerMove(
        from: .init(row: 2, column: 2), direction: .right, in: level))
  }

  func testSafeDirectionOrderingIsDeterministic() {
    let level = testLevel(grid: .init(rows: 7, columns: 7))

    XCTAssertEqual(
      DestinationMoveSafety.safeDirections(from: .init(row: 3, column: 3), in: level),
      [.up, .right, .down, .left])
  }

  #if DEBUG
    func testRightFixtureIsExactlyOneMoveFromRightExit() throws {
      let simulation = try LevelFourSimulation(seed: 496_913)
      simulation.prepareForTransitionUITest(exit: .right)

      let initial = simulation.player.position
      XCTAssertEqual(initial, .init(row: 29, column: 54))
      XCTAssertFalse(
        CollisionProfile.player.region(at: initial).intersects(LevelFourDefinition.rightExitRegion))
      XCTAssertTrue(
        CollisionProfile.player.region(at: initial.moved(.right)).intersects(
          LevelFourDefinition.rightExitRegion))
    }

    func testTopFixtureIsExactlyOneMoveFromTopExit() throws {
      let simulation = try LevelFourSimulation(seed: 496_913)
      simulation.prepareForTransitionUITest(exit: .top)

      let initial = simulation.player.position
      XCTAssertEqual(initial, .init(row: 5, column: 29))
      XCTAssertFalse(
        CollisionProfile.player.region(at: initial).intersects(simulation.level.exitRegion))
      XCTAssertTrue(
        CollisionProfile.player.region(at: initial.moved(.up)).intersects(
          simulation.level.exitRegion))
    }
  #endif

  private func destinationLevel(for contract: TransitionPlayabilityContract) -> LevelDefinition {
    if contract.levelID == .levelFive {
      XCTAssertEqual(contract.entry, .left)
      return LevelFiveDefinition.make()
    }

    XCTAssertEqual(contract.levelID, .levelSix)
    XCTAssertEqual(contract.entry, .bottom)
    return LevelSixDefinition.make()
  }

  private func testLevel(
    grid: GridSize = .init(rows: 6, columns: 6), walls: [GridRegion] = [],
    lava: [GridRegion] = []
  ) -> LevelDefinition {
    let emptyRegion = GridRegion(rows: 0..<0, columns: 0..<0)
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [], bottomWallRegions: [], leftWallRegions: [], rightWallRegions: [],
      topExitRegion: emptyRegion, bottomDoorRegion: emptyRegion)
    return .init(
      grid: grid, start: .init(row: 2, column: 2), exitAnchor: .init(row: 0, column: 0),
      entryAnchor: .init(row: 0, column: 0), chestAnchor: .init(row: 0, column: 0),
      boundary: boundary, walls: walls, lava: lava, internalWallAnchors: [],
      displayName: "Move safety test")
  }
}
