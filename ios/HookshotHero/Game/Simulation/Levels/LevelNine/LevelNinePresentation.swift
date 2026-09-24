import Foundation

enum LevelNineRenderAssets {
  static let floor = LevelSevenRenderAssets.floor
  static let lava = LevelSevenRenderAssets.lava
  static let wallFront = LevelSevenRenderAssets.wallFront
  static let wallLeft = LevelSevenRenderAssets.wallLeft
  static let wallRight = LevelSevenRenderAssets.wallRight
  static let forwardDoor = LevelFiveRenderAssets.entryDoor
  static let bottomDoor = LevelSevenRenderAssets.entryDoor
  static let chestSide = LevelSevenRenderAssets.chestSide
  static let smoke = LevelSevenRenderAssets.smoke
}

extension LevelAssetManifest {
  static let levelNine = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelNineRenderAssets.floor, LevelNineRenderAssets.lava, LevelNineRenderAssets.wallFront,
      LevelNineRenderAssets.wallLeft, LevelNineRenderAssets.wallRight,
      LevelNineRenderAssets.forwardDoor, LevelNineRenderAssets.bottomDoor,
      LevelNineRenderAssets.chestSide, LevelNineRenderAssets.smoke, LevelOneRenderAssets.mine,
      LevelOneRenderAssets.cabbage,
    ]).union(sharedPlayerTextureAssetIDs).union(sharedCoinTextureAssetIDs).union(
      sharedEnemyTextureAssetIDs),
    animationIDs: LevelAssetManifest.levelSeven.animationIDs)
}

enum LevelNinePresentationDefinition {
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
          LevelNineRenderAssets.floor)
      }
    }
    let walls = level.walls.map {
      tile(
        $0,
        $0.columns == 0..<4
          ? LevelNineRenderAssets.wallLeft
          : ($0.columns == 56..<60
            ? LevelNineRenderAssets.wallRight : LevelNineRenderAssets.wallFront))
    }
    return .init(
      levelID: .levelNine, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelNineRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelNineRenderAssets.forwardDoor,
          coordinate: .init(row: 8, column: 0), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelNineRenderAssets.bottomDoor,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelNineRenderAssets.smoke,
          coordinate: .init(row: 40, column: 13), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
        .init(
          id: EntityID(), asset: LevelNineRenderAssets.smoke, coordinate: .init(row: 9, column: 30),
          renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
      ])
  }
}
