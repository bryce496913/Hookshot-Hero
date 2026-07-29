import XCTest
@testable import HookshotHero

@MainActor final class AppRouterTests: XCTestCase {
    private var directory: URL!; private var progression: ProgressionStore!; private var router: AppRouter!
    override func setUp() { directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString); progression = ProgressionStore(repository: ProgressionRepository(fileURL: directory.appending(path: "save.json"))); router = AppRouter(progressionStore: progression) }
    override func tearDownWithError() throws { if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) } }
    func testStartingSecondGameDisposesFirstAndUsesLatestConfiguration() {
        router.startGame(configuration: .init(reducedMotion: false, controlHintsEnabled: true)); let first = router.activeSession!
        router.startGame(configuration: .init(reducedMotion: true, controlHintsEnabled: false))
        XCTAssertEqual(first.state, .disposed); XCTAssertEqual(router.activeSession?.configuration, .init(reducedMotion: true, controlHintsEnabled: false)); XCTAssertEqual(router.path, [.gameplay])
    }
    func testReturnToMenuDisposesActiveSession() {
        router.startGame(); let session = router.activeSession!; router.returnToMenu(); router.returnToMenu()
        XCTAssertEqual(session.state, .disposed); XCTAssertNil(router.activeSession); XCTAssertTrue(router.path.isEmpty)
    }
    func testWinCreatesSingleImmutableResultAndUpdatesProgression() {
        router.startGame(); let session = router.activeSession!; _ = session.initializeWorld(); _ = session.start(); session.addScore(25); session.advance(by: 2); session.win(); session.win()
        guard case .results(let result) = router.path.first else { return XCTFail("Missing results") }
        XCTAssertEqual(router.path.count, 1); XCTAssertNil(router.activeSession); XCTAssertEqual(result.sessionID, session.identifier)
        XCTAssertEqual(result.levelID, session.levelID); XCTAssertEqual(result.score, 25); XCTAssertEqual(result.elapsedTime, 2); XCTAssertEqual(result.outcome, .won)
        XCTAssertEqual(progression.progression.highScore, 25); XCTAssertTrue(progression.progression.completedLevelIDs.contains(session.levelID))
    }
    func testLossCreatesOneResultWithoutCompletion() {
        router.startGame(); let session = router.activeSession!; _ = session.initializeWorld(); _ = session.start(); session.lose()
        guard case .results(let result) = router.path.first else { return XCTFail("Missing results") }
        XCTAssertEqual(result.outcome, .lost); XCTAssertTrue(progression.progression.completedLevelIDs.isEmpty)
    }
    func testStaleTerminalEventIsIgnored() {
        router.startGame(); let old = router.activeSession!; router.startGame(); let current = router.activeSession!
        router.finishGame(sessionID: old.identifier, outcome: .won)
        XCTAssertTrue(router.activeSession === current); XCTAssertEqual(router.path, [.gameplay])
    }
}
