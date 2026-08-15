import Foundation

enum LevelOneRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-one.floor"),
    lava = RenderAssetID(rawValue: "level-one.lava")
  static let wallFront = RenderAssetID(rawValue: "level-one.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-one.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-one.wall.right")
  static let exitDoor = RenderAssetID(rawValue: "level-one.door.open"),
    entryDoor = RenderAssetID(rawValue: "level-one.door.closed")
  static let lidia = RenderAssetID(rawValue: "character.lidia"),
    coin = RenderAssetID(rawValue: "level-one.coin"),
    cabbage = RenderAssetID(rawValue: "level-one.cabbage"),
    mine = RenderAssetID(rawValue: "level-one.mine")
  static let chestClosed = RenderAssetID(rawValue: "level-one.chest.closed"),
    chestOpen = RenderAssetID(rawValue: "level-one.chest.open")
}
enum LevelOneRenderAnimations {
  static func lidiaWalk(_ orientation: RenderOrientation) -> RenderAnimationID {
    RenderAnimationID(rawValue: "character.lidia.walk.\(orientation.rawValue)")
  }
  static let coinSpin = RenderAnimationID(rawValue: "level-one.coin.spin")
}

enum LevelOnePresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ region: GridRegion, _ asset: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: region.rows.lowerBound, column: region.columns.lowerBound),
        sizeInCells: .init(width: Double(region.columns.count), height: Double(region.rows.count)),
        asset: asset, anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: level.grid.rows, by: 10).flatMap { row in
      stride(from: 0, to: level.grid.columns, by: 10).map { col in
        tile(
          .init(
            rows: row..<min(row + 10, level.grid.rows),
            columns: col..<min(col + 10, level.grid.columns)), LevelOneRenderAssets.floor)
      }
    }
    let walls =
      level.boundary.topWallRegions.map { tile($0, LevelOneRenderAssets.wallFront) }
      + level.boundary.bottomWallRegions.map { tile($0, LevelOneRenderAssets.wallFront) }
      + level.boundary.leftWallRegions.map { tile($0, LevelOneRenderAssets.wallLeft) }
      + level.boundary.rightWallRegions.map { tile($0, LevelOneRenderAssets.wallRight) }
      + level.internalWallAnchors.map {
        tile(
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4),
          LevelOneRenderAssets.wallFront)
      }
    return .init(
      levelID: .levelOne, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelOneRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelOneRenderAssets.exitDoor,
          coordinate: .init(
            row: level.exitRegion.rows.lowerBound, column: level.exitRegion.columns.lowerBound),
          renderSize: .init(
            width: Double(level.exitRegion.columns.count),
            height: Double(level.exitRegion.rows.count)), anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelOneRenderAssets.entryDoor,
          coordinate: .init(
            row: level.entryRegion.rows.lowerBound, column: level.entryRegion.columns.lowerBound),
          renderSize: .init(
            width: Double(level.entryRegion.columns.count),
            height: Double(level.entryRegion.rows.count)), anchor: .bottomLeft, zPosition: 3),
      ])
  }
}
