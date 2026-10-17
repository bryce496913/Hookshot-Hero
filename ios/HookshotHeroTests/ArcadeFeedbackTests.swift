import SpriteKit
import XCTest

@testable import HookshotHero

final class ArcadeFeedbackTests: XCTestCase {
  func testConciseVisualMappingRetainsAllAmounts() {
    let cases: [(GameplayFeedbackKind, String, ArcadeFeedbackPresentation.Tone)] = [
      (.coinCollected(points: 10), "+10", .score),
      (.healthLost(amount: 1, source: .mine), "-1", .damage),
      (.healthItemCollected(amount: 2), "+2 HP", .health),
      (.mineDestroyed(points: 20), "+20", .score),
      (.enemyHit(archetype: .ghostWizard, points: 10, remainingHealth: 9), "+10", .score),
      (.healthAlreadyFull, "FULL", .neutral),
      (.levelCompleted(points: 100), "+100", .completion),
      (.enemyDefeated(archetype: .skeleton), "KO", .completion)
    ]
    for (kind, text, tone) in cases {
      let presentation = ArcadeFeedbackPresentation(kind)
      XCTAssertEqual(presentation.text, text)
      XCTAssertEqual(presentation.tone, tone)
      XCTAssertNil(presentation.secondaryText)
    }
    XCTAssertEqual(ArcadeFeedbackPresentation(.chestReward(score: 100, health: 2)).text, "+100")
    XCTAssertEqual(ArcadeFeedbackPresentation(.chestReward(score: 100, health: 2)).secondaryText, "+2 HP")
    XCTAssertNil(ArcadeFeedbackPresentation(.chestReward(score: 100, health: 0)).secondaryText)
  }

  func testGridMappingMatchesSpriteKitIncludingNonSquareFutureGrid() {
    let board = CGSize(width: 300, height: 300)
    let grid = GridSize(rows: 10, columns: 10)
    for (position, expected) in [
      (GridPosition(row: 0, column: 0), CGPoint(x: 15, y: 15)),
      (GridPosition(row: 4, column: 4), CGPoint(x: 135, y: 135)),
      (GridPosition(row: 9, column: 9), CGPoint(x: 285, y: 285))
    ] {
      XCTAssertEqual(ArcadeFeedbackLayout.anchor(position, grid: grid, board: board), expected)
    }
    for grid in [grid, GridSize(rows: 8, columns: 12)] {
      for position in [GridPosition(row: 0, column: 0), GridPosition(row: 4, column: 5)] {
        let sprite = RenderLayoutContext(gridSize: grid).point(position)
        let cell = board.width / CGFloat(max(grid.rows, grid.columns))
        let overlay = ArcadeFeedbackLayout.anchor(position, grid: grid, board: board)
        XCTAssertEqual(overlay.x, sprite.x * cell, accuracy: 0.001)
        XCTAssertEqual(overlay.y, board.height - sprite.y * cell, accuracy: 0.001)
      }
    }
    XCTAssertEqual(ArcadeFeedbackLayout.anchor(.init(row: 2, column: 2),
      grid: GridSize(rows: 5, columns: 5), board: board), CGPoint(x: 150, y: 150))
  }

  func testMissingCoordinateUsesBoardCenterWithoutAList() {
    XCTAssertEqual(ArcadeFeedbackLayout.anchor(nil, grid: .init(rows: 10, columns: 10),
      board: .init(width: 320, height: 320)), CGPoint(x: 160, y: 160))
  }

  func testEdgeClampingKeepsMeasuredTextAndTravelInsideBoard() {
    let board = CGSize(width: 320, height: 320)
    let label = CGSize(width: 90, height: 52)
    for reduced in [false, true] {
      for anchor in [CGPoint.zero, CGPoint(x: 320, y: 0),
                     CGPoint(x: 0, y: 320), CGPoint(x: 320, y: 320)] {
        let center = ArcadeFeedbackLayout.center(anchor: anchor, board: board, label: label,
                                                 lane: 0, reducedMotion: reduced)
        let halfWidth = label.width * ArcadeFeedbackLayout.maximumScale / 2
        let halfHeight = label.height * ArcadeFeedbackLayout.maximumScale / 2
        XCTAssertGreaterThanOrEqual(center.x - halfWidth, 0)
        XCTAssertLessThanOrEqual(center.x + halfWidth, board.width)
        XCTAssertLessThanOrEqual(center.y + halfHeight, board.height)
        XCTAssertGreaterThanOrEqual(center.y - halfHeight - (reduced ? 0 : ArcadeFeedbackLayout.travel), 0)
      }
    }
  }

  func testSimultaneousEventsStackLocallyAtBothEdgesDeterministically() {
    for y in [CGFloat.zero, 160, 320] {
      let anchor = CGPoint(x: 160, y: y)
      let board = CGSize(width: 320, height: 320)
      let label = CGSize(width: 80, height: 52)
      let first = ArcadeFeedbackLayout.center(anchor: anchor, board: board, label: label,
                                              lane: 0, reducedMotion: false)
      let second = ArcadeFeedbackLayout.center(anchor: anchor, board: board, label: label,
                                               lane: 1, reducedMotion: false)
      XCTAssertGreaterThan(abs(first.y - second.y), label.height * ArcadeFeedbackLayout.maximumScale)
      XCTAssertEqual(second, ArcadeFeedbackLayout.center(anchor: anchor, board: board,
        label: label, lane: 1, reducedMotion: false))
    }
  }

  func testLaneAssignmentsSurviveExpirationAndNewEventsDoNotReuseOccupiedLane() {
    func event() -> GameplayFeedback {
      .init(id: UUID(), kind: .coinCollected(points: 10), coordinate: .init(row: 5, column: 5),
            createdAt: 0, duration: 2.4)
    }
    let first = event(), second = event(), third = event()
    let initial = ArcadeFeedbackLayout.lanes(for: [first, second], previous: [:])
    XCTAssertEqual(initial[first.id], 0)
    XCTAssertEqual(initial[second.id], 1)
    let updated = ArcadeFeedbackLayout.lanes(for: [second, third], previous: initial)
    XCTAssertNil(updated[first.id])
    XCTAssertEqual(updated[second.id], 1)
    XCTAssertEqual(updated[third.id], 0)
  }

  func testMotionPopsFloatsAndFadesButReducedMotionOnlyFades() {
    let duration = 2.4
    XCTAssertEqual(ArcadeFeedbackMotion(age: 0, duration: duration, reducedMotion: false).scale, 0.78, accuracy: 0.001)
    XCTAssertEqual(ArcadeFeedbackMotion(age: duration * 0.08, duration: duration, reducedMotion: false).scale, 1.16, accuracy: 0.001)
    for age in [0.0, 0.2, 1.2, 2.4] {
      let normal = ArcadeFeedbackMotion(age: age, duration: duration, reducedMotion: false)
      let reduced = ArcadeFeedbackMotion(age: age, duration: duration, reducedMotion: true)
      XCTAssertEqual(reduced.rise, 0)
      XCTAssertEqual(reduced.scale, 1)
      XCTAssertEqual(reduced.opacity, normal.opacity)
    }
    XCTAssertEqual(ArcadeFeedbackMotion(age: duration, duration: duration, reducedMotion: false).opacity, 0)
    XCTAssertEqual(ArcadeFeedbackMotion(age: duration, duration: duration, reducedMotion: false).rise, 32)
  }
}
