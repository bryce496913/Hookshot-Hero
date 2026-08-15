import Foundation

enum LevelSevenDefinition {
  static let lavaAnchors: [GridPosition] = {
    // Preserve Java source order while retaining one tile for repeated placements, including (400, 480).
    let javaDerivedPositions =
      [8].flatMap { row in [12, 16, 20].map { GridPosition(row: row, column: $0) } }
      + [16].flatMap { row in [12, 16, 20].map { GridPosition(row: row, column: $0) } }
      + [36].flatMap { row in [12, 16, 20].map { GridPosition(row: row, column: $0) } }
      + [40].flatMap { row in [40, 44].map { GridPosition(row: row, column: $0) } }
      + [52].flatMap { row in [32, 36, 40].map { GridPosition(row: row, column: $0) } }
      + [16].flatMap { row in [48, 52].map { GridPosition(row: row, column: $0) } }
      + [28, 32].map { GridPosition(row: $0, column: 48) }
      + [48, 52].map { GridPosition(row: $0, column: 8) }
      + [8, 12].flatMap { row in
        [32, 36, 40, 44, 48, 52].map { GridPosition(row: row, column: $0) }
      }
      + [20, 24, 28].flatMap { row in [4, 8].map { GridPosition(row: row, column: $0) } }
      + [32, 36, 40].flatMap { row in [40, 44].map { GridPosition(row: row, column: $0) } }
      + [
        .init(row: 48, column: 20), .init(row: 48, column: 16), .init(row: 12, column: 28),
        .init(row: 28, column: 44), .init(row: 48, column: 40),
        .init(row: 36, column: 48), .init(row: 40, column: 48),
        .init(row: 48, column: 40),  // duplicate Java draw
      ]

    var seen: Set<GridPosition> = []
    return javaDerivedPositions.filter { seen.insert($0).inserted }
  }()

  static let wallAnchors: [GridPosition] =
    [20, 24, 28, 32].flatMap { row in [12, 16, 20].map { .init(row: row, column: $0) } }
    + [48, 52].flatMap { row in [48, 52].map { .init(row: row, column: $0) } }
    + [40, 44, 48].flatMap { row in [20, 24, 28, 32].map { .init(row: row, column: $0) } }
    + [12, 16, 20, 24].map { .init(row: 4, column: $0) }
    + [4, 8, 12, 16, 20].map { .init(row: 12, column: $0) }
    + [28, 32, 36, 40, 44].map { .init(row: 16, column: $0) }
    + [36, 40, 44, 48, 52].map { .init(row: 24, column: $0) }
    + [4, 8, 12, 16].map { .init(row: 40, column: $0) }
    + [36, 40].map { .init(row: 48, column: $0) }
    + [48, 52].map { .init(row: 44, column: $0) }
    + [24, 28, 32, 36].map { .init(row: 32, column: $0) }
    + [48, 52].map { .init(row: $0, column: 12) }
    + [20, 24].map { .init(row: $0, column: 28) }
    + [
      .init(row: 8, column: 4), .init(row: 36, column: 4), .init(row: 28, column: 36),
      .init(row: 44, column: 36), .init(row: 8, column: 28),
    ]

  // Java's (50, 27) footprint intersects the row-48 wall block. Row 53 is the nearest
  // doorway-aligned position with a complete safe player footprint.
  static let bottomStart = GridPosition(row: 53, column: 27)
  // Java's (5, 23) footprint intersects the row-4 wall. Column 30 is the closest safe,
  // doorway-centered return position.
  static let topStart = GridPosition(row: 5, column: 30)

  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ],
      leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    return .init(
      grid: .init(rows: 60, columns: 60), start: bottomStart,
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: 4, column: 4), boundary: boundary,
      walls: boundary.wallRegions
        + wallAnchors.map { .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4) },
      lava: lavaAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      },
      internalWallAnchors: wallAnchors, displayName: "Level 7")
  }
}
