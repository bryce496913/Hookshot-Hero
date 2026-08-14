import SwiftUI

struct MainMenuView: View {
    let play: () -> Void
    let debugPlayLevel: (LevelID) -> Void
    let settings: () -> Void
    let help: () -> Void

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            ScrollView {
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
                    #if DEBUG
                    NavigationLink {
                        DebugLevelSelectView(playLevel: debugPlayLevel)
                    } label: {
                        Label("Debug Level Select", systemImage: "hammer")
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .accessibilityIdentifier("debugLevelSelectButton")
                    #endif
                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, minHeight: 640)
                .padding(.horizontal, 32)
                .safeAreaPadding(.bottom)
            }
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

#if DEBUG
struct DebugLevelSelectView: View {
    let playLevel: (LevelID) -> Void
    private let levels: [(String, LevelID)] = [
        ("Level 1", .levelOne), ("Level 2", .levelTwo), ("Level 3", .levelThree),
        ("Level 4", .levelFour), ("Level 5", .levelFive), ("Level 6", .levelSix),
    ]

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text("Debug Level Select").appTextStyle(.h1).accessibilityAddTraits(.isHeader)
                    Text("Start directly in any implemented level.")
                        .appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.text.opacity(0.7))
                    ForEach(levels, id: \.1) { level in
                        Button(level.0) { playLevel(level.1) }
                            .buttonStyle(AppPrimaryButtonStyle())
                            .accessibilityIdentifier("debug\(level.0.replacingOccurrences(of: " ", with: ""))Button")
                    }
                }.padding(24)
            }
        }
        .navigationTitle("Levels")
        .appNavigationStyle()
    }
}
#endif
