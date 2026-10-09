import Foundation

enum CountryRoadRenderAssets {
  static func id(_ name: String) -> RenderAssetID { .init(rawValue: "country-road.\(name)") }
  static let grass = id("grass"), cobble = id("cobble"), road = id("road")
  static let water = id("water"), bridge = id("bridge"), cliff = id("cliff")
  static let market = id("market"), market1 = id("market-1"), market2 = id("market-2")
  static let wheat = id("wheat"), bags = id("bags"), island = id("island"), lake = id("lake")
  static let castleWall = id("castle-wall"), castleDoor = id("castle-door")
  static let child = id("npc.child"), olderResident = id("npc.older-resident")
  static let townfolk = id("npc.townfolk")
  static let waterfallFrames = (0..<4).map { id("waterfall.\($0)") }
}

extension LevelAssetManifest {
  static let countryRoad = LevelAssetManifest(
    textureAssetIDs: Set(
      [
        CountryRoadRenderAssets.grass, .init(rawValue: "country-road.cobble"),
        .init(rawValue: "country-road.road"),
        .init(rawValue: "country-road.water"), .init(rawValue: "country-road.bridge"),
        .init(rawValue: "country-road.cliff"),
        .init(rawValue: "country-road.market"), .init(rawValue: "country-road.market-1"),
        .init(rawValue: "country-road.market-2"),
        .init(rawValue: "country-road.wheat"), .init(rawValue: "country-road.bags"),
        .init(rawValue: "country-road.island"),
        .init(rawValue: "country-road.lake"), .init(rawValue: "country-road.castle-wall"),
        .init(rawValue: "country-road.castle-door"),
        CountryRoadRenderAssets.child, CountryRoadRenderAssets.olderResident,
        CountryRoadRenderAssets.townfolk,
      ] + CountryRoadRenderAssets.waterfallFrames
    ).union(sharedPlayerTextureAssetIDs).union(
      LevelAssetManifest.levelOne.textureAssetIDs.filter {
        $0.rawValue.contains("coin") || $0 == LevelOneRenderAssets.cabbage
      }),
    animationIDs: [
      .init(rawValue: "country-road.waterfall"), LevelOneRenderAnimations.coinSpin,
      LevelOneRenderAnimations.lidiaWalk(.up), LevelOneRenderAnimations.lidiaWalk(.down),
      LevelOneRenderAnimations.lidiaWalk(.left), LevelOneRenderAnimations.lidiaWalk(.right),
    ])
}

enum CountryRoadPresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func item(
      _ asset: RenderAssetID, _ row: Int, _ col: Int, _ w: Double, _ h: Double, z: Double = 2,
      animation: RenderAnimationID? = nil
    ) -> StaticRenderDescriptor {
      .init(
        id: EntityID(), asset: asset, coordinate: .init(row: row, column: col),
        renderSize: .init(width: w, height: h), anchor: .bottomLeft, zPosition: z,
        animationID: animation)
    }
    let grass = stride(from: 0, to: 60, by: 4).flatMap { row in
      stride(from: 0, to: 60, by: 4).map { col in
        TileRenderPlacement(
          coordinate: .init(row: row, column: col), renderSize: .init(width: 4, height: 4),
          asset: CountryRoadRenderAssets.grass, anchor: .bottomLeft)
      }
    }
    let cobble = stride(from: 5, to: 14, by: 8).flatMap { row in
      stride(from: 0, to: 60, by: 9).map { col in
        TileRenderPlacement(
          coordinate: .init(row: row, column: col), renderSize: .init(width: 9, height: 8),
          asset: CountryRoadRenderAssets.cobble, anchor: .bottomLeft)
      }
    }
    var objects = (0..<16).map { item(CountryRoadRenderAssets.road, $0 * 3, 25, 9, 8.5, z: 1) }
    objects += stride(from: 0, to: 60, by: 10).flatMap { col in
      [
        item(CountryRoadRenderAssets.water, 25, col, 10, 5, z: 1),
        item(CountryRoadRenderAssets.water, 30, col, 10, 5, z: 1),
      ]
    }
    objects += [
      item(CountryRoadRenderAssets.bridge, 25, 25, 10, 5, z: 3),
      item(CountryRoadRenderAssets.market, 2, 45, 11.2, 9.5),
      item(CountryRoadRenderAssets.market1, 10, 10, 12.7, 4),
      item(CountryRoadRenderAssets.market2, 19, 10, 12.7, 4),
      item(CountryRoadRenderAssets.wheat, 15, 45, 6.2, 6.2),
      item(CountryRoadRenderAssets.bags, 22, 39, 6.4, 2.7),
      item(CountryRoadRenderAssets.island, 27, 45, 6.5, 6),
      item(CountryRoadRenderAssets.lake, 46, 5, 9.5, 9),
      item(
        CountryRoadRenderAssets.waterfallFrames[0], 35, 5, 9.6, 19.3,
        animation: .init(rawValue: "country-road.waterfall")),
    ]
    objects += stride(from: 0, to: 21, by: 7).map {
      item(CountryRoadRenderAssets.cliff, 35, $0, 7, 8)
    }
    objects += stride(from: 0, to: 60, by: 4).compactMap { column in
      CountryRoadDefinition.exitRegion.columns.contains(column)
        ? nil : item(CountryRoadRenderAssets.castleWall, 0, column, 4, 3, z: 3)
    }
    objects += [
      item(CountryRoadRenderAssets.castleDoor, 0, 29, 1.6, 2.4, z: 4),
      item(CountryRoadRenderAssets.castleDoor, 0, 30, 1.6, 2.4, z: 4),
    ]
    return .init(
      levelID: .countryRoad, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "grass"), zPosition: 0, tiles: grass),
        .init(id: .init(rawValue: "cobble"), zPosition: 0.5, tiles: cobble),
      ], staticObjects: objects)
  }
}

extension TileRenderPlacement {
  fileprivate init(
    coordinate: GridPosition, renderSize: LogicalRenderSize, asset: RenderAssetID,
    anchor: RenderAnchor
  ) {
    self.init(coordinate: coordinate, sizeInCells: renderSize, asset: asset, anchor: anchor)
  }
}
