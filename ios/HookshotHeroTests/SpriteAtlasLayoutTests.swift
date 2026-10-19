import XCTest
@testable import HookshotHero

@MainActor final class SpriteAtlasLayoutTests: XCTestCase {
  private let manifests: [LevelAssetManifest] = [
    .levelOne, .levelTwo, .levelThree, .levelFour, .levelFive, .levelSix,
    .levelSeven, .levelEight, .levelNine, .levelTen, .countryRoad, .heroWelcome,
  ]

  func testEveryRequiredAssetIsExplicitlyMappedOrMissing() {
    let required = manifests.reduce(into: Set<RenderAssetID>()) { $0.formUnion($1.textureAssetIDs) }
    let mapped = Set(MasterSpriteAtlas.entries.keys)
    XCTAssertEqual(required.count, 249)
    XCTAssertEqual(required, Set(LevelOneTextureCatalog.entries.keys))
    XCTAssertEqual(required, mapped.union(MasterSpriteAtlas.missingRequiredAssetIDs))
    XCTAssertTrue(mapped.isDisjoint(with: MasterSpriteAtlas.missingRequiredAssetIDs))
    // This is an intentional blocker, not a passing claim that the atlas is complete.
    XCTAssertFalse(MasterSpriteAtlas.isComplete)
    XCTAssertEqual(MasterSpriteAtlas.missingRequiredAssetIDs.count, 249)
    XCTAssertTrue(mapped.isEmpty)
  }

  func testEveryMappedRectIsFiniteAndInsideAtlas() {
    for (id, rect) in MasterSpriteAtlas.entries {
      XCTAssertTrue(MasterSpriteAtlas.isValid(rect), id.rawValue)
    }
    // Exercise validation even while the verified map is empty.
    XCTAssertTrue(MasterSpriteAtlas.isValid(MasterSpriteAtlas.sourceRect(x: 0, y: 0, width: 1774, height: 887)))
    for (x, y, width, height) in [
      (-1.0, 0.0, 1.0, 1.0), (0, -1, 1, 1), (0, 0, 0, 1), (0, 0, 1, -1),
      (1774, 0, 1, 1), (0, 887, 1, 1), (.nan, 0, 1, 1), (0, 0, .infinity, 1),
    ] {
      XCTAssertFalse(MasterSpriteAtlas.isValid(MasterSpriteAtlas.sourceRect(x: x, y: y, width: width, height: height)))
    }
  }

  func testTopLeftCoordinatesConvertToSpriteKitBottomLeft() {
    let rect = SpriteSheet.normalizedRect(x: 100, y: 200, width: 64, height: 32,
                                          sheetWidth: 1774, sheetHeight: 887)
    XCTAssertEqual(rect.minX, 100.0 / 1774, accuracy: 0.000001)
    XCTAssertEqual(rect.minY, 1 - 232.0 / 887, accuracy: 0.000001)
    XCTAssertEqual(rect.width, 64.0 / 1774, accuracy: 0.000001)
    XCTAssertEqual(rect.height, 32.0 / 887, accuracy: 0.000001)
  }

  func testAllDirectionalFrameContractsRemainCompleteAndOrdered() throws {
    let families: [(String, [Int], Int, Int)] = [
      ("character.lidia", [0, 1, 2, 3], 9, 36),
      ("enemy.skeleton", [8, 9, 10, 11], 9, 36),
      ("enemy.flying-terror", [0, 2, 4, 6], 10, 40),
      ("enemy.minotaur", [0, 1, 2, 3], 3, 12),
      ("enemy.ghost-wizard", [0, 1, 2, 3], 2, 8),
    ]
    let recorder = RecordingTextures()
    let animations = LevelOneAnimationCatalog(textureCatalog: recorder)
    for (prefix, rows, count, total) in families {
      let all = rows.flatMap { row in (0..<count).map { RenderAssetID(rawValue: "\(prefix).\(row)-\($0)") } }
      XCTAssertEqual(all.count, total)
      XCTAssertTrue(Set(all).isSubset(of: MasterSpriteAtlas.missingRequiredAssetIDs))
      for row in rows {
        for frame in 0..<count {
          let source = try XCTUnwrap(LevelOneTextureCatalog.entries[.init(rawValue: "\(prefix).\(row)-\(frame)")]?.source)
          XCTAssertEqual(source.x, Double(frame) * source.width)
          XCTAssertEqual(source.y, Double(row) * source.height)
        }
      }
    }
    for direction in [RenderOrientation.up, .left, .down, .right] {
      let name = direction.rawValue
      let cases: [(RenderAnimationID, String, Int, Int)] = [
        (LevelOneRenderAnimations.lidiaWalk(direction), "character.lidia", ["up": 0, "left": 1, "down": 2, "right": 3][name]!, 9),
        (LevelTwoRenderAnimations.enemy(.skeleton, direction), "enemy.skeleton", ["up": 8, "left": 9, "down": 10, "right": 11][name]!, 9),
        (LevelTwoRenderAnimations.enemy(.flyingTerror, direction), "enemy.flying-terror", ["left": 0, "up": 2, "right": 4, "down": 6][name]!, 10),
        (LevelTwoRenderAnimations.enemy(.minotaur, direction), "enemy.minotaur", ["down": 0, "left": 1, "right": 2, "up": 3][name]!, 3),
        (LevelTenRenderAnimations.ghostWizard(direction), "enemy.ghost-wizard", ["down": 0, "right": 1, "left": 2, "up": 3][name]!, 2),
      ]
      for (animation, prefix, row, count) in cases {
        recorder.requests = []
        _ = try animations.frames(for: animation)
        XCTAssertEqual(recorder.requests, (0..<count).map { .init(rawValue: "\(prefix).\(row)-\($0)") })
      }
    }
    recorder.requests = []
    _ = try animations.frames(for: LevelOneRenderAnimations.coinSpin)
    XCTAssertEqual(recorder.requests, (1...9).map { .init(rawValue: "level-one.coin.\($0)") })
    recorder.requests = []
    _ = try animations.frames(for: .init(rawValue: "country-road.waterfall"))
    XCTAssertEqual(recorder.requests, (0..<4).map { .init(rawValue: "country-road.waterfall.\($0)") })
  }

  func testAllManifestAnimationsAreCoveredByAudit() throws {
    let recorder = RecordingTextures()
    let animations = LevelOneAnimationCatalog(textureCatalog: recorder)
    for manifest in manifests {
      for animation in manifest.animationIDs {
        recorder.requests = []
        _ = try animations.frames(for: animation)
        XCTAssertFalse(recorder.requests.isEmpty)
        for asset in recorder.requests {
          XCTAssertTrue(manifest.textureAssetIDs.contains(asset))
          XCTAssertTrue(MasterSpriteAtlas.entries[asset] != nil || MasterSpriteAtlas.missingRequiredAssetIDs.contains(asset))
        }
      }
    }
  }
}

import SpriteKit
private final class RecordingTextures: TextureCatalogProviding {
  var requests: [RenderAssetID] = []
  func texture(for assetID: RenderAssetID) throws -> SKTexture {
    requests.append(assetID)
    return SKTexture()
  }
}
