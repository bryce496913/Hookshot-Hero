import Combine
import Foundation

struct LevelID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }
struct MissionID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }
struct UnlockID: RawRepresentable, Codable, Hashable, Sendable { let rawValue: String }

enum GameSessionState: Equatable, Sendable {
    case loading, initialized, running, paused, won, lost, disposed
}

enum PauseReason: Sendable { case user, applicationLifecycle }

@MainActor
final class GameSession: ObservableObject {
    let identifier: UUID
    @Published private(set) var levelID: LevelID
    @Published private(set) var missionID: MissionID?
    @Published private(set) var score = 0
    @Published private(set) var health = 3
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var state: GameSessionState = .loading

    init(identifier: UUID = UUID(), levelID: LevelID = .init(rawValue: "level-1"), missionID: MissionID? = nil) {
        self.identifier = identifier
        self.levelID = levelID
        self.missionID = missionID
    }

    var isPaused: Bool { state == .paused }
    var didWin: Bool { state == .won }
    var didLose: Bool { state == .lost }
    var canSimulate: Bool { state == .running }

    @discardableResult func initializeWorld() -> Bool {
        guard state == .loading else { return false }
        state = .initialized
        AppLog.session.info("Session world initialized")
        return true
    }

    @discardableResult func start() -> Bool {
        guard state == .initialized else { return false }
        state = .running
        return true
    }

    @discardableResult func pause(reason: PauseReason = .user) -> Bool {
        guard state == .running else { return false }
        state = .paused
        AppLog.session.info("Session paused")
        return true
    }

    @discardableResult func resume() -> Bool {
        guard state == .paused else { return false }
        state = .running
        AppLog.session.info("Session resumed by explicit action")
        return true
    }

    func advance(by deltaTime: TimeInterval) {
        guard canSimulate else { return }
        elapsedTime += deltaTime
    }

    func win() { if state == .running { state = .won } }
    func lose() { if state == .running { state = .lost } }

    func dispose() {
        guard state != .disposed else { return }
        state = .disposed
        AppLog.session.info("Session disposed")
    }
}
