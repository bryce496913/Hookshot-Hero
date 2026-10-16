import XCTest

@testable import HookshotHero

final class GameDurationFormatterTests: XCTestCase {
  func testMinutesAndSecondsWithoutHourWrapping() {
    let examples: [(Double, String)] = [
      (0, "00:00"), (5, "00:05"), (59, "00:59"), (60, "01:00"), (65, "01:05"),
      (599, "09:59"), (600, "10:00"), (3599, "59:59"), (3725, "62:05"),
    ]
    for (elapsed, expected) in examples {
      XCTAssertEqual(GameDurationFormatter.displayString(for: elapsed), expected)
    }
  }

  func testNegativesClampAndFractionalSecondsFloor() {
    for elapsed in [-60.0, -0.1, 0.9] {
      XCTAssertEqual(GameDurationFormatter.displayString(for: elapsed), "00:00")
    }
    XCTAssertEqual(GameDurationFormatter.displayString(for: 59.999), "00:59")
    XCTAssertEqual(GameDurationFormatter.displayString(for: 60.999), "01:00")
    XCTAssertEqual(GameDurationFormatter.displayString(for: 83.4), "01:23")
    XCTAssertEqual(GameDurationFormatter.spokenString(for: 83.4), "1 minute 23 seconds")
  }

  func testNaturalSpeechUsesMatchingWholeSecondsAndSingularUnits() {
    let examples: [(Double, String)] = [
      (0, "0 seconds"), (-1, "0 seconds"), (1.9, "1 second"), (5, "5 seconds"),
      (60, "1 minute"), (61, "1 minute 1 second"), (120, "2 minutes"),
      (3725, "62 minutes 5 seconds"),
    ]
    for (elapsed, expected) in examples {
      XCTAssertEqual(GameDurationFormatter.spokenString(for: elapsed), expected)
    }
  }

  func testInvalidAndOversizedInputCannotTrap() {
    for elapsed in [Double.nan, .infinity, -.infinity] {
      XCTAssertEqual(GameDurationFormatter.displayString(for: elapsed), "00:00")
      XCTAssertEqual(GameDurationFormatter.spokenString(for: elapsed), "0 seconds")
    }
    XCTAssertEqual(GameDurationFormatter.displayString(for: .greatestFiniteMagnitude),
                   "153722867280912930:07") // iOS uses 64-bit Int.
  }
}
