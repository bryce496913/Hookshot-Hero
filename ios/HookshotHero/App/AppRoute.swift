import Foundation

struct GameResult: Hashable, Sendable {
    let score: Int
    let didWin: Bool
}

enum AppRoute: Hashable, Sendable {
    case gameplay
    case settings
    case help
    case results(GameResult)
}
