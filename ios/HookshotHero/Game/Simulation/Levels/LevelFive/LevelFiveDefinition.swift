import Foundation

enum LevelFiveDefinition {
  static let wallAnchors: [GridPosition] =
    stride(from: 32, to: 52, by: 4).map { .init(row: 12, column: $0) }
    + stride(from: 32, to: 44, by: 4).map { .init(row: 16, column: $0) }
    + stride(from: 8, to: 28, by: 4).map { .init(row: 16, column: $0) }
    + stride(from: 4, to: 28, by: 4).map { .init(row: 24, column: $0) }
    + stride(from: 12, to: 28, by: 4).map { .init(row: 32, column: $0) }
    + stride(from: 32, to: 56, by: 4).map { .init(row: $0, column: 32) }
    + stride(from: 20, to: 40, by: 4).flatMap { row in
      [44, 48].map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 8, to: 16, by: 4).map { .init(row: $0, column: 16) }
    + [
      .init(row: 8, column: 32), .init(row: 44, column: 52), .init(row: 52, column: 36),
      .init(row: 32, column: 36), .init(row: 36, column: 36), .init(row: 40, column: 28),
      .init(row: 32, column: 4), .init(row: 36, column: 4), .init(row: 52, column: 4),
      .init(row: 52, column: 28), .init(row: 8, column: 28),
    ]
  static let lavaAnchors: [GridPosition] =
    stride(from: 40, to: 52, by: 4).flatMap { row in
      stride(from: 4, to: 30, by: 4).map { .init(row: row, column: $0) }
    }
    + stride(from: 40, to: 52, by: 4).flatMap { row in
      stride(from: 40, to: 52, by: 4).map { .init(row: row, column: $0) }
    }
    + stride(from: 20, to: 32, by: 4).flatMap { row in
      stride(from: 32, to: 40, by: 4).map { .init(row: row, column: $0) }
    }
    + stride(from: 4, to: 12, by: 4).flatMap { row in
      stride(from: 40, to: 52, by: 4).map { .init(row: row, column: $0) }
    }
    + stride(from: 8, to: 20, by: 4).map { .init(row: 20, column: $0) }
    + stride(from: 24, to: 36, by: 4).map { .init(row: $0, column: 28) }
    + stride(from: 12, to: 24, by: 4).map { .init(row: 36, column: $0) }
    + stride(from: 12, to: 24, by: 4).map { .init(row: 52, column: $0) }
    + [
      .init(row: 4, column: 4), .init(row: 4, column: 8), .init(row: 8, column: 12),
      .init(row: 4, column: 24), .init(row: 8, column: 24), .init(row: 20, column: 40),
      .init(row: 24, column: 40),
    ]
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [.init(rows: 56..<60, columns: 0..<60)],
      leftWallRegions: [.init(rows: 4..<8, columns: 0..<4), .init(rows: 12..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 8..<12, columns: 0..<4))
    return .init(
      grid: .init(rows: 60, columns: 60), start: .init(row: 8, column: 7),
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 8, column: 0),
      chestAnchor: .init(row: 52, column: 4), boundary: boundary,
      walls: boundary.wallRegions
        + wallAnchors.map {
          .init(rows: $0.row..<($0.row + 4), columns: $0.column..<($0.column + 4))
        },
      lava: lavaAnchors.map {
        .init(rows: $0.row..<($0.row + 4), columns: $0.column..<($0.column + 4))
      },
      internalWallAnchors: wallAnchors, displayName: "Level 5")
  }
}
