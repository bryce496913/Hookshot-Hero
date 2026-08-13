import XCTest

@testable import HookshotHero

@MainActor
final class LevelOneStabilizationTests: XCTestCase {
  func testEventSpecificFeedbackAnnouncementsAndChestCoalescing() throws {
    let coin = GameplayFeedback(
      id: UUID(), kind: .coinCollected(points: 10), coordinate: nil, createdAt: 0, duration: 2.4)
    let chest = GameplayFeedback(
      id: UUID(), kind: .chestReward(score: 100, health: 2), coordinate: nil, createdAt: 0,
      duration: 2.4)
    let mine = GameplayFeedback(
      id: UUID(), kind: .mineDestroyed(points: 10), coordinate: nil, createdAt: 0, duration: 2.4)
    let completion = GameplayFeedback(
      id: UUID(), kind: .levelCompleted(points: 100), coordinate: nil, createdAt: 0, duration: 2.4)
    XCTAssertEqual(coin.accessibilityAnnouncement, "Coin collected. Plus 10 score.")
    XCTAssertEqual(chest.accessibilityAnnouncement, "Chest opened. Plus 100 score and 2 health.")
    XCTAssertEqual(mine.accessibilityAnnouncement, "Mine destroyed. Plus 10 score.")
    XCTAssertEqual(completion.accessibilityAnnouncement, "Level complete. Plus 100 score.")
    XCTAssertFalse(chest.accessibilityAnnouncement.localizedCaseInsensitiveContains("coin"))
    XCTAssertTrue(chest.message.contains("+100 Score"))
    XCTAssertTrue(chest.message.contains("+2 Health"))
  }

  func testCancellationGenerationMakesInterruptedHoldsIdempotent() throws {
    let simulation = try LevelOneSimulation(seed: 42)
    simulation.input.send(.beginMove(.up))
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(simulation.player.movementDirection, .up)
    let generation = simulation.input.cancellationGeneration
    simulation.cancelAllInput()
    XCTAssertNil(simulation.player.movementDirection)
    XCTAssertGreaterThan(simulation.input.cancellationGeneration, generation)
    simulation.input.send(.endMove(.up))
    simulation.cancelAllInput()
    simulation.input.send(.beginMove(.up))
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(simulation.player.movementDirection, .up)
  }

  func testLethalInteractionSynchronizesAndStopsSameFrameRewards() throws {
    let mines = (0..<3).map { _ in
      WorldEntity(id: EntityID(), kind: .mine, position: .init(row: 49, column: 27))
    }
    let coin = WorldEntity(id: EntityID(), kind: .coin, position: .init(row: 49, column: 27))
    let simulation = try LevelOneSimulation(seed: 42, entities: mines + [coin])
    var statuses: [(Int, Int)] = []
    var outcomes: [GameOutcome] = []
    simulation.onStatusChange = { statuses.append(($0.health, $0.score)) }
    simulation.onOutcome = { outcomes.append($0) }
    // Three separately resolved mine contacts establish lethal health without test-only state mutation.
    for _ in 0..<3 {
      simulation.input.send(.move(.up))
      simulation.update(deltaTime: 0.01)
      if simulation.outcome == nil {
        simulation.input.send(.move(.down))
        simulation.update(deltaTime: 0.8)
      }
    }
    XCTAssertEqual(simulation.outcome, .lost)
    XCTAssertEqual(simulation.player.health, 0)
    XCTAssertEqual(simulation.player.score, 0)
    XCTAssertTrue(
      simulation.entities.contains { $0.id == coin.id },
      "coin after lethal mine must remain unprocessed")
    XCTAssertEqual(outcomes, [.lost])
    XCTAssertEqual(statuses.last?.0, 0)
    XCTAssertEqual(statuses.last?.1, 0)
  }
  /// Minimal fixture: coin (42,27), mine (53,27). Commands use only normal movement,
  /// dialogue Continue, and grapple from the production start (50,27) through the real map.
  func testDeterministicLevelOneMapPlaythroughReachesVictory() throws {
    let coin = WorldEntity(id: EntityID(), kind: .coin, position: .init(row: 42, column: 27))
    let mine = WorldEntity(id: EntityID(), kind: .mine, position: .init(row: 53, column: 27))
    let session = GameSession(simulation: try LevelOneSimulation(entities: [coin, mine]))
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let progression = ProgressionStore(
      repository: .init(fileURL: directory.appending(path: "progression.json")))
    let router = AppRouter(progressionStore: progression)
    router.startGame(session: session)
    XCTAssertEqual(session.state, .running)
    XCTAssertEqual(router.path, [.gameplay])
    let simulation = try XCTUnwrap(session.simulation as? LevelOneSimulation)
    XCTAssertEqual(simulation.player.position, .init(row: 50, column: 27))
    XCTAssertEqual(session.health, 3)
    XCTAssertEqual(session.score, 0)

    func move(_ direction: GridDirection, _ count: Int) {
      for _ in 0..<count {
        simulation.input.send(.move(direction))
        session.advance(by: 0.01)
      }
    }
    func finishHook() {
      for _ in 0..<80 where simulation.player.hookshot.phase != .idle { session.advance(by: 0.1) }
    }

    move(.up, 4)  // chest footprint is reached legally at (46,27)
    XCTAssertTrue(simulation.chestOpen)
    XCTAssertNotNil(session.dialogue)
    XCTAssertEqual(session.health, 5)
    XCTAssertEqual(session.score, 100)
    let suspendedTime = session.elapsedTime
    session.advance(by: 1)
    XCTAssertEqual(session.elapsedTime, suspendedTime)
    XCTAssertEqual(
      simulation.feedbackEvents.filter { if case .chestReward = $0.kind { true } else { false } }
        .count, 1)
    XCTAssertTrue(session.continueDialogue())
    move(.up, 3)  // coin at (42,27) intersects the player footprint at (43,27)
    XCTAssertEqual(session.score, 110)
    XCTAssertFalse(simulation.entities.contains { $0.id == coin.id })

    simulation.input.send(.move(.down))
    session.advance(by: 0.01)
    simulation.input.send(.fireHook)
    finishHook()  // destroys mine, latches lower wall, and returns
    XCTAssertEqual(session.score, 120)
    XCTAssertFalse(simulation.entities.contains { $0.id == mine.id })
    move(.up, max(0, simulation.player.position.row - 37))
    let safe = simulation.player.lastSafePosition
    move(.up, 1)  // first lava contact
    XCTAssertEqual(session.health, 4)
    XCTAssertEqual(simulation.player.position, safe)

    simulation.input.send(.fireHook)
    finishHook()  // crosses the production lava band and latches the internal wall
    move(.left, max(0, simulation.player.position.column - 17))
    move(.up, max(0, simulation.player.position.row - 13))  // around the internal wall
    move(.right, 12)
    move(.up, 14)  // align column 29 and pass through the six-cell exit
    XCTAssertEqual(simulation.outcome, .won)
    XCTAssertEqual(session.state, .won)
    XCTAssertEqual(session.score, 220)
    XCTAssertEqual(session.health, 4)
    XCTAssertEqual(
      simulation.feedbackEvents.filter { if case .levelCompleted = $0.kind { true } else { false } }
        .count, 1)
    XCTAssertNil(router.activeSession)
    XCTAssertEqual(router.path.count, 1)
    guard case .results(let result) = router.path[0] else {
      return XCTFail("Expected one results route")
    }
    XCTAssertEqual(result.score, 220)
    XCTAssertEqual(result.levelID, .init(rawValue: "level-1"))
    XCTAssertEqual(result.outcome, .won)
    XCTAssertEqual(progression.progression.highScore, 220)
    XCTAssertEqual(progression.progression.completedLevelIDs, [.init(rawValue: "level-1")])
    router.finishGame(sessionID: session.identifier, outcome: .won)
    XCTAssertEqual(router.path, [.results(result)])
  }

  func testLethalFirstQueuedCommandAtomicallyStopsMovementAndHook() throws {
    let lethal = (0..<3).map { _ in
      WorldEntity(id: EntityID(), kind: .mine, position: .init(row: 49, column: 27))
    }
    let simulation = try LevelOneSimulation(entities: lethal)
    var outcomes: [GameOutcome] = []
    simulation.onOutcome = { outcomes.append($0) }
    simulation.input.send(.move(.up))
    simulation.input.send(.move(.left))
    simulation.input.send(.fireHook)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(simulation.outcome, .lost)
    XCTAssertEqual(simulation.player.health, 0)
    XCTAssertEqual(simulation.player.position, .init(row: 49, column: 27))
    XCTAssertEqual(simulation.player.facing, .up)
    XCTAssertEqual(simulation.player.hookshot.phase, .idle)
    XCTAssertEqual(outcomes, [.lost])
    let snapshot = simulation.player
    let chest = simulation.chestOpen
    let feedback = simulation.feedbackEvents
    simulation.attemptMove(.right)
    simulation.fireHook()
    simulation.activateChestAndExit()
    for _ in 0..<5 { simulation.update(deltaTime: 1) }
    XCTAssertEqual(simulation.player, snapshot)
    XCTAssertEqual(simulation.chestOpen, chest)
    XCTAssertEqual(simulation.feedbackEvents, feedback)
    XCTAssertEqual(outcomes, [.lost])
  }

  func testStatusPublishesOnlyCoherentChanges() throws {
    let coin = WorldEntity(id: EntityID(), kind: .coin, position: .init(row: 49, column: 27))
    let simulation = try LevelOneSimulation(entities: [coin])
    var statuses: [PlayerStatusSnapshot] = []
    simulation.onStatusChange = { statuses.append($0) }
    simulation.update(deltaTime: 0.01)
    XCTAssertTrue(statuses.isEmpty)
    simulation.input.send(.move(.up))
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(statuses, [.init(health: 3, score: 10)])
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(statuses.count, 1)
  }

  func testDirectionPressStateMachineSeparatesTapHoldAndCancellation() {
    var press = DirectionPressController()
    XCTAssertEqual(press.press(.up), [])
    XCTAssertEqual(press.release(.up), [.moveOnce(.up)])
    XCTAssertEqual(press.state, .idle)
    XCTAssertEqual(press.release(.up), [], "a quick tap cannot dispatch twice")
    _ = press.press(.left)
    XCTAssertEqual(press.holdThreshold(.left), [.beginHold(.left)])
    XCTAssertEqual(press.release(.left), [.endHold(.left)])
    XCTAssertEqual(press.state, .idle)
    _ = press.press(.right)
    XCTAssertEqual(press.cancel(.right), [])
    XCTAssertEqual(press.cancel(.right), [])
    _ = press.press(.down)
    _ = press.holdThreshold(.down)
    XCTAssertEqual(press.cancel(.down), [.endHold(.down)])
  }

  func testProductionSeed496913SpawnsSafeDeterministicFullFootprints() throws {
    let level = LevelOneDefinition.make()
    var firstRNG = SeededRandomNumberGenerator(seed: 496_913)
    var secondRNG = SeededRandomNumberGenerator(seed: 496_913)
    let first = try SpawnService.spawn(in: level, using: &firstRNG)
    let second = try SpawnService.spawn(in: level, using: &secondRNG)
    XCTAssertEqual(first.map(\.kind), second.map(\.kind))
    XCTAssertEqual(first.map(\.position), second.map(\.position))
    XCTAssertEqual(first.count, 15)
    XCTAssertEqual(first.filter { $0.kind == .mine }.count, 3)
    XCTAssertEqual(first.filter { $0.kind == .cabbage }.count, 2)
    XCTAssertEqual(first.filter { $0.kind == .coin }.count, 10)
    let protected = [
      CollisionProfile.player.region(at: level.start),
      CollisionProfile.chest.region(at: level.chestAnchor), level.exitRegion, level.entryRegion,
    ]
    for (index, entity) in first.enumerated() {
      let region = CollisionProfile.footprint(for: entity.kind).region(at: entity.position)
      XCTAssertFalse(level.isBlocked(region))
      XCTAssertFalse(level.overlapsLava(region))
      XCTAssertFalse(protected.contains { $0.intersects(region) })
      for other in first.dropFirst(index + 1) {
        XCTAssertFalse(
          region.intersects(CollisionProfile.footprint(for: other.kind).region(at: other.position)))
      }
    }
  }

  func testMineEffectDescriptorRespectsReducedMotion() {
    let standard = MineDestructionEffectDescriptor.make(reducedMotion: false, duration: 2.4)
    let reduced = MineDestructionEffectDescriptor.make(reducedMotion: true, duration: 2.4)
    XCTAssertEqual(standard.style, .standard)
    XCTAssertTrue(standard.scales)
    XCTAssertTrue(standard.isVisible)
    XCTAssertEqual(reduced.style, .reducedMotion)
    XCTAssertFalse(reduced.scales)
    XCTAssertTrue(reduced.isVisible)
    XCTAssertEqual(standard.duration, reduced.duration)
    XCTAssertGreaterThan(reduced.duration, 0)
  }

  func testLevelThreeUsesJavaGeometryAndTransitions() throws {
    let level = LevelThreeDefinition.make()
    XCTAssertEqual(level.displayName, "Level 3")
    XCTAssertEqual(level.chestAnchor, .init(row: 52, column: 8))
    XCTAssertTrue(level.isWall(.init(row: 12, column: 24)))
    XCTAssertTrue(level.isWall(.init(row: 24, column: 52)))
    XCTAssertTrue(level.isWall(.init(row: 32, column: 28)))
    XCTAssertTrue(level.isLava(.init(row: 4, column: 4)))
    XCTAssertTrue(level.isLava(.init(row: 32, column: 12)))
    XCTAssertTrue(level.isLava(.init(row: 8, column: 52)))

    let carryover = PlayerCarryoverState(
      characterID: EntityID(), health: 4, score: 250, completedLevelIDs: [.levelOne, .levelTwo])
    let simulation = try LevelThreeSimulation(seed: 496_913, carryover: carryover)
    XCTAssertEqual(simulation.levelID, .levelThree)
    XCTAssertEqual(simulation.player.position, .init(row: 50, column: 29))
    XCTAssertEqual(simulation.player.health, 4)
    XCTAssertEqual(simulation.player.score, 250)
    XCTAssertEqual(simulation.entities.count, 15)

    var transition: LevelTransitionRequest?
    simulation.onLevelTransition = { transition = $0 }
    simulation.player.position = .init(row: 55, column: 27)
    simulation.update(deltaTime: 0.01)
    XCTAssertEqual(transition?.sourceLevelID, .levelThree)
    XCTAssertEqual(transition?.destinationLevelID, .levelTwo)
    XCTAssertEqual(transition?.destinationEntry, .top)
  }

}

@MainActor final class AccessibilityAnnouncementTests: XCTestCase {
  func testFeedbackAnnouncementsAreExplicitAndOneTime() {
    let announcer = RecordingAccessibilityAnnouncer()
    let coordinator = FeedbackAnnouncementCoordinator(announcer: announcer)
    let firstID = UUID()
    let secondID = UUID()
    let events = [
      GameplayFeedback(
        id: firstID, kind: .chestReward(score: 100, health: 2), coordinate: nil, createdAt: 0,
        duration: 2.4),
      GameplayFeedback(
        id: secondID, kind: .mineDestroyed(points: 10), coordinate: nil, createdAt: 1, duration: 2.4
      ),
    ]

    coordinator.update(feedback: events)
    coordinator.update(feedback: events)

    XCTAssertEqual(
      announcer.messages,
      [
        "Chest opened. Plus 100 score and 2 health.",
        "Mine destroyed. Plus 10 score.",
      ])
  }
}

@MainActor private final class RecordingAccessibilityAnnouncer: AccessibilityAnnouncing {
  var messages: [String] = []
  func announce(_ message: String) { messages.append(message) }
}
