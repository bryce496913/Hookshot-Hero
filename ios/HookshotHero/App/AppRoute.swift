import Foundation

struct GameResult: Hashable, Sendable {
    let sessionID: UUID
    let levelID: LevelID
    let missionID: MissionID?
    let score: Int
    let elapsedTime: TimeInterval
    let outcome: GameOutcome
    /// Unsaved terminal score and provisional insertion rank; never stores a mutable repository.
    var highScoreCandidate: HighScoreCandidate? = nil
    var leaderboardRank: Int? = nil
}

enum AppRoute: Hashable, Sendable {
    case gameplay, settings, help, highScores
    case results(GameResult)
    case gameLoadingFailure(GameLoadingFailurePresentation)
}
