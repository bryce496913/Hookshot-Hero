import Foundation

enum LevelTwoRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-two.floor"),
    lava = RenderAssetID(rawValue: "level-two.lava"),
    wallFront = RenderAssetID(rawValue: "level-two.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-two.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-two.wall.right"),
    exitDoor = RenderAssetID(rawValue: "level-two.door.open"),
    entryDoor = RenderAssetID(rawValue: "level-two.door.closed"),
    smoke = RenderAssetID(rawValue: "level-two.smoke")
}
enum LevelTwoRenderAnimations {
  static func enemy(_ a: EnemyArchetype, _ d: RenderOrientation) -> RenderAnimationID {
    if a == .minotaur {
      let row =
        switch d {
        case .down: 0
        case .left: 1
        case .right: 2
        case .up: 3
        case .none: 0
        }
      return .init(rawValue: "enemy.minotaur.\(row)-0")
    }
    return .init(
      rawValue: "enemy.\(a == .skeleton ? "skeleton" : "flying-terror").walk.\(d.rawValue)")
  }
}

enum LevelTwoPresentationDefinition {
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
          LevelTwoRenderAssets.floor)
      }
    }

    // Java LevelTwo renders the basic environment before drawing doors, so the top and bottom
    // wall rows stay visually continuous and the grey door sprites are placed at x=280 (column 28).
    // Keep gameplay collision regions in LevelTwoDefinition unchanged while matching that Java layout.
    let javaBoundaryWalls = [
      GridRegion(rows: 0..<4, columns: 0..<60),
      GridRegion(rows: 56..<60, columns: 0..<60),
      GridRegion(rows: 4..<56, columns: 0..<4),
      GridRegion(rows: 4..<56, columns: 56..<60),
    ]
    let walls =
      javaBoundaryWalls.map { region in
        tile(
          region,
          region.columns == 0..<4
            ? LevelTwoRenderAssets.wallLeft
            : (region.columns == 56..<60
              ? LevelTwoRenderAssets.wallRight : LevelTwoRenderAssets.wallFront))
      }
      + level.internalWallAnchors.map {
        tile(
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4),
          LevelTwoRenderAssets.wallFront)
      }

    return .init(
      levelID: .levelTwo, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelTwoRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelTwoRenderAssets.exitDoor,
          coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelTwoRenderAssets.entryDoor,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelTwoRenderAssets.smoke,
          coordinate: .init(row: 39, column: 5),
          renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
        .init(
          id: EntityID(), asset: LevelTwoRenderAssets.smoke,
          coordinate: .init(row: 55, column: 50),
          renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
      ])
  }
}
