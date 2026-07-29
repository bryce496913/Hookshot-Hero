import XCTest
@testable import HookshotHero

@MainActor final class SimulationClockTests: XCTestCase {
    func testEquivalentMovementAt60And120Hz() {
        var sixty = LinearMovementSimulation(velocity: 37); var oneTwenty = LinearMovementSimulation(velocity: 37)
        for _ in 0..<60 { sixty.update(deltaTime: 1.0 / 60.0) }
        for _ in 0..<120 { oneTwenty.update(deltaTime: 1.0 / 120.0) }
        XCTAssertEqual(sixty.position, oneTwenty.position, accuracy: 0.000_001) // floating-point accumulation tolerance
    }
    func testPausedAndDisposedSessionsDoNotAdvance() {
        let paused = runningSession(); _ = paused.pause(); paused.advance(by: 0.1); XCTAssertEqual(paused.elapsedTime, 0)
        let disposed = runningSession(); disposed.dispose(); disposed.advance(by: 0.1); XCTAssertEqual(disposed.elapsedTime, 0)
    }
    func testExcessiveDeltaIsClamped() {
        var clock = SimulationClock(maximumDeltaTime: 0.05)
        XCTAssertEqual(clock.delta(at: 10), 0); XCTAssertEqual(clock.delta(at: 20), 0.05)
    }
    private func runningSession() -> GameSession { let value = GameSession(); _ = value.initializeWorld(); _ = value.start(); return value }
}
