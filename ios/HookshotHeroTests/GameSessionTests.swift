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
        let session = GameSession(), scene = GameScene(size: CGSize(width: 100, height: 100), session: session), view = SKView()
        scene.didMove(to: view); XCTAssertEqual(session.state, .running)
        scene.willMove(from: view); XCTAssertEqual(session.state, .running)
        scene.didMove(to: view); XCTAssertEqual(session.state, .running)
        XCTAssertEqual(scene.children.filter { $0.name == "development-player-placeholder" }.count, 1)
        XCTAssertEqual(scene.clock.delta(at: 100), 0)
    }
    private func running() -> GameSession { let session = GameSession(); _ = session.initializeWorld(); _ = session.start(); return session }
}
