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
        let settings = SettingsStore(repository: environment.settingsRepository)
        let audio = GameAudioService(backend: AVGameAudioBackend(), settings: settings.settings)
        let router = AppRouter(progressionStore: progressionStore,
                               forcedOutcome: environment.forcedOutcome,
                               levelSeed: environment.levelSeed,
                               startConfiguration: environment.startConfiguration,
                               audioService: audio)
        router.bindAudioSettings(settings)
        _router = StateObject(wrappedValue: router)
        _settingsStore = StateObject(wrappedValue: settings)
    }

    var body: some Scene {
        WindowGroup {
            RootView(router: router, settingsStore: settingsStore)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active: router.applicationDidBecomeActive()
                    case .inactive: router.applicationDidBecomeInactive()
                    case .background: router.applicationDidEnterBackground()
                    @unknown default: router.applicationDidBecomeInactive()
                    }
                }
        }
    }
}
