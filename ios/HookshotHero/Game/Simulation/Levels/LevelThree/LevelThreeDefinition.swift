import Foundation

enum LevelThreeDefinition {
  static let internalWallAnchors =
    stride(from: 24, to: 48, by: 4).map { GridPosition(row: 12, column: $0) }
    + stride(from: 4, to: 12, by: 4).map { GridPosition(row: $0, column: 24) }
    + stride(from: 40, to: 56, by: 4).map { GridPosition(row: $0, column: 24) }
    + stride(from: 24, to: 48, by: 4).map { GridPosition(row: 40, column: $0) }
    + stride(from: 32, to: 56, by: 4).map { GridPosition(row: 24, column: $0) }
    + [
      GridPosition(row: 32, column: 4), GridPosition(row: 36, column: 4),
      GridPosition(row: 28, column: 32), GridPosition(row: 28, column: 4),
      GridPosition(row: 28, column: 8), GridPosition(row: 32, column: 32),
      GridPosition(row: 32, column: 28),
    ]
  static let lavaAnchors =
    stride(from: 4, to: 28, by: 4).flatMap { row in
      stride(from: 4, to: 22, by: 4).map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 32, to: 56, by: 4).flatMap { row in
      stride(from: 12, to: 22, by: 2).map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 40, through: 52, by: 4).map { GridPosition(row: $0, column: 4) }
    + stride(from: 28, through: 36, by: 4).flatMap { row in
      stride(from: 40, through: 48, by: 4).map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 32, through: 40, by: 4).map { GridPosition(row: $0, column: 52) }
    + stride(from: 40, through: 44, by: 4).map { GridPosition(row: $0, column: 8) }
    + stride(from: 8, through: 12, by: 4).flatMap { row in
      stride(from: 48, through: 54, by: 4).map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 12, to: 24, by: 4).map { GridPosition(row: 28, column: $0) }
    + [GridPosition(row: 40, column: 48)]
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ], leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    return .init(
      grid: .init(rows: 60, columns: 60), start: .init(row: 50, column: 27),
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: 52, column: 8), boundary: boundary,
      walls: boundary.wallRegions
        + internalWallAnchors.map {
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
        },
      lava: lavaAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }, internalWallAnchors: internalWallAnchors, displayName: "Level 3")
  }
}
