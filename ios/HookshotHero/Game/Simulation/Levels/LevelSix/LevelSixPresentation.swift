import Foundation

enum LevelSixRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-six.floor")
  static let lava = RenderAssetID(rawValue: "level-six.lava")
  static let wallFront = RenderAssetID(rawValue: "level-six.wall.front")
  static let wallLeft = RenderAssetID(rawValue: "level-six.wall.left")
  static let wallRight = RenderAssetID(rawValue: "level-six.wall.right")
  static let exitDoor = RenderAssetID(rawValue: "level-six.door.open")
  static let entryDoor = RenderAssetID(rawValue: "level-six.door.closed")
  static let chestSide = RenderAssetID(rawValue: "level-six.chest.side")
  static let chestFront = RenderAssetID(rawValue: "level-six.chest.front")
  static let smoke = RenderAssetID(rawValue: "level-six.smoke")
}

extension LevelAssetManifest {
  static let levelSix = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelSixRenderAssets.floor, LevelSixRenderAssets.lava, LevelSixRenderAssets.wallFront,
      LevelSixRenderAssets.wallLeft, LevelSixRenderAssets.wallRight, LevelSixRenderAssets.exitDoor,
      LevelSixRenderAssets.entryDoor, LevelSixRenderAssets.chestSide,
      LevelSixRenderAssets.chestFront, LevelSixRenderAssets.smoke, LevelOneRenderAssets.mine,
      LevelOneRenderAssets.cabbage,
    ]).union(sharedPlayerTextureAssetIDs).union(sharedCoinTextureAssetIDs).union(
      sharedEnemyTextureAssetIDs),
    animationIDs: LevelAssetManifest.levelFive.animationIDs)
}

enum LevelSixPresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ region: GridRegion, _ asset: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: region.rows.lowerBound, column: region.columns.lowerBound),
        sizeInCells: .init(width: Double(region.columns.count), height: Double(region.rows.count)),
        asset: asset, anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: 60, by: 10).flatMap { row in
      stride(from: 0, to: 60, by: 10).map { column in
        tile(.init(rows: row..<min(row + 10, 60), columns: column..<min(column + 10, 60)), LevelSixRenderAssets.floor)
      }
    }
    let walls = level.walls.map {
      tile($0, $0.columns == 0..<4 ? LevelSixRenderAssets.wallLeft : ($0.columns == 56..<60 ? LevelSixRenderAssets.wallRight : LevelSixRenderAssets.wallFront))
    }
    return .init(
      levelID: .levelSix, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(id: .init(rawValue: "lava"), zPosition: 1, tiles: level.lava.map { tile($0, LevelSixRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ], staticObjects: [
        .init(id: EntityID(), asset: LevelSixRenderAssets.exitDoor, coordinate: .init(row: 0, column: 52), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 3),
        .init(id: EntityID(), asset: LevelSixRenderAssets.entryDoor, coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 3),
        .init(id: EntityID(), asset: LevelSixRenderAssets.smoke, coordinate: .init(row: 13, column: 21), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
        .init(id: EntityID(), asset: LevelSixRenderAssets.smoke, coordinate: .init(row: 39, column: 53), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
      ])
  }
}
