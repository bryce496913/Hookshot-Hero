import SpriteKit
import UIKit
import XCTest

@testable import HookshotHero

@MainActor final class TextureCatalogTests: XCTestCase {
  func testRawPNGResolvesAndConstructsCachedNearestTexture() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "floor.png", withExtension: nil))
    let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
    XCTAssertGreaterThan(image.size.width, 0)
    XCTAssertGreaterThan(image.size.height, 0)

    let id = RenderAssetID(rawValue: "test.floor")
    let catalog = TextureCatalog(entries: [id: .init(filename: "floor.png", source: nil)])
    let first = try catalog.texture(for: id)
    let second = try catalog.texture(for: id)

    XCTAssertTrue(first === second)
    XCTAssertEqual(first.filteringMode, .nearest)
    XCTAssertEqual(first.size(), image.size)
  }

  func testSpriteSheetCropRetainsDeclaredDimensions() throws {
    let catalog = TextureCatalog(entries: LevelOneTextureCatalog.entries)

    let mine = try catalog.texture(for: LevelOneRenderAssets.mine)
    let ghostWizard = try catalog.texture(for: LevelTenRenderAssets.ghostWizard)

    XCTAssertEqual(mine.size(), CGSize(width: 20, height: 26))
    XCTAssertEqual(ghostWizard.size(), CGSize(width: 45, height: 58))
    XCTAssertEqual(mine.filteringMode, .nearest)
    XCTAssertEqual(ghostWizard.filteringMode, .nearest)
  }

  func testPalaceCropsHaveCorrectPixelDimensions() throws {
    let catalog = TextureCatalog()
    let expected: [(RenderAssetID, Double, Double)] = [
      (HeroWelcomeRenderAssets.aristocrat, 24, 32),
      (HeroWelcomeRenderAssets.king, 24, 32),
      (HeroWelcomeRenderAssets.queen, 24, 32),
      (HeroWelcomeRenderAssets.prince, 24, 32),
      (HeroWelcomeRenderAssets.princess, 24, 32),
      (HeroWelcomeRenderAssets.knight, 16, 23),
      (HeroWelcomeRenderAssets.desk, 30, 23),
      (HeroWelcomeRenderAssets.bookshelf, 20, 27),
    ]
    for (asset, width, height) in expected {
      let size = try catalog.texture(for: asset).size()
      XCTAssertEqual(Double(size.width), width, accuracy: 0.001, asset.rawValue)
      XCTAssertEqual(Double(size.height), height, accuracy: 0.001, asset.rawValue)
    }
  }

  func testIncorrectSheetDimensionsAreRejectedEvenWhenDeclaredCropFits() {
    let id = RenderAssetID(rawValue: "test.wrong-sheet-size")
    let catalog = TextureCatalog(entries: [id: .init(
      filename: "k1.png", source: .init(
        x: 0, y: 64, width: 24, height: 32, sheetWidth: 72, sheetHeight: 128))])
    XCTAssertThrowsError(try catalog.texture(for: id)) { error in
      guard case TextureCatalogError.invalidRegion(let asset) = error else {
        return XCTFail("Expected invalidRegion, got \(error)")
      }
      XCTAssertEqual(asset, id)
    }
  }

  func testEveryRegisteredTextureMatchesItsBundledSource() throws {
    let catalog = TextureCatalog()
    for asset in LevelOneTextureCatalog.entries.keys {
      _ = try catalog.texture(for: asset)
    }
  }

  func testEveryLevelManifestIncludesInitialDynamicRenderRequests() throws {
    let factory = DefaultGameLevelRuntimeFactory()
    for levelID in LevelSelectView.levels.map(\.levelID) {
      let runtime = try factory.makeRuntime(
        levelID: levelID,
        configuration: .init(reducedMotion: false, controlHintsEnabled: true), seed: 42)
      let snapshot = runtime.simulation.renderSnapshot
      for entity in [snapshot.player] + snapshot.entities {
        XCTAssertTrue(runtime.assetManifest.textureAssetIDs.contains(entity.asset),
                      "Missing texture \(entity.asset.rawValue) in \(levelID.rawValue)")
        if let animation = entity.animation {
          XCTAssertTrue(runtime.assetManifest.animationIDs.contains(animation.animationID),
                        "Missing animation \(animation.animationID.rawValue) in \(levelID.rawValue)")
        }
      }
    }
  }

  func testMissingFileThrowsMissingAsset() {
    let id = RenderAssetID(rawValue: "test.missing")
    let catalog = TextureCatalog(
      entries: [id: .init(filename: "not-a-real-hookshot-hero-texture.png", source: nil)])

    XCTAssertThrowsError(try catalog.texture(for: id)) { error in
      guard case TextureCatalogError.missingAsset(let failedID) = error else {
        return XCTFail("Expected missingAsset, got \(error)")
      }
      XCTAssertEqual(failedID, id)
    }
  }

  func testNonImageResourceThrowsUndecodableAsset() throws {
    let id = RenderAssetID(rawValue: "test.undecodable")
    _ = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo.xcprivacy", withExtension: nil))
    let catalog = TextureCatalog(
      entries: [id: .init(filename: "PrivacyInfo.xcprivacy", source: nil)])

    XCTAssertThrowsError(try catalog.texture(for: id)) { error in
      guard case TextureCatalogError.undecodableAsset(let failedID) = error else {
        return XCTFail("Expected undecodableAsset, got \(error)")
      }
      XCTAssertEqual(failedID, id)
    }
  }

  func testInvalidSourceRectangleThrowsInvalidRegion() {
    let id = RenderAssetID(rawValue: "test.invalid-region")
    let catalog = TextureCatalog(entries: [
      id: .init(
        filename: "floor.png",
        source: .init(x: 0, y: 0, width: 65, height: 64, sheetWidth: 64, sheetHeight: 64))
    ])

    XCTAssertThrowsError(try catalog.texture(for: id)) { error in
      guard case TextureCatalogError.invalidRegion(let failedID) = error else {
        return XCTFail("Expected invalidRegion, got \(error)")
      }
      XCTAssertEqual(failedID, id)
    }
  }

  func testLevelOneRuntimeAssetPreflightSucceeds() throws {
    try assertPreflightSucceeds(for: .levelOne)
  }

  func testLevelTenRuntimeAssetPreflightSucceeds() throws {
    try assertPreflightSucceeds(for: .levelTen)
  }

  func testCountryRoadRuntimeAssetPreflightSucceeds() throws {
    try assertPreflightSucceeds(for: .countryRoad)
  }

  func testHeroWelcomeRuntimeAssetPreflightSucceeds() throws {
    try assertPreflightSucceeds(for: .heroWelcome)
  }

  private func assertPreflightSucceeds(for manifest: LevelAssetManifest) throws {
    let textures = TextureCatalog(entries: LevelOneTextureCatalog.entries)
    let animations = LevelOneAnimationCatalog(textureCatalog: textures)

    try DefaultAssetPreflight().validate(
      manifest: manifest, textureCatalog: textures, animationCatalog: animations)
  }
}
