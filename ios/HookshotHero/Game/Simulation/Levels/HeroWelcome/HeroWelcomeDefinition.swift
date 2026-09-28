import Foundation

enum HeroWelcomeDefinition {
  static let grid = GridSize(rows: 60, columns: 60)
  static let start = GridPosition(row: 50, column: 27)
  static let exitRegion = GridRegion(rows: 0..<4, columns: 27..<33)
  static let doorwayRegion = GridRegion(rows: 56..<60, columns: 27..<33)
  static let chestAnchors = [
    GridPosition(row: 5, column: 6), GridPosition(row: 5, column: 50),
    GridPosition(row: 50, column: 50),
  ]
  static let columnRegions = (0..<5).flatMap { index in
    let row = 10 + index * 10
    return [
      GridRegion(rows: row..<row + 5, columns: 24..<26),
      GridRegion(rows: row..<row + 5, columns: 35..<37),
    ]
  }

  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [
        .init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60),
      ],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ], leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: exitRegion, bottomDoorRegion: doorwayRegion)
    return .init(
      grid: grid, start: start, exitAnchor: .init(row: 0, column: 27),
      entryAnchor: .init(row: 56, column: 27), chestAnchor: chestAnchors[0], boundary: boundary,
      walls: boundary.wallRegions + columnRegions, lava: [], grappleLatchRegions: [doorwayRegion],
      internalWallAnchors: [],
      displayName: "Hero's Welcome")
  }
}
