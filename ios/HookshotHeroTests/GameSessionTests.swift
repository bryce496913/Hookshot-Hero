import SpriteKit
import XCTest
@testable import HookshotHero

@MainActor
final class GameSessionTests: XCTestCase {
    func testInactiveBeforeInitializationRequiresExplicitResume() {
        let session = GameSession()
        session.applicationDidBecomeInactive()

        XCTAssertTrue(session.initializeWorld())
        XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(session.pauseReason, .applicationLifecycle)

        session.applicationDidBecomeActive()
        XCTAssertEqual(session.state, .paused)
        XCTAssertTrue(session.resume())
        XCTAssertEqual(session.state, .running)
    }

    func testRunningSessionLifecyclePauseDoesNotAutoResume() {
        let session = running()
        session.applicationDidBecomeInactive()

        XCTAssertEqual(session.state, .paused)
        XCTAssertFalse(session.resume())

        session.applicationDidBecomeActive()
        XCTAssertEqual(session.state, .paused)
        XCTAssertTrue(session.resume())
    }

    func testInitializedSessionBecomesExplicitLifecyclePause() {
        let session = GameSession()
        XCTAssertTrue(session.initializeWorld())
        XCTAssertEqual(session.state, .initialized)

        session.applicationDidBecomeInactive()
        XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(session.pauseReason, .applicationLifecycle)
        XCTAssertFalse(session.resume())

        session.applicationDidBecomeActive()
        XCTAssertEqual(session.state, .paused)
        XCTAssertTrue(session.resume())
        XCTAssertEqual(session.state, .running)
    }

    func testUserPauseAndTerminalStatesRejectTransitions() {
        let session = running()
        XCTAssertTrue(session.pause())
        XCTAssertEqual(session.pauseReason, .user)
        XCTAssertTrue(session.resume())

        session.win()
        XCTAssertFalse(session.pause())
        XCTAssertFalse(session.resume())
        session.applicationDidBecomeInactive()
        XCTAssertEqual(session.state, .won)
    }

    func testDisposedStateIgnoresLifecycle() {
        let session = running()
        session.dispose()
        session.applicationDidBecomeInactive()
        session.applicationDidBecomeActive()

        XCTAssertEqual(session.state, .disposed)
        XCTAssertFalse(session.resume())
    }

    func testConfigurationSnapshotAndCleanSessions() {
        let configuration = GameConfiguration(reducedMotion: true, controlHintsEnabled: false)
        let first = GameSession(missionID: .init(rawValue: "mission"), configuration: configuration)
        first.dispose()
        let second = GameSession()

        XCTAssertEqual(first.configuration, configuration)
        XCTAssertEqual(second.score, 0)
        XCTAssertEqual(second.health, 3)
        XCTAssertNil(second.missionID)
        XCTAssertNotEqual(first.identifier, second.identifier)
    }

    func testSceneTemporaryDetachmentDoesNotDisposeOrDuplicatePresentation() {
        let session = GameSession()
        XCTAssertTrue(session.initializeWorld())
        XCTAssertTrue(session.start())

        let scene = GameScene(size: CGSize(width: 100, height: 100), session: session)
        let view = SKView()
        scene.didMove(to: view)
        XCTAssertEqual(session.state, .running)

        scene.willMove(from: view)
        XCTAssertEqual(session.state, .running)

        scene.didMove(to: view)
        XCTAssertEqual(session.state, .running)
        XCTAssertFalse(scene.children.isEmpty)
        XCTAssertEqual(scene.clock.delta(at: 100), 0)
    }

    private func running() -> GameSession {
        let session = GameSession()
        _ = session.initializeWorld()
        _ = session.start()
        return session
    }
}

@MainActor
final class LevelOneConversionTests: XCTestCase {
    func testJavaLevelDefinitionUsesFortyPixelBoundaryTiles() {
        let level = LevelOneDefinition.make()

        XCTAssertEqual(level.grid, GridSize(rows: 60, columns: 60))
        XCTAssertEqual(level.start, GridPosition(row: 50, column: 27))
        XCTAssertEqual(level.exitAnchor, GridPosition(row: 0, column: 27))
        XCTAssertEqual(level.entryAnchor, GridPosition(row: 56, column: 27))
        XCTAssertEqual(level.chestAnchor, GridPosition(row: 44, column: 29))
        XCTAssertEqual(level.internalWallAnchors.map(\.column), [20, 24, 28, 32, 36])

        XCTAssertTrue(level.isWall(GridPosition(row: 0, column: 0)))
        XCTAssertTrue(level.isWall(GridPosition(row: 3, column: 10)))
        XCTAssertTrue(level.isWall(GridPosition(row: 30, column: 0)))
        XCTAssertTrue(level.isWall(GridPosition(row: 30, column: 59)))
        XCTAssertTrue(level.isWall(GridPosition(row: 59, column: 27)))

        XCTAssertFalse(level.isWall(GridPosition(row: 0, column: 27)))
        XCTAssertFalse(level.isWall(GridPosition(row: 3, column: 32)))
        XCTAssertFalse(level.isWall(GridPosition(row: 4, column: 4)))
    }

    func testSpawnIsSafeAndRepeatableByPositionAndKind() throws {
        let level = LevelOneDefinition.make()
        var firstGenerator = SeededRandomNumberGenerator(seed: 42)
        var secondGenerator = SeededRandomNumberGenerator(seed: 42)

        let first = try SpawnService.spawn(in: level, using: &firstGenerator)
        let second = try SpawnService.spawn(in: level, using: &secondGenerator)

        XCTAssertEqual(first.count, 15)
        XCTAssertEqual(first.filter { $0.kind == .mine }.count, 3)
        XCTAssertEqual(first.filter { $0.kind == .cabbage }.count, 2)
        XCTAssertEqual(first.filter { $0.kind == .coin }.count, 10)
        XCTAssertEqual(first.map(\.position), second.map(\.position))
        XCTAssertEqual(Set(first.map(\.position)).count, 15)
        XCTAssertTrue(first.allSatisfy { !level.isWall($0.position) && !level.isLava($0.position) })
    }

    func testMovementHookAndLidiaSpriteCrop() throws {
        let simulation = try LevelOneSimulation(seed: 1)
        simulation.input.send(.move(.up))
        simulation.update(deltaTime: 0.01)

        XCTAssertEqual(simulation.player.position, GridPosition(row: 49, column: 27))
        XCTAssertEqual(simulation.player.facing, .up)

        simulation.input.send(.fireHook)
        simulation.update(deltaTime: 0.01)
        XCTAssertEqual(simulation.player.hookshot.phase, .extending)
        XCTAssertEqual(HookshotState.maximumRange, 19)

        XCTAssertEqual(
            SpriteSheet.normalizedRect(
                x: 0,
                y: 64,
                width: 64,
                height: 64,
                sheetWidth: 576,
                sheetHeight: 256
            ),
            CGRect(x: 0, y: 0.5, width: 1.0 / 9.0, height: 0.25)
        )
    }

    func testLegacySpriteSheetDimensionsProduceCorrectSlices() {
        XCTAssertEqual(
            SpriteSheet.normalizedRect(
                x: 0,
                y: 0,
                width: 20,
                height: 26,
                sheetWidth: 120,
                sheetHeight: 26
            ),
            CGRect(x: 0, y: 0, width: 1.0 / 6.0, height: 1)
        )
        XCTAssertEqual(
            SpriteSheet.normalizedRect(
                x: 64,
                y: 32,
                width: 32,
                height: 32,
                sheetWidth: 128,
                sheetHeight: 64
            ),
            CGRect(x: 0.5, y: 0, width: 0.25, height: 0.5)
        )
        XCTAssertEqual(
            SpriteSheet.normalizedRect(
                x: 291,
                y: 67,
                width: 25,
                height: 25,
                sheetWidth: 320,
                sheetHeight: 384
            ),
            CGRect(
                x: 291.0 / 320.0,
                y: 1.0 - (92.0 / 384.0),
                width: 25.0 / 320.0,
                height: 25.0 / 384.0
            )
        )
    }

    func testVictoryAwardsJavaCompletionScoreExactlyOnce() throws {
        let simulation = try LevelOneSimulation(
            seed: 7,
            startOverride: GridPosition(row: 4, column: 27)
        )
        simulation.input.send(.move(.up))
        simulation.update(deltaTime: 0.01)

        XCTAssertEqual(simulation.outcome, .won)
        XCTAssertEqual(simulation.player.score, 100)

        simulation.update(deltaTime: 1)
        XCTAssertEqual(simulation.player.score, 100)
    }
}
