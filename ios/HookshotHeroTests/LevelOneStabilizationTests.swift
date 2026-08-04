import XCTest
@testable import HookshotHero

@MainActor
final class LevelOneStabilizationTests: XCTestCase {
    func testEventSpecificFeedbackAnnouncementsAndChestCoalescing() throws {
        let coin = GameplayFeedback(id: UUID(), kind: .coinCollected(points: 10), coordinate: nil, createdAt: 0, duration: 2.4)
        let chest = GameplayFeedback(id: UUID(), kind: .chestReward(score: 100, health: 2), coordinate: nil, createdAt: 0, duration: 2.4)
        let mine = GameplayFeedback(id: UUID(), kind: .mineDestroyed(points: 10), coordinate: nil, createdAt: 0, duration: 2.4)
        let completion = GameplayFeedback(id: UUID(), kind: .levelCompleted(points: 100), coordinate: nil, createdAt: 0, duration: 2.4)
        XCTAssertEqual(coin.accessibilityAnnouncement, "Coin collected. Plus 10 score.")
        XCTAssertEqual(chest.accessibilityAnnouncement, "Chest opened. Plus 100 score and 2 health.")
        XCTAssertEqual(mine.accessibilityAnnouncement, "Mine destroyed. Plus 10 score.")
        XCTAssertEqual(completion.accessibilityAnnouncement, "Level complete. Plus 100 score.")
        XCTAssertFalse(chest.accessibilityAnnouncement.localizedCaseInsensitiveContains("coin"))
        XCTAssertTrue(chest.message.contains("+100 Score")); XCTAssertTrue(chest.message.contains("+2 Health"))
    }

    func testCancellationGenerationMakesInterruptedHoldsIdempotent() throws {
        let simulation = try LevelOneSimulation(seed: 42)
        simulation.input.send(.beginMove(.up)); simulation.update(deltaTime: 0.01)
        XCTAssertEqual(simulation.player.movementDirection, .up)
        let generation = simulation.input.cancellationGeneration
        simulation.cancelAllInput()
        XCTAssertNil(simulation.player.movementDirection)
        XCTAssertGreaterThan(simulation.input.cancellationGeneration, generation)
        simulation.input.send(.endMove(.up)); simulation.cancelAllInput()
        simulation.input.send(.beginMove(.up)); simulation.update(deltaTime: 0.01)
        XCTAssertEqual(simulation.player.movementDirection, .up)
    }

    func testLethalInteractionSynchronizesAndStopsSameFrameRewards() throws {
        let mines = (0..<3).map { _ in WorldEntity(id: EntityID(), kind: .mine, position: .init(row: 49, column: 27)) }
        let coin = WorldEntity(id: EntityID(), kind: .coin, position: .init(row: 49, column: 27))
        let simulation = try LevelOneSimulation(seed: 42, entities: mines + [coin])
        var statuses: [(Int, Int)] = []; var outcomes: [GameOutcome] = []
        simulation.onStatusChange = { statuses.append(($0, $1)) }; simulation.onOutcome = { outcomes.append($0) }
        // Three separately resolved mine contacts establish lethal health without test-only state mutation.
        for _ in 0..<3 {
            simulation.input.send(.move(.up)); simulation.update(deltaTime: 0.01)
            if simulation.outcome == nil { simulation.input.send(.move(.down)); simulation.update(deltaTime: 0.8) }
        }
        XCTAssertEqual(simulation.outcome, .lost)
        XCTAssertEqual(simulation.player.health, 0)
        XCTAssertEqual(simulation.player.score, 0)
        XCTAssertTrue(simulation.entities.contains { $0.id == coin.id }, "coin after lethal mine must remain unprocessed")
        XCTAssertEqual(outcomes, [.lost])
        XCTAssertEqual(statuses.last?.0, 0); XCTAssertEqual(statuses.last?.1, 0)
    }
    /// Fixture seed 496913: coin (42,27), mine (53,27). Commands use only normal movement,
    /// dialogue Continue, and grapple from the production start (50,27) through the real map.
    func testDeterministicFullLevelOnePlaythroughFromProductionStart() throws {
        let coin = WorldEntity(id: EntityID(), kind: .coin, position: .init(row: 42, column: 27))
        let mine = WorldEntity(id: EntityID(), kind: .mine, position: .init(row: 53, column: 27))
        let session = GameSession(seed: 496_913, entities: [coin, mine])
        XCTAssertTrue(session.initializeWorld()); XCTAssertTrue(session.start())
        let simulation = try XCTUnwrap(session.simulation)
        XCTAssertEqual(simulation.player.position, .init(row: 50, column: 27)); XCTAssertEqual(session.health, 3); XCTAssertEqual(session.score, 0)

        func move(_ direction: GridDirection, _ count: Int) { for _ in 0..<count { simulation.input.send(.move(direction)); session.advance(by: 0.01) } }
        func finishHook() { for _ in 0..<80 where simulation.player.hookshot.phase != .idle { session.advance(by: 0.1) } }

        move(.up, 4) // chest footprint is reached legally at (46,27)
        XCTAssertTrue(simulation.chestOpen); XCTAssertNotNil(session.dialogue); XCTAssertEqual(session.health, 5); XCTAssertEqual(session.score, 100)
        let suspendedTime = session.elapsedTime; session.advance(by: 1); XCTAssertEqual(session.elapsedTime, suspendedTime)
        XCTAssertEqual(simulation.feedbackEvents.filter { if case .chestReward = $0.kind { true } else { false } }.count, 1)
        XCTAssertTrue(session.continueDialogue())
        move(.up, 3) // coin at (42,27) intersects the player footprint at (43,27)
        XCTAssertEqual(session.score, 110); XCTAssertFalse(simulation.entities.contains { $0.id == coin.id })

        simulation.input.send(.move(.down)); session.advance(by: 0.01)
        simulation.input.send(.fireHook); finishHook() // destroys mine, latches lower wall, and returns
        XCTAssertEqual(session.score, 120); XCTAssertFalse(simulation.entities.contains { $0.id == mine.id })
        move(.up, max(0, simulation.player.position.row - 37))
        let safe = simulation.player.lastSafePosition; move(.up, 1) // first lava contact
        XCTAssertEqual(session.health, 4); XCTAssertEqual(simulation.player.position, safe)

        simulation.input.send(.fireHook); finishHook() // crosses the production lava band and latches the internal wall
        move(.left, max(0, simulation.player.position.column - 17))
        move(.up, max(0, simulation.player.position.row - 13)) // around the internal wall
        move(.right, 12); move(.up, 14) // align column 29 and pass through the six-cell exit
        XCTAssertEqual(simulation.outcome, .won); XCTAssertEqual(session.score, 220); XCTAssertEqual(session.health, 4)
        XCTAssertEqual(simulation.feedbackEvents.filter { if case .levelCompleted = $0.kind { true } else { false } }.count, 1)
    }

}
