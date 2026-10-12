import SwiftUI
import UIKit
import XCTest

@testable import HookshotHero

@MainActor final class AppThemeTests: XCTestCase {
  func testInstalledPrimaryIconResolvesInHostApplication() throws {
    let image = try XCTUnwrap(PrimaryAppIcon.load(bundle: .main),
                             "The built app must expose its compiled primary icon")
    XCTAssertGreaterThan(image.size.width, 0)
    XCTAssertGreaterThan(image.size.height, 0)
  }

  func testPrimaryIconMetadataUsesOnlyPrimaryResourcesAndHandlesMissingMetadata() {
    let info: [String: Any] = ["CFBundleIcons": [
      "CFBundlePrimaryIcon": ["CFBundleIconFiles": ["AppIcon60x60", "AppIcon60x60"],
                              "CFBundleIconName": "AppIcon"],
      "CFBundleAlternateIcons": ["Other": ["CFBundleIconFiles": ["OtherIcon"]]]],
      "CFBundleIconFiles": ["LegacyIcon"]]
    XCTAssertEqual(PrimaryAppIcon.resourceNames(in: info),
                   ["AppIcon60x60", "AppIcon", "LegacyIcon"])
    XCTAssertTrue(PrimaryAppIcon.resourceNames(in: [:]).isEmpty)
    XCTAssertNil(PrimaryAppIcon.load(bundle: Bundle(for: Self.self)))
  }

  func testEndingCardsKeepNamesAndStableDirectEntryIdentifiers() {
    let endings = LevelSelectView.levels.filter(\.isEndingArea)
    XCTAssertEqual(endings.map(\.levelID), [.countryRoad, .heroWelcome])
    XCTAssertEqual(endings.map(\.accessibilityIdentifier), ["level11Button", "level12Button"])
    XCTAssertEqual(LevelSelectView.levels.filter { !$0.isEndingArea }.count, 10)
  }

  func testSemanticTypographyProvidesReadableHierarchy() {
    XCTAssertTrue(AppTextStyle.allCases.contains(.heroTitle))
    XCTAssertTrue(AppTextStyle.allCases.contains(.caption))
    XCTAssertEqual(AppTextStyle.heroTitle.semanticStyle, .largeTitle)
    XCTAssertEqual(AppTextStyle.h1.semanticStyle, .title)
    XCTAssertEqual(AppTextStyle.h2.semanticStyle, .title2)
    XCTAssertEqual(AppTextStyle.h3.semanticStyle, .headline)
    XCTAssertEqual(AppTextStyle.paragraph.semanticStyle, .body)
    XCTAssertEqual(AppTextStyle.caption.semanticStyle, .caption)
    XCTAssertGreaterThan(AppTextStyle.heroTitle.baseSize, AppTextStyle.h1.baseSize)
    XCTAssertGreaterThan(AppTextStyle.h1.baseSize, AppTextStyle.h2.baseSize)
    XCTAssertGreaterThan(AppTextStyle.h2.baseSize, AppTextStyle.paragraph.baseSize)
    XCTAssertGreaterThanOrEqual(AppTextStyle.paragraph.baseSize, 15)
    XCTAssertGreaterThanOrEqual(AppTextStyle.caption.baseSize, 12)
    XCTAssertEqual(AppTextStyle.h1.weight, .bold)
    XCTAssertEqual(AppTextStyle.paragraph.weight, .regular)
  }

  func testActualTypographyGrowsWithDynamicType() {
    let regular = fittedHeight(
      Text("Adventure awaits").appTextStyle(.paragraph).environment(\.dynamicTypeSize, .large))
    let accessible = fittedHeight(
      Text("Adventure awaits").appTextStyle(.paragraph).environment(\.dynamicTypeSize, .accessibility3))
    XCTAssertGreaterThan(accessible, regular)
    let hero = fittedHeight(
      Text("Adventure awaits").appTextStyle(.heroTitle).environment(\.dynamicTypeSize, .large))
    XCTAssertGreaterThan(hero, regular)
  }

  func testSemanticTextContrastOnDarkSurfaces() {
    let backgrounds = [AppTheme.Colors.background, AppTheme.Colors.backgroundElevated,
                       AppTheme.Colors.surface, AppTheme.Colors.surfaceElevated,
                       AppTheme.Colors.surfacePressed]
    let foregrounds = [AppTheme.Colors.text, AppTheme.Colors.textSecondary,
                       AppTheme.Colors.textMuted, AppTheme.Colors.accent,
                       AppTheme.Colors.highlight, AppTheme.Colors.danger, AppTheme.Colors.success]
    for foreground in foregrounds {
      for background in backgrounds {
        XCTAssertGreaterThanOrEqual(contrast(foreground, background), 4.5,
                                   "Semantic text must meet normal-text contrast")
      }
    }
    for background in [AppTheme.Colors.accentSecondary, AppTheme.Colors.primaryEnd] {
      XCTAssertGreaterThanOrEqual(contrast(AppTheme.Colors.text, background), 4.5)
    }
    XCTAssertGreaterThanOrEqual(contrast(AppTheme.Colors.background, AppTheme.Colors.highlight), 4.5)
  }

  func testPressedSurfaceLabelsKeepReadableContrast() {
    let foregrounds = [AppTheme.Colors.text, AppTheme.Colors.textSecondary,
                       AppTheme.Colors.textMuted, AppTheme.Colors.accent, AppTheme.Colors.highlight]
    let backgrounds = [AppTheme.Colors.surface, AppTheme.Colors.surfaceElevated,
                       AppTheme.Colors.backgroundElevated]
    for foreground in foregrounds {
      for background in backgrounds {
        // The pressed overlay composites over both label and surface.
        XCTAssertGreaterThanOrEqual(contrast(pressedTint(foreground), pressedTint(background)), 4.5)
      }
    }
    XCTAssertGreaterThanOrEqual(contrast(AppTheme.Colors.textMuted, AppTheme.Colors.backgroundElevated), 4.5)
  }

  func testSurfaceButtonStylePreservesTargetsAndAccessibleLabelGrowth() {
    let button = Button {} label: {
      AppNavigationRow(title: "Privacy Policy", systemImage: "shield",
                       subtitle: "How information is handled")
    }.buttonStyle(AppSurfaceButtonStyle(cornerRadius: AppTheme.Radius.control))
    let regular = fittedHeight(button.environment(\.dynamicTypeSize, .large), width: 220)
    let accessible = fittedHeight(button.environment(\.dynamicTypeSize, .accessibility3), width: 220)
    XCTAssertGreaterThanOrEqual(regular, 44)
    XCTAssertGreaterThan(accessible, regular)
  }

  func testDecorativeMotionCanBeDisabledBySystemOrAppPreference() {
    XCTAssertFalse(AppMotion.shouldReduceMotion(system: false, appSetting: false))
    XCTAssertTrue(AppMotion.shouldReduceMotion(system: true, appSetting: false))
    XCTAssertTrue(AppMotion.shouldReduceMotion(system: false, appSetting: true))
    XCTAssertTrue(AppMotion.shouldReduceMotion(system: true, appSetting: true))
    XCTAssertNil(AppMotion.animation(reducedMotion: true))
    XCTAssertNotNil(AppMotion.animation(reducedMotion: false))
    XCTAssertEqual(AppMotion.pressScale(isPressed: true, reducedMotion: true), 1)
    XCTAssertEqual(AppMotion.pressScale(isPressed: false, reducedMotion: false), 1)
    XCTAssertLessThan(AppMotion.pressScale(isPressed: true, reducedMotion: false), 1)
  }

  func testButtonsHaveMinimumTargetsAndCanGrowForAccessibleLabels() {
    XCTAssertGreaterThanOrEqual(AppTheme.Layout.minimumHitTarget, 44)
    XCTAssertGreaterThanOrEqual(AppTheme.Layout.buttonHeight, 52)
    let button = Button("Continue the adventure") {}.buttonStyle(AppPrimaryButtonStyle())
    let regular = fittedHeight(button.environment(\.dynamicTypeSize, .large), width: 220)
    let accessible = fittedHeight(button.environment(\.dynamicTypeSize, .accessibility3), width: 220)
    XCTAssertGreaterThanOrEqual(regular, AppTheme.Layout.buttonHeight)
    XCTAssertGreaterThan(accessible, regular)
    XCTAssertGreaterThanOrEqual(fittedHeight(
      Button("Explore") {}.buttonStyle(AppSecondaryButtonStyle()).disabled(true)), 44)
    XCTAssertGreaterThanOrEqual(fittedHeight(
      Button("Claim treasure") {}.buttonStyle(AppHighlightButtonStyle())), 44)
    XCTAssertGreaterThanOrEqual(fittedHeight(
      AppIconButton(title: "Help", systemImage: "questionmark") {}), 44)
  }

  func testReusableComponentsLayoutAtCompactAndStandardWidths() {
    for width: CGFloat in [320, 390] {
      let gallery = VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        AppCard(style: .hero) {
          Text("Dungeon adventure").appTextStyle(.heroTitle)
        }
        AppSectionHeader(title: "Your journey", systemImage: "sparkles")
        AppCard(style: .elevated) {
          AppStatPill(title: "Treasure", value: "1,200", systemImage: "diamond.fill")
        }
        AppDivider()
        AppIconButton(title: "Help", systemImage: "questionmark") {}
        AppCard(style: .danger) { Text("Danger ahead").appTextStyle(.paragraph) }
      }
      .padding(AppTheme.Layout.screenPadding)
      .appScreenBackground()
      .environment(\.appReducedMotion, true)
      .environment(\.dynamicTypeSize, .accessibility3)
      .preferredColorScheme(.dark)
      XCTAssertGreaterThan(fittedHeight(gallery, width: width), 0)
    }
  }

  private func fittedHeight<Content: View>(_ content: Content, width: CGFloat = 320) -> CGFloat {
    let controller = UIHostingController(rootView: content)
    controller.loadViewIfNeeded()
    controller.view.frame = CGRect(x: 0, y: 0, width: width, height: 1_000)
    controller.view.layoutIfNeeded()
    return controller.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
  }

  private func pressedTint(_ base: Color) -> Color {
    func rgb(_ color: Color) -> (Double, Double, Double) {
      var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
      XCTAssertTrue(UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a))
      return (Double(r), Double(g), Double(b))
    }
    let background = rgb(base)
    let overlay = rgb(AppTheme.Colors.accent)
    let alpha = AppTheme.Interaction.pressedTintOpacity
    return Color(red: overlay.0 * alpha + background.0 * (1 - alpha),
                 green: overlay.1 * alpha + background.1 * (1 - alpha),
                 blue: overlay.2 * alpha + background.2 * (1 - alpha))
  }

  private func contrast(_ lhs: Color, _ rhs: Color) -> Double {
    let first = luminance(lhs)
    let second = luminance(rhs)
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)
  }

  private func luminance(_ color: Color) -> Double {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
      XCTFail("Semantic color must resolve into RGB")
      return 0
    }
    func linear(_ value: CGFloat) -> Double {
      let value = Double(value)
      return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }
}
