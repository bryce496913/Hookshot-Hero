import XCTest

@testable import HookshotHero

@MainActor final class LevelEightDefinitionTests: XCTestCase {
  func testDefinitionContainsEveryUniqueExecutableJavaAnchor() {
    let level = LevelEightDefinition.make()
    XCTAssertEqual(level.grid, .init(rows: 60, columns: 60))
    XCTAssertEqual(Set(LevelEightDefinition.lavaAnchors), expectedLava)
    XCTAssertEqual(LevelEightDefinition.lavaAnchors.count, 35)
    XCTAssertEqual(Set(LevelEightDefinition.wallAnchors), expectedWalls)
    XCTAssertEqual(LevelEightDefinition.wallAnchors.count, 77)
    XCTAssertEqual(Set(level.internalWallAnchors), expectedWalls)

    for anchor in LevelEightDefinition.lavaAnchors + LevelEightDefinition.wallAnchors {
      XCTAssertTrue((0...56).contains(anchor.row))
      XCTAssertTrue((0...56).contains(anchor.column))
    }
  }

  func testLiteralJava4000LavaLoopIsDead() {
    let executableIterations = stride(from: 4000, to: 520, by: 40).count
    XCTAssertEqual(
      executableIterations, 0, "LevelEight.java's 4000 start is preserved, not changed to 400")
    XCTAssertFalse(LevelEightDefinition.lavaAnchors.contains(.init(row: 40, column: 4)))
  }

  func testThreeDoorwaysAndBranchStartsHaveSafePlayerFootprints() {
    let level = LevelEightDefinition.make()
    XCTAssertEqual(level.exitRegion, LevelEightDefinition.topDoorRegion)
    XCTAssertEqual(level.entryRegion, LevelEightDefinition.bottomDoorRegion)
    XCTAssertEqual(LevelEightDefinition.leftDoorRegion, .init(rows: 27..<33, columns: 0..<4))
    XCTAssertEqual(level.exitAnchor, .init(row: 0, column: 50))
    XCTAssertEqual(level.entryAnchor, .init(row: 56, column: 27))
    XCTAssertEqual(LevelEightDefinition.fromLevelSevenStart, .init(row: 50, column: 27))
    XCTAssertEqual(LevelEightDefinition.fromLevelSixStart, .init(row: 29, column: 5))
    XCTAssertEqual(LevelEightDefinition.topReturnStart, .init(row: 5, column: 23))

    for start in [
      LevelEightDefinition.fromLevelSevenStart, LevelEightDefinition.fromLevelSixStart,
      LevelEightDefinition.topReturnStart,
    ] {
      let footprint = CollisionProfile.player.region(at: start)
      XCTAssertTrue(footprint.cells.allSatisfy(level.isInside), "unsafe start: \(start)")
      XCTAssertFalse(level.isBlocked(footprint), "blocked start: \(start)")
      XCTAssertFalse(level.overlapsLava(footprint), "lava start: \(start)")
    }
  }

  func testDoorRenderingMatchesLogicalOpeningsAndEmitters() {
    let presentation = LevelEightPresentationDefinition.make(from: LevelEightDefinition.make())
    let doors = presentation.staticObjects.filter {
      [
        LevelEightRenderAssets.exitDoor, LevelEightRenderAssets.leftDoor,
        LevelEightRenderAssets.bottomDoor,
      ].contains($0.asset)
    }
    XCTAssertEqual(doors.count, 3)
    XCTAssertEqual(
      doors.map(\.coordinate),
      [
        .init(row: 0, column: 48), .init(row: 28, column: 0), .init(row: 56, column: 28),
      ])
    XCTAssertTrue(
      doors.allSatisfy { door in
        let rendered = GridRegion(
          rows: door.coordinate.row..<door.coordinate.row + Int(door.renderSize.height),
          columns: door.coordinate.column..<door.coordinate.column + Int(door.renderSize.width))
        return [
          LevelEightDefinition.topDoorRegion, LevelEightDefinition.leftDoorRegion,
          LevelEightDefinition.bottomDoorRegion,
        ].contains(where: { $0.intersects(rendered) })
      })
    XCTAssertEqual(
      presentation.staticObjects.filter { $0.asset == LevelEightRenderAssets.smoke }.map(
        \.coordinate),
      [.init(row: 9, column: 25), .init(row: 51, column: 50)])
  }

  func testRepeatedDefinitionConstructionIsDeterministic() {
    let first = LevelEightDefinition.make()
    for _ in 0..<10 {
      let next = LevelEightDefinition.make()
      XCTAssertEqual(next.grid, first.grid)
      XCTAssertEqual(next.boundary, first.boundary)
      XCTAssertEqual(next.walls, first.walls)
      XCTAssertEqual(next.lava, first.lava)
      XCTAssertEqual(next.internalWallAnchors, first.internalWallAnchors)
    }
  }

  private var expectedLava: Set<GridPosition> {
    var result: Set<GridPosition> = []
    add([8, 12], [24, 28, 32], to: &result)
    add([24, 28, 32], [20, 24], to: &result)
    add([32, 36, 40], [44, 48], to: &result)
    add([40, 44, 48], [48, 52], to: &result)
    add([20, 24, 28], [36], to: &result)
    add([48], [16, 20, 24], to: &result)
    add([20], [12, 16, 20], to: &result)
    add([32], [40], to: &result)
    add([52], [40], to: &result)
    add([36], [12], to: &result)
    return result
  }

  private var expectedWalls: Set<GridPosition> {
    var result: Set<GridPosition> = []
    add([4, 8, 12, 16], [4, 8, 12], to: &result)
    add([4, 8, 12, 16, 20, 24], [40, 44], to: &result)
    add([20, 24, 28, 32, 36, 40, 44], [28, 32], to: &result)
    add([40, 44], [8, 12, 16, 20, 24], to: &result)
    add([4, 8, 12, 16, 20, 24, 28], [52], to: &result)
    add([36, 40, 44, 48], [36], to: &result)
    add([24, 28, 32], [12], to: &result)
    add([20, 24], [4], to: &result)
    add([16], [16, 20], to: &result)
    add([52], [16, 20, 24], to: &result)
    add([48], [36, 40, 44], to: &result)
    add([32], [4], to: &result)
    add([48], [8], to: &result)
    add([4], [32, 36], to: &result)
    add([16], [32], to: &result)
    add([28], [40], to: &result)
    return result
  }

  private func add(_ rows: [Int], _ columns: [Int], to result: inout Set<GridPosition>) {
    for row in rows { for column in columns { result.insert(.init(row: row, column: column)) } }
  }
}
