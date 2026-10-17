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

  func testFixedUUIDAlwaysProducesTheSameGoldenProfile() {
    let profile = ArcadeFeedbackVariation(id: id(1))
    XCTAssertEqual(profile, ArcadeFeedbackVariation(id: id(1)))
    XCTAssertEqual(profile.direction.x, 0.6715129863028783, accuracy: 0.000000001)
    XCTAssertEqual(profile.direction.y, -0.7409927862176463, accuracy: 0.000000001)
    XCTAssertEqual(profile.travel, 37.76044632230441, accuracy: 0.000000001)
    XCTAssertEqual(profile.rotationDegrees, 2.854108461481008, accuracy: 0.000000001)
    XCTAssertEqual(profile.initialScale, 0.9025507576059248, accuracy: 0.000000001)
    XCTAssertEqual(profile.peakScale, 1.0907250951366474, accuracy: 0.000000001)
  }

  func testUUIDProfilesAreFiniteVariedAndWithinConfiguredRanges() {
    let profiles = (1...64).map { ArcadeFeedbackVariation(id: id($0)) }
    XCTAssertTrue(profiles.contains { $0.direction.x < -0.3 })
    XCTAssertTrue(profiles.contains { $0.direction.x > 0.3 })
    XCTAssertTrue(profiles.contains { abs($0.direction.x) < 0.2 })
    XCTAssertGreaterThan(Set(profiles.map(\.travel)).count, 50)
    for profile in profiles {
      for value in [profile.direction.x, profile.direction.y, profile.travel,
                    profile.lateralOffset, CGFloat(profile.rotationDegrees), profile.initialScale, profile.peakScale] {
        XCTAssertTrue(value.isFinite)
      }
      let angle = atan2(profile.direction.y, profile.direction.x) * 180 / .pi
      XCTAssertTrue((-135...(-45)).contains(angle))
      XCTAssertLessThan(profile.direction.y, 0)
      XCTAssertEqual(hypot(profile.direction.x, profile.direction.y), 1, accuracy: 0.000001)
      XCTAssertTrue((ArcadeFeedbackVariation.minimumTravel...ArcadeFeedbackVariation.maximumTravel).contains(profile.travel))
      XCTAssertTrue((-7...7).contains(profile.rotationDegrees))
      XCTAssertTrue((-4...4).contains(profile.lateralOffset))
      XCTAssertTrue((0.86...0.92).contains(profile.initialScale))
      XCTAssertTrue((1.06...1.12).contains(profile.peakScale))
    }
  }

  func testWholeTrajectoryIncludingPeakScaleAndRotationFitsAtCenterAndEveryCorner() {
    for side in [CGFloat(240), 320] {
      let board = CGSize(width: side, height: side)
      let anchors = [CGPoint(x: side / 2, y: side / 2), .zero, CGPoint(x: side, y: 0),
                     CGPoint(x: 0, y: side), CGPoint(x: side, y: side)]
      // Single-line score and two-line chest; measured extents include both reward lines.
      for label in [CGSize(width: 48, height: 18), CGSize(width: 92, height: 36)] {
        for anchor in anchors {
          for number in 1...8 {
            let variation = ArcadeFeedbackVariation(id: id(number))
            for reduced in [false, true] {
              for capacity in [1, 3] {
                for lane in 0..<capacity {
                  let trajectory = ArcadeFeedbackLayout.trajectory(anchor: anchor, board: board, label: label,
                    lane: lane, capacity: capacity, variation: variation, reducedMotion: reduced)
                  for progress in [0.0, 0.08, 0.5, 1.0] {
                    let motion = ArcadeFeedbackMotion(age: progress * 2.4, duration: 2.4,
                      variation: variation, trajectory: trajectory, reducedMotion: reduced)
                    let point = CGPoint(x: trajectory.start.x + motion.xOffset,
                                        y: trajectory.start.y + motion.yOffset)
                    assertInside(trajectory.envelope(at: point), region: CGRect(origin: .zero, size: board))
                    assertInside(trajectory.envelope(at: point), region: trajectory.region)
                    XCTAssertLessThanOrEqual(motion.yOffset, 0)
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  func testEdgesMirrorOutwardHorizontalMotionAndShortenTopTravel() {
    let board = CGSize(width: 320, height: 320), label = CGSize(width: 60, height: 20)
    let left = ArcadeFeedbackLayout.trajectory(anchor: CGPoint(x: 0, y: 160), board: board,
      label: label, lane: 0, capacity: 1, variation: ArcadeFeedbackVariation(id: id(2)), reducedMotion: false)
    let right = ArcadeFeedbackLayout.trajectory(anchor: CGPoint(x: 320, y: 160), board: board,
      label: label, lane: 0, capacity: 1, variation: ArcadeFeedbackVariation(id: id(1)), reducedMotion: false)
    XCTAssertGreaterThan(left.xTravel, 0)
    XCTAssertLessThan(right.xTravel, 0)
    let variation = ArcadeFeedbackVariation(id: id(1))
    let top = ArcadeFeedbackLayout.trajectory(anchor: CGPoint(x: 160, y: 0), board: board,
      label: label, lane: 0, capacity: 1, variation: variation, reducedMotion: false)
    XCTAssertLessThan(hypot(top.xTravel, top.yTravel), variation.travel)
    XCTAssertEqual(top.yTravel, 0, accuracy: 0.000001)
    // Oversized Dynamic Type labels fit statically rather than being clipped by the board.
    let oversized = ArcadeFeedbackLayout.trajectory(anchor: CGPoint(x: 160, y: 160), board: board,
      label: CGSize(width: 500, height: 200), lane: 0, capacity: 3, variation: variation, reducedMotion: false)
    XCTAssertLessThan(oversized.fitScale, 1)
    assertInside(oversized.envelope(at: oversized.start), region: oversized.region)
  }

  func testThreeSimultaneousEventsKeepSeparateLanesAfterExpirationAndFreeLaneReuse() {
    let events = (1...3).map { event($0) }
    let initial = ArcadeFeedbackLayout.lanes(for: events, previous: [:])
    let capacities = ArcadeFeedbackLayout.capacities(for: events, lanes: initial, previous: [:])
    XCTAssertEqual(events.map { initial[$0.id] }, [0, 1, 2])
    let remaining = Array(events.dropFirst())
    let afterRemoval = ArcadeFeedbackLayout.lanes(for: remaining, previous: initial)
    let retained = ArcadeFeedbackLayout.capacities(for: remaining, lanes: afterRemoval, previous: capacities)
    XCTAssertNil(afterRemoval[events[0].id])
    XCTAssertEqual(afterRemoval[events[1].id], 1)
    XCTAssertEqual(afterRemoval[events[2].id], 2)
    XCTAssertEqual(retained, capacities)
    let arrival = event(4)
    let afterArrival = ArcadeFeedbackLayout.lanes(for: remaining + [arrival], previous: afterRemoval)
    XCTAssertEqual(afterArrival[arrival.id], 0)
    XCTAssertEqual(afterArrival[events[1].id], 1)
    XCTAssertEqual(afterArrival[events[2].id], 2)
    XCTAssertTrue(ArcadeFeedbackLayout.capacities(for: [], lanes: [:], previous: retained).isEmpty)

    for anchor in [CGPoint.zero, CGPoint(x: 160, y: 160), CGPoint(x: 320, y: 320)] {
      for reduced in [false, true] {
        let trajectories = events.enumerated().map { index, event in
          ArcadeFeedbackLayout.trajectory(anchor: anchor, board: CGSize(width: 320, height: 320),
            label: index == 0 ? CGSize(width: 92, height: 36) : CGSize(width: 48, height: 18),
            lane: initial[event.id]!, capacity: capacities[event.coordinate]!,
            variation: ArcadeFeedbackVariation(id: event.id), reducedMotion: reduced)
        }
        for progress in [CGFloat.zero, 0.5, 1] {
          let envelopes = trajectories.map { trajectory in
            trajectory.envelope(at: CGPoint(x: trajectory.start.x + trajectory.xTravel * progress,
                                            y: trajectory.start.y + trajectory.yTravel * progress))
          }
          for index in 0..<3 {
            assertInside(envelopes[index], region: CGRect(x: 0, y: 0, width: 320, height: 320))
            for other in (index + 1)..<3 { XCTAssertFalse(envelopes[index].intersects(envelopes[other])) }
          }
        }
        for index in 1...2 {
          let event = events[index]
          let unchanged = ArcadeFeedbackLayout.trajectory(anchor: anchor, board: CGSize(width: 320, height: 320),
            label: CGSize(width: 48, height: 18), lane: afterRemoval[event.id]!,
            capacity: retained[event.coordinate]!, variation: ArcadeFeedbackVariation(id: event.id), reducedMotion: reduced)
          XCTAssertEqual(unchanged, trajectories[index])
        }
      }
    }
  }

  func testMotionMovesLeftRightAndUpWithSmallPopAndCompleteFade() {
    var offsets: [CGFloat] = []
    for number in [1, 2, 3] {
      let variation = ArcadeFeedbackVariation(id: id(number))
      let trajectory = ArcadeFeedbackLayout.trajectory(anchor: CGPoint(x: 160, y: 160),
        board: CGSize(width: 320, height: 320), label: CGSize(width: 48, height: 18), lane: 0,
        capacity: 1, variation: variation, reducedMotion: false)
      let start = ArcadeFeedbackMotion(age: 0, duration: 2.4, variation: variation,
        trajectory: trajectory, reducedMotion: false)
      let peak = ArcadeFeedbackMotion(age: 2.4 * 0.08, duration: 2.4, variation: variation,
        trajectory: trajectory, reducedMotion: false)
      let end = ArcadeFeedbackMotion(age: 2.4, duration: 2.4, variation: variation,
        trajectory: trajectory, reducedMotion: false)
      XCTAssertEqual(start.scale, variation.initialScale, accuracy: 0.000001)
      XCTAssertEqual(peak.scale, variation.peakScale, accuracy: 0.000001)
      XCTAssertGreaterThan(peak.scale, 1)
      XCTAssertEqual(end.scale, 1)
      XCTAssertLessThan(end.yOffset, 0)
      XCTAssertEqual(end.opacity, 0)
      XCTAssertEqual(end.rotationDegrees, start.rotationDegrees)
      offsets.append(end.xOffset)
    }
    XCTAssertGreaterThan(offsets[0], 0)
    XCTAssertLessThan(offsets[1], 0)
    XCTAssertLessThan(abs(offsets[2]), 8)
  }

  func testReducedMotionOnlyFadesWithNoTranslationRotationOrPop() {
    let variation = ArcadeFeedbackVariation(id: id(1))
    let trajectory = ArcadeFeedbackLayout.trajectory(anchor: CGPoint(x: 160, y: 160),
      board: CGSize(width: 320, height: 320), label: CGSize(width: 48, height: 18), lane: 0,
      capacity: 1, variation: variation, reducedMotion: true)
    XCTAssertEqual(trajectory.xTravel, 0)
    XCTAssertEqual(trajectory.yTravel, 0)
    XCTAssertEqual(trajectory.rotationDegrees, 0)
    for age in [0.0, 0.096, 0.2, 1.2, 2.2, 2.4] {
      let reduced = ArcadeFeedbackMotion(age: age, duration: 2.4, variation: variation,
        trajectory: trajectory, reducedMotion: true)
      let normal = ArcadeFeedbackMotion(age: age, duration: 2.4, variation: variation,
        trajectory: trajectory, reducedMotion: false)
      XCTAssertEqual(reduced.xOffset, 0)
      XCTAssertEqual(reduced.yOffset, 0)
      XCTAssertEqual(reduced.rotationDegrees, 0)
      XCTAssertEqual(reduced.scale, 1)
      XCTAssertEqual(reduced.opacity, normal.opacity)
    }
    XCTAssertEqual(ArcadeFeedbackMotion(age: 2.4, duration: 2.4, variation: variation,
      trajectory: trajectory, reducedMotion: true).opacity, 0)
  }

  private func id(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", number))!
  }

  private func event(_ number: Int) -> GameplayFeedback {
    .init(id: id(number), kind: .coinCollected(points: 10), coordinate: .init(row: 5, column: 5),
          createdAt: 0, duration: 2.4)
  }

  private func assertInside(_ bounds: CGRect, region: CGRect, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThanOrEqual(bounds.minX, region.minX - 0.000001, file: file, line: line)
    XCTAssertLessThanOrEqual(bounds.maxX, region.maxX + 0.000001, file: file, line: line)
    XCTAssertGreaterThanOrEqual(bounds.minY, region.minY - 0.000001, file: file, line: line)
    XCTAssertLessThanOrEqual(bounds.maxY, region.maxY + 0.000001, file: file, line: line)
  }
}
