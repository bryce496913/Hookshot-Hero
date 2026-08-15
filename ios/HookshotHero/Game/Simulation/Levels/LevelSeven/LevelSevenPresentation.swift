import Foundation

enum LevelSevenRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-seven.floor")
  static let lava = RenderAssetID(rawValue: "level-seven.lava")
  static let wallFront = RenderAssetID(rawValue: "level-seven.wall.front")
  static let wallLeft = RenderAssetID(rawValue: "level-seven.wall.left")
  static let wallRight = RenderAssetID(rawValue: "level-seven.wall.right")
  static let exitDoor = RenderAssetID(rawValue: "level-seven.door.open")
  static let entryDoor = RenderAssetID(rawValue: "level-seven.door.closed")
  static let chestSide = RenderAssetID(rawValue: "level-seven.chest.side")
  static let chestBack = RenderAssetID(rawValue: "level-seven.chest.back")
  static let smoke = RenderAssetID(rawValue: "level-seven.smoke")
}

extension LevelAssetManifest {
  static let levelSeven = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelSevenRenderAssets.floor, LevelSevenRenderAssets.lava, LevelSevenRenderAssets.wallFront,
      LevelSevenRenderAssets.wallLeft, LevelSevenRenderAssets.wallRight,
      LevelSevenRenderAssets.exitDoor, LevelSevenRenderAssets.entryDoor,
      LevelSevenRenderAssets.chestSide, LevelSevenRenderAssets.chestBack,
      LevelSevenRenderAssets.smoke, LevelOneRenderAssets.mine, LevelOneRenderAssets.cabbage,
    ]).union(sharedPlayerTextureAssetIDs).union(sharedCoinTextureAssetIDs).union(
      sharedEnemyTextureAssetIDs),
    animationIDs: LevelAssetManifest.levelFive.animationIDs)
}

enum LevelSevenPresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ region: GridRegion, _ asset: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: region.rows.lowerBound, column: region.columns.lowerBound),
        sizeInCells: .init(width: Double(region.columns.count), height: Double(region.rows.count)),
        asset: asset, anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: 60, by: 10).flatMap { row in
      stride(from: 0, to: 60, by: 10).map { column in
        tile(
          .init(rows: row..<min(row + 10, 60), columns: column..<min(column + 10, 60)),
          LevelSevenRenderAssets.floor)
      }
    }
    let walls = level.walls.map {
      tile(
        $0,
        $0.columns == 0..<4
          ? LevelSevenRenderAssets.wallLeft
          : ($0.columns == 56..<60
            ? LevelSevenRenderAssets.wallRight : LevelSevenRenderAssets.wallFront))
    }
    return .init(
      levelID: .levelSeven, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelSevenRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelSevenRenderAssets.exitDoor,
          coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelSevenRenderAssets.entryDoor,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelSevenRenderAssets.smoke,
          coordinate: .init(row: 19, column: 55), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
        .init(
          id: EntityID(), asset: LevelSevenRenderAssets.smoke,
          coordinate: .init(row: 20, column: 5), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
        .init(
          id: EntityID(), asset: LevelSevenRenderAssets.smoke,
          coordinate: .init(row: 43, column: 45), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
      ])
  }
}
