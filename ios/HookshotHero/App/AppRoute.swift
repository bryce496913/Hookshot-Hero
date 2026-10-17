import Foundation

struct GameResult: Hashable, Sendable {
    let sessionID: UUID
    let levelID: LevelID
    let missionID: MissionID?
    let score: Int
    let elapsedTime: TimeInterval
    let outcome: GameOutcome
    /// Presentation snapshot attached only after an eligible terminal result is recorded.
    var leaderboardEntry: HighScoreEntry? = nil
    var leaderboardRank: Int? = nil
}

enum AppRoute: Hashable, Sendable {
    case gameplay, settings, help, highScores
    case results(GameResult)
    case gameLoadingFailure(GameLoadingFailurePresentation)
}
