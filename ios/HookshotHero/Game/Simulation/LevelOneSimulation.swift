import Foundation

struct GridSize: Equatable, Sendable { let rows: Int; let columns: Int }
struct GridPosition: Hashable, Sendable { var row: Int; var column: Int
    func moved(_ direction: GridDirection) -> Self { .init(row: row + direction.delta.row, column: column + direction.delta.column) }
}
struct GridRegion: Equatable, Sendable {
    let rows: Range<Int>; let columns: Range<Int>
    func contains(_ p: GridPosition) -> Bool { rows.contains(p.row) && columns.contains(p.column) }
    var cells: [GridPosition] { rows.flatMap { r in columns.map { GridPosition(row: r, column: $0) } } }
}
enum GridDirection: String, CaseIterable, Equatable, Sendable {
    case up, down, left, right
    var delta: (row: Int, column: Int) { switch self { case .up: (-1,0); case .down: (1,0); case .left: (0,-1); case .right: (0,1) } }
}
enum GameCommand: Equatable, Sendable { case move(GridDirection), beginMove(GridDirection), endMove(GridDirection), fireHook }
enum EntityKind: Equatable, Sendable { case coin, cabbage, mine }
struct WorldEntity: Identifiable, Equatable, Sendable { let id: UUID; let kind: EntityKind; let position: GridPosition }
enum HookshotPhase: String, Equatable, Sendable { case idle, extending, latched, pulling, retracting }
struct HookshotState: Equatable, Sendable {
    var phase: HookshotPhase = .idle; var origin: GridPosition?; var head: GridPosition?
    var direction: GridDirection = .right; var travelled = 0; var accumulator = 0.0
    static let maximumRange = 19
}
struct PlayerState: Equatable, Sendable {
    let id: UUID; var position: GridPosition; var lastSafePosition: GridPosition
    var facing: GridDirection = .right; var health = 3; let maximumHealth = 5; var score = 0
    var movementDirection: GridDirection?; var hookshot = HookshotState(); var damageCooldown = 0.0; var animationTime = 0.0
}

struct LevelDefinition: Sendable {
    let grid: GridSize; let start, exitAnchor, entryAnchor, chestAnchor: GridPosition
    let exitRegion, entryRegion: GridRegion; let walls, lava: [GridRegion]; let internalWallAnchors: [GridPosition]
    let displayName: String
    func isInside(_ p: GridPosition) -> Bool { (0..<grid.rows).contains(p.row) && (0..<grid.columns).contains(p.column) }
    func isWall(_ p: GridPosition) -> Bool { walls.contains { $0.contains(p) } }
    func isLava(_ p: GridPosition) -> Bool { lava.contains { $0.contains(p) } }
}

enum LevelOneDefinition {
    static let levelOneGrid = GridSize(rows: 60, columns: 60)
    static func make() -> LevelDefinition {
        let exit = GridRegion(rows: 0..<2, columns: 27..<33)
        let entry = GridRegion(rows: 56..<60, columns: 27..<33)
        var walls = [GridRegion(rows: 0..<2, columns: 0..<27), GridRegion(rows: 0..<2, columns: 33..<60),
                     GridRegion(rows: 58..<60, columns: 0..<60), GridRegion(rows: 0..<60, columns: 0..<2),
                     GridRegion(rows: 0..<60, columns: 58..<60), entry]
        let anchors = [20,24,28,32,36].map { GridPosition(row: 16, column: $0) }
        walls += anchors.map { GridRegion(rows: $0.row..<$0.row+4, columns: $0.column..<$0.column+4) }
        let lava = [24,28,32].flatMap { row in stride(from: 4, through: 52, by: 4).map { GridRegion(rows: row..<row+4, columns: $0..<$0+4) } }
        return .init(grid: levelOneGrid, start: .init(row: 50, column: 27), exitAnchor: .init(row: 0, column: 27),
                     entryAnchor: .init(row: 56, column: 27), chestAnchor: .init(row: 44, column: 29), exitRegion: exit,
                     entryRegion: entry, walls: walls, lava: lava, internalWallAnchors: anchors, displayName: "Level 1")
    }
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 { state ^= state >> 12; state ^= state << 25; state ^= state >> 27; return state &* 2685821657736338717 }
}
enum SpawnError: LocalizedError { case insufficientCapacity
    var errorDescription: String? { "Level 1 does not contain enough safe cells for its items." }
}
enum SpawnService {
    static func spawn<R: RandomNumberGenerator>(in level: LevelDefinition, using rng: inout R) throws -> [WorldEntity] {
        var excluded = Set(level.walls.flatMap(\.cells) + level.lava.flatMap(\.cells) + level.exitRegion.cells + level.entryRegion.cells)
        excluded.insert(level.start); excluded.insert(level.chestAnchor)
        var candidates = (2..<58).flatMap { r in (2..<58).map { GridPosition(row: r, column: $0) } }.filter { !excluded.contains($0) }
        guard candidates.count >= 15 else { throw SpawnError.insufficientCapacity }
        candidates.shuffle(using: &rng)
        let kinds = Array(repeating: EntityKind.mine, count: 3) + Array(repeating: .cabbage, count: 2) + Array(repeating: .coin, count: 10)
        return zip(kinds, candidates).map { WorldEntity(id: UUID(), kind: $0, position: $1) }
    }
}

@MainActor final class GameInputController: ObservableObject {
    private var queue: [GameCommand] = []
    func send(_ command: GameCommand) { queue.append(command) }
    func drain() -> [GameCommand] { defer { queue.removeAll() }; return queue }
}

@MainActor final class LevelOneSimulation: ObservableObject {
    static let chestMessage = "Welcome Heroine!! Tap the on-screen Hook button to launch grapple. You can use grapple to jump across lava, attack mines, and fetch items. Each level has chests that give extra score and health. Food barrels can also replenish your health. Beware of bombs."
    let level: LevelDefinition; let input = GameInputController()
    @Published private(set) var player: PlayerState
    @Published private(set) var entities: [WorldEntity]
    @Published private(set) var chestOpen = false
    @Published var dialogue: String?
    @Published private(set) var feedback: String?
    private var movementAccumulator = 0.0; private var feedbackRemaining = 0.0
    private(set) var outcome: GameOutcome?
    var onStatusChange: ((Int, Int) -> Void)?; var onOutcome: ((GameOutcome) -> Void)?

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) throws {
        level = LevelOneDefinition.make(); player = .init(id: UUID(), position: level.start, lastSafePosition: level.start)
        var random = SeededRandomNumberGenerator(seed: seed); entities = try SpawnService.spawn(in: level, using: &random)
    }
    func update(deltaTime raw: TimeInterval) {
        let dt = min(max(raw, 0), 0.1); guard outcome == nil else { return }
        player.damageCooldown = max(0, player.damageCooldown - dt); player.animationTime += dt
        feedbackRemaining -= dt; if feedbackRemaining <= 0 { feedback = nil }
        consumeCommands(); updateHeldMovement(dt); updateHook(dt); checkChestAndExit(); onStatusChange?(player.health, player.score)
    }
    private func consumeCommands() { for command in input.drain() { switch command {
        case .move(let d): player.facing = d; attemptMove(d)
        case .beginMove(let d): player.facing = d; player.movementDirection = d; movementAccumulator = 0; attemptMove(d)
        case .endMove(let d): if player.movementDirection == d { player.movementDirection = nil }
        case .fireHook: fireHook()
    } } }
    private func updateHeldMovement(_ dt: Double) { guard let d = player.movementDirection, player.hookshot.phase == .idle else { return }; movementAccumulator += dt; while movementAccumulator >= 0.14 { movementAccumulator -= 0.14; attemptMove(d) } }
    private func attemptMove(_ d: GridDirection) { guard player.hookshot.phase == .idle else { return }; let next = player.position.moved(d); guard level.isInside(next), !level.isWall(next) else { return }; if level.isLava(next) { damageFromLava(); return }; player.position = next; player.lastSafePosition = next; interact(at: next, hooked: false) }
    private func damageFromLava() { guard player.damageCooldown <= 0 else { return }; player.health -= 1; player.damageCooldown = 0.75; player.position = player.lastSafePosition; show("-1 Health"); checkLoss() }
    private func fireHook() { guard player.hookshot.phase == .idle else { return }; player.movementDirection = nil; player.hookshot = .init(phase: .extending, origin: player.position, head: player.position, direction: player.facing) }
    private func updateHook(_ dt: Double) { guard player.hookshot.phase != .idle else { return }; player.hookshot.accumulator += dt * 18
        while player.hookshot.accumulator >= 1, player.hookshot.phase != .idle { player.hookshot.accumulator -= 1; hookStep() }
    }
    private func hookStep() { switch player.hookshot.phase {
        case .extending:
            guard let head = player.hookshot.head else { player.hookshot.phase = .idle; return }; let next = head.moved(player.hookshot.direction)
            if !level.isInside(next) || level.isWall(next) { player.hookshot.phase = .latched; player.hookshot.head = next; return }
            player.hookshot.head = next; player.hookshot.travelled += 1; interact(at: next, hooked: true)
            if player.hookshot.travelled >= HookshotState.maximumRange { player.hookshot.phase = .retracting }
        case .latched: player.hookshot.phase = .pulling
        case .pulling:
            let next = player.position.moved(player.hookshot.direction)
            if level.isWall(next) || !level.isInside(next) { finishHook() } else { player.position = next; interact(at: next, hooked: true) }
        case .retracting: finishHook()
        case .idle: break
        }
    }
    private func finishHook() { if !level.isLava(player.position) { player.lastSafePosition = player.position }; player.hookshot = HookshotState() }
    private func interact(at p: GridPosition, hooked: Bool) { guard let entity = entities.first(where: { $0.position == p }) else { return }; entities.removeAll { $0.id == entity.id }
        switch entity.kind { case .coin: player.score += 10; show("+10")
        case .cabbage: let old = player.health; player.health = min(player.maximumHealth, player.health + 1); show(player.health > old ? "+1 Health" : "Health Full")
        case .mine: if hooked { player.score += 10; show("Mine explosion +10") } else { player.health -= 1; show("-1 Health"); checkLoss() } }
    }
    private func checkChestAndExit() { if !chestOpen && abs(player.position.row-level.chestAnchor.row) <= 2 && abs(player.position.column-level.chestAnchor.column) <= 2 { chestOpen = true; player.score += 100; let old = player.health; player.health = min(5, player.health+2); show(player.health-old == 2 ? "+100, +2 Health" : "+100, +1 Health"); dialogue = Self.chestMessage }
        if level.exitRegion.contains(player.position), outcome == nil { outcome = .won; onOutcome?(.won) }
    }
    private func checkLoss() { if player.health <= 0, outcome == nil { outcome = .lost; onOutcome?(.lost) } }
    private func show(_ text: String) { feedback = text; feedbackRemaining = 1.2 }
}
