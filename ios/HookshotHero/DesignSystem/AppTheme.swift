import SwiftUI

/// Shared scrollable structure for settings, guidance and legal information.
struct AppSecondaryScreen<Content: View>: View {
  let title: String
  @ViewBuilder let content: () -> Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
        Text(title).appTextStyle(.heroTitle).accessibilityAddTraits(.isHeader)
        content()
      }
      .frame(maxWidth: 640, alignment: .leading)
      .padding(AppTheme.Spacing.lg)
      .frame(maxWidth: .infinity)
    }
    .appScreenBackground()
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .appNavigationStyle()
  }
}

struct AppInformationSection<Content: View>: View {
  let title: String
  var systemImage: String? = nil
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      AppSectionHeader(title: title, systemImage: systemImage)
      AppCard {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) { content() }
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

struct AppNavigationRow: View {
  let title: String
  let systemImage: String
  var subtitle: String? = nil

  var body: some View {
    HStack(spacing: AppTheme.Spacing.md) {
      Image(systemName: systemImage).foregroundStyle(AppTheme.Colors.accent)
        .frame(width: 24).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
        Text(title).appTextStyle(.h3)
        if let subtitle {
          Text(subtitle).appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Image(systemName: "chevron.right").appTextStyle(.caption)
        .foregroundStyle(AppTheme.Colors.textMuted).accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, minHeight: AppTheme.Layout.minimumHitTarget, alignment: .leading)
    .padding(.vertical, AppTheme.Spacing.xs)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

struct AppSettingLabel: View {
  let title: String
  let explanation: String

  var body: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
      Text(title).appTextStyle(.h3)
      Text(explanation).appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

/// Shared visual foundations. Gameplay and pixel artwork remain simulation-owned.
enum AppTheme {
  enum Colors {
    static let background = Color(red: 0.035, green: 0.025, blue: 0.065)
    static let backgroundElevated = Color(red: 0.075, green: 0.045, blue: 0.12)
    static let surface = Color(red: 0.12, green: 0.08, blue: 0.18)
    static let surfaceElevated = Color(red: 0.17, green: 0.12, blue: 0.25)
    static let surfacePressed = Color(red: 0.22, green: 0.15, blue: 0.32)
    static let accent = Color(red: 0.76, green: 0.52, blue: 0.95)
    static let accentSecondary = Color(red: 0.45, green: 0.22, blue: 0.69)
    static let highlight = Color(red: 0.94, green: 0.42, blue: 0.68)
    static let danger = Color(red: 0.98, green: 0.46, blue: 0.54)
    static let success = Color(red: 0.48, green: 0.82, blue: 0.66)
    static let text = Color.white
    static let textSecondary = Color(red: 0.83, green: 0.79, blue: 0.89)
    static let textMuted = Color(red: 0.65, green: 0.59, blue: 0.73)
    static let divider = Color(red: 0.37, green: 0.28, blue: 0.46)
    static let shadow = Color.black.opacity(0.35)
    static let primaryEnd = Color(red: 0.52, green: 0.16, blue: 0.47)
  }

  enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
  }

  enum Radius {
    static let control: CGFloat = 16
    static let card: CGFloat = 20
    static let hero: CGFloat = 28
  }

  enum Layout {
    static let minimumHitTarget: CGFloat = 44
    static let buttonHeight: CGFloat = 54
    static let buttonVerticalPadding: CGFloat = 12
    static let cardPadding = Spacing.md
    static let screenPadding = Spacing.lg
    static let borderWidth: CGFloat = 1
  }

  enum Elevation {
    static let radius: CGFloat = 12
    static let offset: CGFloat = 4
    static let actionRadius: CGFloat = 8
  }

  enum Gradients {
    static var primary: LinearGradient {
      LinearGradient(colors: [Colors.accentSecondary, Colors.primaryEnd],
                     startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var hero: LinearGradient {
      LinearGradient(colors: [Colors.surfaceElevated, Colors.backgroundElevated],
                     startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }
}

enum AppTextStyle: Sendable, CaseIterable, Equatable {
  case heroTitle, h1, h2, h3, paragraph, caption

  var semanticStyle: Font.TextStyle {
    switch self {
    case .heroTitle: .largeTitle
    case .h1: .title
    case .h2: .title2
    case .h3: .headline
    case .paragraph: .body
    case .caption: .caption
    }
  }

  /// Reference sizes at standard Dynamic Type; the actual font uses semantic scaling.
  var baseSize: CGFloat {
    switch self {
    case .heroTitle: 34
    case .h1: 30
    case .h2: 22
    case .h3, .paragraph: 17
    case .caption: 12
    }
  }

  var weight: Font.Weight {
    switch self {
    case .heroTitle, .h1: .bold
    case .h2, .h3: .semibold
    case .paragraph, .caption: .regular
    }
  }

  var font: Font {
    .system(semanticStyle, design: self == .paragraph || self == .caption ? .default : .rounded)
      .weight(weight)
  }
}

struct AppTextStyleModifier: ViewModifier {
  let style: AppTextStyle
  func body(content: Content) -> some View {
    // Typography does not override a caller's semantic foreground color.
    content.font(style.font)
  }
}

struct AppBackground: View {
  var body: some View {
    ZStack {
      AppTheme.Colors.background
      LinearGradient(
        colors: [AppTheme.Colors.accentSecondary.opacity(0.22), .clear],
        startPoint: .top, endPoint: .center)
      RadialGradient(
        colors: [AppTheme.Colors.accent.opacity(0.12), .clear],
        center: .top, startRadius: 0, endRadius: 420)
      LinearGradient(
        colors: [.clear, AppTheme.Colors.background.opacity(0.85)],
        startPoint: .center, endPoint: .bottom)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

enum AppSurfaceStyle: CaseIterable, Equatable {
  case standard, elevated, hero, danger

  var fill: AnyShapeStyle {
    switch self {
    case .standard: AnyShapeStyle(AppTheme.Colors.surface)
    case .elevated: AnyShapeStyle(AppTheme.Colors.surfaceElevated)
    case .hero: AnyShapeStyle(AppTheme.Gradients.hero)
    case .danger: AnyShapeStyle(AppTheme.Colors.danger.opacity(0.12))
    }
  }

  var border: Color {
    switch self {
    case .standard, .elevated: AppTheme.Colors.divider.opacity(0.6)
    case .hero: AppTheme.Colors.accent.opacity(0.3)
    case .danger: AppTheme.Colors.danger.opacity(0.45)
    }
  }

  var cornerRadius: CGFloat {
    self == .hero ? AppTheme.Radius.hero : AppTheme.Radius.card
  }

  var shadowRadius: CGFloat {
    self == .elevated || self == .hero ? AppTheme.Elevation.radius : 0
  }
}

private struct AppSurfaceModifier: ViewModifier {
  let style: AppSurfaceStyle
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    content
      .background {
        shape.fill(AppTheme.Colors.surface)
          .overlay(shape.fill(style.fill))
          .shadow(color: style.shadowRadius == 0 ? .clear : AppTheme.Colors.shadow,
                  radius: style.shadowRadius, y: AppTheme.Elevation.offset)
      }
      .overlay(shape.stroke(style.border, lineWidth: AppTheme.Layout.borderWidth)
        .allowsHitTesting(false))
  }
}

private struct AppReducedMotionKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var appReducedMotion: Bool {
    get { self[AppReducedMotionKey.self] }
    set { self[AppReducedMotionKey.self] = newValue }
  }
}

enum AppMotion {
  static func shouldReduceMotion(system: Bool, appSetting: Bool) -> Bool {
    system || appSetting
  }

  static func animation(reducedMotion: Bool) -> Animation? {
    reducedMotion ? nil : .easeOut(duration: 0.16)
  }

  static func pressScale(isPressed: Bool, reducedMotion: Bool) -> CGFloat {
    isPressed && !reducedMotion ? 0.98 : 1
  }
}

extension View {
  func appTextStyle(_ style: AppTextStyle) -> some View {
    modifier(AppTextStyleModifier(style: style))
  }

  func appScreenBackground() -> some View { background { AppBackground() } }

  /// The optional radius keeps existing call sites source-compatible.
  func appSurface(cornerRadius: CGFloat? = nil, style: AppSurfaceStyle = .standard) -> some View {
    modifier(AppSurfaceModifier(style: style, cornerRadius: cornerRadius ?? style.cornerRadius))
  }

  func appNavigationStyle() -> some View {
    self
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbarBackground(.hidden, for: .navigationBar)
      .foregroundStyle(AppTheme.Colors.text)
      .tint(AppTheme.Colors.accent)
  }
}

private enum AppButtonRole: Equatable {
  case primary, secondary, highlight

  var foreground: Color {
    self == .highlight ? AppTheme.Colors.background : AppTheme.Colors.text
  }

  func fill(isPressed: Bool) -> AnyShapeStyle {
    switch self {
    case .primary:
      isPressed ? AnyShapeStyle(AppTheme.Colors.surfacePressed)
        : AnyShapeStyle(AppTheme.Gradients.primary)
    case .secondary:
      AnyShapeStyle(isPressed ? AppTheme.Colors.surfacePressed : AppTheme.Colors.surfaceElevated)
    case .highlight:
      AnyShapeStyle(AppTheme.Colors.highlight.opacity(isPressed ? 0.85 : 1))
    }
  }
}

/// Decorates the native Button label; no gestures or accessibility traits are replaced.
private struct AppButtonChrome: View {
  let label: ButtonStyleConfiguration.Label
  let isPressed: Bool
  let role: AppButtonRole
  var expands = true
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
  @Environment(\.appReducedMotion) private var appReducedMotion

  init(label: ButtonStyleConfiguration.Label, isPressed: Bool, role: AppButtonRole,
       expands: Bool = true) {
    self.label = label
    self.isPressed = isPressed
    self.role = role
    self.expands = expands
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
    let reducedMotion = AppMotion.shouldReduceMotion(
      system: systemReducedMotion, appSetting: appReducedMotion)
    label
      .font(AppTextStyle.h3.font)
      .foregroundStyle(role.foreground)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, expands ? AppTheme.Spacing.md : AppTheme.Spacing.sm)
      .padding(.vertical, expands ? AppTheme.Layout.buttonVerticalPadding : AppTheme.Spacing.sm)
      .frame(minWidth: AppTheme.Layout.minimumHitTarget,
             maxWidth: expands ? .infinity : nil,
             minHeight: expands ? AppTheme.Layout.buttonHeight : AppTheme.Layout.minimumHitTarget)
      .background {
        shape.fill(role.fill(isPressed: isPressed && isEnabled))
          .shadow(color: role == .primary && isEnabled ? AppTheme.Colors.shadow : .clear,
                  radius: AppTheme.Elevation.actionRadius, y: AppTheme.Elevation.offset)
      }
      .overlay(shape.stroke(isPressed ? AppTheme.Colors.text.opacity(0.45)
                             : AppTheme.Colors.divider, lineWidth: AppTheme.Layout.borderWidth)
        .allowsHitTesting(false))
      .contentShape(shape)
      .opacity(isEnabled ? 1 : 0.45)
      .scaleEffect(AppMotion.pressScale(isPressed: isPressed && isEnabled && expands,
                                       reducedMotion: reducedMotion))
      .animation(AppMotion.animation(reducedMotion: reducedMotion), value: isPressed)
  }
}

struct AppPrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    AppButtonChrome(label: configuration.label, isPressed: configuration.isPressed, role: .primary)
  }
}

struct AppSecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    AppButtonChrome(label: configuration.label, isPressed: configuration.isPressed, role: .secondary)
  }
}

struct AppHighlightButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    AppButtonChrome(label: configuration.label, isPressed: configuration.isPressed, role: .highlight)
  }
}

private struct AppIconButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    AppButtonChrome(label: configuration.label, isPressed: configuration.isPressed,
                    role: .secondary, expands: false)
  }
}

struct AppCard<Content: View>: View {
  let style: AppSurfaceStyle
  private let content: Content

  init(style: AppSurfaceStyle = .standard, @ViewBuilder content: () -> Content) {
    self.style = style
    self.content = content()
  }

  var body: some View {
    content.padding(AppTheme.Layout.cardPadding).foregroundStyle(AppTheme.Colors.text)
      .appSurface(style: style)
  }
}

struct AppSectionHeader: View {
  let title: String
  var systemImage: String? = nil

  var body: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      if let systemImage {
        Image(systemName: systemImage).foregroundStyle(AppTheme.Colors.accent)
          .accessibilityHidden(true)
      }
      Text(title).appTextStyle(.h3).foregroundStyle(AppTheme.Colors.text)
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}

struct AppIconButton: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage).accessibilityHidden(true)
    }
    .buttonStyle(AppIconButtonStyle())
    .accessibilityLabel(title)
  }
}

struct AppStatPill: View {
  let title: String
  let value: String
  var systemImage: String? = nil

  var body: some View {
    HStack(spacing: AppTheme.Spacing.sm) {
      if let systemImage {
        Image(systemName: systemImage).foregroundStyle(AppTheme.Colors.highlight)
          .accessibilityHidden(true)
      }
      Text(title).foregroundStyle(AppTheme.Colors.textSecondary)
      Text(value).bold().foregroundStyle(AppTheme.Colors.text)
    }
    .appTextStyle(.caption)
    .padding(.horizontal, AppTheme.Spacing.md)
    .padding(.vertical, AppTheme.Spacing.sm)
    .background(AppTheme.Colors.surfaceElevated, in: Capsule())
    .overlay(Capsule().stroke(AppTheme.Colors.divider, lineWidth: AppTheme.Layout.borderWidth))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
  }
}

struct AppDivider: View {
  var body: some View {
    Rectangle().fill(AppTheme.Colors.divider)
      .frame(height: AppTheme.Layout.borderWidth).allowsHitTesting(false).accessibilityHidden(true)
  }
}

#if DEBUG
private struct AppThemeGallery: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
        AppCard(style: .hero) {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Into the dungeon").appTextStyle(.heroTitle)
            Text("Magic, danger, and treasure await.").appTextStyle(.paragraph)
              .foregroundStyle(AppTheme.Colors.textSecondary)
          }
        }
        AppSectionHeader(title: "Your adventure", systemImage: "sparkles")
        AppCard(style: .elevated) {
          VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            AppStatPill(title: "Treasure", value: "1,200", systemImage: "diamond.fill")
            AppDivider()
            AppIconButton(title: "Help", systemImage: "questionmark") {}
          }
        }
        Button("Continue adventure") {}.buttonStyle(AppPrimaryButtonStyle())
        Button("Explore levels") {}.buttonStyle(AppSecondaryButtonStyle())
        Button("Claim treasure") {}.buttonStyle(AppHighlightButtonStyle())
        Button("Unavailable") {}.buttonStyle(AppPrimaryButtonStyle()).disabled(true)
        AppCard(style: .danger) {
          Text("Danger ahead. Prepare before entering.").appTextStyle(.paragraph)
        }
      }
      .padding(AppTheme.Layout.screenPadding)
    }
    .appScreenBackground()
    .preferredColorScheme(.dark)
  }
}

#Preview("Compact width") { AppThemeGallery().frame(width: 320) }
#Preview("Standard width") { AppThemeGallery().frame(width: 390) }
#Preview("Large Dynamic Type") {
  AppThemeGallery().frame(width: 390).environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Reduce Motion") {
  AppThemeGallery().frame(width: 390).environment(\.appReducedMotion, true)
}
#endif
