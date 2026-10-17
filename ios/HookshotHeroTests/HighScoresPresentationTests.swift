import SwiftUI
import UIKit
import XCTest

@testable import HookshotHero

@MainActor final class HighScoresPresentationTests: XCTestCase {
  func testHighScoresRouteReadsLiveProgressionWithoutUnlockingLevelSelect() {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ProgressionStore(repository: ProgressionRepository(fileURL: directory.appending(path: "save.json")))
    let router = AppRouter(progressionStore: store)
    router.showHighScores()
    XCTAssertEqual(router.path, [.highScores])
    XCTAssertTrue(router.highScoreEntries.isEmpty)
    XCTAssertFalse(router.isLevelSelectUnlocked)
    store.record(result: GameResult(sessionID: UUID(), levelID: .heroWelcome, missionID: nil,
                                   score: 100, elapsedTime: 1200, outcome: .won), leaderboardEligible: true)
    XCTAssertEqual(router.highScoreEntries.count, 1)
    XCTAssertFalse(router.isLevelSelectUnlocked)
  }

  func testResultRankUsesPostInsertionStateAndDoesNotCelebrateDiscardedRun() async throws {
    for count in [1, 10] {
      let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: directory) }
      let store = ProgressionStore(repository: ProgressionRepository(fileURL: directory.appending(path: "save.json")))
      for index in 0..<count {
        store.record(result: GameResult(sessionID: UUID(), levelID: .heroWelcome, missionID: nil,
                                       score: 10_000 + index, elapsedTime: 300, outcome: .won), leaderboardEligible: true)
      }
      let router = AppRouter(progressionStore: store)
      let simulation = try HeroWelcomeSimulation()
      // Explicit eligible session injection is test-only; player-facing direct entry stays ineligible.
      let session = GameSession(simulation: simulation, isLeaderboardEligible: true)
      router.startGame(session: session)
      simulation.player.position = .init(row: 1, column: 29)
      session.advance(by: 0.05)
      for _ in 0..<100 {
        if router.activeSession == nil { break }
        await Task.yield()
      }
      guard case .results(let result) = router.path.first else { return XCTFail("Expected Results") }
      XCTAssertNotNil(result.leaderboardEntry)
      XCTAssertEqual(result.leaderboardRank, count == 1 ? 2 : nil)
      XCTAssertEqual(store.progression.highScoreEntries.count, min(count + 1, HighScoreScoring.maximumEntries))
    }
  }

  func testRowSummaryDistinguishesEveryValueAndUsesSpokenDuration() {
    let entry = HighScoreEntry(id: UUID(), rawScore: 100, elapsedTime: 1200, timeBonus: 1200, totalScore: 1300)
    XCTAssertEqual(HighScoreRow(rank: 1, entry: entry).accessibilitySummary,
                   "Rank 1. Final score 1300. Game score 100. Time bonus 1200. Time 20 minutes.")
    XCTAssertEqual(GameDurationFormatter.displayString(for: entry.elapsedTime), "20:00")
    XCTAssertTrue(HighScoreScoring.explanation.contains(String(HighScoreScoring.secondsPerBonusPoint)))
    XCTAssertTrue(HighScoreScoring.explanation.contains(
      GameDurationFormatter.displayString(for: Double(HighScoreScoring.parSeconds))))
  }

  func testLargeScoresAndAccessibleTextGrowRowsInsteadOfTruncating() {
    let entry = HighScoreEntry(id: UUID(), rawScore: Int.max, elapsedTime: 3725,
                               timeBonus: 0, totalScore: Int.max)
    for width in [CGFloat(288), CGFloat(342)] {
      let regular = height(HighScoreRow(rank: 1, entry: entry).environment(\.dynamicTypeSize, .large), width: width)
      let accessible = height(HighScoreRow(rank: 1, entry: entry)
        .environment(\.dynamicTypeSize, .accessibility3), width: width)
      XCTAssertGreaterThan(regular, 0)
      XCTAssertGreaterThan(accessible, regular)
    }
  }

  private func height<Content: View>(_ content: Content, width: CGFloat) -> CGFloat {
    let host = UIHostingController(rootView: content)
    host.loadViewIfNeeded()
    return host.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
  }
}
