import Foundation

enum LevelEightDefinition {
  static let lavaAnchors: [GridPosition] = {
    var javaAnchors =
      [8, 12].flatMap { row in [24, 28, 32].map { GridPosition(row: row, column: $0) } }
      + [24, 28, 32].flatMap { row in
        [20, 24].map { GridPosition(row: row, column: $0) }
      }
      + [32, 36, 40].flatMap { row in
        [44, 48].map { GridPosition(row: row, column: $0) }
      }
      + [40, 44, 48].flatMap { row in
        [48, 52].map { GridPosition(row: row, column: $0) }
      }

    // Java says `for (int y = 4000; y < 520; ...)`; its body never executes. This is
    // preserved as executable behavior rather than guessing that the author meant 400.
    let deadJavaLoopAnchors: [GridPosition] = []
    javaAnchors += deadJavaLoopAnchors
    javaAnchors += [20, 24, 28].map { .init(row: $0, column: 36) }
    javaAnchors += [16, 20, 24].map { .init(row: 48, column: $0) }
    javaAnchors += [12, 16, 20].map { .init(row: 20, column: $0) }
    javaAnchors += [
      .init(row: 32, column: 40),  // Java (400, 320)
      .init(row: 52, column: 40),  // Java (400, 520)
      .init(row: 36, column: 12),  // Java (120, 360)
    ]

    var seen: Set<GridPosition> = []
    return javaAnchors.filter { seen.insert($0).inserted }
  }()

  static let wallAnchors: [GridPosition] = {
    var javaAnchors =
      [4, 8, 12, 16].flatMap { row in
        [4, 8, 12].map { GridPosition(row: row, column: $0) }
      }
      + [4, 8, 12, 16, 20, 24].flatMap { row in
        [40, 44].map { GridPosition(row: row, column: $0) }
      }
      + [20, 24, 28, 32, 36, 40, 44].flatMap { row in
        [28, 32].map { GridPosition(row: row, column: $0) }
      }
      + [40, 44].flatMap { row in
        [8, 12, 16, 20, 24].map { GridPosition(row: row, column: $0) }
      }
    javaAnchors += [4, 8, 12, 16, 20, 24, 28].map { .init(row: $0, column: 52) }
    javaAnchors += [36, 40, 44, 48].map { .init(row: $0, column: 36) }
    javaAnchors += [24, 28, 32].map { .init(row: $0, column: 12) }
    javaAnchors += [20, 24].map { .init(row: $0, column: 4) }
    javaAnchors += [16, 20].map { .init(row: 16, column: $0) }
    javaAnchors += [16, 20, 24].map { .init(row: 52, column: $0) }
    javaAnchors += [36, 40, 44].map { .init(row: 48, column: $0) }
    javaAnchors += [
      .init(row: 32, column: 4), .init(row: 48, column: 8),
      .init(row: 4, column: 32), .init(row: 4, column: 36),
      .init(row: 16, column: 32), .init(row: 28, column: 40),
    ]
    var seen: Set<GridPosition> = []
    return javaAnchors.filter { seen.insert($0).inserted }
  }()

  static let topDoorRegion = GridRegion(rows: 0..<4, columns: 48..<54)
  static let leftDoorRegion = GridRegion(rows: 27..<33, columns: 0..<4)
  static let bottomDoorRegion = GridRegion(rows: 56..<60, columns: 27..<33)

  static let fromLevelSevenStart = GridPosition(row: 50, column: 27)
  // Java's (27, 5) intersects the wall tile at (24, 4) under the native 3x3 player
  // footprint. (29, 5) is the nearest doorway-aligned position with a complete safe footprint.
  static let fromLevelSixStart = GridPosition(row: 29, column: 5)
  static let topReturnStart = GridPosition(row: 5, column: 23)

  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [
        .init(rows: 0..<4, columns: 0..<48), .init(rows: 0..<4, columns: 54..<60),
      ],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ],
      leftWallRegions: [
        .init(rows: 4..<27, columns: 0..<4), .init(rows: 33..<56, columns: 0..<4),
      ],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: topDoorRegion, bottomDoorRegion: bottomDoorRegion)
    return .init(
      grid: .init(rows: 60, columns: 60), start: fromLevelSevenStart,
      exitAnchor: .init(row: 0, column: 50), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: -100, column: -100), boundary: boundary,
      walls: boundary.wallRegions
        + wallAnchors.map {
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
        },
      lava: lavaAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }, internalWallAnchors: wallAnchors, displayName: "Level 8")
  }
}
