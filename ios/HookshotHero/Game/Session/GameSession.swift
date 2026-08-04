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
    let identifier: UUID; let configuration: GameConfiguration; let simulation: LevelOneSimulation?
    @Published private(set) var levelID: LevelID; @Published private(set) var missionID: MissionID?
    @Published private(set) var score = 0; @Published private(set) var health = 3
    @Published private(set) var elapsedTime: TimeInterval = 0; @Published private(set) var state: GameSessionState = .loading
    @Published private(set) var initializationError: String?
    private(set) var pauseReason: PauseReason?; private var applicationIsActive = true
    init(identifier: UUID = UUID(), levelID: LevelID = .init(rawValue: "level-1"), missionID: MissionID? = nil,
         configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true), seed: UInt64? = nil, entities: [WorldEntity]? = nil) {
        self.identifier = identifier; self.levelID = levelID; self.missionID = missionID; self.configuration = configuration
        do { simulation = try LevelOneSimulation(seed: seed ?? UInt64.random(in: 1...UInt64.max), entities: entities) }
        catch { simulation = nil; initializationError = error.localizedDescription }
        simulation?.onStatusChange = { [weak self] status in self?.synchronize(status: status) }
        simulation?.onOutcome = { [weak self] outcome in if outcome == .won { self?.win() } else { self?.lose() } }
        simulation?.onDialogue = { [weak self] message in self?.openDialogue(message) }
    }
    var isPaused: Bool { state == .paused }; var canSimulate: Bool { state == .running && applicationIsActive }
    var dialogue: String? { if case .dialogue(let message) = state { message } else { nil } }
    @discardableResult func initializeWorld() -> Bool { guard state == .loading, simulation != nil else { return false }; state = applicationIsActive ? .initialized : .paused; if !applicationIsActive { pauseReason = .applicationLifecycle }; return true }
    @discardableResult func start() -> Bool { guard state == .initialized, applicationIsActive else { return false }; pauseReason = nil; state = .running; return true }
    @discardableResult func pause(reason: PauseReason = .user) -> Bool { guard state == .running else{return false}; simulation?.cancelAllInput(); pauseReason = reason; state = .paused; return true }
    @discardableResult func resume() -> Bool { guard state == .paused, applicationIsActive else{return false}; pauseReason = nil; state = .running; return true }
    func applicationDidBecomeInactive(){ guard !isTerminal else{return}; applicationIsActive = false; simulation?.cancelAllInput(); if state == .running || state == .initialized { pauseReason = .applicationLifecycle; state = .paused } }
    func applicationDidBecomeActive(){ guard !isTerminal else{return}; applicationIsActive = true }
    func advance(by dt: TimeInterval){ guard canSimulate else{return}; let delta = max(dt,0); elapsedTime += delta; simulation?.update(deltaTime: delta) }
    func addScore(_ points:Int){ guard canSimulate else{return}; score += max(points,0) }
    func openDialogue(_ message:String){ guard state == .running else{return}; simulation?.cancelAllInput(); state = .dialogue(message) }
    @discardableResult func continueDialogue()->Bool { guard case .dialogue = state, applicationIsActive else{return false}; state = .running; return true }
    func win(){ if state == .running { simulation?.cancelAllInput(); state = .won } }; func lose(){ if state == .running { simulation?.cancelAllInput(); state = .lost } }
    func dispose(){ guard state != .disposed else{return}; simulation?.cancelAllInput(); pauseReason = nil; if !isTerminal { state = .disposed } }
    func synchronize(status: PlayerStatusSnapshot) {
        if health != status.health { health = status.health }
        if score != status.score { score = status.score }
    }
    private var isTerminal:Bool { state == .won || state == .lost || state == .disposed }
}
