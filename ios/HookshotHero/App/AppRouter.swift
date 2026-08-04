import Combine
import Foundation
import OSLog

struct GameStartConfiguration: Sendable {
  let initialLevelID: LevelID
  static let current = Self(initialLevelID: .levelOne)
}
struct GameLoadingRequestID: Hashable, Sendable { let rawValue: UUID }
struct GameLoadingFailurePresentation: Hashable, Sendable {
  let requestID: GameLoadingRequestID
  let requestedLevelID: LevelID
  let title: String
  let message: String
  let recoverySuggestion: String
  let diagnosticCode: String
}
protocol GameLoadingLogging {
  func loadingFailed(levelID: LevelID, error: GameLoadingError, isRetry: Bool)
}
struct AppGameLoadingLogger: GameLoadingLogging {
  func loadingFailed(levelID: LevelID, error: GameLoadingError, isRetry: Bool) {
    AppLog.session.error(
      "Level construction failed; level=\(levelID.rawValue,privacy:.public) category=\(error.diagnosticCode,privacy:.public) retry=\(isRetry,privacy:.public) diagnostic=\(error.localizedDescription,privacy:.public)"
    )
  }
}

@MainActor final class AppRouter: ObservableObject {
  @Published var path: [AppRoute] = []
  @Published private(set) var activeSession: GameSession?
  private let progressionStore: ProgressionStore
  private var sessionObservation: AnyCancellable?
  private var completedSessionIDs: Set<UUID> = []
  private let forcedOutcome: GameOutcome?
  private let simulationFactory: any GameSimulationFactory
  private let levelSeed: UInt64?
  private let startConfiguration: GameStartConfiguration
  private let logger: any GameLoadingLogging
  private var gameConfiguration = GameConfiguration(reducedMotion: false, controlHintsEnabled: true)
  private var loadingRequestID: GameLoadingRequestID?
  init(
    progressionStore: ProgressionStore, forcedOutcome: GameOutcome? = nil,
    simulationFactory: any GameSimulationFactory = DefaultGameSimulationFactory(),
    levelSeed: UInt64? = nil, startConfiguration: GameStartConfiguration = .current,
    logger: any GameLoadingLogging = AppGameLoadingLogger()
  ) {
    self.progressionStore = progressionStore
    self.forcedOutcome = forcedOutcome
    self.simulationFactory = simulationFactory
    self.levelSeed = levelSeed
    self.startConfiguration = startConfiguration
    self.logger = logger
  }
  func startNewGame(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true)
  ) {
    gameConfiguration = configuration
    startGame(levelID: startConfiguration.initialLevelID)
  }
  func startGame(levelID: LevelID) {
    startGame(levelID: levelID, isRetry: false, requestID: .init(rawValue: UUID()))
  }
  private func startGame(levelID: LevelID, isRetry: Bool, requestID: GameLoadingRequestID) {
    endActiveSession(expectedID: activeSession?.identifier)
    loadingRequestID = requestID
    path.removeAll()
    do {
      let simulation = try simulationFactory.makeSimulation(
        levelID: levelID, configuration: gameConfiguration, seed: levelSeed)
      guard loadingRequestID == requestID else {
        simulation.dispose()
        return
      }
      let session = GameSession(
        configuration: gameConfiguration, simulation: simulation,
        publishesDiagnosticPosition: levelSeed != nil)
      activeSession = session
      observe(session)
      guard session.initializeWorld(), session.start() else {
        simulation.dispose()
        activeSession = nil
        handle(
          .invalidInitialState(levelID), levelID: levelID, isRetry: isRetry, requestID: requestID)
        return
      }
      loadingRequestID = nil
      path = [.gameplay]
    } catch {
      guard loadingRequestID == requestID else { return }
      handle(
        error as? GameLoadingError ?? .invalidLevelDefinition(levelID), levelID: levelID,
        isRetry: isRetry, requestID: requestID)
    }
  }
  func retryLoading(_ failure: GameLoadingFailurePresentation) {
    guard loadingRequestID == failure.requestID, path == [.gameLoadingFailure(failure)] else {
      return
    }
    path.removeAll()
    startGame(levelID: failure.requestedLevelID, isRetry: true, requestID: .init(rawValue: UUID()))
  }
  private func handle(
    _ error: GameLoadingError, levelID: LevelID, isRetry: Bool, requestID: GameLoadingRequestID
  ) {
    activeSession = nil
    logger.loadingFailed(levelID: levelID, error: error, isRetry: isRetry)
    let p = GameLoadingFailurePresentation(
      requestID: requestID, requestedLevelID: levelID, title: "Unable to Load Level",
      message: "The requested level “\(levelID.rawValue)” could not be loaded.",
      recoverySuggestion: "Retry, or return to the main menu.", diagnosticCode: error.diagnosticCode
    )
    loadingRequestID = requestID
    path = [.gameLoadingFailure(p)]
  }
  func startGame(session: GameSession) {
    endActiveSession(expectedID: activeSession?.identifier)
    loadingRequestID = nil
    activeSession = session
    observe(session)
    guard session.initializeWorld(), session.start() else {
      path = [.gameplay]
      return
    }
    path = [.gameplay]
  }
  func showSettings() { path.append(.settings) }
  func showHelp() { path.append(.help) }
  func dismiss() { if !path.isEmpty { path.removeLast() } }
  func applicationDidBecomeInactive() { activeSession?.applicationDidBecomeInactive() }
  func applicationDidBecomeActive() { activeSession?.applicationDidBecomeActive() }
  func returnToMenu() {
    loadingRequestID = nil
    endActiveSession(expectedID: activeSession?.identifier)
    path.removeAll()
  }
  func finishGame(sessionID: UUID, outcome: GameOutcome) {
    guard let session = activeSession, session.identifier == sessionID,
      !completedSessionIDs.contains(sessionID)
    else { return }
    let expected: GameSessionState = outcome == .won ? .won : .lost
    guard session.state == expected else { return }
    completedSessionIDs.insert(sessionID)
    let result = GameResult(
      sessionID: sessionID, levelID: session.levelID, missionID: session.missionID,
      score: session.score, elapsedTime: session.elapsedTime, outcome: outcome)
    progressionStore.record(result: result)
    endActiveSession(expectedID: sessionID)
    path = [.results(result)]
  }
  private func observe(_ session: GameSession) {
    let id = session.identifier
    sessionObservation = session.$state.sink { [weak self] state in
      guard state == .won || state == .lost else {
        if state == .running, let outcome = self?.forcedOutcome {
          #if DEBUG
            outcome == .won ? session.win() : session.lose()
          #endif
        }
        return
      }
      self?.finishGame(sessionID: id, outcome: state == .won ? .won : .lost)
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
