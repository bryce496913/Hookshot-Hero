import Combine
import Foundation

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published private(set) var activeSession: GameSession?
    private let progressionStore: ProgressionStore
    private var sessionObservation: AnyCancellable?
    private var completedSessionIDs: Set<UUID> = []
    private let forcedOutcome: GameOutcome?

    init(progressionStore: ProgressionStore, forcedOutcome: GameOutcome? = nil) {
        self.progressionStore = progressionStore
        self.forcedOutcome = forcedOutcome
    }

    func startGame(configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true)) {
        endActiveSession(expectedID: activeSession?.identifier)
        let session = GameSession(configuration: configuration)
        activeSession = session
        observe(session)
        path = [.gameplay]
    }

    func showSettings() { path.append(.settings) }
    func showHelp() { path.append(.help) }
    func dismiss() { if !path.isEmpty { path.removeLast() } }

    func applicationDidBecomeInactive() { activeSession?.applicationDidBecomeInactive() }
    func applicationDidBecomeActive() { activeSession?.applicationDidBecomeActive() }

    func returnToMenu() {
        endActiveSession(expectedID: activeSession?.identifier)
        path.removeAll()
    }

    func finishGame(sessionID: UUID, outcome: GameOutcome) {
        guard let session = activeSession,
              session.identifier == sessionID,
              !completedSessionIDs.contains(sessionID) else { return }
        let expectedState: GameSessionState = outcome == .won ? .won : .lost
        guard session.state == expectedState else { return }
        completedSessionIDs.insert(sessionID)
        let result = GameResult(sessionID: sessionID, levelID: session.levelID,
                                missionID: session.missionID, score: session.score,
                                elapsedTime: session.elapsedTime, outcome: outcome)
        progressionStore.record(result: result)
        endActiveSession(expectedID: sessionID)
        path = [.results(result)]
    }

    private func observe(_ session: GameSession) {
        let sessionID = session.identifier
        sessionObservation = session.$state.sink { [weak self] state in
            guard state == .won || state == .lost else {
                if state == .running, let outcome = self?.forcedOutcome {
                    #if DEBUG
                    outcome == .won ? session.win() : session.lose()
                    #endif
                }
                return
            }
            self?.finishGame(sessionID: sessionID, outcome: state == .won ? .won : .lost)
        }
    }

    private func endActiveSession(expectedID: UUID?) {
        guard let session = activeSession, session.identifier == expectedID else { return }
        sessionObservation?.cancel()
        sessionObservation = nil
        session.dispose()
        activeSession = nil
    }
}
