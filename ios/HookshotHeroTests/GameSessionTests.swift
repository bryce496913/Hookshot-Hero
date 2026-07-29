import XCTest
import SpriteKit
@testable import HookshotHero

@MainActor final class GameSessionTests: XCTestCase {
    func testInactiveBeforeInitializationRequiresExplicitResume() {
        let session = GameSession(); session.applicationDidBecomeInactive()
        XCTAssertTrue(session.initializeWorld()); XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(session.pauseReason, .applicationLifecycle)
        session.applicationDidBecomeActive(); XCTAssertEqual(session.state, .paused)
        XCTAssertTrue(session.resume()); XCTAssertEqual(session.state, .running)
    }
    func testRunningSessionLifecyclePauseDoesNotAutoResume() {
        let session = running(); session.applicationDidBecomeInactive()
        XCTAssertEqual(session.state, .paused); XCTAssertFalse(session.resume())
        session.applicationDidBecomeActive(); XCTAssertEqual(session.state, .paused); XCTAssertTrue(session.resume())
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
        let session = running(); XCTAssertTrue(session.pause()); XCTAssertEqual(session.pauseReason, .user); XCTAssertTrue(session.resume())
        session.win(); XCTAssertFalse(session.pause()); XCTAssertFalse(session.resume())
        session.applicationDidBecomeInactive(); XCTAssertEqual(session.state, .won)
    }
    func testDisposedStateIgnoresLifecycle() {
        let session = running(); session.dispose(); session.applicationDidBecomeInactive(); session.applicationDidBecomeActive()
        XCTAssertEqual(session.state, .disposed); XCTAssertFalse(session.resume())
    }
    func testConfigurationSnapshotAndCleanSessions() {
        let config = GameConfiguration(reducedMotion: true, controlHintsEnabled: false)
        let first = GameSession(missionID: .init(rawValue: "mission"), configuration: config); first.dispose()
        let second = GameSession()
        XCTAssertEqual(first.configuration, config); XCTAssertEqual(second.score, 0); XCTAssertEqual(second.health, 3)
        XCTAssertNil(second.missionID); XCTAssertNotEqual(first.identifier, second.identifier)
    }
    func testSceneTemporaryDetachmentDoesNotDisposeOrDuplicatePresentation() {
        let session = GameSession(); XCTAssertTrue(session.initializeWorld()); XCTAssertTrue(session.start())
        let scene = GameScene(size: CGSize(width: 100, height: 100), session: session), view = SKView()
        scene.didMove(to: view); XCTAssertEqual(session.state, .running)
        scene.willMove(from: view); XCTAssertEqual(session.state, .running)
        scene.didMove(to: view); XCTAssertEqual(session.state, .running)
        XCTAssertFalse(scene.children.isEmpty)
        XCTAssertEqual(scene.clock.delta(at: 100), 0)
    }
    private func running() -> GameSession { let session = GameSession(); _ = session.initializeWorld(); _ = session.start(); return session }
}

@MainActor final class LevelOneConversionTests: XCTestCase {
    func testJavaLevelDefinition() {
        let l = LevelOneDefinition.make()
        XCTAssertEqual(l.grid, GridSize(rows: 60, columns: 60)); XCTAssertEqual(l.start, GridPosition(row: 50, column: 27))
        XCTAssertEqual(l.exitAnchor, GridPosition(row: 0, column: 27)); XCTAssertEqual(l.entryAnchor, GridPosition(row: 56, column: 27))
        XCTAssertEqual(l.chestAnchor, GridPosition(row: 44, column: 29)); XCTAssertEqual(l.internalWallAnchors.map(\.column), [20,24,28,32,36])
        XCTAssertFalse(l.isWall(GridPosition(row: 0, column: 27))); XCTAssertTrue(l.isWall(GridPosition(row: 59, column: 27)))
    }
    func testSpawnIsSafeAndRepeatableByPositionAndKind() throws {
        let l=LevelOneDefinition.make(); var a=SeededRandomNumberGenerator(seed:42),b=SeededRandomNumberGenerator(seed:42)
        let x=try SpawnService.spawn(in:l,using:&a),y=try SpawnService.spawn(in:l,using:&b)
        XCTAssertEqual(x.count,15);XCTAssertEqual(x.filter{$0.kind == .mine}.count,3);XCTAssertEqual(x.filter{$0.kind == .cabbage}.count,2);XCTAssertEqual(x.filter{$0.kind == .coin}.count,10)
        XCTAssertEqual(x.map{[$0.position.row,$0.position.column]},y.map{[$0.position.row,$0.position.column]})
        XCTAssertEqual(Set(x.map(\.position)).count,15);XCTAssertTrue(x.allSatisfy{!l.isWall($0.position) && !l.isLava($0.position)})
    }
    func testMovementHookAndSpriteCrop() throws {
        let sim=try LevelOneSimulation(seed:1);sim.input.send(.move(.up));sim.update(deltaTime:0.01)
        XCTAssertEqual(sim.player.position,GridPosition(row:49,column:27));XCTAssertEqual(sim.player.facing,.up)
        sim.input.send(.fireHook);sim.update(deltaTime:0.01);XCTAssertEqual(sim.player.hookshot.phase,.extending)
        XCTAssertEqual(HookshotState.maximumRange,19)
        XCTAssertEqual(SpriteSheet.normalizedRect(x:0,y:64,width:64,height:64,sheetWidth:576,sheetHeight:256),CGRect(x:0,y:0.5,width:1.0/9.0,height:0.25))
    }
}
