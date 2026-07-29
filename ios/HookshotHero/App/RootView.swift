import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @ObservedObject var router: AppRouter
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        NavigationStack(path: $router.path) {
            MainMenuView(
                play: { router.startGame(configuration: settingsStore.configuration(systemReduceMotion: systemReduceMotion)) },
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
                case .results(let result):
                    ResultsView(result: result, returnToMenu: router.returnToMenu)
                }
            }
        }
    }
}
