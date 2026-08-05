import SwiftUI
import UIKit
import XCTest
@testable import HookshotHero

@MainActor final class AppThemeTests: XCTestCase {
    func testExactThemeColorComponents() {
        assertColor(AppTheme.Colors.background, red: 0, green: 0, blue: 0)
        assertColor(AppTheme.Colors.surface, red: 0.12, green: 0.04, blue: 0.2)
        assertColor(AppTheme.Colors.accent, red: 0.72, green: 0.29, blue: 0.95)
        assertColor(AppTheme.Colors.highlight, red: 0.98, green: 0.32, blue: 0.67)
        assertColor(AppTheme.Colors.text, red: 1, green: 1, blue: 1)
    }

    func testExactBaseTypographySizes() {
        XCTAssertEqual(AppTextStyle.h1.size, 16)
        XCTAssertEqual(AppTextStyle.h2.size, 14)
        XCTAssertEqual(AppTextStyle.h3.size, 12)
        XCTAssertEqual(AppTextStyle.paragraph.size, 10)
    }

    func testSemanticTypographyWeights() {
        XCTAssertEqual(AppTextStyle.h1.weight, .bold)
        XCTAssertEqual(AppTextStyle.h2.weight, .semibold)
        XCTAssertEqual(AppTextStyle.h3.weight, .medium)
        XCTAssertEqual(AppTextStyle.paragraph.weight, .regular)
    }

    private func assertColor(_ color: Color, red: CGFloat, green: CGFloat, blue: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let resolved = UIColor(color)
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &actualAlpha), file: file, line: line)
        XCTAssertEqual(actualRed, red, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actualGreen, green, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actualBlue, blue, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actualAlpha, 1, accuracy: 0.0001, file: file, line: line)
    }
}
