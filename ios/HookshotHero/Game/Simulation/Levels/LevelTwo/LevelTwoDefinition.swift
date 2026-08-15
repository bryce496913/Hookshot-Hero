import Foundation

enum LevelTwoDefinition {
  static let internalWallAnchors =
    [4, 8, 12, 16, 20, 24, 28, 32, 36, 40].map { GridPosition(row: 16, column: $0) }
    + [8, 12].map { GridPosition(row: 24, column: $0) }
    + [20, 24].flatMap { r in [36, 40].map { GridPosition(row: r, column: $0) } }
  static let lavaAnchors =
    [32, 36, 40].flatMap { r in
      stride(from: 4, through: 52, by: 4).map { GridPosition(row: r, column: $0) }
    }
    + [44, 48, 52].flatMap { r in [36, 40, 44, 48, 52].map { GridPosition(row: r, column: $0) } }
    + [20, 24, 28].flatMap { r in [20, 24, 28].map { GridPosition(row: r, column: $0) } }
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ], leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    let walls =
      boundary.wallRegions
      + internalWallAnchors.map {
        GridRegion(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }
    let lava = lavaAnchors.map {
      GridRegion(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
    }
    return .init(
      grid: .init(rows: 60, columns: 60), start: .init(row: 50, column: 27),
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: -100, column: -100), boundary: boundary, walls: walls, lava: lava,
      internalWallAnchors: internalWallAnchors, displayName: "Level 2")
  }
}
