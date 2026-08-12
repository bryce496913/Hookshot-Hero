import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var router: AppRouter
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        NavigationStack(path: $router.path) {
            MainMenuView(
                play: { router.startNewGame(configuration: settingsStore.configuration(systemReduceMotion: systemReduceMotion)) },
                debugPlayLevel: { levelID in
                    router.setGameConfiguration(settingsStore.configuration(systemReduceMotion: systemReduceMotion))
                    router.startGame(levelID: levelID)
                },
                settings: router.showSettings,
                help: router.showHelp
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .gameplay:
                    if let session = router.activeSession {
                        GameplayView(session: session, returnToMenu: router.returnToMenu)
                    } else {
                        ContentUnavailableView {
                            Label("Session unavailable", systemImage: "exclamationmark.triangle")
                                .appTextStyle(.h1)
                        } description: {
                            Text("Return to the main menu and start a new run.").appTextStyle(.paragraph)
                        }
                        .appScreenBackground()
                        .appNavigationStyle()
                    }
                case .settings:
                    SettingsView(store: settingsStore, dismiss: router.dismiss)
                case .help:
                    HelpView(dismiss: router.dismiss)
                case .gameLoadingFailure(let failure):
                    GameLoadingFailureView(failure: failure, retry: { router.retryLoading(failure) }, returnToMenu: router.returnToMenu)
                case .results(let result):
                    ResultsView(result: result, returnToMenu: router.returnToMenu)
                }
            }
        }
        .tint(AppTheme.Colors.accent)
    }
}

struct GameLoadingFailureView: View {
    let failure: GameLoadingFailurePresentation
    let retry: () -> Void
    let returnToMenu: () -> Void

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.highlight)
                    .accessibilityHidden(true)
                Text(failure.title)
                    .appTextStyle(.h1)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(failure.message)
                    .appTextStyle(.paragraph)
                    .multilineTextAlignment(.center)
                Text(failure.recoverySuggestion)
                    .appTextStyle(.paragraph)
                    .foregroundStyle(AppTheme.Colors.text.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button("Retry", action: retry)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .accessibilityIdentifier("retryLevelButton")
                Button("Return to Menu", action: returnToMenu)
                    .buttonStyle(AppSecondaryButtonStyle())
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.Colors.highlight, lineWidth: 1))
                    .accessibilityIdentifier("loadingFailureMenuButton")
            }
            .padding(20)
            .appSurface()
            .padding(24)
        }
        .navigationBarBackButtonHidden()
        .appNavigationStyle()
    }
}
