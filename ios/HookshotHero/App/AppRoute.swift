import Foundation

struct GameResult: Hashable, Sendable {
    let sessionID: UUID
    let levelID: LevelID
    let missionID: MissionID?
    let score: Int
    let elapsedTime: TimeInterval
    let outcome: GameOutcome
}

enum AppRoute: Hashable, Sendable {
    case gameplay, settings, help
    case results(GameResult)
    case gameLoadingFailure(GameLoadingFailurePresentation)
}
