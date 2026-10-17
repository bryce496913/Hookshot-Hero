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
  let transitionRequest: LevelTransitionRequest?
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
  private var progressionObservation: AnyCancellable?
  var isLevelSelectUnlocked: Bool {
    progressionStore.progression.completedLevelIDs.contains(.levelTen)
  }
  var highScoreEntries: [HighScoreEntry] { progressionStore.progression.highScoreEntries }
  var highScoreSavePending: Bool { progressionStore.hasUnsavedChanges }
  func retryHighScoreSave() { progressionStore.flushPendingSave() }
  private var sessionObservation: AnyCancellable?
  private var completedSessionIDs: Set<UUID> = []
  private let forcedOutcome: GameOutcome?
  private let runtimeFactory: any GameLevelRuntimeFactory
  private let levelSeed: UInt64?
  private let startConfiguration: GameStartConfiguration
  private let logger: any GameLoadingLogging
  private var gameConfiguration = GameConfiguration(reducedMotion: false, controlHintsEnabled: true)
  private var pendingStartEligibility = false
  private var loadingRequestID: GameLoadingRequestID?
  init(
    progressionStore: ProgressionStore, forcedOutcome: GameOutcome? = nil,
    simulationFactory: any GameSimulationFactory = DefaultGameSimulationFactory(),
    runtimeFactory: (any GameLevelRuntimeFactory)? = nil,
    levelSeed: UInt64? = nil, startConfiguration: GameStartConfiguration = .current,
    logger: any GameLoadingLogging = AppGameLoadingLogger()
  ) {
    self.progressionStore = progressionStore
    self.forcedOutcome = forcedOutcome
    self.runtimeFactory =
      runtimeFactory ?? DefaultGameLevelRuntimeFactory(simulationFactory: simulationFactory)
    self.levelSeed = levelSeed
    self.startConfiguration = startConfiguration
    self.logger = logger
    // Forward nested progression changes even when the navigation path stays unchanged.
    progressionObservation = progressionStore.objectWillChange.sink { [weak self] _ in
      self?.objectWillChange.send()
    }
  }
  func startNewGame(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true)
  ) {
    gameConfiguration = configuration
    var eligible = startConfiguration.initialLevelID == .levelOne && forcedOutcome == nil
    #if DEBUG
      // Explicit direct-level environment fixtures must never masquerade as normal Play.
      if ProcessInfo.processInfo.environment["HOOKSHOT_START_LEVEL"] != nil { eligible = false }
    #endif
    startGame(levelID: startConfiguration.initialLevelID, isRetry: false,
              requestID: .init(rawValue: UUID()), leaderboardEligible: eligible)
  }
  func startGame(levelID: LevelID) {
    startGame(levelID: levelID, isRetry: false, requestID: .init(rawValue: UUID()))
  }
  func setGameConfiguration(_ configuration: GameConfiguration) {
    gameConfiguration = configuration
  }
  private func startGame(levelID: LevelID, isRetry: Bool, requestID: GameLoadingRequestID,
                         leaderboardEligible: Bool = false) {
    endActiveSession(expectedID: activeSession?.identifier)
    pendingStartEligibility = leaderboardEligible
    loadingRequestID = requestID
    path.removeAll()
    do {
      let runtime = try runtimeFactory.makeRuntime(
        levelID: levelID, configuration: gameConfiguration, seed: levelSeed)
      guard loadingRequestID == requestID else {
        runtime.simulation.dispose()
        return
      }
      let session = GameSession(
        configuration: gameConfiguration, runtime: runtime,
        publishesDiagnosticPosition: levelSeed != nil, isLeaderboardEligible: leaderboardEligible)
      guard session.initializeWorld(), session.start() else {
        session.dispose()
        handle(
          .invalidInitialState(levelID), levelID: levelID, isRetry: isRetry, requestID: requestID)
        return
      }
      #if DEBUG
        if levelID == .levelFour,
          let fixture = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("--level-four-transition=")
          }),
          let simulation = session.simulation as? LevelFourSimulation
        {
          switch fixture {
          case "--level-four-transition=right":
            simulation.prepareForTransitionUITest(exit: .right)
          case "--level-four-transition=top":
            simulation.prepareForTransitionUITest(exit: .top)
          default:
            break
          }
        }
      #endif
      activeSession = session
      observe(session)
      pendingStartEligibility = false
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
    if let request = failure.transitionRequest, let session = activeSession {
      let retryID = GameLoadingRequestID(rawValue: UUID())
      loadingRequestID = retryID
      performTransition(request, for: session, isRetry: true, requestID: retryID)
    } else {
      startGame(
        levelID: failure.requestedLevelID, isRetry: true, requestID: .init(rawValue: UUID()),
        leaderboardEligible: pendingStartEligibility)
    }
  }
  private func handle(
    _ error: GameLoadingError, levelID: LevelID, isRetry: Bool, requestID: GameLoadingRequestID,
    transitionRequest: LevelTransitionRequest? = nil, clearActiveSession: Bool = true
  ) {
    if clearActiveSession {
      sessionObservation?.cancel()
      sessionObservation = nil
      activeSession = nil
    }
    logger.loadingFailed(levelID: levelID, error: error, isRetry: isRetry)
    let p = GameLoadingFailurePresentation(
      requestID: requestID, requestedLevelID: levelID, title: "Unable to Load Level",
      message: "The requested level “\(levelID.rawValue)” could not be loaded.",
      recoverySuggestion: "Retry, or return to the main menu.",
      diagnosticCode: error.diagnosticCode,
      transitionRequest: transitionRequest
    )
    loadingRequestID = requestID
    path = [.gameLoadingFailure(p)]
  }
  func startGame(session: GameSession) {
    pendingStartEligibility = false
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
  func showHighScores() { path.append(.highScores) }
  func dismiss() { if !path.isEmpty { path.removeLast() } }
  func applicationDidBecomeInactive() { activeSession?.applicationDidBecomeInactive() }
  func applicationDidEnterBackground() {
    activeSession?.applicationDidBecomeInactive()
    progressionStore.flushPendingSave()
  }
  func applicationDidBecomeActive() { activeSession?.applicationDidBecomeActive() }
  func returnToMenu() {
    pendingStartEligibility = false
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
    var result = GameResult(
      sessionID: sessionID, levelID: session.levelID, missionID: session.missionID,
      score: session.score, elapsedTime: session.elapsedTime, outcome: outcome)
    progressionStore.record(result: result)
    if session.hasNaturalTerminalOutcome && forcedOutcome == nil {
      attachScoreCandidate(to: &result, fullCampaignVictory: session.isLeaderboardEligible)
    }
    endActiveSession(expectedID: sessionID)
    path = [.results(result)]
  }
  private func attachScoreCandidate(to result: inout GameResult, fullCampaignVictory: Bool) {
    guard let candidate = HighScoreCandidate.terminalResult(result, fullCampaignVictory: fullCampaignVictory) else { return }
    result.highScoreCandidate = candidate
    result.leaderboardRank = HighScoreScoring.qualifyingRank(candidate: candidate, existingEntries: highScoreEntries)
  }

  /// The route is the authority: stale results, duplicate taps and discarded candidates cannot submit.
  func submitHighScore(sessionID: UUID, initials: String) -> HighScoreEntry? {
    guard case .results(let result) = path.last, result.sessionID == sessionID,
          let candidate = result.highScoreCandidate, result.leaderboardRank != nil else { return nil }
    return progressionStore.submit(candidate: candidate, initials: initials)
  }

  #if DEBUG
  /// Explicit scoring-path fixture; ordinary forced outcomes still cannot create candidates.
  func presentHighScoreFixture(qualifying: Bool) {
    returnToMenu()
    var result = GameResult(sessionID: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
      levelID: .levelSeven, missionID: nil, score: qualifying ? 5000 : 0, elapsedTime: 83.4, outcome: .lost)
    progressionStore.record(result: result)
    attachScoreCandidate(to: &result, fullCampaignVictory: false)
    path = [.results(result)]
  }
  #endif

  private func observe(_ session: GameSession) {
    let id = session.identifier
    sessionObservation = session.$state.sink { [weak self] state in
      if case .transitioning = state, let request = session.pendingTransitionRequest {
        Task { @MainActor [weak self] in self?.performTransition(request, for: session) }
      }
      guard state == .won || state == .lost else {
        if state == .running, let outcome = self?.forcedOutcome {
          #if DEBUG
            outcome == .won ? session.win() : session.lose()
          #endif
        }
        return
      }
      Task { @MainActor [weak self] in
        self?.finishGame(sessionID: id, outcome: state == .won ? .won : .lost)
      }
    }
  }
  private func performTransition(
    _ request: LevelTransitionRequest, for session: GameSession, isRetry: Bool = false,
    requestID: GameLoadingRequestID = .init(rawValue: UUID())
  ) {
    guard activeSession?.identifier == session.identifier else { return }
    do {
      let runtime = try runtimeFactory.makeRuntime(
        levelID: request.destinationLevelID, configuration: gameConfiguration, seed: levelSeed,
        entryPosition: request.destinationEntry, carryover: request.carryover)
      if request.reason == .completedForward {
        progressionStore.record(
          result: GameResult(
            sessionID: session.identifier, levelID: request.sourceLevelID,
            missionID: session.missionID, score: request.carryover.score,
            elapsedTime: session.elapsedTime, outcome: .won))
      }
      session.installRuntime(runtime)
      loadingRequestID = nil
      path = [.gameplay]
    } catch {
      handle(
        error as? GameLoadingError ?? .invalidLevelDefinition(request.destinationLevelID),
        levelID: request.destinationLevelID, isRetry: isRetry, requestID: requestID,
        transitionRequest: request, clearActiveSession: false)
    }
  }
  private func endActiveSession(expectedID: UUID?) {
    sessionObservation?.cancel()
    sessionObservation = nil
    guard let session = activeSession, session.identifier == expectedID else { return }
    session.dispose()
    activeSession = nil
  }
}
