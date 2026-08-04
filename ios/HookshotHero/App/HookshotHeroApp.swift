import SwiftUI

@main
struct HookshotHeroApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router: AppRouter
    @StateObject private var settingsStore: SettingsStore

    @MainActor
    init() {
        let environment = AppEnvironment.current()
        let progressionStore = ProgressionStore(repository: environment.progressionRepository)
        _router = StateObject(wrappedValue: AppRouter(progressionStore: progressionStore,
                                                       forcedOutcome: environment.forcedOutcome,
                                                       levelSeed: environment.levelSeed))
        _settingsStore = StateObject(wrappedValue: SettingsStore(repository: environment.settingsRepository))
    }

    var body: some Scene {
        WindowGroup {
            RootView(router: router, settingsStore: settingsStore)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: router.applicationDidBecomeActive()
                    case .inactive, .background: router.applicationDidBecomeInactive()
                    @unknown default: router.applicationDidBecomeInactive()
                    }
                }
        }
    }
}
