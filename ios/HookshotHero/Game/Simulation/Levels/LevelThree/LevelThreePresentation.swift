import Foundation

enum LevelThreeRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-three.floor"),
    lava = RenderAssetID(rawValue: "level-three.lava"),
    wallFront = RenderAssetID(rawValue: "level-three.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-three.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-three.wall.right"),
    exitDoor = RenderAssetID(rawValue: "level-three.door.open"),
    entryDoor = RenderAssetID(rawValue: "level-three.door.closed"),
    smoke = RenderAssetID(rawValue: "level-three.smoke")
}
enum LevelThreeRenderAnimations {
  static let smokeLoop = RenderAnimationID(rawValue: "level-three.smoke.loop")
}

enum LevelThreePresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ r: GridRegion, _ a: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: r.rows.lowerBound, column: r.columns.lowerBound),
        sizeInCells: .init(width: Double(r.columns.count), height: Double(r.rows.count)), asset: a,
        anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: level.grid.rows, by: 10).flatMap { row in
      stride(from: 0, to: level.grid.columns, by: 10).map { col in
        tile(
          .init(
            rows: row..<min(row + 10, level.grid.rows),
            columns: col..<min(col + 10, level.grid.columns)), LevelThreeRenderAssets.floor)
      }
    }
    let javaBoundaryWalls = [
      GridRegion(rows: 0..<4, columns: 0..<60), .init(rows: 56..<60, columns: 0..<60),
      .init(rows: 4..<56, columns: 0..<4), .init(rows: 4..<56, columns: 56..<60),
    ]
    let walls =
      javaBoundaryWalls.map {
        tile(
          $0,
          $0.columns == 0..<4
            ? LevelThreeRenderAssets.wallLeft
            : ($0.columns == 56..<60
              ? LevelThreeRenderAssets.wallRight : LevelThreeRenderAssets.wallFront))
      }
      + level.internalWallAnchors.map {
        tile(
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4),
          LevelThreeRenderAssets.wallFront)
      }
    return .init(
      levelID: .levelThree, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelThreeRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.exitDoor,
          coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.entryDoor,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.smoke,
          coordinate: .init(row: 9, column: 5),
          renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4,
          animationID: LevelThreeRenderAnimations.smokeLoop),
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.smoke,
          coordinate: .init(row: 56, column: 20), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4, animationID: LevelThreeRenderAnimations.smokeLoop),
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.smoke,
          coordinate: .init(row: 42, column: 49), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4, animationID: LevelThreeRenderAnimations.smokeLoop),
      ])
  }
}
