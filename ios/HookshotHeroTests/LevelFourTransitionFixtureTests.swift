import XCTest

@testable import HookshotHero

@MainActor final class LevelFourTransitionFixtureTests: XCTestCase {
  private let levelSixBottomStartUITestContract = GridPosition(row: 50, column: 27)

  func testLevelSixBottomStartMatchesUITestContract() {
    XCTAssertEqual(LevelSixDefinition.bottomStart, levelSixBottomStartUITestContract)
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
}
