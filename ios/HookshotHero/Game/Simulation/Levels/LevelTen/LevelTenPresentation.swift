import Foundation

enum LevelTenRenderAssets {
  static let floor = LevelSevenRenderAssets.floor
  static let wallFront = LevelSevenRenderAssets.wallFront
  static let wallLeft = LevelSevenRenderAssets.wallLeft
  static let wallRight = LevelSevenRenderAssets.wallRight
  static let entranceDoor = LevelFourRenderAssets.doorOpenSide
  static let endingDoorOpen = LevelOneRenderAssets.exitDoor
  static let endingDoorClosed = LevelOneRenderAssets.entryDoor
  static let specialChest = LevelOneRenderAssets.chestClosed
  static let ghostWizard = RenderAssetID(rawValue: "enemy.ghost-wizard")
  static let projectile = RenderAssetID(rawValue: "enemy.ghost-wizard.projectile")
}
enum LevelTenRenderAnimations {
  static func ghostWizard(_ direction: RenderOrientation) -> RenderAnimationID {
    let row =
      switch direction {
      case .down: 0
      case .left: 1
      case .right: 2
      case .up: 3
      case .none: 0
      }
    return .init(rawValue: "enemy.ghost-wizard.\(row)")
  }
}
extension LevelAssetManifest {
  static let levelTen = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelTenRenderAssets.floor, LevelTenRenderAssets.wallFront, LevelTenRenderAssets.wallLeft,
      LevelTenRenderAssets.wallRight, LevelTenRenderAssets.entranceDoor,
      LevelTenRenderAssets.endingDoorOpen, LevelTenRenderAssets.endingDoorClosed,
      LevelTenRenderAssets.specialChest, LevelOneRenderAssets.chestOpen,
      LevelTenRenderAssets.ghostWizard,
      LevelTenRenderAssets.projectile,
    ]).union(sharedPlayerTextureAssetIDs).union(
      (0..<4).flatMap { row in
        (0..<3).map { RenderAssetID(rawValue: "enemy.ghost-wizard.\(row)-\($0)") }
      }),
    animationIDs: Set([
      LevelOneRenderAnimations.lidiaWalk(.up), LevelOneRenderAnimations.lidiaWalk(.down),
      LevelOneRenderAnimations.lidiaWalk(.left), LevelOneRenderAnimations.lidiaWalk(.right),
      ghostAnimation(.up), ghostAnimation(.down), ghostAnimation(.left), ghostAnimation(.right),
    ]))
  private static func ghostAnimation(_ d: RenderOrientation) -> RenderAnimationID {
    LevelTenRenderAnimations.ghostWizard(d)
  }
}
enum LevelTenPresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ r: GridRegion, _ asset: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: r.rows.lowerBound, column: r.columns.lowerBound),
        sizeInCells: .init(width: Double(r.columns.count), height: Double(r.rows.count)),
        asset: asset, anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: 60, by: 10).flatMap { row in
      stride(from: 0, to: 60, by: 10).map { col in
        tile(
          .init(rows: row..<min(row + 10, 60), columns: col..<min(col + 10, 60)),
          LevelTenRenderAssets.floor)
      }
    }
    let walls = level.walls.map {
      tile(
        $0,
        $0.columns == 0..<4
          ? LevelTenRenderAssets.wallLeft
          : ($0.columns == 56..<60
            ? LevelTenRenderAssets.wallRight : LevelTenRenderAssets.wallFront))
    }
    return .init(
      levelID: .levelTen, logicalGridSize: level.grid,
      background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelTenRenderAssets.entranceDoor,
          coordinate: .init(row: 28, column: 56), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3)
      ])
  }
}
