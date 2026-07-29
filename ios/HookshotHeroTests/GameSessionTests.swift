import XCTest
@testable import HookshotHero

@MainActor final class GameSessionTests: XCTestCase {
    func testNewSessionStartsLoadingWithCleanState() {
        let session = GameSession()
        XCTAssertEqual(session.state, .loading); XCTAssertEqual(session.score, 0)
        XCTAssertNil(session.missionID); XCTAssertEqual(session.elapsedTime, 0)
    }
    func testCannotRunBeforeInitialization() { XCTAssertFalse(GameSession().start()) }
    func testInitializedSessionCanRunPauseAndResume() {
        let session = GameSession(); XCTAssertTrue(session.initializeWorld()); XCTAssertTrue(session.start())
        XCTAssertTrue(session.pause()); XCTAssertEqual(session.state, .paused)
        XCTAssertTrue(session.resume()); XCTAssertEqual(session.state, .running)
    }
    func testTerminalSessionsDoNotAdvanceOrResume() {
        let won = runningSession(); won.win(); won.advance(by: 1); XCTAssertEqual(won.elapsedTime, 0); XCTAssertFalse(won.resume())
        let lost = runningSession(); lost.lose(); lost.advance(by: 1); XCTAssertEqual(lost.elapsedTime, 0); XCTAssertFalse(lost.resume())
    }
    func testDisposedSessionCannotResumeOrAdvance() {
        let session = runningSession(); session.dispose(); session.advance(by: 1)
        XCTAssertEqual(session.state, .disposed); XCTAssertFalse(session.resume()); XCTAssertEqual(session.elapsedTime, 0)
    }
    func testNewSessionDoesNotReuseMission() {
        let first = GameSession(missionID: MissionID(rawValue: "escort")); first.dispose()
        let second = GameSession(); XCTAssertNil(second.missionID); XCTAssertNotEqual(first.identifier, second.identifier)
    }
    private func runningSession() -> GameSession { let value = GameSession(); _ = value.initializeWorld(); _ = value.start(); return value }
}
