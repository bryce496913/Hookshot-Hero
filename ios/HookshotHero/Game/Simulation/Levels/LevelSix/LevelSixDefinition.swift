import Foundation

enum LevelSixDefinition {
  static let lavaAnchors: [GridPosition] =
    [8, 12, 16].map { .init(row: 4, column: $0) }
    + [8, 12, 16].flatMap { row in [20, 24, 28].map { .init(row: row, column: $0) } }
    + [20, 24, 28].flatMap { row in [40, 44, 48].map { .init(row: row, column: $0) } }
    + [40, 44, 48].flatMap { row in [20, 24, 28].map { .init(row: row, column: $0) } }
    + [24, 28].map { .init(row: $0, column: 52) }
    + [20, 24].map { .init(row: $0, column: 4) }
    + [32, 36, 40].map { .init(row: $0, column: 8) }
    + [40, 44, 48].map { .init(row: $0, column: 12) }
    + [40, 44].map { .init(row: $0, column: 4) }
    + [16, 20, 24].map { .init(row: 52, column: $0) }
    + [32, 36, 40, 48].map { .init(row: 32, column: $0) }
  static let wallAnchors: [GridPosition] =
    [20, 24].flatMap { row in [8, 12, 16].map { .init(row: row, column: $0) } }
    + [36, 40, 44, 48].flatMap { row in [40, 44, 48].map { .init(row: row, column: $0) } }
    + [4, 8, 12, 16].map { .init(row: 12, column: $0) }
    + [20, 24, 28].map { .init(row: 32, column: $0) }
    + [28, 32, 36].map { .init(row: 24, column: $0) }
    + [4, 8].map { .init(row: 52, column: $0) }
    + [28, 32, 36, 40, 44, 48].map { .init(row: $0, column: 16) }
    + [40, 44, 48, 52].map { .init(row: $0, column: 32) }
    + [8, 12, 16].map { .init(row: $0, column: 36) }
    + [4, 8, 12, 16].map { .init(row: $0, column: 48) }
    + [
      .init(row: 4, column: 28), .init(row: 12, column: 32),
      .init(row: 20, column: 28), .init(row: 32, column: 4),
      .init(row: 28, column: 12), .init(row: 32, column: 12),
      .init(row: 24, column: 24),
    ]
  static let bottomStart = GridPosition(row: 50, column: 27)
  static let topStart = GridPosition(row: 5, column: 53)
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<51), .init(rows: 0..<4, columns: 57..<60)],
      bottomWallRegions: [.init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60)],
      leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 51..<57),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    return .init(
      grid: .init(rows: 60, columns: 60), start: bottomStart,
      exitAnchor: .init(row: 0, column: 51), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: 4, column: 24), boundary: boundary,
      walls: boundary.wallRegions + wallAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }, lava: lavaAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }, internalWallAnchors: wallAnchors, displayName: "Level 6")
  }
}
