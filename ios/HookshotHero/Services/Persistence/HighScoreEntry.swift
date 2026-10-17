import Foundation

/// Local completed-run data only; the UUID identifies a run, not a player or device.
struct HighScoreEntry: Codable, Hashable, Sendable, Identifiable {
  let id: UUID
  let rawScore: Int
  let elapsedTime: TimeInterval
  let timeBonus: Int
  let totalScore: Int

  static func completedRun(_ result: GameResult) -> HighScoreEntry? {
    guard result.elapsedTime.isFinite else { return nil }
    let elapsed = max(0, result.elapsedTime)
    let bonus = HighScoreScoring.timeBonus(for: elapsed)
    return HighScoreEntry(id: result.sessionID, rawScore: result.score, elapsedTime: elapsed,
                          timeBonus: bonus,
                          totalScore: HighScoreScoring.totalScore(rawScore: result.score, elapsedTime: elapsed))
  }
}

enum HighScoreScoring {
  static let parSeconds = 3_600
  static let secondsPerBonusPoint = 2
  static let maximumEntries = 10
  static let maximumTimeBonus = parSeconds / secondsPerBonusPoint

  static var explanation: String {
    let unit = secondsPerBonusPoint == 1 ? "second" : "seconds"
    return "Final score combines your game score with a speed bonus. Earn 1 bonus point for every "
      + "\(secondsPerBonusPoint) \(unit) under \(GameDurationFormatter.displayString(for: Double(parSeconds)))."
  }

  /// Round UP for ranking (unlike the floored visual clock), so fractions never gain bonus time.
  static func timeBonus(for elapsedTime: TimeInterval) -> Int {
    guard elapsedTime.isFinite, elapsedTime < Double(parSeconds) else { return 0 }
    let completed = Int(max(0, elapsedTime).rounded(.up))
    return (parSeconds - completed) / secondsPerBonusPoint
  }

  static func totalScore(rawScore: Int, elapsedTime: TimeInterval) -> Int {
    let total = rawScore.addingReportingOverflow(timeBonus(for: elapsedTime))
    return total.overflow ? Int.max : total.partialValue
  }

  static func precedes(_ lhs: HighScoreEntry, _ rhs: HighScoreEntry) -> Bool {
    if lhs.totalScore != rhs.totalScore { return lhs.totalScore > rhs.totalScore }
    if lhs.elapsedTime != rhs.elapsedTime { return lhs.elapsedTime < rhs.elapsedTime }
    if lhs.rawScore != rhs.rawScore { return lhs.rawScore > rhs.rawScore }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  static func topEntries(_ entries: [HighScoreEntry]) -> [HighScoreEntry] {
    var seen = Set<UUID>()
    return Array(entries.sorted(by: precedes).filter { seen.insert($0.id).inserted }
      .prefix(maximumEntries))
  }
}
