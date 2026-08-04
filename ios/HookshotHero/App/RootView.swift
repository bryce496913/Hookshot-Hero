import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var router: AppRouter
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        NavigationStack(path: $router.path) {
            MainMenuView(
                play: { router.startNewGame(configuration: settingsStore.configuration(systemReduceMotion: systemReduceMotion)) },
                settings: router.showSettings,
                help: router.showHelp
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .gameplay:
                    if let session = router.activeSession {
                        GameplayView(session: session, returnToMenu: router.returnToMenu)
                    } else {
                        ContentUnavailableView("Session unavailable", systemImage: "exclamationmark.triangle")
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
    }
}

struct GameLoadingFailureView: View {
    let failure: GameLoadingFailurePresentation; let retry: () -> Void; let returnToMenu: () -> Void
    var body: some View { ContentUnavailableView { Label(failure.title, systemImage: "exclamationmark.triangle") } description: { VStack { Text(failure.message); Text(failure.recoverySuggestion) } } actions: { Button("Retry", action: retry).buttonStyle(.borderedProminent).accessibilityIdentifier("retryLevelButton"); Button("Return to Menu", action: returnToMenu).accessibilityIdentifier("loadingFailureMenuButton") }.navigationBarBackButtonHidden() }
}
