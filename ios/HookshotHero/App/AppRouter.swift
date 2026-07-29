import Combine
import Foundation

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published private(set) var activeSession: GameSession?

    func startGame() {
        activeSession?.dispose()
        let session = GameSession()
        activeSession = session
        path = [.gameplay]
        AppLog.navigation.info("Started a new gameplay session")
    }

    func showSettings() { path.append(.settings) }
    func showHelp() { path.append(.help) }
    func dismiss() { if !path.isEmpty { path.removeLast() } }

    func returnToMenu() {
        activeSession?.dispose()
        activeSession = nil
        path.removeAll()
        AppLog.navigation.info("Returned to the main menu")
    }
}
