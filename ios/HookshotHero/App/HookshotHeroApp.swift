import SwiftUI

@main
struct HookshotHeroApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = AppRouter()
    @StateObject private var settingsStore = SettingsStore(repository: UserDefaultsSettingsRepository())

    var body: some Scene {
        WindowGroup {
            RootView(router: router, settingsStore: settingsStore)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        AppLog.lifecycle.info("Application became active; gameplay remains deliberately paused")
                    case .inactive, .background:
                        router.activeSession?.pause(reason: .applicationLifecycle)
                        AppLog.lifecycle.info("Application left the active state")
                    @unknown default:
                        router.activeSession?.pause(reason: .applicationLifecycle)
                    }
                }
            }
    }
}
