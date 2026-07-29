import Combine
import Foundation

struct LevelID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }
struct MissionID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }
struct UnlockID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }

struct GameConfiguration: Equatable, Sendable {
    let reducedMotion: Bool
    let controlHintsEnabled: Bool
}

enum GameOutcome: Equatable, Sendable { case won, lost }
enum GameSessionState: Equatable, Sendable { case loading, initialized, running, paused, won, lost, disposed }
enum PauseReason: Equatable, Sendable { case user, applicationLifecycle }

@MainActor
final class GameSession: ObservableObject {
    let identifier: UUID
    let configuration: GameConfiguration
    @Published private(set) var levelID: LevelID
    @Published private(set) var missionID: MissionID?
    @Published private(set) var score = 0
    @Published private(set) var health = 3
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var state: GameSessionState = .loading
    private(set) var pauseReason: PauseReason?
    private var applicationIsActive = true

    init(
        identifier: UUID = UUID(),
        levelID: LevelID = .init(rawValue: "level-1"),
        missionID: MissionID? = nil,
        configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true)
    ) {
        self.identifier = identifier
        self.levelID = levelID
        self.missionID = missionID
        self.configuration = configuration
    }

    var isPaused: Bool { state == .paused }
    var canSimulate: Bool { state == .running && applicationIsActive }

    @discardableResult func initializeWorld() -> Bool {
        guard state == .loading else { return false }
        if applicationIsActive {
            state = .initialized
        } else {
            pauseReason = .applicationLifecycle
            state = .paused
        }
        return true
    }

    @discardableResult func start() -> Bool {
        guard state == .initialized, applicationIsActive else { return false }
        pauseReason = nil
        state = .running
        return true
    }

    @discardableResult func pause(reason: PauseReason = .user) -> Bool {
        guard state == .running else { return false }
        pauseReason = reason
        state = .paused
        return true
    }

    @discardableResult func resume() -> Bool {
        guard state == .paused, applicationIsActive else { return false }
        pauseReason = nil
        state = .running
        return true
    }

    func applicationDidBecomeInactive() {
        guard !isTerminal else { return }
        applicationIsActive = false
        if state == .running { _ = pause(reason: .applicationLifecycle) }
    }

    func applicationDidBecomeActive() {
        guard !isTerminal else { return }
        applicationIsActive = true
        // Application lifecycle suspension always requires an explicit user resume.
    }

    func advance(by deltaTime: TimeInterval) {
        guard canSimulate else { return }
        elapsedTime += max(deltaTime, 0)
    }

    func addScore(_ points: Int) { guard canSimulate else { return }; score += max(points, 0) }
    func win() { if state == .running { state = .won } }
    func lose() { if state == .running { state = .lost } }

    func dispose() {
        guard state != .disposed else { return }
        pauseReason = nil
        state = .disposed
    }

    private var isTerminal: Bool { [.won, .lost, .disposed].contains(state) }
}
