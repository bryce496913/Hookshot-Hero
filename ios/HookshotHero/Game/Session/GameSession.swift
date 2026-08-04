import Combine
import Foundation

struct LevelID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }
struct MissionID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }
struct UnlockID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }
struct GameConfiguration: Equatable, Sendable { let reducedMotion: Bool; let controlHintsEnabled: Bool }
enum GameOutcome: Equatable, Sendable { case won, lost }
enum GameSessionState: Equatable, Sendable { case loading, initialized, running, dialogue(String), paused, won, lost, disposed }
enum PauseReason: Equatable, Sendable { case user, applicationLifecycle }

@MainActor final class GameSession: ObservableObject {
    let identifier: UUID
    let configuration: GameConfiguration
    let simulation: any GameSimulation
    let levelID: LevelID
    let missionID: MissionID?

    @Published private(set) var uiSnapshot: GameplayUISnapshot
    @Published private(set) var state: GameSessionState = .loading
    let initializationError: String? = nil
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var pauseReason: PauseReason?
    private var applicationIsActive = true
    private let publishesDiagnosticPosition: Bool
    private var disposedSimulation = false

    init(identifier: UUID = UUID(), missionID: MissionID? = nil,
         configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
         simulation: any GameSimulation, publishesDiagnosticPosition: Bool = false) {
        self.identifier = identifier
        self.missionID = missionID
        self.configuration = configuration
        self.simulation = simulation
        self.levelID = simulation.levelID
        self.publishesDiagnosticPosition = publishesDiagnosticPosition
        self.uiSnapshot = simulation.uiSnapshot
        bindSimulation()
        refreshUISnapshot()
    }

    convenience init(identifier: UUID = UUID(), levelID: LevelID = .init(rawValue: "level-1"), missionID: MissionID? = nil,
                     configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true), seed: UInt64? = nil,
                     publishesDiagnosticPosition: Bool = false) {
        let simulation = try! DefaultGameSimulationFactory().makeSimulation(
            levelID: levelID, configuration: configuration, seed: seed
        )
        self.init(identifier: identifier, missionID: missionID, configuration: configuration,
                  simulation: simulation, publishesDiagnosticPosition: publishesDiagnosticPosition)
    }

    var score: Int { simulation.finalStatus.score }
    var health: Int { simulation.finalStatus.health }
    var isPaused: Bool { state == .paused }
    var canSimulate: Bool { state == .running && applicationIsActive }
    var dialogue: String? { if case .dialogue(let message) = state { message } else { nil } }

    @discardableResult func initializeWorld() -> Bool {
        guard state == .loading else { return false }
        state = applicationIsActive ? .initialized : .paused
        if !applicationIsActive { pauseReason = .applicationLifecycle; simulation.setPaused(true) }
        refreshUISnapshot()
        return true
    }

    @discardableResult func start() -> Bool {
        guard state == .initialized, applicationIsActive else { return false }
        pauseReason = nil; state = .running; simulation.setPaused(false); refreshUISnapshot(); return true
    }

    @discardableResult func pause(reason: PauseReason = .user) -> Bool {
        guard state == .running else { return false }
        simulation.setPaused(true); pauseReason = reason; state = .paused; refreshUISnapshot(); return true
    }

    @discardableResult func resume() -> Bool {
        guard state == .paused, applicationIsActive else { return false }
        pauseReason = nil; state = .running; simulation.setPaused(false); refreshUISnapshot(); return true
    }

    func applicationDidBecomeInactive() {
        guard !isTerminal else { return }
        applicationIsActive = false; simulation.cancelAllInput()
        if state == .running || state == .initialized { pauseReason = .applicationLifecycle; state = .paused; simulation.setPaused(true); refreshUISnapshot() }
    }
    func applicationDidBecomeActive() { guard !isTerminal else { return }; applicationIsActive = true }

    func advance(by dt: TimeInterval) {
        guard canSimulate else { return }
        let delta = max(dt, 0); elapsedTime += delta; simulation.update(deltaTime: delta)
        if publishesDiagnosticPosition { refreshUISnapshot() }
    }

    func openDialogue(_ message: String) {
        guard state == .running else { return }
        simulation.cancelAllInput(); state = .dialogue(message); refreshUISnapshot()
    }
    @discardableResult func continueDialogue() -> Bool {
        guard case .dialogue = state, applicationIsActive else { return false }
        simulation.continueDialogue(); state = .running; refreshUISnapshot(); return true
    }

    func win() { transitionToTerminal(.won) }
    func lose() { transitionToTerminal(.lost) }

    func dispose() {
        guard state != .disposed else { return }
        if !disposedSimulation { disposedSimulation = true; simulation.dispose() }
        pauseReason = nil
        if !isTerminal { state = .disposed; refreshUISnapshot() }
    }

    private func bindSimulation() {
        simulation.onUISnapshotChange = { [weak self] _ in self?.refreshUISnapshot() }
        simulation.onOutcome = { [weak self] outcome in self?.transitionToTerminal(outcome) }
        simulation.onDialogue = { [weak self] message in self?.openDialogue(message) }
    }

    private func transitionToTerminal(_ outcome: GameOutcome) {
        guard state == .running else { return }
        simulation.cancelAllInput(); state = outcome == .won ? .won : .lost; refreshUISnapshot()
    }

    private func refreshUISnapshot() {
        let base = simulation.uiSnapshot
        let snapshot = GameplayUISnapshot(
            levelID: base.levelID, levelName: base.levelName, health: base.health,
            maximumHealth: base.maximumHealth, score: base.score,
            canMove: canSimulate && dialogue == nil && simulation.outcome == nil,
            canGrapple: canSimulate && dialogue == nil && base.canGrapple && simulation.outcome == nil,
            isPaused: isPaused, dialogue: dialogue, feedback: base.feedback,
            diagnosticPlayerPosition: publishesDiagnosticPosition ? simulation.renderSnapshot.player.position : nil
        )
        guard snapshot != uiSnapshot else { return }
        uiSnapshot = snapshot
    }

    private var isTerminal: Bool { state == .won || state == .lost || state == .disposed }
}
