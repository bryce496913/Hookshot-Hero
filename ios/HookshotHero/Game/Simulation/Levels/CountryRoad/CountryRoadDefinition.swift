import Foundation

enum CountryRoadDefinition {
  static let grid = GridSize(rows: 60, columns: 60)
  static let start = GridPosition(row: 50, column: 27)
  static let exitRegion = GridRegion(rows: 0..<4, columns: 26..<34)
  static let doorwayRegion = GridRegion(rows: 56..<60, columns: 27..<33)

  // Java records one 10x10 collision cell for every AddWallCell call. Preserve those cells,
  // while native perimeter strips close the gaps left by the Java sprite/collision mismatch.
  static let sceneryWalls: [GridRegion] = [
    .init(rows: 35..<36, columns: 0..<1), .init(rows: 35..<36, columns: 4..<5),
    .init(rows: 39..<40, columns: 0..<1), .init(rows: 39..<40, columns: 4..<5),
    .init(rows: 35..<36, columns: 7..<8), .init(rows: 35..<36, columns: 11..<12),
    .init(rows: 39..<40, columns: 7..<8), .init(rows: 39..<40, columns: 11..<12),
    .init(rows: 35..<36, columns: 14..<15), .init(rows: 35..<36, columns: 18..<19),
    .init(rows: 39..<40, columns: 14..<15), .init(rows: 39..<40, columns: 18..<19),
    .init(rows: 2..<3, columns: 45..<46), .init(rows: 2..<3, columns: 49..<50),
    .init(rows: 2..<3, columns: 53..<54), .init(rows: 6..<7, columns: 45..<46),
    .init(rows: 6..<7, columns: 49..<50), .init(rows: 6..<7, columns: 53..<54),
    .init(rows: 10..<11, columns: 10..<11), .init(rows: 10..<11, columns: 15..<16),
    .init(rows: 10..<11, columns: 19..<20), .init(rows: 20..<21, columns: 10..<11),
    .init(rows: 20..<21, columns: 15..<16), .init(rows: 20..<21, columns: 19..<20),
    .init(rows: 15..<16, columns: 45..<46), .init(rows: 15..<16, columns: 50..<51),
    .init(rows: 22..<23, columns: 39..<40), .init(rows: 27..<28, columns: 45..<46),
  ]

  static let population = (children: 9, old: 5, townfolk: 15)

  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<26), .init(rows: 0..<4, columns: 34..<60)],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ],
      leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)], topExitRegion: exitRegion,
      bottomDoorRegion: doorwayRegion)
    return .init(
      grid: grid, start: start, exitAnchor: .init(row: 0, column: 27),
      entryAnchor: .init(row: 56, column: 27), chestAnchor: .init(row: 52, column: 52),
      boundary: boundary,
      walls: boundary.wallRegions + sceneryWalls, lava: [], grappleLatchRegions: [doorwayRegion],
      internalWallAnchors: [],
      displayName: "Country Road")
  }
}
