import Foundation

/// Nil outcome/level on an entry explicitly means unknown legacy context.
enum HighScoreOutcome: String, Codable, Hashable, Sendable {
  case campaignVictory, victory, gameOver
}

struct HighScoreEntry: Codable, Hashable, Sendable, Identifiable {
  let id: UUID
  let rawScore: Int
  let elapsedTime: TimeInterval
  let timeBonus: Int
  let totalScore: Int
  var initials: String = "---"
  var levelID: LevelID? = nil
  var outcome: HighScoreOutcome? = nil

  var context: String {
    if outcome == .campaignVictory || outcome == .victory { return "Victory" }
    return levelID?.displayName ?? "Legacy score"
  }
}

/// Ephemeral terminal result. Never encoded into Progression before initials submission.
struct HighScoreCandidate: Hashable, Sendable, Identifiable {
  let id: UUID
  let rawScore: Int
  let elapsedTime: TimeInterval
  let timeBonus: Int
  let totalScore: Int
  let outcome: HighScoreOutcome
  let levelID: LevelID

  static func terminalResult(_ result: GameResult, fullCampaignVictory: Bool) -> Self? {
    guard result.elapsedTime.isFinite else { return nil }
    let outcome: HighScoreOutcome
    if result.outcome == .lost { outcome = .gameOver }
    else if result.levelID == .heroWelcome { outcome = fullCampaignVictory ? .campaignVictory : .victory }
    else { return nil }
    let elapsed = max(0, result.elapsedTime)
    let bonus = HighScoreScoring.timeBonus(for: elapsed, outcome: outcome)
    return Self(id: result.sessionID, rawScore: result.score, elapsedTime: elapsed,
                timeBonus: bonus, totalScore: HighScoreScoring.totalScore(rawScore: result.score,
                  elapsedTime: elapsed, outcome: outcome), outcome: outcome, levelID: result.levelID)
  }

  func finalized(initials: String) -> HighScoreEntry? {
    guard let initials = HighScoreInitials.validated(initials) else { return nil }
    return HighScoreEntry(id: id, rawScore: rawScore, elapsedTime: elapsedTime,
                          timeBonus: timeBonus, totalScore: totalScore, initials: initials,
                          levelID: levelID, outcome: outcome)
  }
}

enum HighScoreInitials {
  /// ASCII letters only; filter during editing, normalize case, reject excess input.
  static func constrained(_ input: String) -> String {
    String(input.unicodeScalars.filter { (65...90).contains($0.value) || (97...122).contains($0.value) }
      .prefix(3).map { Character(String($0).uppercased()) })
  }

  static func validated(_ input: String) -> String? {
    let normalized = constrained(input)
    guard input.unicodeScalars.count == 3, normalized.count == 3 else { return nil }
    return normalized
  }
}

enum HighScoreScoring {
  static let parSeconds = 3_600
  static let secondsPerBonusPoint = 2
  static let maximumEntries = 10
  static let maximumTimeBonus = parSeconds / secondsPerBonusPoint

  static var explanation: String {
    let unit = secondsPerBonusPoint == 1 ? "second" : "seconds"
    return "Every natural Game Over can qualify. Completed campaigns add a speed bonus: 1 point for every "
      + "\(secondsPerBonusPoint) \(unit) under \(GameDurationFormatter.displayString(for: Double(parSeconds))). "
      + "Game Over scores use game score only."
  }

  /// Round UP for ranking (unlike the floored visual clock), so fractions never gain bonus time.
  static func timeBonus(for elapsedTime: TimeInterval, outcome: HighScoreOutcome = .campaignVictory) -> Int {
    guard outcome == .campaignVictory, elapsedTime.isFinite, elapsedTime < Double(parSeconds) else { return 0 }
    let completed = Int(max(0, elapsedTime).rounded(.up))
    return (parSeconds - completed) / secondsPerBonusPoint
  }

  static func totalScore(rawScore: Int, elapsedTime: TimeInterval,
                         outcome: HighScoreOutcome = .campaignVictory) -> Int {
    let total = rawScore.addingReportingOverflow(timeBonus(for: elapsedTime, outcome: outcome))
    return total.overflow ? Int.max : total.partialValue
  }

  private struct RankingKey {
    let total: Int
    let raw: Int
    let victoryTime: TimeInterval
    let id: UUID
  }

  private static func key(total: Int, raw: Int, elapsed: TimeInterval,
                          outcome: HighScoreOutcome?, id: UUID) -> RankingKey {
    .init(total: total, raw: raw, victoryTime: outcome == .campaignVictory ? elapsed : .infinity, id: id)
  }

  private static func key(_ entry: HighScoreEntry) -> RankingKey {
    key(total: entry.totalScore, raw: entry.rawScore, elapsed: entry.elapsedTime,
        outcome: entry.outcome, id: entry.id)
  }

  private static func precedes(_ lhs: RankingKey, _ rhs: RankingKey) -> Bool {
    if lhs.total != rhs.total { return lhs.total > rhs.total }
    if lhs.raw != rhs.raw { return lhs.raw > rhs.raw }
    // A single total-order key prevents cycles across mixed outcomes. Only completed
    // campaigns use speed for ties; losses/unknown context use stable UUID ordering.
    if lhs.victoryTime != rhs.victoryTime { return lhs.victoryTime < rhs.victoryTime }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  static func precedes(_ lhs: HighScoreEntry, _ rhs: HighScoreEntry) -> Bool {
    precedes(key(lhs), key(rhs))
  }

  static func topEntries(_ entries: [HighScoreEntry]) -> [HighScoreEntry] {
    var seen = Set<UUID>()
    return Array(entries.sorted(by: precedes).filter { seen.insert($0.id).inserted }
      .prefix(maximumEntries))
  }

  static func qualifyingRank(candidate: HighScoreCandidate, existingEntries: [HighScoreEntry]) -> Int? {
    let existing = topEntries(existingEntries)
    guard !existing.contains(where: { $0.id == candidate.id }) else { return nil }
    let candidateKey = key(total: candidate.totalScore, raw: candidate.rawScore,
      elapsed: candidate.elapsedTime, outcome: candidate.outcome, id: candidate.id)
    let rank = existing.filter { precedes(key($0), candidateKey) }.count + 1
    return rank <= maximumEntries ? rank : nil
  }
}
