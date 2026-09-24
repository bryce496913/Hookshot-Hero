import Foundation

enum LevelTenDefinition {
  static let rightDoorRegion = GridRegion(rows: 27..<34, columns: 56..<60)
  // Java reports (27,27) as the exit while drawing a right-side door. Native keeps the
  // right door as the Level 9 entrance and renders the ending portal over this trigger.
  static let endingExitRegion = GridRegion(rows: 25..<32, columns: 25..<32)
  static let rightStart = GridPosition(row: 27, column: 50)
  static let bossStart = GridPosition(row: 25, column: 25)
  static let chestAnchor = GridPosition(row: 28, column: 29)

  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<60)],
      bottomWallRegions: [.init(rows: 56..<60, columns: 0..<60)],
      leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [
        .init(rows: 4..<27, columns: 56..<60), .init(rows: 34..<56, columns: 56..<60),
      ], topExitRegion: endingExitRegion, bottomDoorRegion: rightDoorRegion)
    return .init(
      grid: .init(rows: 60, columns: 60), start: rightStart,
      exitAnchor: .init(row: 27, column: 27), entryAnchor: .init(row: 27, column: 56),
      chestAnchor: chestAnchor, boundary: boundary, walls: boundary.wallRegions, lava: [],
      internalWallAnchors: [], displayName: "Level 10")
  }
}
