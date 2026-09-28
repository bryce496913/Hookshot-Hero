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
