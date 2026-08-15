import Foundation

enum LevelOneDefinition {
  static let levelOneGrid = GridSize(rows: 60, columns: 60)
  static let boundaryTileSize = 4
  static let boundary = LevelBoundaryGeometry(
    topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
    bottomWallRegions: [.init(rows: 56..<60, columns: 0..<60)],
    leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
    rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
    topExitRegion: .init(rows: 0..<4, columns: 27..<33),
    bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
  static let topDoorColumns = boundary.topExitRegion.columns
  static func make() -> LevelDefinition {
    let anchors = [20, 24, 28, 32, 36].map { GridPosition(row: 16, column: $0) }
    let internalWalls = anchors.map {
      GridRegion(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
    }
    let lava = [24, 28, 32].flatMap { row in
      stride(from: 4, through: 52, by: 4).map {
        GridRegion(rows: row..<row + 4, columns: $0..<$0 + 4)
      }
    }
    return .init(
      grid: levelOneGrid, start: .init(row: 50, column: 27), exitAnchor: .init(row: 0, column: 27),
      entryAnchor: .init(row: 56, column: 27), chestAnchor: .init(row: 44, column: 29),
      boundary: boundary, walls: boundary.wallRegions + internalWalls, lava: lava,
      internalWallAnchors: anchors, displayName: "Level 1")
  }
}
