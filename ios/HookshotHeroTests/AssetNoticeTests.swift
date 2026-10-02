import XCTest
@testable import HookshotHero

final class AssetNoticeTests: XCTestCase {
  func testBundledNoticeExistsAndContainsEveryProductionTextureFilename() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md"))
    let notice = try String(contentsOf: url, encoding: .utf8)
    XCTAssertTrue(notice.contains("Release status: BLOCKED"))

    let filenames = Set(LevelOneTextureCatalog.entries.values.map(\.filename))
    for filename in filenames.sorted() {
      XCTAssertTrue(notice.contains("`\(filename)`"), "Missing audit record for \(filename)")
    }
  }
}
