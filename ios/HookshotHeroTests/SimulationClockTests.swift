import XCTest
@testable import HookshotHero

final class SimulationClockTests: XCTestCase {
    func testFirstOrdinaryClampedAndNegativeDeltas() {
        var clock = SimulationClock(maximumDeltaTime: 0.05)
        XCTAssertEqual(clock.delta(at: 10), 0)
        XCTAssertEqual(clock.delta(at: 10.02), 0.02, accuracy: 0.000_001)
        XCTAssertEqual(clock.delta(at: 20), 0.05)
        XCTAssertEqual(clock.delta(at: 19), 0)
    }
    func testEveryLifecycleBoundaryMakesNextFrameZero() {
        var clock = SimulationClock(); _ = clock.delta(at: 1); _ = clock.delta(at: 2)
        for timestamp in [100.0, 200.0, 300.0] { clock.reset(); XCTAssertEqual(clock.delta(at: timestamp), 0) }
    }
    func testLongPauseDoesNotMoveOnFirstFrame() {
        var clock = SimulationClock(), simulation = LinearMovementSimulation(velocity: 10)
        simulation.update(deltaTime: clock.delta(at: 1)); clock.reset()
        simulation.update(deltaTime: clock.delta(at: 100)); XCTAssertEqual(simulation.position, 0)
    }
    func testEquivalentMovementAt60And120Hz() {
        var sixty = LinearMovementSimulation(velocity: 37), oneTwenty = LinearMovementSimulation(velocity: 37)
        for _ in 0..<60 { sixty.update(deltaTime: 1 / 60) }
        for _ in 0..<120 { oneTwenty.update(deltaTime: 1 / 120) }
        XCTAssertEqual(sixty.position, oneTwenty.position, accuracy: 0.000_001)
    }
}
