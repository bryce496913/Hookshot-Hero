import Foundation

struct GridSize: Equatable, Sendable {
    let rows: Int
    let columns: Int
}

struct GridPosition: Hashable, Codable, Sendable {
    var row: Int
    var column: Int

    func moved(_ direction: GridDirection) -> Self {
        .init(row: row + direction.delta.row, column: column + direction.delta.column)
    }
}

struct GridRegion: Equatable, Sendable {
    let rows: Range<Int>
    let columns: Range<Int>

    func contains(_ position: GridPosition) -> Bool {
        rows.contains(position.row) && columns.contains(position.column)
    }

    var cells: [GridPosition] {
        rows.flatMap { row in
            columns.map { GridPosition(row: row, column: $0) }
        }
    }
}

enum GridDirection: String, CaseIterable, Equatable, Sendable {
    case up
    case down
    case left
    case right

    var delta: (row: Int, column: Int) {
        switch self {
        case .up: return (-1, 0)
        case .down: return (1, 0)
        case .left: return (0, -1)
        case .right: return (0, 1)
        }
    }
}

enum GameCommand: Equatable, Sendable {
    case move(GridDirection)
    case beginMove(GridDirection)
    case endMove(GridDirection)
    case fireHook
}

enum EntityKind: Equatable, Sendable {
    case coin
    case cabbage
    case mine
}

struct EntityID: Hashable, Codable, Sendable {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct WorldEntity: Identifiable, Equatable, Sendable {
    let id: EntityID
    let kind: EntityKind
    let position: GridPosition
}

enum HookshotPhase: String, Equatable, Sendable {
    case idle
    case extending
    case latched
    case pulling
    case retracting
}

struct HookshotState: Equatable, Sendable {
    var phase: HookshotPhase = .idle
    var origin: GridPosition?
    var head: GridPosition?
    var direction: GridDirection = .right
    var travelled = 0
    var accumulator = 0.0

    static let maximumRange = 19
}

struct PlayerState: Equatable, Sendable {
    let id: EntityID
    var position: GridPosition
    var lastSafePosition: GridPosition
    var facing: GridDirection = .right
    var health = 3
    let maximumHealth = 5
    var score = 0
    var movementDirection: GridDirection?
    var hookshot = HookshotState()
    var damageCooldown = 0.0
    var animationTime = 0.0
}

struct LevelDefinition: Sendable {
    let grid: GridSize
    let start: GridPosition
    let exitAnchor: GridPosition
    let entryAnchor: GridPosition
    let chestAnchor: GridPosition
    let exitRegion: GridRegion
    let entryRegion: GridRegion
    let walls: [GridRegion]
    let lava: [GridRegion]
    let internalWallAnchors: [GridPosition]
    let displayName: String

    func isInside(_ position: GridPosition) -> Bool {
        (0..<grid.rows).contains(position.row) && (0..<grid.columns).contains(position.column)
    }

    func isWall(_ position: GridPosition) -> Bool {
        walls.contains { $0.contains(position) }
    }

    func isLava(_ position: GridPosition) -> Bool {
        lava.contains { $0.contains(position) }
    }
}

enum LevelOneDefinition {
    static let levelOneGrid = GridSize(rows: 60, columns: 60)
    static let boundaryTileSize = 4
    static let topDoorColumns = 27..<33

    static func make() -> LevelDefinition {
        let exit = GridRegion(rows: 0..<4, columns: topDoorColumns)
        let entry = GridRegion(rows: 56..<60, columns: 27..<33)

        // Java draws 40×40 perimeter tiles at y=0/y=560 and x=0/x=560.
        // Keep the top doorway traversable while retaining the complete closed bottom wall.
        var walls = [
            GridRegion(rows: 0..<4, columns: 0..<topDoorColumns.lowerBound),
            GridRegion(rows: 0..<4, columns: topDoorColumns.upperBound..<60),
            GridRegion(rows: 56..<60, columns: 0..<60),
            GridRegion(rows: 4..<56, columns: 0..<4),
            GridRegion(rows: 4..<56, columns: 56..<60)
        ]

        let internalWallAnchors = [20, 24, 28, 32, 36].map {
            GridPosition(row: 16, column: $0)
        }
        walls += internalWallAnchors.map {
            GridRegion(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
        }

        let lava = [24, 28, 32].flatMap { row in
            stride(from: 4, through: 52, by: 4).map {
                GridRegion(rows: row..<row + 4, columns: $0..<$0 + 4)
            }
        }

        return .init(
            grid: levelOneGrid,
            start: .init(row: 50, column: 27),
            exitAnchor: .init(row: 0, column: 27),
            entryAnchor: .init(row: 56, column: 27),
            chestAnchor: .init(row: 44, column: 29),
            exitRegion: exit,
            entryRegion: entry,
            walls: walls,
            lava: lava,
            internalWallAnchors: internalWallAnchors,
            displayName: "Level 1"
        )
    }
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}

enum SpawnError: LocalizedError {
    case insufficientCapacity

    var errorDescription: String? {
        "Level 1 does not contain enough safe cells for its items."
    }
}

enum SpawnService {
    static func spawn<R: RandomNumberGenerator>(
        in level: LevelDefinition,
        using randomNumberGenerator: inout R
    ) throws -> [WorldEntity] {
        var excluded = Set(
            level.walls.flatMap(\.cells)
                + level.lava.flatMap(\.cells)
                + level.exitRegion.cells
                + level.entryRegion.cells
        )
        excluded.insert(level.start)
        excluded.insert(level.chestAnchor)

        var candidates = (4..<56).flatMap { row in
            (4..<56).map { GridPosition(row: row, column: $0) }
        }.filter { !excluded.contains($0) }

        guard candidates.count >= 15 else {
            throw SpawnError.insufficientCapacity
        }

        candidates.shuffle(using: &randomNumberGenerator)
        let kinds = Array(repeating: EntityKind.mine, count: 3)
            + Array(repeating: .cabbage, count: 2)
            + Array(repeating: .coin, count: 10)

        return zip(kinds, candidates).map {
            WorldEntity(id: EntityID(), kind: $0, position: $1)
        }
    }
}

@MainActor
final class GameInputController: ObservableObject {
    private var queue: [GameCommand] = []

    func send(_ command: GameCommand) {
        queue.append(command)
    }

    func drain() -> [GameCommand] {
        defer { queue.removeAll() }
        return queue
    }
}

@MainActor
final class LevelOneSimulation: ObservableObject {
    static let chestMessage = "Welcome Heroine!! Tap Grapple to launch in the direction you are facing. Use it to cross lava, attack mines, and collect items. Chests and food barrels can restore health or add score. Beware of bombs."

    let level: LevelDefinition
    let input = GameInputController()

    @Published private(set) var player: PlayerState
    @Published private(set) var entities: [WorldEntity]
    @Published private(set) var chestOpen = false
    @Published var dialogue: String?
    @Published private(set) var feedback: String?

    private var movementAccumulator = 0.0
    private var feedbackRemaining = 0.0
    private(set) var outcome: GameOutcome?

    var onStatusChange: ((Int, Int) -> Void)?
    var onOutcome: ((GameOutcome) -> Void)?

    init(
        seed: UInt64 = UInt64.random(in: 1...UInt64.max),
        startOverride: GridPosition? = nil
    ) throws {
        level = LevelOneDefinition.make()
        let initialPosition = startOverride ?? level.start
        player = .init(
            id: EntityID(),
            position: initialPosition,
            lastSafePosition: initialPosition
        )
        var random = SeededRandomNumberGenerator(seed: seed)
        entities = try SpawnService.spawn(in: level, using: &random)
    }

    func update(deltaTime rawDeltaTime: TimeInterval) {
        let deltaTime = min(max(rawDeltaTime, 0), 0.1)
        guard outcome == nil else { return }

        player.damageCooldown = max(0, player.damageCooldown - deltaTime)
        player.animationTime += deltaTime
        feedbackRemaining -= deltaTime
        if feedbackRemaining <= 0 { feedback = nil }

        consumeCommands()
        updateHeldMovement(deltaTime)
        updateHook(deltaTime)
        checkChestAndExit()
        onStatusChange?(player.health, player.score)
    }

    private func consumeCommands() {
        for command in input.drain() {
            switch command {
            case .move(let direction):
                player.facing = direction
                attemptMove(direction)
            case .beginMove(let direction):
                player.facing = direction
                player.movementDirection = direction
                movementAccumulator = 0
                attemptMove(direction)
            case .endMove(let direction):
                if player.movementDirection == direction {
                    player.movementDirection = nil
                }
            case .fireHook:
                fireHook()
            }
        }
    }

    private func updateHeldMovement(_ deltaTime: Double) {
        guard let direction = player.movementDirection,
              player.hookshot.phase == .idle else { return }

        movementAccumulator += deltaTime
        while movementAccumulator >= 0.14 {
            movementAccumulator -= 0.14
            attemptMove(direction)
        }
    }

    private func attemptMove(_ direction: GridDirection) {
        guard player.hookshot.phase == .idle else { return }

        let next = player.position.moved(direction)
        guard level.isInside(next), !level.isWall(next) else { return }

        if level.isLava(next) {
            damageFromLava()
            return
        }

        player.position = next
        player.lastSafePosition = next
        interact(at: next, hooked: false)
    }

    private func damageFromLava() {
        guard player.damageCooldown <= 0 else { return }
        player.health -= 1
        player.damageCooldown = 0.75
        player.position = player.lastSafePosition
        show("-1 Health")
        checkLoss()
    }

    private func fireHook() {
        guard player.hookshot.phase == .idle else { return }
        player.movementDirection = nil
        player.hookshot = .init(
            phase: .extending,
            origin: player.position,
            head: player.position,
            direction: player.facing
        )
    }

    private func updateHook(_ deltaTime: Double) {
        guard player.hookshot.phase != .idle else { return }
        player.hookshot.accumulator += deltaTime * 18

        while player.hookshot.accumulator >= 1, player.hookshot.phase != .idle {
            player.hookshot.accumulator -= 1
            hookStep()
        }
    }

    private func hookStep() {
        switch player.hookshot.phase {
        case .extending:
            guard let head = player.hookshot.head else {
                player.hookshot.phase = .idle
                return
            }
            let next = head.moved(player.hookshot.direction)
            if !level.isInside(next) || level.isWall(next) {
                player.hookshot.phase = .latched
                player.hookshot.head = next
                return
            }
            player.hookshot.head = next
            player.hookshot.travelled += 1
            interact(at: next, hooked: true)
            if player.hookshot.travelled >= HookshotState.maximumRange {
                player.hookshot.phase = .retracting
            }
        case .latched:
            player.hookshot.phase = .pulling
        case .pulling:
            let next = player.position.moved(player.hookshot.direction)
            if level.isWall(next) || !level.isInside(next) {
                finishHook()
            } else {
                player.position = next
                interact(at: next, hooked: true)
            }
        case .retracting:
            finishHook()
        case .idle:
            break
        }
    }

    private func finishHook() {
        if !level.isLava(player.position) {
            player.lastSafePosition = player.position
        }
        player.hookshot = HookshotState()
    }

    private func interact(at position: GridPosition, hooked: Bool) {
        guard let entity = entities.first(where: { $0.position == position }) else { return }
        entities.removeAll { $0.id == entity.id }

        switch entity.kind {
        case .coin:
            player.score += 10
            show("+10")
        case .cabbage:
            let oldHealth = player.health
            player.health = min(player.maximumHealth, player.health + 1)
            show(player.health > oldHealth ? "+1 Health" : "Health Full")
        case .mine:
            if hooked {
                player.score += 10
                show("Mine explosion +10")
            } else {
                player.health -= 1
                show("-1 Health")
                checkLoss()
            }
        }
    }

    private func checkChestAndExit() {
        if !chestOpen,
           abs(player.position.row - level.chestAnchor.row) <= 2,
           abs(player.position.column - level.chestAnchor.column) <= 2 {
            chestOpen = true
            player.score += 100
            let oldHealth = player.health
            player.health = min(player.maximumHealth, player.health + 2)
            show(player.health - oldHealth == 2 ? "+100, +2 Health" : "+100, +1 Health")
            dialogue = Self.chestMessage
        }

        if level.exitRegion.contains(player.position), outcome == nil {
            player.score += 100
            show("Level complete +100")
            outcome = .won
            onStatusChange?(player.health, player.score)
            onOutcome?(.won)
        }
    }

    private func checkLoss() {
        if player.health <= 0, outcome == nil {
            outcome = .lost
            onOutcome?(.lost)
        }
    }

    private func show(_ text: String) {
        feedback = text
        feedbackRemaining = 1.2
    }
}
