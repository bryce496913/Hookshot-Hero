import Foundation

enum LevelFourDefinition {
  static let rightExitRegion = GridRegion(rows: 27..<33, columns: 56..<60)
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [.init(rows: 56..<60, columns: 0..<60)],
      leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [
        .init(rows: 4..<27, columns: 56..<60), .init(rows: 33..<56, columns: 56..<60),
      ],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    return .init(
      grid: .init(rows: 60, columns: 60), start: .init(row: 50, column: 27),
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: -100, column: -100), boundary: boundary, walls: boundary.wallRegions,
      lava: [], internalWallAnchors: [], displayName: "Level 4")
  }
}
