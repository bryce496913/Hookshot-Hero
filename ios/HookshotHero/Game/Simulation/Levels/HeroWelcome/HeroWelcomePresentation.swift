import Foundation

enum HeroWelcomeRenderAssets {
  static func id(_ name: String) -> RenderAssetID { .init(rawValue: "hero-welcome.\(name)") }
  static let floor = id("floor"), wallFront = id("wall-front"), sideWall = id("side-wall")
  static let column = id("column"), door = id("door"), wallFlags = id("wall-flags")
  static let redCarpet = id("red-carpet"), carpet = id("carpet"), knight = id("knight")
  static let desk = id("desk"), bookshelf = id("bookshelf"), flower1 = id("flower-1")
  static let flower2 = id("flower-2"), silverChest = id("silver-chest"), barrels = id("barrels")
  static let aristocrat = id("npc.aristocrat"), king = id("npc.king"), queen = id("npc.queen")
  static let prince = id("npc.prince"), princess = id("npc.princess")
  static let all: Set<RenderAssetID> = [
    floor, wallFront, sideWall, column, door, wallFlags, redCarpet, carpet, knight, desk,
    bookshelf, flower1, flower2, silverChest, barrels, aristocrat, king, queen, prince, princess,
  ]
}

extension LevelAssetManifest {
  static let heroWelcome = LevelAssetManifest(
    textureAssetIDs: HeroWelcomeRenderAssets.all.union(sharedPlayerTextureAssetIDs).union([
      LevelOneRenderAssets.chestClosed, LevelOneRenderAssets.chestOpen,
    ]),
    animationIDs: Set([
      LevelOneRenderAnimations.lidiaWalk(.up), LevelOneRenderAnimations.lidiaWalk(.down),
      LevelOneRenderAnimations.lidiaWalk(.left), LevelOneRenderAnimations.lidiaWalk(.right),
    ]))
}

enum HeroWelcomePresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func item(
      _ asset: RenderAssetID, _ row: Int, _ col: Int, _ width: Double, _ height: Double,
      z: Double = 2
    ) -> StaticRenderDescriptor {
      .init(
        id: EntityID(), asset: asset, coordinate: .init(row: row, column: col),
        renderSize: .init(width: width, height: height), anchor: .bottomLeft, zPosition: z)
    }
    let floor = stride(from: 0, to: 56, by: 3).flatMap { row in
      stride(from: 0, to: 60, by: 3).map { col in
        TileRenderPlacement(
          coordinate: .init(row: row, column: col), sizeInCells: .init(width: 3.2, height: 3.2),
          asset: HeroWelcomeRenderAssets.floor, anchor: .bottomLeft)
      }
    }
    var objects = [item(HeroWelcomeRenderAssets.redCarpet, 3, 27, 6.4, 6.4, z: 1)]
    objects += (0..<15).map {
      item(HeroWelcomeRenderAssets.carpet, 10 + $0 * 3, 28, 4.7, 3.1, z: 1)
    }
    objects += stride(from: 0, to: 60, by: 4).flatMap { col in
      [
        item(HeroWelcomeRenderAssets.wallFront, 0, col, 4, 3),
        item(HeroWelcomeRenderAssets.wallFront, 56, col, 4, 3),
      ]
    }
    objects += stride(from: 0, to: 56, by: 4).flatMap { row in
      [
        item(HeroWelcomeRenderAssets.sideWall, row, 0, 0.7, 4),
        item(HeroWelcomeRenderAssets.sideWall, row, 59, 0.7, 4),
      ]
    }
    objects += (0..<5).flatMap { index in
      [
        item(HeroWelcomeRenderAssets.column, 10 + index * 10, 24, 1.6, 5),
        item(HeroWelcomeRenderAssets.column, 10 + index * 10, 35, 1.6, 5),
      ]
    }
    objects += [
      item(HeroWelcomeRenderAssets.wallFlags, 0, 15, 5, 2.5),
      item(HeroWelcomeRenderAssets.wallFlags, 0, 43, 5, 2.5),
      item(HeroWelcomeRenderAssets.knight, 1, 10, 1.6, 2.3),
      item(HeroWelcomeRenderAssets.knight, 1, 50, 1.6, 2.3),
      item(HeroWelcomeRenderAssets.desk, 10, 29, 3, 2.3),
      item(HeroWelcomeRenderAssets.bookshelf, 0, 25, 2, 2.7),
      item(HeroWelcomeRenderAssets.bookshelf, 0, 34, 2, 2.7),
      item(HeroWelcomeRenderAssets.barrels, 50, 6, 9, 4.5),
      item(HeroWelcomeRenderAssets.door, 56, 29, 1.6, 2.4, z: 4),
      item(HeroWelcomeRenderAssets.door, 56, 30, 1.6, 2.4, z: 4),
    ]
    objects += (0..<5).flatMap { index in
      [
        item(HeroWelcomeRenderAssets.flower1, index * 12, 0, 2, 2.7),
        item(HeroWelcomeRenderAssets.flower1, index * 12, 57, 2, 2.7),
        item(HeroWelcomeRenderAssets.flower2, 5 + index * 12, 0, 1.6, 2.7),
        item(HeroWelcomeRenderAssets.flower2, 5 + index * 12, 57, 1.6, 2.7),
      ]
    }
    return .init(
      levelID: .heroWelcome, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [.init(id: .init(rawValue: "castle-floor"), zPosition: 0, tiles: floor)],
      staticObjects: objects)
  }
}
