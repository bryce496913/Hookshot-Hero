import Foundation

enum LevelFiveRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-five.floor"),
    lava = RenderAssetID(rawValue: "level-five.lava"),
    wallFront = RenderAssetID(rawValue: "level-five.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-five.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-five.wall.right"),
    exitDoor = RenderAssetID(rawValue: "level-five.door.open"),
    entryDoor = RenderAssetID(rawValue: "level-five.door.closed.left"),
    chest = RenderAssetID(rawValue: "level-five.chest.side"),
    smoke = RenderAssetID(rawValue: "level-five.smoke")
}
extension LevelAssetManifest {
  static let levelFive = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelFiveRenderAssets.floor, LevelFiveRenderAssets.lava, LevelFiveRenderAssets.wallFront,
      LevelFiveRenderAssets.wallLeft, LevelFiveRenderAssets.wallRight,
      LevelFiveRenderAssets.exitDoor, LevelFiveRenderAssets.entryDoor, LevelFiveRenderAssets.smoke,
      LevelFiveRenderAssets.chest, LevelOneRenderAssets.mine, LevelOneRenderAssets.cabbage,
    ]).union(sharedPlayerTextureAssetIDs).union(sharedCoinTextureAssetIDs).union(
      sharedEnemyTextureAssetIDs),
    animationIDs: Set([
      LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up),
      LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left),
      LevelOneRenderAnimations.lidiaWalk(.right), LevelTwoRenderAnimations.enemy(.skeleton, .up),
      LevelTwoRenderAnimations.enemy(.skeleton, .down),
      LevelTwoRenderAnimations.enemy(.skeleton, .left),
      LevelTwoRenderAnimations.enemy(.skeleton, .right),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .up),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .down),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .left),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .right),
    ]))
}

enum LevelFivePresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ r: GridRegion, _ a: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: r.rows.lowerBound, column: r.columns.lowerBound),
        sizeInCells: .init(width: Double(r.columns.count), height: Double(r.rows.count)), asset: a,
        anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: 60, by: 10).flatMap { row in
      stride(from: 0, to: 60, by: 10).map { col in
        tile(
          .init(rows: row..<min(row + 10, 60), columns: col..<min(col + 10, 60)),
          LevelFiveRenderAssets.floor)
      }
    }
    return .init(
      levelID: .levelFive, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelFiveRenderAssets.lava) }),
        .init(
          id: .init(rawValue: "walls"), zPosition: 2,
          tiles: level.walls.map {
            tile(
              $0,
              $0.columns == 0..<4
                ? LevelFiveRenderAssets.wallLeft
                : ($0.columns == 56..<60
                  ? LevelFiveRenderAssets.wallRight : LevelFiveRenderAssets.wallFront))
          }),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelFiveRenderAssets.exitDoor,
          coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelFiveRenderAssets.entryDoor,
          coordinate: .init(row: 8, column: 0), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelFiveRenderAssets.smoke,
          coordinate: .init(row: 55, column: 16), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
        .init(
          id: EntityID(), asset: LevelFiveRenderAssets.smoke,
          coordinate: .init(row: 26, column: 43), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
      ])
  }
}
