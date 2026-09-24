import Foundation

enum LevelNineDefinition {
  static let lavaAnchors: [GridPosition] = {
    var anchors = [40, 44].flatMap { row in [8, 12, 16].map { GridPosition(row: row, column: $0) } }
    anchors += [20, 24].flatMap { row in [12, 16].map { GridPosition(row: row, column: $0) } }
    anchors += [8, 12, 16].map { .init(row: $0, column: 20) }
    anchors += [36, 40, 44].map { .init(row: $0, column: 28) }
    anchors += [40, 44, 48].map { .init(row: $0, column: 52) }
    anchors += [12].flatMap { row in [12, 16].map { GridPosition(row: row, column: $0) } }
    anchors += [8].flatMap { row in [24, 28].map { GridPosition(row: row, column: $0) } }
    anchors += [24].flatMap { row in [24, 28, 32].map { GridPosition(row: row, column: $0) } }
    anchors += [20].flatMap { row in [40, 44, 48].map { GridPosition(row: row, column: $0) } }
    anchors += [16].flatMap { row in [32, 36, 40].map { GridPosition(row: row, column: $0) } }
    anchors += [32].flatMap { row in [36, 40, 44].map { GridPosition(row: row, column: $0) } }
    anchors += [48].flatMap { row in [20, 24].map { GridPosition(row: row, column: $0) } }
    anchors += [44].flatMap { row in [32, 36].map { GridPosition(row: row, column: $0) } }
    anchors += [52].flatMap { row in [40, 44, 48].map { GridPosition(row: row, column: $0) } }
    anchors += [
      .init(row: 20, column: 8), .init(row: 48, column: 8), .init(row: 36, column: 16),
      .init(row: 48, column: 36), .init(row: 40, column: 40),
    ]
    var seen: Set<GridPosition> = []
    return anchors.filter { seen.insert($0).inserted }
  }()

  static let wallAnchors: [GridPosition] = {
    var anchors = [4, 8, 12, 16].flatMap { row in
      [48, 52].map { GridPosition(row: row, column: $0) }
    }
    anchors += [32, 36].flatMap { row in [20, 24].map { GridPosition(row: row, column: $0) } }
    anchors += [28].flatMap { row in
      stride(from: 8, to: 56, by: 4).map { GridPosition(row: row, column: $0) }
    }
    anchors += [4].flatMap { row in [4, 8, 12].map { GridPosition(row: row, column: $0) } }
    anchors += [16].flatMap { row in [4, 8, 12, 16].map { GridPosition(row: row, column: $0) } }
    anchors += [4].flatMap { row in [24, 28].map { GridPosition(row: row, column: $0) } }
    anchors += [20].flatMap { row in [24, 28, 32].map { GridPosition(row: row, column: $0) } }
    anchors += [36].flatMap { row in [8, 12].map { GridPosition(row: row, column: $0) } }
    anchors += [52].flatMap { row in [20, 24].map { GridPosition(row: row, column: $0) } }
    anchors += [48].flatMap { row in [40, 44, 48].map { GridPosition(row: row, column: $0) } }
    anchors += [36].flatMap { row in [32, 36, 40, 44].map { GridPosition(row: row, column: $0) } }
    anchors += [44, 48].map { .init(row: $0, column: 4) }
    anchors += [48, 52].map { .init(row: $0, column: 32) }
    anchors += [40, 44, 48].map { .init(row: $0, column: 48) }
    anchors += [
      .init(row: 12, column: 4), .init(row: 8, column: 12), .init(row: 24, column: 8),
      .init(row: 32, column: 8), .init(row: 48, column: 12), .init(row: 44, column: 20),
      .init(row: 40, column: 32), .init(row: 32, column: 52), .init(row: 24, column: 40),
      .init(row: 16, column: 24), .init(row: 12, column: 32), .init(row: 4, column: 44),
      .init(row: 8, column: 44), .init(row: 32, column: 12), .init(row: 32, column: 16),
      .init(row: 8, column: 36), .init(row: 12, column: 36),
    ]
    var seen: Set<GridPosition> = []
    return anchors.filter { seen.insert($0).inserted }
  }()

  static let forwardDoorRegion = GridRegion(rows: 7..<14, columns: 0..<4)
  static let bottomDoorRegion = GridRegion(rows: 56..<60, columns: 27..<33)
  static let bottomStart = GridPosition(row: 50, column: 27)
  static let chestAnchor = GridPosition(row: 52, column: 4)

  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<60)],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ],
      leftWallRegions: [.init(rows: 4..<7, columns: 0..<4), .init(rows: 14..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: forwardDoorRegion, bottomDoorRegion: bottomDoorRegion)
    return .init(
      grid: .init(rows: 60, columns: 60), start: bottomStart,
      exitAnchor: .init(row: 7, column: 1), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: chestAnchor, boundary: boundary,
      walls: boundary.wallRegions
        + wallAnchors.map { .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4) },
      lava: lavaAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      },
      internalWallAnchors: wallAnchors, displayName: "Level 9")
  }
}
