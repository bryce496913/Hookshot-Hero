import Foundation

enum LevelFourRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-four.floor"),
    wallFront = RenderAssetID(rawValue: "level-four.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-four.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-four.wall.right"),
    doorOpen = RenderAssetID(rawValue: "level-four.door.open"),
    doorClosed = RenderAssetID(rawValue: "level-four.door.closed"),
    doorOpenSide = RenderAssetID(rawValue: "level-four.door.open.side"),
    doorClosedRight = RenderAssetID(rawValue: "level-four.door.closed.right")
}
enum LevelFourRenderAnimations {
  static func minotaur(_ d: RenderOrientation) -> RenderAnimationID {
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
}

extension LevelAssetManifest {
  static let levelFour = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelFourRenderAssets.floor, LevelFourRenderAssets.wallFront,
      LevelFourRenderAssets.wallLeft, LevelFourRenderAssets.wallRight,
      LevelFourRenderAssets.doorOpen, LevelFourRenderAssets.doorClosed,
      LevelFourRenderAssets.doorOpenSide, LevelFourRenderAssets.doorClosedRight,
      EnemyArchetype.minotaur.asset,
    ])
    .union(sharedPlayerTextureAssetIDs)
    .union(
      (0..<4).flatMap { row in
        (0..<3).map { RenderAssetID(rawValue: "enemy.minotaur.\(row)-\($0)") }
      }),
    animationIDs: Set([
      LevelOneRenderAnimations.lidiaWalk(.up), LevelOneRenderAnimations.lidiaWalk(.down),
      LevelOneRenderAnimations.lidiaWalk(.left), LevelOneRenderAnimations.lidiaWalk(.right),
      LevelTwoRenderAnimations.enemy(.minotaur, .up),
      LevelTwoRenderAnimations.enemy(.minotaur, .down),
      LevelTwoRenderAnimations.enemy(.minotaur, .left),
      LevelTwoRenderAnimations.enemy(.minotaur, .right),
    ]))
}

extension LevelTwoRenderAnimations {
  static func minotaur(_ d: RenderOrientation) -> RenderAnimationID {
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
}

enum LevelFourPresentationDefinition {
  static func make(from level: LevelDefinition, bossDefeated: Bool = false)
    -> LevelPresentationDefinition
  {
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
            columns: col..<min(col + 10, level.grid.columns)), LevelFourRenderAssets.floor)
      }
    }
    let javaBoundaryWalls = [
      GridRegion(rows: 0..<4, columns: 0..<60), .init(rows: 56..<60, columns: 0..<60),
      .init(rows: 4..<56, columns: 0..<4), .init(rows: 4..<56, columns: 56..<60),
    ]
    let walls = javaBoundaryWalls.map {
      tile(
        $0,
        $0.columns == 0..<4
          ? LevelFourRenderAssets.wallLeft
          : ($0.columns == 56..<60
            ? LevelFourRenderAssets.wallRight : LevelFourRenderAssets.wallFront))
    }
    return .init(
      levelID: .levelFour, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelFourRenderAssets.doorClosed,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3)
      ])
  }
}
