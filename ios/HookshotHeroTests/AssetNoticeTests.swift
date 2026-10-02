import XCTest
@testable import HookshotHero

final class AssetNoticeTests: XCTestCase {
  func testBundledNoticeAndLicenseResourcesExist() throws {
    let noticeURL = try XCTUnwrap(
      Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md"))
    let notice = try String(contentsOf: noticeURL, encoding: .utf8)
    XCTAssertTrue(notice.contains("Release status: BLOCKED"))

    let licenseURL = try XCTUnwrap(
      Bundle.main.url(forResource: "Hookshot-Hero-MIT", withExtension: "txt"))
    let license = try String(contentsOf: licenseURL, encoding: .utf8)
    XCTAssertTrue(license.hasPrefix("MIT License\n\nCopyright (c) 2023 Jerry Hsiung"))

    for filename in Set(LevelOneTextureCatalog.entries.values.map(\.filename)).sorted() {
      XCTAssertTrue(notice.contains("`\(filename)`"), "Missing audit record for \(filename)")
    }
  }

  func testApplicationResourceBuildPhaseMatchesCheckedInInventory() throws {
    let root = repositoryRoot
    let project = try String(
      contentsOf: root.appendingPathComponent("ios/HookshotHero.xcodeproj/project.pbxproj"),
      encoding: .utf8)
    let inventory = try String(
      contentsOf: root.appendingPathComponent("ios/Documentation/ShippedAssetInventory.txt"),
      encoding: .utf8)

    let phasePattern = #"12A78AD7BB4C0410A4A933CB = \{isa = PBXResourcesBuildPhase;.*?files = \((.*?)\);"#
    let phase = try XCTUnwrap(firstCapture(in: project, pattern: phasePattern))
    let phaseNames = Set(captures(in: phase, pattern: #"/\* (.*?) in Resources \*/"#))
    let auditedNames = Set(
      inventory.split(separator: "\n").compactMap { line -> String? in
        let prefix = "target|"
        return line.hasPrefix(prefix) ? String(line.dropFirst(prefix.count)) : nil
      })
    XCTAssertEqual(phaseNames, auditedNames, "Regenerate the shipped-resource inventory")
  }

  func testEveryAppIconRenditionMatchesCheckedInInventory() throws {
    let root = repositoryRoot
    let iconDirectory = root.appendingPathComponent(
      "ios/HookshotHero/Assets.xcassets/AppIcon.appiconset")
    let actual = Set(try FileManager.default.contentsOfDirectory(atPath: iconDirectory.path)
      .filter { $0.hasSuffix(".png") })
    let inventory = try String(
      contentsOf: root.appendingPathComponent("ios/Documentation/ShippedAssetInventory.txt"),
      encoding: .utf8)
    let audited = Set(inventory.split(separator: "\n").compactMap { line -> String? in
      let prefix = "app-icon|"
      return line.hasPrefix(prefix) ? String(line.dropFirst(prefix.count)) : nil
    })
    XCTAssertEqual(actual, audited, "Regenerate the app-icon inventory")
  }

  private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  }

  private func firstCapture(in text: String, pattern: String) -> String? {
    captures(in: text, pattern: pattern).first
  }

  private func captures(in text: String, pattern: String) -> [String] {
    guard let expression = try? NSRegularExpression(
      pattern: pattern, options: [.dotMatchesLineSeparators])
    else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    return expression.matches(in: text, range: range).compactMap { match in
      guard match.numberOfRanges > 1, let capture = Range(match.range(at: 1), in: text) else {
        return nil
      }
      return String(text[capture])
    }
  }
}
