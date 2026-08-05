import Foundation

struct GridSize: Equatable, Hashable, Sendable {
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
  func intersects(_ other: Self) -> Bool {
    rows.overlaps(other.rows) && columns.overlaps(other.columns)
  }
  var cells: [GridPosition] { rows.flatMap { row in columns.map { .init(row: row, column: $0) } } }
}

/// A device-independent hit box whose offsets are relative to the sprite's centered grid anchor.
struct CollisionFootprint: Equatable, Sendable {
  let rowOffsets: Range<Int>
  let columnOffsets: Range<Int>
  func region(at anchor: GridPosition) -> GridRegion {
    .init(
      rows: (anchor.row + rowOffsets.lowerBound)..<(anchor.row + rowOffsets.upperBound),
      columns: (anchor.column + columnOffsets.lowerBound)..<(anchor.column
        + columnOffsets.upperBound))
  }
  var isEmpty: Bool { rowOffsets.isEmpty || columnOffsets.isEmpty }
}

enum CollisionProfile {
  // Deliberately exclude transparent canvas padding while following the centered render anchor.
  static let player = CollisionFootprint(rowOffsets: -1..<2, columnOffsets: -1..<2)
  static let coin = CollisionFootprint(rowOffsets: 0..<1, columnOffsets: 0..<1)
  static let cabbage = CollisionFootprint(rowOffsets: -1..<2, columnOffsets: -1..<2)
  static let mine = CollisionFootprint(rowOffsets: -1..<1, columnOffsets: -1..<1)
  static let chest = CollisionFootprint(rowOffsets: -1..<2, columnOffsets: -1..<2)
  static let hookHead = CollisionFootprint(rowOffsets: 0..<1, columnOffsets: 0..<1)
  static func footprint(for kind: EntityKind) -> CollisionFootprint {
    switch kind {
    case .coin: coin
    case .cabbage: cabbage
    case .mine: mine
    }
  }
}

enum GridDirection: String, CaseIterable, Equatable, Sendable {
  case up, down, left, right
  var delta: (row: Int, column: Int) {
    switch self {
    case .up: (-1, 0)
    case .down: (1, 0)
    case .left: (0, -1)
    case .right: (0, 1)
    }
  }
}
enum GameCommand: Equatable, Sendable {
  case move(GridDirection)
  case beginMove(GridDirection)
  case endMove(GridDirection)
  case fireHook
}
enum EntityKind: Equatable, Sendable { case coin, cabbage, mine }
struct EntityID: Hashable, Codable, Sendable {
  let rawValue: UUID
  init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}
struct WorldEntity: Identifiable, Equatable, Sendable {
  let id: EntityID
  let kind: EntityKind
  let position: GridPosition
}

struct LevelBoundaryGeometry: Equatable, Sendable {
  let topWallRegions: [GridRegion]
  let bottomWallRegions: [GridRegion]
  let leftWallRegions: [GridRegion]
  let rightWallRegions: [GridRegion]
  let topExitRegion: GridRegion
  let bottomDoorRegion: GridRegion
  var wallRegions: [GridRegion] {
    topWallRegions + bottomWallRegions + leftWallRegions + rightWallRegions
  }
}

enum HookshotPhase: String, Equatable, Sendable {
  case idle, extending, latched, pulling, retracting
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
  let start, exitAnchor, entryAnchor, chestAnchor: GridPosition
  let boundary: LevelBoundaryGeometry
  let walls, lava: [GridRegion]
  let internalWallAnchors: [GridPosition]
  let displayName: String
  var exitRegion: GridRegion { boundary.topExitRegion }
  var entryRegion: GridRegion { boundary.bottomDoorRegion }
  func isInside(_ p: GridPosition) -> Bool {
    (0..<grid.rows).contains(p.row) && (0..<grid.columns).contains(p.column)
  }
  func isWall(_ p: GridPosition) -> Bool { walls.contains { $0.contains(p) } }
  func isLava(_ p: GridPosition) -> Bool { lava.contains { $0.contains(p) } }
  func isBlocked(_ region: GridRegion) -> Bool {
    !region.cells.allSatisfy(isInside) || walls.contains { $0.intersects(region) }
  }
  func overlapsLava(_ region: GridRegion) -> Bool { lava.contains { $0.intersects(region) } }
}

enum LevelOneDefinition {
  static let levelOneGrid = GridSize(rows: 60, columns: 60)
  static let boundaryTileSize = 4
  static let boundary = LevelBoundaryGeometry(
    topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
    bottomWallRegions: [.init(rows: 56..<60, columns: 0..<60)],
    leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
    rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
    topExitRegion: .init(rows: 0..<4, columns: 27..<33),
    bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
  static let topDoorColumns = boundary.topExitRegion.columns
  static func make() -> LevelDefinition {
    let anchors = [20, 24, 28, 32, 36].map { GridPosition(row: 16, column: $0) }
    let internalWalls = anchors.map {
      GridRegion(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
    }
    let lava = [24, 28, 32].flatMap { row in
      stride(from: 4, through: 52, by: 4).map {
        GridRegion(rows: row..<row + 4, columns: $0..<$0 + 4)
      }
    }
    return .init(
      grid: levelOneGrid, start: .init(row: 50, column: 27), exitAnchor: .init(row: 0, column: 27),
      entryAnchor: .init(row: 56, column: 27), chestAnchor: .init(row: 44, column: 29),
      boundary: boundary, walls: boundary.wallRegions + internalWalls, lava: lava,
      internalWallAnchors: anchors, displayName: "Level 1")
  }
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
  private var state: UInt64
  init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
  mutating func next() -> UInt64 {
    state ^= state >> 12
    state ^= state << 25
    state ^= state >> 27
    return state &* 2_685_821_657_736_338_717
  }
}
struct EntitySpawnRequirement: Equatable, Sendable { let kind: EntityKind; let count: Int }

enum SpawnError: LocalizedError {
  case insufficientCapacity
  var errorDescription: String? {
    "Level 1 does not contain enough footprint-safe space for its items."
  }
}
enum SpawnService {
  static func spawn<R: RandomNumberGenerator>(in level: LevelDefinition, using rng: inout R) throws
    -> [WorldEntity]
  {
    try spawn(in: level, requirements: [.init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2), .init(kind: .coin, count: 10)], protectedRegions: [], using: &rng)
  }
  static func spawn<R: RandomNumberGenerator>(in level: LevelDefinition, requirements: [EntitySpawnRequirement], protectedRegions extraProtected: [GridRegion], using rng: inout R) throws -> [WorldEntity] {
    let kinds = requirements.flatMap { Array(repeating: $0.kind, count: $0.count) }
    var candidates = (4..<56).flatMap { r in (4..<56).map { GridPosition(row: r, column: $0) } }
    candidates.shuffle(using: &rng)
    let protected = [
      CollisionProfile.player.region(at: level.start),
      CollisionProfile.chest.region(at: level.chestAnchor), level.exitRegion, level.entryRegion,
    ] + extraProtected
    var result: [WorldEntity] = []
    for kind in kinds {
      let footprint = CollisionProfile.footprint(for: kind)
      guard
        let index = candidates.firstIndex(where: { p in
          let region = footprint.region(at: p)
          return !level.isBlocked(region) && !level.overlapsLava(region)
            && !protected.contains(where: { $0.intersects(region) })
            && !result.contains(where: {
              CollisionProfile.footprint(for: $0.kind).region(at: $0.position).intersects(region)
            })
        })
      else { throw SpawnError.insufficientCapacity }
      result.append(.init(id: EntityID(), kind: kind, position: candidates.remove(at: index)))
    }
    return result
  }
}

enum DamageSource: Equatable, Sendable { case lava, mine, enemy(EnemyArchetype) }

enum LevelEntryPosition: Hashable, Sendable { case bottom, top }
struct PlayerCarryoverState: Hashable, Sendable { let characterID: EntityID; let health: Int; let score: Int; let completedLevelIDs: Set<LevelID> }
struct LevelTransitionRequest: Hashable, Sendable { let sourceLevelID: LevelID; let destinationLevelID: LevelID; let destinationEntry: LevelEntryPosition; let carryover: PlayerCarryoverState }
enum LevelDestination: Equatable, Sendable { case level(LevelID, entry: LevelEntryPosition); case currentContentComplete(nextLevelID: LevelID?) }
enum GameplayFeedbackKind: Equatable, Sendable {
  case coinCollected(points: Int)
  case chestReward(score: Int, health: Int)
  case healthItemCollected(amount: Int)
  case healthAlreadyFull
  case healthLost(amount: Int, source: DamageSource)
  case mineDestroyed(points: Int)
  case levelCompleted(points: Int)
  case enemyHit(archetype: EnemyArchetype, points: Int, remainingHealth: Int)
  case enemyDefeated(archetype: EnemyArchetype)

  var visualMessage: String {
    switch self {
    case .coinCollected(let points): "Coin: +\(points) Score"
    case .chestReward(let score, let health):
      health > 0
        ? "Chest: +\(score) Score, +\(health) Health" : "Chest: +\(score) Score, Health Full"
    case .healthItemCollected(let amount): "+\(amount) Health"
    case .healthAlreadyFull: "Health Full"
    case .healthLost(let amount, _): "-\(amount) Health"
    case .mineDestroyed(let points): "Mine: +\(points) Score"
    case .levelCompleted(let points): "Level Complete: +\(points) Score"
    case .enemyHit(let archetype, let points, _): "\(archetype.displayName) hit: +\(points)"
    case .enemyDefeated(let archetype): "\(archetype.displayName) defeated"
    }
  }

  var accessibilityAnnouncement: String {
    switch self {
    case .coinCollected(let points): "Coin collected. Plus \(points) score."
    case .chestReward(let score, let health):
      health > 0
        ? "Chest opened. Plus \(score) score and \(health) health."
        : "Chest opened. Plus \(score) score. Health is already full."
    case .healthItemCollected(let amount): "Health restored. Plus \(amount) health."
    case .healthAlreadyFull: "Health is already full."
    case .healthLost(let amount, _): "Damage taken. Minus \(amount) health."
    case .mineDestroyed(let points): "Mine destroyed. Plus \(points) score."
    case .levelCompleted(let points): "Level complete. Plus \(points) score."
    case .enemyHit(let archetype, let points, let remaining): "\(archetype.displayName) hit. Plus \(points) score. \(remaining) health remaining."
    case .enemyDefeated(let archetype): "\(archetype.displayName) defeated."
    }
  }
}
struct GameplayFeedback: Identifiable, Equatable, Sendable {
  let id: UUID
  let kind: GameplayFeedbackKind
  let coordinate: GridPosition?
  let createdAt, duration: TimeInterval
  var message: String { kind.visualMessage }
  var accessibilityAnnouncement: String { kind.accessibilityAnnouncement }
}
struct PlayerStatusSnapshot: Equatable, Sendable {
  let health: Int
  let score: Int
}

/// The complete set of values SwiftUI is allowed to observe during gameplay.
/// Render positions and animation clocks intentionally do not belong here.
struct GameplayUISnapshot: Equatable, Sendable {
  let levelID: LevelID
  let levelName: String
  let health: Int
  let maximumHealth: Int
  let score: Int
  let canMove: Bool
  let canGrapple: Bool
  let isPaused: Bool
  let dialogue: String?
  let feedback: [GameplayFeedback]
  let diagnosticPlayerPosition: GridPosition?
}

struct RenderAssetID: Hashable, Codable, Sendable { let rawValue: String }
struct RenderAnimationID: Hashable, Codable, Sendable { let rawValue: String }
struct RenderLayerID: Hashable, Codable, Sendable { let rawValue: String }
struct LogicalRenderSize: Equatable, Sendable {
  let width: Double
  let height: Double
}
struct RenderAnchor: Equatable, Sendable {
  let x: Double
  let y: Double
  static let center = Self(x: 0.5, y: 0.5)
  static let bottomLeft = Self(x: 0, y: 0)
}
enum RenderOrientation: String, Sendable { case up, down, left, right, none }
struct TextureSourceRect: Equatable, Sendable {
  let x, y, width, height, sheetWidth, sheetHeight: Double
}
struct RenderAnimationSnapshot: Equatable, Sendable {
  let animationID: RenderAnimationID
  let frameIndex: Int
}
struct BackgroundRenderDescriptor: Sendable { let colorName: String }
struct TileRenderPlacement: Sendable {
  let coordinate: GridPosition
  let sizeInCells: LogicalRenderSize
  let asset: RenderAssetID
  let anchor: RenderAnchor
}
struct TileLayerRenderDescriptor: Sendable {
  let id: RenderLayerID
  let zPosition: Double
  let tiles: [TileRenderPlacement]
}
struct StaticRenderDescriptor: Sendable {
  let id: EntityID
  let asset: RenderAssetID
  let coordinate: GridPosition
  let renderSize: LogicalRenderSize
  let anchor: RenderAnchor
  let zPosition: Double
}
struct LevelPresentationDefinition: Sendable {
  let levelID: LevelID
  let logicalGridSize: GridSize
  let background: BackgroundRenderDescriptor
  let tileLayers: [TileLayerRenderDescriptor]
  let staticObjects: [StaticRenderDescriptor]
}
struct RenderEntitySnapshot: Identifiable, Sendable {
  let id: EntityID
  let asset: RenderAssetID
  let coordinate: GridPosition
  let renderSize: LogicalRenderSize
  let anchor: RenderAnchor
  let zPosition: Double
  let orientation: RenderOrientation
  let animation: RenderAnimationSnapshot?
  let opacity: Double
  let isHidden: Bool
  let health: RenderHealthSnapshot?
  init(id: EntityID, asset: RenderAssetID, coordinate: GridPosition, renderSize: LogicalRenderSize, anchor: RenderAnchor, zPosition: Double, orientation: RenderOrientation, animation: RenderAnimationSnapshot?, opacity: Double, isHidden: Bool, health: RenderHealthSnapshot? = nil) { self.id=id; self.asset=asset; self.coordinate=coordinate; self.renderSize=renderSize; self.anchor=anchor; self.zPosition=zPosition; self.orientation=orientation; self.animation=animation; self.opacity=opacity; self.isHidden=isHidden; self.health=health }
}
struct RenderHealthSnapshot: Equatable, Sendable { let current: Int; let maximum: Int }
struct GrappleRenderSnapshot: Sendable {
  let origin: GridPosition
  let head: GridPosition
}
struct RenderEffectDescriptor: Equatable, Sendable {
  let duration: TimeInterval
  let initialRadius: Double
  let finalScale: Double
  let zPosition: Double
  var scales: Bool { finalScale != 1 }
  static func mineDestruction(reducedMotion: Bool) -> Self {
    .init(duration: 0.35, initialRadius: 1.8, finalScale: reducedMotion ? 1 : 1.8, zPosition: 9)
  }
  static func enemyDefeat(reducedMotion: Bool) -> Self { .init(duration: 0.4, initialRadius: 2.2, finalScale: reducedMotion ? 1 : 2, zPosition: 9) }
}
struct RenderEffectSnapshot: Identifiable, Equatable, Sendable {
  let id: UUID
  let coordinate: GridPosition
  let descriptor: RenderEffectDescriptor
  let createdAt: TimeInterval
}
struct GameRenderSnapshot: Sendable {
  let player: RenderEntitySnapshot
  let entities: [RenderEntitySnapshot]
  let grapple: GrappleRenderSnapshot?
  let effects: [RenderEffectSnapshot]
}

enum LevelOneRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-one.floor"),
    lava = RenderAssetID(rawValue: "level-one.lava")
  static let wallFront = RenderAssetID(rawValue: "level-one.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-one.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-one.wall.right")
  static let exitDoor = RenderAssetID(rawValue: "level-one.door.open"),
    entryDoor = RenderAssetID(rawValue: "level-one.door.closed")
  static let lidia = RenderAssetID(rawValue: "character.lidia"),
    coin = RenderAssetID(rawValue: "level-one.coin"),
    cabbage = RenderAssetID(rawValue: "level-one.cabbage"),
    mine = RenderAssetID(rawValue: "level-one.mine")
  static let chestClosed = RenderAssetID(rawValue: "level-one.chest.closed"),
    chestOpen = RenderAssetID(rawValue: "level-one.chest.open")
}
enum LevelOneRenderAnimations {
  static func lidiaWalk(_ orientation: RenderOrientation) -> RenderAnimationID {
    RenderAnimationID(rawValue: "character.lidia.walk.\(orientation.rawValue)")
  }
  static let coinSpin = RenderAnimationID(rawValue: "level-one.coin.spin")
}

enum LevelOnePresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ region: GridRegion, _ asset: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: region.rows.lowerBound, column: region.columns.lowerBound),
        sizeInCells: .init(width: Double(region.columns.count), height: Double(region.rows.count)),
        asset: asset, anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: level.grid.rows, by: 10).flatMap { row in
      stride(from: 0, to: level.grid.columns, by: 10).map { col in
        tile(
          .init(
            rows: row..<min(row + 10, level.grid.rows),
            columns: col..<min(col + 10, level.grid.columns)), LevelOneRenderAssets.floor)
      }
    }
    let walls =
      level.boundary.topWallRegions.map { tile($0, LevelOneRenderAssets.wallFront) }
      + level.boundary.bottomWallRegions.map { tile($0, LevelOneRenderAssets.wallFront) }
      + level.boundary.leftWallRegions.map { tile($0, LevelOneRenderAssets.wallLeft) }
      + level.boundary.rightWallRegions.map { tile($0, LevelOneRenderAssets.wallRight) }
      + level.internalWallAnchors.map {
        tile(
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4),
          LevelOneRenderAssets.wallFront)
      }
    return .init(
      levelID: .levelOne, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelOneRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelOneRenderAssets.exitDoor,
          coordinate: .init(
            row: level.exitRegion.rows.lowerBound, column: level.exitRegion.columns.lowerBound),
          renderSize: .init(
            width: Double(level.exitRegion.columns.count),
            height: Double(level.exitRegion.rows.count)), anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelOneRenderAssets.entryDoor,
          coordinate: .init(
            row: level.entryRegion.rows.lowerBound, column: level.entryRegion.columns.lowerBound),
          renderSize: .init(
            width: Double(level.entryRegion.columns.count),
            height: Double(level.entryRegion.rows.count)), anchor: .bottomLeft, zPosition: 3),
      ])
  }
}

@MainActor protocol GameSimulation: AnyObject {
  var levelID: LevelID { get }
  var levelName: String { get }
  var presentationDefinition: LevelPresentationDefinition { get }
  var outcome: GameOutcome? { get }
  var finalStatus: PlayerStatusSnapshot { get }
  var uiSnapshot: GameplayUISnapshot { get }
  var renderSnapshot: GameRenderSnapshot { get }
  var inputController: GameInputController { get }
  var onUISnapshotChange: ((GameplayUISnapshot) -> Void)? { get set }
  var onOutcome: ((GameOutcome) -> Void)? { get set }
  var onLevelTransition: ((LevelTransitionRequest) -> Void)? { get set }
  var onDialogue: ((String) -> Void)? { get set }
  func update(deltaTime: TimeInterval)
  func continueDialogue()
  func setPaused(_ paused: Bool)
  func cancelAllInput()
  func dispose()
}

enum GameLoadingError: LocalizedError, Equatable, Sendable {
  case unsupportedLevel(LevelID)
  case invalidLevelDefinition(LevelID)
  case missingRequiredAsset(String)
  case invalidTextureRegion(String)
  case spawnFailure(LevelID)
  case invalidInitialState(LevelID)
  var errorDescription: String? {
    switch self {
    case .unsupportedLevel(let id): "Unsupported level: \(id.rawValue)."
    case .invalidLevelDefinition(let id): "Invalid definition for \(id.rawValue)."
    case .missingRequiredAsset(let id): "Missing required asset \(id)."
    case .invalidTextureRegion(let id): "Invalid texture region \(id)."
    case .spawnFailure(let id): "Could not spawn \(id.rawValue)."
    case .invalidInitialState(let id): "Invalid initial state for \(id.rawValue)."
    }
  }
  var diagnosticCode: String {
    switch self {
    case .unsupportedLevel: "unsupported-level"
    case .invalidLevelDefinition: "invalid-definition"
    case .missingRequiredAsset: "missing-asset"
    case .invalidTextureRegion: "invalid-texture-region"
    case .spawnFailure: "spawn-failure"
    case .invalidInitialState: "invalid-initial-state"
    }
  }
}
struct LevelAssetManifest: Equatable, Sendable {
  let textureAssetIDs: Set<RenderAssetID>
  let animationIDs: Set<RenderAnimationID>
}
@MainActor struct GameLevelRuntime {
  let simulation: any GameSimulation
  let presentation: LevelPresentationDefinition
  let textureCatalog: any TextureCatalogProviding
  let animationCatalog: any AnimationCatalogProviding
  let assetManifest: LevelAssetManifest
}
@MainActor protocol AssetPreflighting {
  func validate(manifest: LevelAssetManifest, textureCatalog: any TextureCatalogProviding, animationCatalog: any AnimationCatalogProviding) throws
}
@MainActor struct DefaultAssetPreflight: AssetPreflighting {
  func validate(manifest: LevelAssetManifest, textureCatalog: any TextureCatalogProviding, animationCatalog: any AnimationCatalogProviding) throws {
    for assetID in manifest.textureAssetIDs { _ = try textureCatalog.texture(for: assetID) }
    for animationID in manifest.animationIDs {
      let frames = try animationCatalog.frames(for: animationID)
      if frames.isEmpty { throw GameLoadingError.missingRequiredAsset(animationID.rawValue) }
    }
  }
}
@MainActor protocol GameLevelRuntimeFactory {
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws -> GameLevelRuntime
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?, entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?) throws -> GameLevelRuntime
}
@MainActor struct DefaultGameLevelRuntimeFactory: GameLevelRuntimeFactory {
  let simulationFactory: any GameSimulationFactory
  let preflight: any AssetPreflighting
  init(simulationFactory: any GameSimulationFactory = DefaultGameSimulationFactory(), preflight: any AssetPreflighting = DefaultAssetPreflight()) { self.simulationFactory = simulationFactory; self.preflight = preflight }
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws -> GameLevelRuntime {
    try makeRuntime(levelID: levelID, configuration: configuration, seed: seed, entryPosition: .bottom, carryover: nil)
  }
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?, entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?) throws -> GameLevelRuntime {
    let simulation = try simulationFactory.makeSimulation(levelID: levelID, configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover)
    let textureCatalog = TextureCatalog(entries: LevelOneTextureCatalog.entries)
    let animationCatalog = LevelOneAnimationCatalog(textureCatalog: textureCatalog)
    let manifest = levelID == .levelTwo ? LevelAssetManifest.levelTwo : LevelAssetManifest.levelOne
    do { try preflight.validate(manifest: manifest, textureCatalog: textureCatalog, animationCatalog: animationCatalog) }
    catch let e as TextureCatalogError { simulation.dispose(); throw e.gameLoadingError }
    catch let e as GameLoadingError { simulation.dispose(); throw e }
    catch { simulation.dispose(); throw GameLoadingError.invalidLevelDefinition(levelID) }
    return .init(simulation: simulation, presentation: simulation.presentationDefinition, textureCatalog: textureCatalog, animationCatalog: animationCatalog, assetManifest: manifest)
  }
}
extension TextureCatalogError {
  var gameLoadingError: GameLoadingError {
    switch self {
    case .missingAsset(let id): .missingRequiredAsset(id.rawValue)
    case .invalidRegion(let id): .invalidTextureRegion(id.rawValue)
    }
  }
}
extension LevelAssetManifest {
  static let levelOne = LevelAssetManifest(textureAssetIDs: Set(LevelOneTextureCatalog.entries.keys), animationIDs: Set([LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up), LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left), LevelOneRenderAnimations.lidiaWalk(.right)]))
  static let levelTwo = LevelAssetManifest(textureAssetIDs: Set(LevelOneTextureCatalog.entries.keys), animationIDs: Set([LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up), LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left), LevelOneRenderAnimations.lidiaWalk(.right), LevelTwoRenderAnimations.enemy(.skeleton,.up), LevelTwoRenderAnimations.enemy(.skeleton,.down), LevelTwoRenderAnimations.enemy(.skeleton,.left), LevelTwoRenderAnimations.enemy(.skeleton,.right), LevelTwoRenderAnimations.enemy(.flyingTerror,.up), LevelTwoRenderAnimations.enemy(.flyingTerror,.down), LevelTwoRenderAnimations.enemy(.flyingTerror,.left), LevelTwoRenderAnimations.enemy(.flyingTerror,.right)]))
}
@MainActor protocol GameSimulationFactory {
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> any GameSimulation
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?, entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?) throws
    -> any GameSimulation
}
struct DefaultGameSimulationFactory: GameSimulationFactory {
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws -> any GameSimulation {
    try makeSimulation(levelID: levelID, configuration: configuration, seed: seed, entryPosition: .bottom, carryover: nil)
  }
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?, entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?) throws -> any GameSimulation {
    do {
      switch levelID {
      case .levelOne:
        return try LevelOneSimulation(configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max), entryPosition: entryPosition, carryover: carryover)
      case .levelTwo:
        return try LevelTwoSimulation(configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max), entryPosition: entryPosition, carryover: carryover)
      default:
        throw GameLoadingError.unsupportedLevel(levelID)
      }
    } catch let e as GameLoadingError { throw e } catch { throw GameLoadingError.spawnFailure(levelID) }
  }
}

@MainActor final class GameInputController: ObservableObject {
  private var queue: [GameCommand] = []
  @Published private(set) var heldDirection: GridDirection?
  @Published private(set) var cancellationGeneration = 0
  func send(_ command: GameCommand) {
    if case .beginMove(let d) = command { heldDirection = d }
    if case .endMove(let d) = command, heldDirection == d { heldDirection = nil }
    queue.append(command)
  }
  func drain() -> [GameCommand] {
    defer { queue.removeAll() }
    return queue
  }
  func cancelAllInput() {
    queue.removeAll()
    heldDirection = nil
    cancellationGeneration &+= 1
  }
}

@MainActor class LevelOneSimulation: GameSimulation {
  static let chestMessage =
    "Welcome Heroine!! Tap Grapple to launch in the direction you are facing. Use it to cross lava, attack mines, and collect items. Chests and food barrels can restore health or add score. Beware of bombs."
  var level: LevelDefinition
  var presentationDefinition: LevelPresentationDefinition
  let input = GameInputController()
  let configuration: GameConfiguration
  let seed: UInt64
  var player: PlayerState
  var entities: [WorldEntity]
  private(set) var chestOpen = false
  private(set) var feedbackEvents: [GameplayFeedback] = []
  var effectEvents: [RenderEffectSnapshot] = []
  private var movementAccumulator = 0.0
  var simulationTime = 0.0
  private(set) var outcome: GameOutcome?
  private var lastPublishedStatus: PlayerStatusSnapshot
  private var lastPublishedUISnapshot: GameplayUISnapshot
  var completedLevelIDs: Set<LevelID> = []
  var onStatusChange: ((PlayerStatusSnapshot) -> Void)?
  var onUISnapshotChange: ((GameplayUISnapshot) -> Void)?
  var onOutcome: ((GameOutcome) -> Void)?
  var onLevelTransition: ((LevelTransitionRequest) -> Void)?
  var onDialogue: ((String) -> Void)?
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = UInt64.random(in: 1...UInt64.max), entryPosition: LevelEntryPosition = .bottom, carryover: PlayerCarryoverState? = nil, startOverride: GridPosition? = nil,
    entities fixture: [WorldEntity]? = nil
  ) throws {
    self.configuration = configuration
    self.seed = seed
    level = LevelOneDefinition.make()
    presentationDefinition = LevelOnePresentationDefinition.make(from: level)
    let entryStart = entryPosition == .top ? GridPosition(row: 5, column: 23) : level.start
    let initial = startOverride ?? entryStart
    player = .init(id: carryover?.characterID ?? EntityID(), position: initial, lastSafePosition: initial)
    player.health = carryover?.health ?? 3; player.score = carryover?.score ?? 0
    completedLevelIDs = carryover?.completedLevelIDs ?? []
    lastPublishedStatus = .init(health: player.health, score: player.score)
    lastPublishedUISnapshot = .init(
      levelID: .levelOne, levelName: "Level 1", health: 3, maximumHealth: 5, score: 0,
      canMove: true, canGrapple: true, isPaused: false, dialogue: nil, feedback: [],
      diagnosticPlayerPosition: nil)
    var rng = SeededRandomNumberGenerator(seed: seed)
    entities = try fixture ?? SpawnService.spawn(in: level, using: &rng)
  }
  var levelID: LevelID { .levelOne }
  var levelName: String { level.displayName }
  var finalStatus: PlayerStatusSnapshot { .init(health: player.health, score: player.score) }
  var inputController: GameInputController { input }
  var uiSnapshot: GameplayUISnapshot {
    .init(
      levelID: levelID, levelName: levelName, health: player.health,
      maximumHealth: player.maximumHealth, score: player.score, canMove: outcome == nil,
      canGrapple: outcome == nil && player.hookshot.phase == .idle, isPaused: false, dialogue: nil,
      feedback: feedbackEvents, diagnosticPlayerPosition: nil)
  }
  var renderSnapshot: GameRenderSnapshot {
    let orientation = RenderOrientation(rawValue: player.facing.rawValue) ?? .none
    let walking = player.movementDirection != nil && player.hookshot.phase == .idle
    let playerRender = RenderEntitySnapshot(
      id: player.id, asset: LevelOneRenderAssets.lidia, coordinate: player.position,
      renderSize: .init(width: 5.4, height: 4.4), anchor: .center, zPosition: 8,
      orientation: orientation,
      animation: .init(
        animationID: LevelOneRenderAnimations.lidiaWalk(orientation),
        frameIndex: configuration.reducedMotion || !walking
          ? 0 : Int(player.animationTime / 0.09) % 9), opacity: 1, isHidden: false)
    let world = entities.map { entity -> RenderEntitySnapshot in
      let data: (RenderAssetID, LogicalRenderSize, RenderAnimationSnapshot?) =
        switch entity.kind {
        case .coin:
          (
            LevelOneRenderAssets.coin, .init(width: 2, height: 2),
            .init(
              animationID: LevelOneRenderAnimations.coinSpin,
              frameIndex: configuration.reducedMotion ? 0 : Int(player.animationTime / 0.08) % 9)
          )
        case .mine: (LevelOneRenderAssets.mine, .init(width: 2, height: 2.6), nil)
        case .cabbage: (LevelOneRenderAssets.cabbage, .init(width: 3.2, height: 3.2), nil)
        }
      return .init(
        id: entity.id, asset: data.0, coordinate: entity.position, renderSize: data.1,
        anchor: .center, zPosition: 6, orientation: .none, animation: data.2, opacity: 1,
        isHidden: false)
    }
    let chest = RenderEntitySnapshot(
      id: EntityID(UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))),
      asset: chestOpen ? LevelOneRenderAssets.chestOpen : LevelOneRenderAssets.chestClosed, coordinate: level.chestAnchor,
      renderSize: .init(width: 2.5, height: chestOpen ? 2.9 : 2.5), anchor: .center, zPosition: 5,
      orientation: .none, animation: nil, opacity: 1, isHidden: false)
    let grapple =
      player.hookshot.phase != .idle && player.hookshot.head != nil
      ? GrappleRenderSnapshot(origin: player.position, head: player.hookshot.head!) : nil
    return .init(player: playerRender, entities: world + [chest], grapple: grapple, effects: effectEvents)
  }
  func update(deltaTime raw: TimeInterval) {
    guard outcome == nil else { return }
    let dt = min(max(raw, 0), 0.1)
    simulationTime += dt
    player.damageCooldown = max(0, player.damageCooldown - dt)
    player.animationTime += dt
    feedbackEvents.removeAll { $0.createdAt + $0.duration <= simulationTime }
    effectEvents.removeAll { $0.createdAt + $0.descriptor.duration <= simulationTime }
    consumeCommands()
    guard outcome == nil else { return }
    updateHeldMovement(dt)
    guard outcome == nil else { return }
    updateHook(dt)
    guard outcome == nil else { return }
    checkChestAndExit()
    guard outcome == nil else { return }
    publishStatusIfChanged()
    publishUISnapshotIfChanged()
  }
  func continueDialogue() { publishUISnapshotIfChanged() }
  func setPaused(_ paused: Bool) { if paused { cancelAllInput() } }
  func dispose() {
    cancelAllInput()
    onUISnapshotChange = nil
    onOutcome = nil
    onLevelTransition = nil
    onDialogue = nil
  }
  func cancelAllInput() {
    input.cancelAllInput()
    player.movementDirection = nil
    movementAccumulator = 0
  }
  private func consumeCommands() {
    for command in input.drain() {
      guard outcome == nil else { break }
      process(command)
    }
  }
  private func process(_ command: GameCommand) {
    guard outcome == nil else { return }
    switch command {
    case .move(let d):
      player.facing = d
      attemptMove(d)
    case .beginMove(let d):
      player.facing = d
      player.movementDirection = d
      movementAccumulator = 0
      attemptMove(d)
    case .endMove(let d): if player.movementDirection == d { player.movementDirection = nil }
    case .fireHook: fireHook()
    }
  }
  private func updateHeldMovement(_ dt: Double) {
    guard outcome == nil, let d = player.movementDirection, player.hookshot.phase == .idle else {
      return
    }
    movementAccumulator += dt
    while movementAccumulator >= 0.14 {
      guard outcome == nil else { return }
      movementAccumulator -= 0.14
      attemptMove(d)
    }
  }
  func attemptMove(_ d: GridDirection) {
    guard outcome == nil, player.hookshot.phase == .idle else { return }
    let next = player.position.moved(d)
    let region = CollisionProfile.player.region(at: next)
    guard !level.isBlocked(region) else { return }
    if level.overlapsLava(region) {
      damageFromLava()
      return
    }
    player.position = next
    player.lastSafePosition = next
    interact(region, hooked: false)
    publishStatusIfChanged()
  }
  private func damageFromLava() {
    guard outcome == nil, player.damageCooldown <= 0 else { return }
    player.health -= 1
    player.damageCooldown = 0.75
    player.position = player.lastSafePosition
    emit(.healthLost(amount: 1, source: .lava), at: player.position)
    publishStatusIfChanged()
    checkLoss()
  }
  func fireHook() {
    guard outcome == nil, player.hookshot.phase == .idle else { return }
    player.movementDirection = nil
    player.hookshot = .init(
      phase: .extending, origin: player.position, head: player.position, direction: player.facing)
  }
  private func updateHook(_ dt: Double) {
    guard outcome == nil, player.hookshot.phase != .idle else { return }
    player.hookshot.accumulator += dt * 18
    while player.hookshot.accumulator >= 1, player.hookshot.phase != .idle {
      guard outcome == nil else { return }
      player.hookshot.accumulator -= 1
      hookStep()
    }
  }
  private func hookStep() {
    guard outcome == nil else { return }
    switch player.hookshot.phase {
    case .extending:
      guard let head = player.hookshot.head else {
        finishHook()
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
      interact(CollisionProfile.hookHead.region(at: next), hooked: true)
      if player.hookshot.travelled >= HookshotState.maximumRange {
        player.hookshot.phase = .retracting
      }
    case .latched: player.hookshot.phase = .pulling
    case .pulling:
      let next = player.position.moved(player.hookshot.direction)
      if level.isBlocked(CollisionProfile.player.region(at: next)) {
        finishHook()
      } else {
        player.position = next
        interact(CollisionProfile.player.region(at: next), hooked: true)
      }
    case .retracting: finishHook()
    case .idle: break
    }
    publishStatusIfChanged()
  }
  private func finishHook() {
    if !level.overlapsLava(CollisionProfile.player.region(at: player.position)) {
      player.lastSafePosition = player.position
    }
    player.hookshot = HookshotState()
  }
  private func interact(_ contact: GridRegion, hooked: Bool) {
    // Entity array order is the deterministic collision order. A terminal contact short-circuits the remainder.
    let hits = entities.filter {
      CollisionProfile.footprint(for: $0.kind).region(at: $0.position).intersects(contact)
    }
    for entity in hits {
      guard outcome == nil else { return }
      entities.removeAll { $0.id == entity.id }
      switch entity.kind {
      case .coin:
        player.score += 10
        emit(.coinCollected(points: 10), at: entity.position)
      case .cabbage:
        let old = player.health
        player.health = min(player.maximumHealth, player.health + 1)
        emit(
          player.health > old ? .healthItemCollected(amount: 1) : .healthAlreadyFull,
          at: entity.position)
      case .mine:
        if hooked {
          player.score += 10
          let effectID = emit(.mineDestroyed(points: 10), at: entity.position)
          effectEvents.append(.init(id: effectID, coordinate: entity.position, descriptor: .mineDestruction(reducedMotion: configuration.reducedMotion), createdAt: simulationTime))
        } else {
          player.health -= 1
          emit(.healthLost(amount: 1, source: .mine), at: entity.position)
          publishStatusIfChanged()
          checkLoss()
          if outcome != nil { return }
        }
      }
    }
  }
  func activateChestAndExit() { checkChestAndExit() }
  private func checkChestAndExit() {
    guard outcome == nil, levelID == .levelOne else { return }
    let playerRegion = CollisionProfile.player.region(at: player.position)
    if !chestOpen, playerRegion.intersects(CollisionProfile.chest.region(at: level.chestAnchor)) {
      guard outcome == nil else { return }
      chestOpen = true
      player.score += 100
      let gain = min(2, player.maximumHealth - player.health)
      player.health += gain
      emit(.chestReward(score: 100, health: gain), at: level.chestAnchor)
      publishStatusIfChanged()
      cancelAllInput()
      onDialogue?(Self.chestMessage)
    }
    guard outcome == nil else { return }
    if playerRegion.intersects(level.exitRegion) {
      completeLevel()
    }
  }
  private func completeLevel() {
    if !completedLevelIDs.contains(levelID) { player.score += 100; completedLevelIDs.insert(levelID); emit(.levelCompleted(points: 100), at: player.position) }
    publishStatusIfChanged()
    cancelAllInput()
    let carry = PlayerCarryoverState(characterID: player.id, health: player.health, score: player.score, completedLevelIDs: completedLevelIDs)
    onLevelTransition?(LevelTransitionRequest(sourceLevelID: .levelOne, destinationLevelID: .levelTwo, destinationEntry: .bottom, carryover: carry))
  }
  func checkLoss() {
    if player.health <= 0 {
      publishStatusIfChanged()
      setOutcome(.lost)
    }
  }
  func setOutcome(_ value: GameOutcome) {
    guard outcome == nil else { return }
    outcome = value
    cancelAllInput()
    player.hookshot = HookshotState()
    publishUISnapshotIfChanged()
    onOutcome?(value)
  }
  private func publishStatusIfChanged() {
    guard outcome == nil else { return }
    let status = PlayerStatusSnapshot(health: player.health, score: player.score)
    guard status != lastPublishedStatus else { return }
    lastPublishedStatus = status
    onStatusChange?(status)
  }
  private func publishUISnapshotIfChanged() {
    let snapshot = uiSnapshot
    guard snapshot != lastPublishedUISnapshot else { return }
    lastPublishedUISnapshot = snapshot
    onUISnapshotChange?(snapshot)
  }
  @discardableResult func emit(_ kind: GameplayFeedbackKind, at coordinate: GridPosition?) -> UUID {
    guard outcome == nil else { return UUID() }
    let id = UUID()
    feedbackEvents.append(
      .init(
        id: id, kind: kind, coordinate: coordinate, createdAt: simulationTime, duration: 2.4))
    publishUISnapshotIfChanged()
    return id
  }
}

enum EnemyArchetype: Equatable, Sendable { case skeleton, flyingTerror
  var displayName: String { self == .skeleton ? "Skeleton" : "Flying Terror" }
  var asset: RenderAssetID { RenderAssetID(rawValue: self == .skeleton ? "enemy.skeleton" : "enemy.flying-terror") }
  var maximumHealth: Int { self == .skeleton ? 3 : 5 }
  var sight: Double { self == .skeleton ? 19 : 39 }
  var patrolInterval: TimeInterval { self == .skeleton ? 0.7 : 0.3 }
  var seekInterval: TimeInterval { self == .skeleton ? 0.5 : 0.3 }
  var footprint: CollisionFootprint { self == .skeleton ? .init(rowOffsets: -2..<3, columnOffsets: -2..<3) : .init(rowOffsets: -3..<5, columnOffsets: -3..<5) }
  var renderSize: LogicalRenderSize { self == .skeleton ? .init(width: 4.9, height: 4.7) : .init(width: 12.8, height: 12.8) }
}
enum EnemyBehaviorState: Equatable, Sendable { case patrol, seek }
struct EnemyState: Identifiable, Equatable, Sendable { let id: EntityID; let archetype: EnemyArchetype; var position: GridPosition; var facing: GridDirection; var health: Int; let maximumHealth: Int; var behaviorState: EnemyBehaviorState; var decisionAccumulator: TimeInterval; var animationTime: TimeInterval }
struct LevelRandomStreams { var itemSpawn: SeededRandomNumberGenerator; var skeletonAI: SeededRandomNumberGenerator; var flyingTerrorAI: SeededRandomNumberGenerator; init(seed: UInt64) { itemSpawn = .init(seed: seed ^ 0x11); skeletonAI = .init(seed: seed ^ 0x5151); flyingTerrorAI = .init(seed: seed ^ 0x7171) } }

enum LevelTwoDefinition {
  static let internalWallAnchors = [4,8,12,16,20,24,28,32,36,40].map{GridPosition(row:16,column:$0)} + [8,12].map{GridPosition(row:24,column:$0)} + [20,24].flatMap{r in [36,40].map{GridPosition(row:r,column:$0)}}
  static let lavaAnchors = [32,36,40].flatMap{r in stride(from:4, through:52, by:4).map{GridPosition(row:r,column:$0)}} + [44,48,52].flatMap{r in [36,40,44,48,52].map{GridPosition(row:r,column:$0)}} + [20,24,28].flatMap{r in [20,24,28].map{GridPosition(row:r,column:$0)}}
  static func make() -> LevelDefinition { let boundary = LevelBoundaryGeometry(topWallRegions:[.init(rows:0..<4,columns:0..<27),.init(rows:0..<4,columns:33..<60)], bottomWallRegions:[.init(rows:56..<60,columns:0..<27),.init(rows:56..<60,columns:33..<60)], leftWallRegions:[.init(rows:4..<56,columns:0..<4)], rightWallRegions:[.init(rows:4..<56,columns:56..<60)], topExitRegion:.init(rows:0..<4,columns:27..<33), bottomDoorRegion:.init(rows:56..<60,columns:27..<33)); let walls = boundary.wallRegions + internalWallAnchors.map{GridRegion(rows:$0.row..<$0.row+4, columns:$0.column..<$0.column+4)}; let lava = lavaAnchors.map{GridRegion(rows:$0.row..<$0.row+4, columns:$0.column..<$0.column+4)}; return .init(grid:.init(rows:60,columns:60), start:.init(row:50,column:27), exitAnchor:.init(row:0,column:27), entryAnchor:.init(row:56,column:27), chestAnchor:.init(row:-100,column:-100), boundary:boundary, walls:walls, lava:lava, internalWallAnchors:internalWallAnchors, displayName:"Level 2") }
}
enum LevelTwoRenderAssets { static let floor=RenderAssetID(rawValue:"level-two.floor"), lava=RenderAssetID(rawValue:"level-two.lava"), wallFront=RenderAssetID(rawValue:"level-two.wall.front"), wallLeft=RenderAssetID(rawValue:"level-two.wall.left"), wallRight=RenderAssetID(rawValue:"level-two.wall.right"), exitDoor=RenderAssetID(rawValue:"level-two.door.open"), entryDoor=RenderAssetID(rawValue:"level-two.door.closed"), smoke=RenderAssetID(rawValue:"level-two.smoke" ) }
enum LevelTwoRenderAnimations { static func enemy(_ a: EnemyArchetype, _ d: RenderOrientation) -> RenderAnimationID { .init(rawValue:"enemy.\(a == .skeleton ? "skeleton" : "flying-terror").walk.\(d.rawValue)") } }

enum LevelTwoPresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ region: GridRegion, _ asset: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: region.rows.lowerBound, column: region.columns.lowerBound),
        sizeInCells: .init(width: Double(region.columns.count), height: Double(region.rows.count)),
        asset: asset, anchor: .bottomLeft)
    }

    let floor = stride(from: 0, to: level.grid.rows, by: 10).flatMap { row in
      stride(from: 0, to: level.grid.columns, by: 10).map { column in
        tile(
          .init(rows: row..<min(row + 10, level.grid.rows), columns: column..<min(column + 10, level.grid.columns)),
          LevelTwoRenderAssets.floor)
      }
    }

    // Java LevelTwo renders the basic environment before drawing doors, so the top and bottom
    // wall rows stay visually continuous and the grey door sprites are placed at x=280 (column 28).
    // Keep gameplay collision regions in LevelTwoDefinition unchanged while matching that Java layout.
    let javaBoundaryWalls = [
      GridRegion(rows: 0..<4, columns: 0..<60),
      GridRegion(rows: 56..<60, columns: 0..<60),
      GridRegion(rows: 4..<56, columns: 0..<4),
      GridRegion(rows: 4..<56, columns: 56..<60),
    ]
    let walls = javaBoundaryWalls.map { region in
      tile(
        region,
        region.columns == 0..<4
          ? LevelTwoRenderAssets.wallLeft
          : (region.columns == 56..<60 ? LevelTwoRenderAssets.wallRight : LevelTwoRenderAssets.wallFront))
    } + level.internalWallAnchors.map {
      tile(.init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4), LevelTwoRenderAssets.wallFront)
    }

    return .init(
      levelID: .levelTwo, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(id: .init(rawValue: "lava"), zPosition: 1, tiles: level.lava.map { tile($0, LevelTwoRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(id: EntityID(), asset: LevelTwoRenderAssets.exitDoor, coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 3),
        .init(id: EntityID(), asset: LevelTwoRenderAssets.entryDoor, coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 3),
        .init(id: EntityID(), asset: LevelTwoRenderAssets.smoke, coordinate: .init(row: 39, column: 5), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
        .init(id: EntityID(), asset: LevelTwoRenderAssets.smoke, coordinate: .init(row: 55, column: 50), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
      ])
  }
}

@MainActor final class LevelTwoSimulation: LevelOneSimulation {
  private var enemies: [EnemyState]
  private var skeletonRNG: SeededRandomNumberGenerator; private var flyingRNG: SeededRandomNumberGenerator
  override var levelID: LevelID { .levelTwo }; override var levelName: String { "Level 2" }
  override var renderSnapshot: GameRenderSnapshot { let s=super.renderSnapshot; let es=enemies.map{e in RenderEntitySnapshot(id:e.id, asset:e.archetype.asset, coordinate:e.position, renderSize:e.archetype.renderSize, anchor:.center, zPosition:7, orientation:RenderOrientation(rawValue:e.facing.rawValue) ?? .right, animation:.init(animationID:LevelTwoRenderAnimations.enemy(e.archetype, RenderOrientation(rawValue:e.facing.rawValue) ?? .right), frameIndex:Int(e.animationTime/0.08)%10), opacity:1, isHidden:false, health:.init(current:e.health, maximum:e.maximumHealth))}; return .init(player:s.player, entities:s.entities.filter{$0.asset != LevelOneRenderAssets.chestClosed && $0.asset != LevelOneRenderAssets.chestOpen}+es, grapple:s.grapple, effects:s.effects) }
  init(configuration: GameConfiguration = .init(reducedMotion:false, controlHintsEnabled:true), seed: UInt64 = 2, entryPosition: LevelEntryPosition = .bottom, carryover: PlayerCarryoverState? = nil) throws { let streams=LevelRandomStreams(seed:seed); skeletonRNG=streams.skeletonAI; flyingRNG=streams.flyingTerrorAI; enemies=[.init(id:EntityID(), archetype:.skeleton, position:.init(row:6,column:23), facing:.right, health:3, maximumHealth:3, behaviorState:.patrol, decisionAccumulator:0, animationTime:0), .init(id:EntityID(), archetype:.flyingTerror, position:.init(row:5,column:33), facing:.right, health:5, maximumHealth:5, behaviorState:.patrol, decisionAccumulator:0, animationTime:0)]; try super.init(configuration:configuration, seed:seed, entryPosition:entryPosition, carryover:carryover, startOverride: entryPosition == .top ? .init(row:50,column:27) : .init(row:50,column:27), entities:nil); level = LevelTwoDefinition.make(); presentationDefinition = LevelTwoPresentationDefinition.make(from: level); var rng=streams.itemSpawn; entities = try SpawnService.spawn(in: level, requirements:[.init(kind:.mine,count:3),.init(kind:.cabbage,count:2),.init(kind:.coin,count:10)], protectedRegions:enemies.map{$0.archetype.footprint.region(at:$0.position)} + [.init(rows:39..<43,columns:5..<9),.init(rows:55..<59,columns:50..<54)], using:&rng) }
  override func update(deltaTime: TimeInterval) { let beforeOutcome = outcome; super.update(deltaTime: deltaTime); guard outcome == beforeOutcome else { return }; checkLevelTwoDoors(); updateEnemyGrappleHits(); updateEnemies(deltaTime) }
  private func updateEnemies(_ dt: TimeInterval) { for i in enemies.indices { enemies[i].animationTime += dt; let dist=hypot(Double(enemies[i].position.row-player.position.row), Double(enemies[i].position.column-player.position.column)); enemies[i].behaviorState = dist <= enemies[i].archetype.sight ? .seek : .patrol; enemies[i].decisionAccumulator += dt; let interval = enemies[i].behaviorState == .seek ? enemies[i].archetype.seekInterval : enemies[i].archetype.patrolInterval; if enemies[i].decisionAccumulator >= interval { enemies[i].decisionAccumulator = 0; stepEnemy(i) }; if enemies[i].archetype.footprint.region(at: enemies[i].position).intersects(CollisionProfile.player.region(at: player.position)) { damageFromEnemy(enemies[i].archetype) } } }
  private func stepEnemy(_ i:Int) { let dirs = GridDirection.allCases; func canMove(_ dir: GridDirection) -> Bool { let region=enemies[i].archetype.footprint.region(at:enemies[i].position.moved(dir)); return region.cells.allSatisfy(level.isInside) && (enemies[i].archetype != .skeleton || !level.walls.contains{$0.intersects(region)}) }; let dir: GridDirection; if enemies[i].behaviorState == .patrol { let start = Int((enemies[i].archetype == .skeleton ? skeletonRNG.next() : flyingRNG.next()) % UInt64(dirs.count)); dir = (0..<dirs.count).map { dirs[($0 + start) % dirs.count] }.first(where: canMove) ?? dirs[start] } else { guard let best = dirs.filter(canMove).min(by:{ a,b in distance(enemies[i].position.moved(a)) == distance(enemies[i].position.moved(b)) ? dirs.firstIndex(of:a)! < dirs.firstIndex(of:b)! : distance(enemies[i].position.moved(a)) < distance(enemies[i].position.moved(b)) }) else { return }; dir = best }; enemies[i].facing=dir; enemies[i].position=enemies[i].position.moved(dir) }
  private func distance(_ p:GridPosition)->Double{ hypot(Double(p.row-player.position.row), Double(p.column-player.position.column)) }
  private var enemiesHitByCurrentHook: Set<EntityID> = []
  private func updateEnemyGrappleHits() { guard let head = player.hookshot.head, player.hookshot.phase == .extending else { if player.hookshot.phase == .idle { enemiesHitByCurrentHook.removeAll() }; return }; let hook = CollisionProfile.hookHead.region(at: head); for i in enemies.indices where !enemiesHitByCurrentHook.contains(enemies[i].id) && enemies[i].archetype.footprint.region(at: enemies[i].position).intersects(hook) { enemiesHitByCurrentHook.insert(enemies[i].id); enemies[i].health -= 1; player.score += 10; let archetype = enemies[i].archetype; emit(.enemyHit(archetype: archetype, points: 10, remainingHealth: max(0,enemies[i].health)), at: enemies[i].position); if enemies[i].health <= 0 { let pos = enemies[i].position; enemies.remove(at: i); let id = emit(.enemyDefeated(archetype: archetype), at: pos); effectEvents.append(.init(id:id, coordinate:pos, descriptor:.enemyDefeat(reducedMotion: configuration.reducedMotion), createdAt:simulationTime)) }; player.hookshot.phase = .retracting; break } }
  private func checkLevelTwoDoors() { let region = CollisionProfile.player.region(at: player.position); if region.intersects(level.entryRegion) { cancelAllInput(); let carry=PlayerCarryoverState(characterID:player.id, health:player.health, score:player.score, completedLevelIDs:completedLevelIDs); onLevelTransition?(LevelTransitionRequest(sourceLevelID:.levelTwo,destinationLevelID:.levelOne,destinationEntry:.top,carryover:carry)) } else if region.intersects(level.exitRegion) { if !completedLevelIDs.contains(.levelTwo) { player.score += 100; completedLevelIDs.insert(.levelTwo); emit(.levelCompleted(points:100), at:player.position) }; setOutcome(.won) } }
  private func damageFromEnemy(_ a: EnemyArchetype) { guard player.damageCooldown <= 0 else { return }; player.health -= 1; player.damageCooldown = 0.75; emit(.healthLost(amount:1, source:.enemy(a)), at:player.position); checkLoss() }
}
