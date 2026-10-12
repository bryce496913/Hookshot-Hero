import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var initializedStateFixture = false
    @ObservedObject var router: AppRouter
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        NavigationStack(path: $router.path) {
            MainMenuView(
                play: { router.startNewGame(configuration: settingsStore.configuration(systemReduceMotion: systemReduceMotion)) },
                playLevel: { levelID in
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
                        GameplayView(
                            session: session,
                            controlLayout: settingsStore.settings.controlLayout,
                            returnToMenu: router.returnToMenu)
                    } else {
                        SessionUnavailableView(returnToMenu: router.returnToMenu)
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
        .foregroundStyle(AppTheme.Colors.text)
        .preferredColorScheme(.dark)
        .environment(\.appReducedMotion, settingsStore.settings.reducedMotion)
        .onAppear(perform: initializeStateFixture)
    }
    private func initializeStateFixture() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard !initializedStateFixture, arguments.contains("--ui-testing") else { return }
        initializedStateFixture = true
        if arguments.contains("--preview-loading-failure") {
            // Exercise the real unsupported request/retry path; never substitute another level.
            router.startGame(levelID: LevelID(rawValue: "ui-test-unsupported-level"))
        } else if arguments.contains("--preview-session-unavailable") {
            router.path = [.gameplay]
        }
        #endif
    }

}

struct GameLoadingFailureView: View {
    let failure: GameLoadingFailurePresentation
    let retry: () -> Void
    let returnToMenu: () -> Void

    var body: some View {
        AppStateScreen {
            AppCard(style: .elevated) {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .appTextStyle(.heroTitle).foregroundStyle(AppTheme.Colors.accent)
                        .accessibilityHidden(true)
                    Text(failure.title).appTextStyle(.h1).accessibilityAddTraits(.isHeader)
                    Text(failure.message).appTextStyle(.paragraph)
                    Text(failure.recoverySuggestion).appTextStyle(.paragraph)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    #if DEBUG
                    Text("Diagnostic code: \(failure.diagnosticCode)")
                        .appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textMuted)
                        .accessibilityIdentifier("loadingFailureDiagnosticCode")
                    #endif
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            Button("Retry", action: retry).buttonStyle(AppPrimaryButtonStyle())
                .accessibilityIdentifier("retryLevelButton")
            Button("Return to Menu", action: returnToMenu).buttonStyle(AppSecondaryButtonStyle())
                .accessibilityIdentifier("loadingFailureMenuButton")
        }
    }
}

struct SessionUnavailableView: View {
    let returnToMenu: () -> Void

    var body: some View {
        AppStateScreen {
            AppCard(style: .elevated) {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "scope").appTextStyle(.heroTitle)
                        .foregroundStyle(AppTheme.Colors.accent).accessibilityHidden(true)
                    Text("Session unavailable").appTextStyle(.h1).accessibilityAddTraits(.isHeader)
                    Text("Return to the main menu and start a new run.")
                        .appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            Button("Return to Menu", action: returnToMenu).buttonStyle(AppPrimaryButtonStyle())
                .accessibilityIdentifier("sessionUnavailableMenuButton")
        }
        .accessibilityIdentifier("sessionUnavailableScreen")
    }
}
