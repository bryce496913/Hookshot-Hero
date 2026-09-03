import Foundation

enum LevelEightRenderAssets {
  // Level Eight reuses the already tracked grey-environment and smoke resources.
  static let floor = LevelSevenRenderAssets.floor
  static let lava = LevelSevenRenderAssets.lava
  static let wallFront = LevelSevenRenderAssets.wallFront
  static let wallLeft = LevelSevenRenderAssets.wallLeft
  static let wallRight = LevelSevenRenderAssets.wallRight
  static let exitDoor = LevelSevenRenderAssets.exitDoor
  static let bottomDoor = LevelSevenRenderAssets.entryDoor
  static let leftDoor = LevelFiveRenderAssets.entryDoor
  static let smoke = LevelSevenRenderAssets.smoke
}

extension LevelAssetManifest {
  static let levelEight = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelEightRenderAssets.floor, LevelEightRenderAssets.lava, LevelEightRenderAssets.wallFront,
      LevelEightRenderAssets.wallLeft, LevelEightRenderAssets.wallRight,
      LevelEightRenderAssets.exitDoor, LevelEightRenderAssets.bottomDoor,
      LevelEightRenderAssets.leftDoor, LevelEightRenderAssets.smoke, LevelOneRenderAssets.mine,
      LevelOneRenderAssets.cabbage,
    ]).union(sharedPlayerTextureAssetIDs).union(sharedCoinTextureAssetIDs).union(
      sharedEnemyTextureAssetIDs),
    animationIDs: LevelAssetManifest.levelSeven.animationIDs)
}

enum LevelEightPresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ region: GridRegion, _ asset: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: region.rows.lowerBound, column: region.columns.lowerBound),
        sizeInCells: .init(width: Double(region.columns.count), height: Double(region.rows.count)),
        asset: asset, anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: level.grid.rows, by: 10).flatMap { row in
      stride(from: 0, to: level.grid.columns, by: 10).map { column in
        tile(
          .init(
            rows: row..<min(row + 10, level.grid.rows),
            columns: column..<min(column + 10, level.grid.columns)),
          LevelEightRenderAssets.floor)
      }
    }
    let walls = level.walls.map {
      tile(
        $0,
        $0.columns == 0..<4
          ? LevelEightRenderAssets.wallLeft
          : ($0.columns == 56..<60
            ? LevelEightRenderAssets.wallRight : LevelEightRenderAssets.wallFront))
    }
    return .init(
      levelID: .levelEight, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelEightRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelEightRenderAssets.exitDoor,
          coordinate: .init(row: 0, column: 48), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelEightRenderAssets.leftDoor,
          coordinate: .init(row: 28, column: 0), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelEightRenderAssets.bottomDoor,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelEightRenderAssets.smoke,
          coordinate: .init(row: 9, column: 25), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
        .init(
          id: EntityID(), asset: LevelEightRenderAssets.smoke,
          coordinate: .init(row: 51, column: 50), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
      ])
  }
}
