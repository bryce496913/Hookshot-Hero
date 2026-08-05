import SwiftUI

struct MainMenuView: View {
    let play: () -> Void
    let settings: () -> Void
    let help: () -> Void

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 20)
                VStack(spacing: 12) {
                    Image(systemName: "scope")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.highlight)
                        .accessibilityHidden(true)
                    Text("Hookshot Hero")
                        .appTextStyle(.h1)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Native iOS development build")
                        .appTextStyle(.paragraph)
                        .foregroundStyle(AppTheme.Colors.text.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .appSurface()
                Spacer(minLength: 12)
                menuButton("Play", systemImage: "play.fill", style: .primary, action: play)
                    .accessibilityIdentifier("playButton")
                menuButton("Settings", systemImage: "gearshape", style: .secondary, action: settings)
                    .accessibilityIdentifier("settingsButton")
                menuButton("Help", systemImage: "questionmark.circle", style: .secondary, action: help)
                    .accessibilityIdentifier("helpButton")
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 32)
            .safeAreaPadding(.bottom)
        }
        .navigationBarBackButtonHidden()
        .appNavigationStyle()
        .accessibilityElement(children: .contain)
    }

    private enum MenuButtonStyle { case primary, secondary }

    @ViewBuilder
    private func menuButton(_ title: String, systemImage: String, style: MenuButtonStyle, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) { Label(title, systemImage: systemImage) }
            .accessibilityLabel(title)
        switch style {
        case .primary: button.buttonStyle(AppPrimaryButtonStyle())
        case .secondary: button.buttonStyle(AppSecondaryButtonStyle())
        }
    }
}
