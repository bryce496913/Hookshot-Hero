import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color.black
        static let surface = Color(red: 0.12, green: 0.04, blue: 0.2)
        static let accent = Color(red: 0.72, green: 0.29, blue: 0.95)
        static let highlight = Color(red: 0.98, green: 0.32, blue: 0.67)
        static let text = Color.white
    }
}

enum AppTextStyle: Sendable, CaseIterable {
    case h1
    case h2
    case h3
    case paragraph

    var size: CGFloat {
        switch self {
        case .h1:
            return 16
        case .h2:
            return 14
        case .h3:
            return 12
        case .paragraph:
            return 10
        }
    }

    var weight: Font.Weight {
        switch self {
        case .h1:
            return .bold
        case .h2:
            return .semibold
        case .h3:
            return .medium
        case .paragraph:
            return .regular
        }
    }

    var font: Font { .system(size: size, weight: weight, design: .rounded) }
}

struct AppTextStyleModifier: ViewModifier {
    let style: AppTextStyle

    func body(content: Content) -> some View {
        content.font(style.font).foregroundStyle(AppTheme.Colors.text)
    }
}

extension View {
    func appTextStyle(_ style: AppTextStyle) -> some View { modifier(AppTextStyleModifier(style: style)) }

    func appScreenBackground() -> some View { background(AppTheme.Colors.background) }

    func appSurface(cornerRadius: CGFloat = 16) -> some View {
        background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func appNavigationStyle() -> some View {
        self
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppTheme.Colors.accent)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appTextStyle(.h3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(AppTheme.Colors.accent.opacity(isEnabled ? (configuration.isPressed ? 0.76 : 1) : 0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.Colors.text.opacity(configuration.isPressed ? 0.55 : 0.18), lineWidth: 1))
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appTextStyle(.h3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(AppTheme.Colors.surface.opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.Colors.accent.opacity(isEnabled ? 1 : 0.35), lineWidth: configuration.isPressed ? 2 : 1))
    }
}

struct AppHighlightButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appTextStyle(.h3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .background(AppTheme.Colors.highlight.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.Colors.text.opacity(0.22), lineWidth: 1))
    }
}
