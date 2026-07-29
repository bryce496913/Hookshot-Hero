import Foundation

struct SimulationClock: Sendable {
    let maximumDeltaTime: TimeInterval
    private(set) var lastTimestamp: TimeInterval?

    init(maximumDeltaTime: TimeInterval = 1.0 / 15.0) {
        precondition(maximumDeltaTime > 0)
        self.maximumDeltaTime = maximumDeltaTime
    }

    mutating func delta(at timestamp: TimeInterval) -> TimeInterval {
        defer { lastTimestamp = timestamp }
        guard let lastTimestamp else { return 0 }
        return min(max(timestamp - lastTimestamp, 0), maximumDeltaTime)
    }

    mutating func reset() { lastTimestamp = nil }
    func clamped(_ deltaTime: TimeInterval) -> TimeInterval { min(max(deltaTime, 0), maximumDeltaTime) }
}

struct LinearMovementSimulation: Sendable {
    var position: Double = 0
    let velocity: Double
    mutating func update(deltaTime: TimeInterval) { position += velocity * deltaTime }
}
