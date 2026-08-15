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
struct LevelChestDefinition: Identifiable, Sendable {
  let id: EntityID
  let interactionAnchor: GridPosition
  let renderAnchor: GridPosition
  let closedAsset: RenderAssetID
  let openedAsset: RenderAssetID
  let renderSize: LogicalRenderSize
  let renderAnchorPoint: RenderAnchor
  let message: String?
  let scoreReward: Int
  let healthReward: Int

  var spawnExclusionRegion: GridRegion {
    let height = Int(ceil(renderSize.height))
    let width = Int(ceil(renderSize.width))
    switch renderAnchorPoint {
    case .bottomLeft:
      return .init(
        rows: renderAnchor.row..<renderAnchor.row + height,
        columns: renderAnchor.column..<renderAnchor.column + width)
    case .center:
      let firstRow = renderAnchor.row - height / 2
      let firstColumn = renderAnchor.column - width / 2
      return .init(
        rows: firstRow..<firstRow + height, columns: firstColumn..<firstColumn + width)
    }
  }
}
struct LevelChestState: Identifiable, Sendable {
  let definition: LevelChestDefinition
  var isOpened: Bool
  var id: EntityID { definition.id }
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
struct EntitySpawnRequirement: Equatable, Sendable {
  let kind: EntityKind
  let count: Int
}

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
    try spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ], protectedRegions: [], using: &rng)
  }
  static func spawn<R: RandomNumberGenerator>(
    in level: LevelDefinition, requirements: [EntitySpawnRequirement],
    protectedRegions extraProtected: [GridRegion], using rng: inout R
  ) throws -> [WorldEntity] {
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

enum DamageSource: Equatable, Sendable {
  case lava, mine
  case enemy(EnemyArchetype)
}

enum LevelEntryPosition: Hashable, Sendable { case bottom, top, right }
struct OpenedChestID: Hashable, Sendable {
  let levelID: LevelID
  let interactionAnchor: GridPosition
}
struct WorldCarryoverState: Hashable, Sendable {
  var openedChestIDs: Set<OpenedChestID> = []
}
struct PlayerCarryoverState: Hashable, Sendable {
  let characterID: EntityID
  let health: Int
  let score: Int
  let completedLevelIDs: Set<LevelID>
  var worldState: WorldCarryoverState = .init()
}
enum LevelTransitionReason: Hashable, Sendable { case completedForward, returnedBackward }
struct LevelTransitionRequest: Hashable, Sendable {
  let sourceLevelID: LevelID
  let destinationLevelID: LevelID
  let destinationEntry: LevelEntryPosition
  let carryover: PlayerCarryoverState
  let reason: LevelTransitionReason
  init(
    sourceLevelID: LevelID, destinationLevelID: LevelID, destinationEntry: LevelEntryPosition,
    carryover: PlayerCarryoverState, reason: LevelTransitionReason = .completedForward
  ) {
    self.sourceLevelID = sourceLevelID
    self.destinationLevelID = destinationLevelID
    self.destinationEntry = destinationEntry
    self.carryover = carryover
    self.reason = reason
  }
}
enum LevelDestination: Equatable, Sendable {
  case level(LevelID, entry: LevelEntryPosition)
  case currentContentComplete(nextLevelID: LevelID?)
}
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
    case .enemyHit(let archetype, let points, let remaining):
      "\(archetype.displayName) hit. Plus \(points) score. \(remaining) health remaining."
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
  let animationID: RenderAnimationID?
  init(
    id: EntityID, asset: RenderAssetID, coordinate: GridPosition, renderSize: LogicalRenderSize,
    anchor: RenderAnchor, zPosition: Double, animationID: RenderAnimationID? = nil
  ) {
    self.id = id
    self.asset = asset
    self.coordinate = coordinate
    self.renderSize = renderSize
    self.anchor = anchor
    self.zPosition = zPosition
    self.animationID = animationID
  }
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
  init(
    id: EntityID, asset: RenderAssetID, coordinate: GridPosition, renderSize: LogicalRenderSize,
    anchor: RenderAnchor, zPosition: Double, orientation: RenderOrientation,
    animation: RenderAnimationSnapshot?, opacity: Double, isHidden: Bool,
    health: RenderHealthSnapshot? = nil
  ) {
    self.id = id
    self.asset = asset
    self.coordinate = coordinate
    self.renderSize = renderSize
    self.anchor = anchor
    self.zPosition = zPosition
    self.orientation = orientation
    self.animation = animation
    self.opacity = opacity
    self.isHidden = isHidden
    self.health = health
  }
}
struct RenderHealthSnapshot: Equatable, Sendable {
  let current: Int
  let maximum: Int
}
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
  static func enemyDefeat(reducedMotion: Bool) -> Self {
    .init(duration: 0.4, initialRadius: 2.2, finalScale: reducedMotion ? 1 : 2, zPosition: 9)
  }
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
  func validate(
    manifest: LevelAssetManifest, textureCatalog: any TextureCatalogProviding,
    animationCatalog: any AnimationCatalogProviding) throws
}
@MainActor struct DefaultAssetPreflight: AssetPreflighting {
  func validate(
    manifest: LevelAssetManifest, textureCatalog: any TextureCatalogProviding,
    animationCatalog: any AnimationCatalogProviding
  ) throws {
    for assetID in manifest.textureAssetIDs { _ = try textureCatalog.texture(for: assetID) }
    for animationID in manifest.animationIDs {
      let frames = try animationCatalog.frames(for: animationID)
      if frames.isEmpty { throw GameLoadingError.missingRequiredAsset(animationID.rawValue) }
    }
  }
}
@MainActor protocol GameLevelRuntimeFactory {
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> GameLevelRuntime
  func makeRuntime(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws -> GameLevelRuntime
}
@MainActor struct DefaultGameLevelRuntimeFactory: GameLevelRuntimeFactory {
  let simulationFactory: any GameSimulationFactory
  let preflight: any AssetPreflighting
  init(
    simulationFactory: any GameSimulationFactory = DefaultGameSimulationFactory(),
    preflight: any AssetPreflighting = DefaultAssetPreflight()
  ) {
    self.simulationFactory = simulationFactory
    self.preflight = preflight
  }
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> GameLevelRuntime
  {
    try makeRuntime(
      levelID: levelID, configuration: configuration, seed: seed, entryPosition: .bottom,
      carryover: nil)
  }
  func makeRuntime(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws -> GameLevelRuntime {
    let simulation = try simulationFactory.makeSimulation(
      levelID: levelID, configuration: configuration, seed: seed, entryPosition: entryPosition,
      carryover: carryover)
    let textureCatalog = TextureCatalog(entries: LevelOneTextureCatalog.entries)
    let animationCatalog = LevelOneAnimationCatalog(textureCatalog: textureCatalog)
    let manifest = try LevelAssetManifest.manifest(for: levelID)
    do {
      try preflight.validate(
        manifest: manifest, textureCatalog: textureCatalog, animationCatalog: animationCatalog)
    } catch let e as TextureCatalogError {
      simulation.dispose()
      throw e.gameLoadingError
    } catch let e as GameLoadingError {
      simulation.dispose()
      throw e
    } catch {
      simulation.dispose()
      throw GameLoadingError.invalidLevelDefinition(levelID)
    }
    return .init(
      simulation: simulation, presentation: simulation.presentationDefinition,
      textureCatalog: textureCatalog, animationCatalog: animationCatalog, assetManifest: manifest)
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
  static func manifest(for levelID: LevelID) throws -> LevelAssetManifest {
    switch levelID {
    case .levelOne: levelOne
    case .levelTwo: levelTwo
    case .levelThree: levelThree
    case .levelFour: levelFour
    case .levelFive: levelFive
    case .levelSix: levelSix
    default: throw GameLoadingError.unsupportedLevel(levelID)
    }
  }
  static let levelOne = LevelAssetManifest(
    textureAssetIDs: Set(
      [
        LevelOneRenderAssets.floor, LevelOneRenderAssets.lava, LevelOneRenderAssets.wallFront,
        LevelOneRenderAssets.wallLeft, LevelOneRenderAssets.wallRight,
        LevelOneRenderAssets.exitDoor,
        LevelOneRenderAssets.entryDoor, LevelOneRenderAssets.lidia, LevelOneRenderAssets.coin,
        LevelOneRenderAssets.cabbage, LevelOneRenderAssets.mine, LevelOneRenderAssets.chestClosed,
        LevelOneRenderAssets.chestOpen,
      ] + (1...9).map { RenderAssetID(rawValue: "level-one.coin.\($0)") }
        + (0..<4).flatMap { row in
          (0..<9).map { RenderAssetID(rawValue: "character.lidia.\(row)-\($0)") }
        }),
    animationIDs: Set([
      LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up),
      LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left),
      LevelOneRenderAnimations.lidiaWalk(.right),
    ]))
  private static let sharedPlayerTextureAssetIDs = Set(
    (0..<4).flatMap { row in
      (0..<9).map { RenderAssetID(rawValue: "character.lidia.\(row)-\($0)") }
    } + [LevelOneRenderAssets.lidia])
  private static let sharedCoinTextureAssetIDs = Set(
    (1...9).map { RenderAssetID(rawValue: "level-one.coin.\($0)") } + [LevelOneRenderAssets.coin])
  private static let sharedEnemyTextureAssetIDs = Set(
    [EnemyArchetype.skeleton.asset, EnemyArchetype.flyingTerror.asset]
      + [8, 9, 10, 11].flatMap { row in
        (0..<9).map { RenderAssetID(rawValue: "enemy.skeleton.\(row)-\($0)") }
      }
      + [0, 2, 4, 6].flatMap { row in
        (0..<10).map { RenderAssetID(rawValue: "enemy.flying-terror.\(row)-\($0)") }
      })
  static let levelTwo = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelTwoRenderAssets.floor, LevelTwoRenderAssets.lava, LevelTwoRenderAssets.wallFront,
      LevelTwoRenderAssets.wallLeft, LevelTwoRenderAssets.wallRight, LevelTwoRenderAssets.exitDoor,
      LevelTwoRenderAssets.entryDoor, LevelTwoRenderAssets.smoke, LevelOneRenderAssets.mine,
      LevelOneRenderAssets.cabbage,
    ])
    .union(sharedPlayerTextureAssetIDs)
    .union(sharedCoinTextureAssetIDs)
    .union(sharedEnemyTextureAssetIDs)
    .union((1...3).map { RenderAssetID(rawValue: "level-two.smoke.\($0)") }),
    animationIDs: Set([
      LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up),
      LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left),
      LevelOneRenderAnimations.lidiaWalk(.right), LevelTwoRenderAnimations.enemy(.skeleton, .up),
      LevelTwoRenderAnimations.enemy(.skeleton, .down),
      LevelTwoRenderAnimations.enemy(.skeleton, .left),
      LevelTwoRenderAnimations.enemy(.skeleton, .right),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .up),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .down),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .left),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .right),
    ]))
  static let levelThree = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelThreeRenderAssets.floor, LevelThreeRenderAssets.lava, LevelThreeRenderAssets.wallFront,
      LevelThreeRenderAssets.wallLeft, LevelThreeRenderAssets.wallRight,
      LevelThreeRenderAssets.exitDoor,
      LevelThreeRenderAssets.entryDoor, LevelThreeRenderAssets.smoke, LevelOneRenderAssets.mine,
      LevelOneRenderAssets.cabbage, LevelOneRenderAssets.chestClosed,
      LevelOneRenderAssets.chestOpen,
    ])
    .union(sharedPlayerTextureAssetIDs)
    .union(sharedCoinTextureAssetIDs)
    .union(sharedEnemyTextureAssetIDs)
    .union((1...3).map { RenderAssetID(rawValue: "level-three.smoke.\($0)") }),
    animationIDs: Set([
      LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up),
      LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left),
      LevelOneRenderAnimations.lidiaWalk(.right), LevelThreeRenderAnimations.smokeLoop,
      LevelTwoRenderAnimations.enemy(.skeleton, .up),
      LevelTwoRenderAnimations.enemy(.skeleton, .down),
      LevelTwoRenderAnimations.enemy(.skeleton, .left),
      LevelTwoRenderAnimations.enemy(.skeleton, .right),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .up),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .down),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .left),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .right),
    ]))
}
@MainActor protocol GameSimulationFactory {
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> any GameSimulation
  func makeSimulation(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws
    -> any GameSimulation
}
struct DefaultGameSimulationFactory: GameSimulationFactory {
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> any GameSimulation
  {
    try makeSimulation(
      levelID: levelID, configuration: configuration, seed: seed, entryPosition: .bottom,
      carryover: nil)
  }
  func makeSimulation(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws -> any GameSimulation {
    do {
      switch levelID {
      case .levelOne:
        return try LevelOneSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelTwo:
        return try LevelTwoSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelThree:
        return try LevelThreeSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelFour:
        return try LevelFourSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelFive:
        return try LevelFiveSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelSix:
        return try LevelSixSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      default:
        throw GameLoadingError.unsupportedLevel(levelID)
      }
    } catch let e as GameLoadingError { throw e } catch {
      throw GameLoadingError.spawnFailure(levelID)
    }
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
  var enemies: [EnemyState] = []
  private var enemiesHitByCurrentHook: Set<EntityID> = []
  private var skeletonRNG: SeededRandomNumberGenerator
  private var flyingRNG: SeededRandomNumberGenerator
  var chestStates: [LevelChestState] = []
  var chestOpen: Bool { chestStates.first?.isOpened ?? false }
  private(set) var feedbackEvents: [GameplayFeedback] = []
  var effectEvents: [RenderEffectSnapshot] = []
  private var movementAccumulator = 0.0
  var simulationTime = 0.0
  private(set) var outcome: GameOutcome?
  private var lastPublishedStatus: PlayerStatusSnapshot
  private var lastPublishedUISnapshot: GameplayUISnapshot
  var completedLevelIDs: Set<LevelID> = []
  var worldState = WorldCarryoverState()
  var onStatusChange: ((PlayerStatusSnapshot) -> Void)?
  var onUISnapshotChange: ((GameplayUISnapshot) -> Void)?
  var onOutcome: ((GameOutcome) -> Void)?
  var onLevelTransition: ((LevelTransitionRequest) -> Void)?
  var onDialogue: ((String) -> Void)?
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = UInt64.random(in: 1...UInt64.max), entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil, startOverride: GridPosition? = nil,
    entities fixture: [WorldEntity]? = nil
  ) throws {
    self.configuration = configuration
    self.seed = seed
    skeletonRNG = .init(seed: seed ^ 0x5151)
    flyingRNG = .init(seed: seed ^ 0x7171)
    level = LevelOneDefinition.make()
    presentationDefinition = LevelOnePresentationDefinition.make(from: level)
    let entryStart = entryPosition == .top ? GridPosition(row: 5, column: 23) : level.start
    let initial = startOverride ?? entryStart
    player = .init(
      id: carryover?.characterID ?? EntityID(), position: initial, lastSafePosition: initial)
    player.health = carryover?.health ?? 3
    player.score = carryover?.score ?? 0
    completedLevelIDs = carryover?.completedLevelIDs ?? []
    worldState = carryover?.worldState ?? .init()
    lastPublishedStatus = .init(health: player.health, score: player.score)
    lastPublishedUISnapshot = .init(
      levelID: .levelOne, levelName: "Level 1", health: 3, maximumHealth: 5, score: 0,
      canMove: true, canGrapple: true, isPaused: false, dialogue: nil, feedback: [],
      diagnosticPlayerPosition: nil)
    var rng = SeededRandomNumberGenerator(seed: seed)
    entities = try fixture ?? SpawnService.spawn(in: level, using: &rng)
    chestStates = [Self.standardChest(at: level.chestAnchor, message: Self.chestMessage)]
    restoreOpenedChestStates()
    try validateInitialPlayerFootprint()
  }
  static func standardChest(at anchor: GridPosition, message: String) -> LevelChestState {
    .init(
      definition: .init(
        id: EntityID(), interactionAnchor: anchor, renderAnchor: anchor,
        closedAsset: LevelOneRenderAssets.chestClosed, openedAsset: LevelOneRenderAssets.chestOpen,
        renderSize: .init(width: 2.5, height: 2.5), renderAnchorPoint: .center,
        message: message, scoreReward: 100, healthReward: 2), isOpened: false)
  }
  func validateInitialPlayerFootprint() throws {
    let region = CollisionProfile.player.region(at: player.position)
    guard !level.isBlocked(region), !level.overlapsLava(region) else {
      throw GameLoadingError.invalidInitialState(levelID)
    }
  }
  func restoreOpenedChestStates() {
    for index in chestStates.indices {
      let definition = chestStates[index].definition
      chestStates[index].isOpened = worldState.openedChestIDs.contains(
        .init(levelID: levelID, interactionAnchor: definition.interactionAnchor))
    }
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
    let grapple =
      player.hookshot.phase != .idle && player.hookshot.head != nil
      ? GrappleRenderSnapshot(origin: player.position, head: player.hookshot.head!) : nil
    let chestSnapshots = chestStates.map { chest in
      RenderEntitySnapshot(
        id: chest.id,
        asset: chest.isOpened ? chest.definition.openedAsset : chest.definition.closedAsset,
        coordinate: chest.definition.renderAnchor, renderSize: chest.definition.renderSize,
        anchor: chest.definition.renderAnchorPoint, zPosition: 5, orientation: .none,
        animation: nil, opacity: 1, isHidden: false)
    }
    return .init(
      player: playerRender, entities: world + chestSnapshots + enemyRenderSnapshots,
      grapple: grapple, effects: effectEvents)
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
          effectEvents.append(
            .init(
              id: effectID, coordinate: entity.position,
              descriptor: .mineDestruction(reducedMotion: configuration.reducedMotion),
              createdAt: simulationTime))
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
  var enemyRenderSnapshots: [RenderEntitySnapshot] {
    enemies.map { enemy in
      let orientation = RenderOrientation(rawValue: enemy.facing.rawValue) ?? .right
      return .init(
        id: enemy.id, asset: enemy.archetype.asset, coordinate: enemy.position,
        renderSize: enemy.archetype.renderSize, anchor: .center, zPosition: 7,
        orientation: orientation,
        animation: .init(
          animationID: LevelTwoRenderAnimations.enemy(enemy.archetype, orientation),
          frameIndex: configuration.reducedMotion
            ? 0 : Int(enemy.animationTime / 0.08) % (enemy.archetype == .skeleton ? 9 : 10)),
        opacity: 1, isHidden: false,
        health: .init(current: enemy.health, maximum: enemy.maximumHealth))
    }
  }
  func validateEnemyFootprints(entryPositions: [GridPosition]) throws {
    let entryRegions = entryPositions.map { CollisionProfile.player.region(at: $0) }
    for enemy in enemies {
      let region = enemy.archetype.footprint.region(at: enemy.position)
      guard region.cells.allSatisfy(level.isInside),
        enemy.archetype == .flyingTerror || !level.isBlocked(region),
        !entryRegions.contains(where: region.intersects)
      else {
        throw GameLoadingError.invalidInitialState(levelID)
      }
    }
  }
  func updateEnemySystem(_ rawDeltaTime: TimeInterval) {
    guard outcome == nil else { return }
    let dt = min(max(rawDeltaTime, 0), 0.1)
    updateEnemyGrappleHits()
    for index in enemies.indices {
      enemies[index].animationTime += dt
      enemies[index].behaviorState =
        enemyDistance(enemies[index].position) <= enemies[index].archetype.sight ? .seek : .patrol
      enemies[index].decisionAccumulator += dt
      let interval =
        enemies[index].behaviorState == .seek
        ? enemies[index].archetype.seekInterval : enemies[index].archetype.patrolInterval
      if enemies[index].decisionAccumulator >= interval {
        enemies[index].decisionAccumulator.formTruncatingRemainder(dividingBy: interval)
        stepEnemy(index)
      }
      if enemies[index].archetype.footprint.region(at: enemies[index].position).intersects(
        CollisionProfile.player.region(at: player.position))
      {
        damageFromEnemy(enemies[index].archetype)
      }
    }
  }
  private func stepEnemy(_ index: Int) {
    let directions = GridDirection.allCases
    func canMove(_ direction: GridDirection) -> Bool {
      let region = enemies[index].archetype.footprint.region(
        at: enemies[index].position.moved(direction))
      return region.cells.allSatisfy(level.isInside)
        && (enemies[index].archetype == .flyingTerror
          || !level.walls.contains { $0.intersects(region) })
    }
    let direction: GridDirection?
    if enemies[index].behaviorState == .seek {
      direction = directions.filter(canMove).min { lhs, rhs in
        let left = enemyDistance(enemies[index].position.moved(lhs))
        let right = enemyDistance(enemies[index].position.moved(rhs))
        return left == right
          ? directions.firstIndex(of: lhs)! < directions.firstIndex(of: rhs)! : left < right
      }
    } else {
      let random = enemies[index].archetype == .skeleton ? skeletonRNG.next() : flyingRNG.next()
      let start = Int(random % UInt64(directions.count))
      direction = (0..<directions.count).map { directions[($0 + start) % directions.count] }.first(
        where: canMove)
    }
    guard let direction else { return }
    enemies[index].facing = direction
    enemies[index].position = enemies[index].position.moved(direction)
  }
  private func enemyDistance(_ position: GridPosition) -> Double {
    hypot(
      Double(position.row - player.position.row), Double(position.column - player.position.column))
  }
  private func updateEnemyGrappleHits() {
    guard let head = player.hookshot.head, player.hookshot.phase == .extending else {
      if player.hookshot.phase == .idle { enemiesHitByCurrentHook.removeAll() }
      return
    }
    let hookRegion = CollisionProfile.hookHead.region(at: head)
    guard
      let index = enemies.firstIndex(where: {
        !enemiesHitByCurrentHook.contains($0.id)
          && $0.archetype.footprint.region(at: $0.position).intersects(hookRegion)
      })
    else { return }
    enemiesHitByCurrentHook.insert(enemies[index].id)
    enemies[index].health -= 1
    player.score += 10
    let enemy = enemies[index]
    emit(
      .enemyHit(archetype: enemy.archetype, points: 10, remainingHealth: max(0, enemy.health)),
      at: enemy.position)
    if enemy.health <= 0 {
      enemies.remove(at: index)
      let effectID = emit(.enemyDefeated(archetype: enemy.archetype), at: enemy.position)
      effectEvents.append(
        .init(
          id: effectID, coordinate: enemy.position,
          descriptor: .enemyDefeat(reducedMotion: configuration.reducedMotion),
          createdAt: simulationTime))
    }
    player.hookshot.phase = .retracting
  }
  private func damageFromEnemy(_ archetype: EnemyArchetype) {
    guard player.damageCooldown <= 0 else { return }
    player.health -= 1
    player.damageCooldown = 0.75
    emit(.healthLost(amount: 1, source: .enemy(archetype)), at: player.position)
    checkLoss()
  }
  func activateChestAndExit() { checkChestAndExit() }
  private func checkChestAndExit() {
    guard outcome == nil else { return }
    let playerRegion = CollisionProfile.player.region(at: player.position)
    if let index = chestStates.firstIndex(where: {
      !$0.isOpened
        && playerRegion.intersects(CollisionProfile.chest.region(at: $0.definition.interactionAnchor))
    }) {
      guard outcome == nil else { return }
      chestStates[index].isOpened = true
      let chest = chestStates[index].definition
      worldState.openedChestIDs.insert(
        .init(levelID: levelID, interactionAnchor: chest.interactionAnchor))
      player.score += chest.scoreReward
      let gain = min(chest.healthReward, player.maximumHealth - player.health)
      player.health += gain
      emit(.chestReward(score: chest.scoreReward, health: gain), at: chest.interactionAnchor)
      publishStatusIfChanged()
      cancelAllInput()
      if let message = chest.message { onDialogue?(message) }
    }
    guard outcome == nil, levelID == .levelOne else { return }
    if playerRegion.intersects(level.exitRegion) {
      completeLevel()
    }
  }
  private func completeLevel() {
    if !completedLevelIDs.contains(levelID) {
      player.score += 100
      completedLevelIDs.insert(levelID)
      emit(.levelCompleted(points: 100), at: player.position)
    }
    publishStatusIfChanged()
    cancelAllInput()
    let carry = PlayerCarryoverState(
      characterID: player.id, health: player.health, score: player.score,
      completedLevelIDs: completedLevelIDs, worldState: worldState)
    onLevelTransition?(
      LevelTransitionRequest(
        sourceLevelID: .levelOne, destinationLevelID: .levelTwo, destinationEntry: .bottom,
        carryover: carry, reason: .completedForward))
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

enum EnemyArchetype: Equatable, Sendable {
  case skeleton, flyingTerror, minotaur
  var displayName: String {
    switch self {
    case .skeleton: "Skeleton"
    case .flyingTerror: "Flying Terror"
    case .minotaur: "Minotaur"
    }
  }
  var asset: RenderAssetID {
    RenderAssetID(
      rawValue: self == .skeleton
        ? "enemy.skeleton" : (self == .flyingTerror ? "enemy.flying-terror" : "enemy.minotaur"))
  }
  var maximumHealth: Int { self == .skeleton ? 3 : (self == .flyingTerror ? 5 : 10) }
  var sight: Double { self == .skeleton ? 19 : (self == .flyingTerror ? 39 : 19) }
  var patrolInterval: TimeInterval {
    self == .skeleton ? 0.7 : (self == .flyingTerror ? 0.3 : 0.45)
  }
  var seekInterval: TimeInterval { self == .skeleton ? 0.5 : (self == .flyingTerror ? 0.3 : 0.35) }
  var footprint: CollisionFootprint {
    self == .skeleton
      ? .init(rowOffsets: -2..<3, columnOffsets: -2..<3)
      : (self == .flyingTerror
        ? .init(rowOffsets: -3..<5, columnOffsets: -3..<5)
        : .init(rowOffsets: -2..<3, columnOffsets: -2..<3))
  }
  var renderSize: LogicalRenderSize {
    self == .skeleton
      ? .init(width: 4.9, height: 4.7)
      : (self == .flyingTerror ? .init(width: 12.8, height: 12.8) : .init(width: 4.8, height: 6.4))
  }
}
enum EnemyBehaviorState: Equatable, Sendable { case patrol, seek }
struct EnemyState: Identifiable, Equatable, Sendable {
  let id: EntityID
  let archetype: EnemyArchetype
  var position: GridPosition
  var facing: GridDirection
  var health: Int
  let maximumHealth: Int
  var behaviorState: EnemyBehaviorState
  var decisionAccumulator: TimeInterval
  var animationTime: TimeInterval
}
struct LevelRandomStreams {
  var itemSpawn: SeededRandomNumberGenerator
  var skeletonAI: SeededRandomNumberGenerator
  var flyingTerrorAI: SeededRandomNumberGenerator
  init(seed: UInt64) {
    itemSpawn = .init(seed: seed ^ 0x11)
    skeletonAI = .init(seed: seed ^ 0x5151)
    flyingTerrorAI = .init(seed: seed ^ 0x7171)
  }
}

enum LevelTwoDefinition {
  static let internalWallAnchors =
    [4, 8, 12, 16, 20, 24, 28, 32, 36, 40].map { GridPosition(row: 16, column: $0) }
    + [8, 12].map { GridPosition(row: 24, column: $0) }
    + [20, 24].flatMap { r in [36, 40].map { GridPosition(row: r, column: $0) } }
  static let lavaAnchors =
    [32, 36, 40].flatMap { r in
      stride(from: 4, through: 52, by: 4).map { GridPosition(row: r, column: $0) }
    }
    + [44, 48, 52].flatMap { r in [36, 40, 44, 48, 52].map { GridPosition(row: r, column: $0) } }
    + [20, 24, 28].flatMap { r in [20, 24, 28].map { GridPosition(row: r, column: $0) } }
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ], leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    let walls =
      boundary.wallRegions
      + internalWallAnchors.map {
        GridRegion(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }
    let lava = lavaAnchors.map {
      GridRegion(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
    }
    return .init(
      grid: .init(rows: 60, columns: 60), start: .init(row: 50, column: 27),
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: -100, column: -100), boundary: boundary, walls: walls, lava: lava,
      internalWallAnchors: internalWallAnchors, displayName: "Level 2")
  }
}
enum LevelTwoRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-two.floor"),
    lava = RenderAssetID(rawValue: "level-two.lava"),
    wallFront = RenderAssetID(rawValue: "level-two.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-two.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-two.wall.right"),
    exitDoor = RenderAssetID(rawValue: "level-two.door.open"),
    entryDoor = RenderAssetID(rawValue: "level-two.door.closed"),
    smoke = RenderAssetID(rawValue: "level-two.smoke")
}
enum LevelTwoRenderAnimations {
  static func enemy(_ a: EnemyArchetype, _ d: RenderOrientation) -> RenderAnimationID {
    if a == .minotaur {
      let row =
        switch d {
        case .down: 0
        case .left: 1
        case .right: 2
        case .up: 3
        case .none: 0
        }
      return .init(rawValue: "enemy.minotaur.\(row)-0")
    }
    return .init(
      rawValue: "enemy.\(a == .skeleton ? "skeleton" : "flying-terror").walk.\(d.rawValue)")
  }
}

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
          .init(
            rows: row..<min(row + 10, level.grid.rows),
            columns: column..<min(column + 10, level.grid.columns)),
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
    let walls =
      javaBoundaryWalls.map { region in
        tile(
          region,
          region.columns == 0..<4
            ? LevelTwoRenderAssets.wallLeft
            : (region.columns == 56..<60
              ? LevelTwoRenderAssets.wallRight : LevelTwoRenderAssets.wallFront))
      }
      + level.internalWallAnchors.map {
        tile(
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4),
          LevelTwoRenderAssets.wallFront)
      }

    return .init(
      levelID: .levelTwo, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelTwoRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelTwoRenderAssets.exitDoor,
          coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelTwoRenderAssets.entryDoor,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelTwoRenderAssets.smoke,
          coordinate: .init(row: 39, column: 5),
          renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
        .init(
          id: EntityID(), asset: LevelTwoRenderAssets.smoke,
          coordinate: .init(row: 55, column: 50),
          renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
      ])
  }
}

@MainActor final class LevelTwoSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelTwo }
  override var levelName: String { "Level 2" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 2, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let streams = LevelRandomStreams(seed: seed)
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: entryPosition == .top ? .init(row: 5, column: 27) : .init(row: 50, column: 27),
      entities: [])
    level = LevelTwoDefinition.make()
    presentationDefinition = LevelTwoPresentationDefinition.make(from: level)
    chestStates = []
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 6, column: 23), facing: .right,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 5, column: 33),
        facing: .right, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [
      .init(row: 5, column: 27), .init(row: 50, column: 27),
    ])
    try validateInitialPlayerFootprint()
    var rng = streams.itemSpawn
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: enemies.map { $0.archetype.footprint.region(at: $0.position) } + [
        .init(rows: 39..<43, columns: 5..<9), .init(rows: 55..<59, columns: 50..<54),
      ], using: &rng)
  }
  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateEnemySystem(deltaTime)
    checkDoors()
  }
  private func checkDoors() {
    let region = CollisionProfile.player.region(at: player.position)
    let carry = {
      PlayerCarryoverState(
        characterID: self.player.id, health: self.player.health, score: self.player.score,
        completedLevelIDs: self.completedLevelIDs, worldState: self.worldState)
    }
    if region.intersects(level.entryRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelTwo, destinationLevelID: .levelOne, destinationEntry: .top,
          carryover: carry(), reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      if !completedLevelIDs.contains(.levelTwo) {
        player.score += 100
        completedLevelIDs.insert(.levelTwo)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelTwo, destinationLevelID: .levelThree, destinationEntry: .bottom,
          carryover: carry()))
    }
  }
}

enum LevelThreeDefinition {
  static let internalWallAnchors =
    stride(from: 24, to: 48, by: 4).map { GridPosition(row: 12, column: $0) }
    + stride(from: 4, to: 12, by: 4).map { GridPosition(row: $0, column: 24) }
    + stride(from: 40, to: 56, by: 4).map { GridPosition(row: $0, column: 24) }
    + stride(from: 24, to: 48, by: 4).map { GridPosition(row: 40, column: $0) }
    + stride(from: 32, to: 56, by: 4).map { GridPosition(row: 24, column: $0) }
    + [
      GridPosition(row: 32, column: 4), GridPosition(row: 36, column: 4),
      GridPosition(row: 28, column: 32), GridPosition(row: 28, column: 4),
      GridPosition(row: 28, column: 8), GridPosition(row: 32, column: 32),
      GridPosition(row: 32, column: 28),
    ]
  static let lavaAnchors =
    stride(from: 4, to: 28, by: 4).flatMap { row in
      stride(from: 4, to: 22, by: 4).map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 32, to: 56, by: 4).flatMap { row in
      stride(from: 12, to: 22, by: 2).map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 40, through: 52, by: 4).map { GridPosition(row: $0, column: 4) }
    + stride(from: 28, through: 36, by: 4).flatMap { row in
      stride(from: 40, through: 48, by: 4).map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 32, through: 40, by: 4).map { GridPosition(row: $0, column: 52) }
    + stride(from: 40, through: 44, by: 4).map { GridPosition(row: $0, column: 8) }
    + stride(from: 8, through: 12, by: 4).flatMap { row in
      stride(from: 48, through: 54, by: 4).map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 12, to: 24, by: 4).map { GridPosition(row: 28, column: $0) }
    + [GridPosition(row: 40, column: 48)]
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [
        .init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60),
      ], leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    return .init(
      grid: .init(rows: 60, columns: 60), start: .init(row: 50, column: 27),
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: 52, column: 8), boundary: boundary,
      walls: boundary.wallRegions
        + internalWallAnchors.map {
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
        },
      lava: lavaAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }, internalWallAnchors: internalWallAnchors, displayName: "Level 3")
  }
}
enum LevelThreeRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-three.floor"),
    lava = RenderAssetID(rawValue: "level-three.lava"),
    wallFront = RenderAssetID(rawValue: "level-three.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-three.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-three.wall.right"),
    exitDoor = RenderAssetID(rawValue: "level-three.door.open"),
    entryDoor = RenderAssetID(rawValue: "level-three.door.closed"),
    smoke = RenderAssetID(rawValue: "level-three.smoke")
}
enum LevelThreeRenderAnimations {
  static let smokeLoop = RenderAnimationID(rawValue: "level-three.smoke.loop")
}

enum LevelThreePresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ r: GridRegion, _ a: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: r.rows.lowerBound, column: r.columns.lowerBound),
        sizeInCells: .init(width: Double(r.columns.count), height: Double(r.rows.count)), asset: a,
        anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: level.grid.rows, by: 10).flatMap { row in
      stride(from: 0, to: level.grid.columns, by: 10).map { col in
        tile(
          .init(
            rows: row..<min(row + 10, level.grid.rows),
            columns: col..<min(col + 10, level.grid.columns)), LevelThreeRenderAssets.floor)
      }
    }
    let javaBoundaryWalls = [
      GridRegion(rows: 0..<4, columns: 0..<60), .init(rows: 56..<60, columns: 0..<60),
      .init(rows: 4..<56, columns: 0..<4), .init(rows: 4..<56, columns: 56..<60),
    ]
    let walls =
      javaBoundaryWalls.map {
        tile(
          $0,
          $0.columns == 0..<4
            ? LevelThreeRenderAssets.wallLeft
            : ($0.columns == 56..<60
              ? LevelThreeRenderAssets.wallRight : LevelThreeRenderAssets.wallFront))
      }
      + level.internalWallAnchors.map {
        tile(
          .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4),
          LevelThreeRenderAssets.wallFront)
      }
    return .init(
      levelID: .levelThree, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelThreeRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.exitDoor,
          coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.entryDoor,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.smoke,
          coordinate: .init(row: 9, column: 5),
          renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4,
          animationID: LevelThreeRenderAnimations.smokeLoop),
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.smoke,
          coordinate: .init(row: 56, column: 20), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4, animationID: LevelThreeRenderAnimations.smokeLoop),
        .init(
          id: EntityID(), asset: LevelThreeRenderAssets.smoke,
          coordinate: .init(row: 42, column: 49), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4, animationID: LevelThreeRenderAnimations.smokeLoop),
      ])
  }
}

@MainActor final class LevelThreeSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelThree }
  override var levelName: String { "Level 3" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 3, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: entryPosition == .top ? .init(row: 5, column: 29) : .init(row: 50, column: 29),
      entities: [])
    level = LevelThreeDefinition.make()
    presentationDefinition = LevelThreePresentationDefinition.make(from: level)
    chestStates = [Self.standardChest(at: level.chestAnchor, message: "You made it!")]
    restoreOpenedChestStates()
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 16, column: 29), facing: .right,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 18, column: 42),
        facing: .left, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [
      .init(row: 5, column: 29), .init(row: 50, column: 29),
    ])
    try validateInitialPlayerFootprint()
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x33)
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: enemies.map { $0.archetype.footprint.region(at: $0.position) } + [
        .init(rows: 9..<13, columns: 5..<9), .init(rows: 56..<60, columns: 20..<24),
        .init(rows: 42..<46, columns: 49..<53),
      ], using: &rng)
  }
  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateEnemySystem(deltaTime)
    checkDoors()
  }
  private func checkDoors() {
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(level.entryRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelThree, destinationLevelID: .levelTwo, destinationEntry: .top,
          carryover: .init(
            characterID: player.id, health: player.health, score: player.score,
            completedLevelIDs: completedLevelIDs, worldState: worldState),
          reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      if !completedLevelIDs.contains(.levelThree) {
        player.score += 100
        completedLevelIDs.insert(.levelThree)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelThree, destinationLevelID: .levelFour, destinationEntry: .bottom,
          carryover: .init(
            characterID: player.id, health: player.health, score: player.score,
            completedLevelIDs: completedLevelIDs)))
    }
  }
}

enum LevelFourDefinition {
  static let rightExitRegion = GridRegion(rows: 27..<33, columns: 56..<60)
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [.init(rows: 56..<60, columns: 0..<60)],
      leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [
        .init(rows: 4..<27, columns: 56..<60), .init(rows: 33..<56, columns: 56..<60),
      ],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    return .init(
      grid: .init(rows: 60, columns: 60), start: .init(row: 50, column: 27),
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: -100, column: -100), boundary: boundary, walls: boundary.wallRegions,
      lava: [], internalWallAnchors: [], displayName: "Level 4")
  }
}
enum LevelFourRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-four.floor"),
    wallFront = RenderAssetID(rawValue: "level-four.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-four.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-four.wall.right"),
    doorOpen = RenderAssetID(rawValue: "level-four.door.open"),
    doorClosed = RenderAssetID(rawValue: "level-four.door.closed"),
    doorOpenSide = RenderAssetID(rawValue: "level-four.door.open.side"),
    doorClosedRight = RenderAssetID(rawValue: "level-four.door.closed.right")
}
enum LevelFourRenderAnimations {
  static func minotaur(_ d: RenderOrientation) -> RenderAnimationID {
    let row =
      switch d {
      case .down: 0
      case .left: 1
      case .right: 2
      case .up: 3
      case .none: 0
      }
    return .init(rawValue: "enemy.minotaur.\(row)-0")
  }
}

extension LevelAssetManifest {
  static let levelFour = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelFourRenderAssets.floor, LevelFourRenderAssets.wallFront,
      LevelFourRenderAssets.wallLeft, LevelFourRenderAssets.wallRight,
      LevelFourRenderAssets.doorOpen, LevelFourRenderAssets.doorClosed,
      LevelFourRenderAssets.doorOpenSide, LevelFourRenderAssets.doorClosedRight,
      EnemyArchetype.minotaur.asset,
    ])
    .union(sharedPlayerTextureAssetIDs)
    .union(
      (0..<4).flatMap { row in
        (0..<3).map { RenderAssetID(rawValue: "enemy.minotaur.\(row)-\($0)") }
      }),
    animationIDs: Set([
      LevelOneRenderAnimations.lidiaWalk(.up), LevelOneRenderAnimations.lidiaWalk(.down),
      LevelOneRenderAnimations.lidiaWalk(.left), LevelOneRenderAnimations.lidiaWalk(.right),
      LevelTwoRenderAnimations.enemy(.minotaur, .up),
      LevelTwoRenderAnimations.enemy(.minotaur, .down),
      LevelTwoRenderAnimations.enemy(.minotaur, .left),
      LevelTwoRenderAnimations.enemy(.minotaur, .right),
    ]))
}

extension LevelTwoRenderAnimations {
  static func minotaur(_ d: RenderOrientation) -> RenderAnimationID {
    let row =
      switch d {
      case .down: 0
      case .left: 1
      case .right: 2
      case .up: 3
      case .none: 0
      }
    return .init(rawValue: "enemy.minotaur.\(row)-0")
  }
}

enum LevelFourPresentationDefinition {
  static func make(from level: LevelDefinition, bossDefeated: Bool = false)
    -> LevelPresentationDefinition
  {
    func tile(_ r: GridRegion, _ a: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: r.rows.lowerBound, column: r.columns.lowerBound),
        sizeInCells: .init(width: Double(r.columns.count), height: Double(r.rows.count)), asset: a,
        anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: level.grid.rows, by: 10).flatMap { row in
      stride(from: 0, to: level.grid.columns, by: 10).map { col in
        tile(
          .init(
            rows: row..<min(row + 10, level.grid.rows),
            columns: col..<min(col + 10, level.grid.columns)), LevelFourRenderAssets.floor)
      }
    }
    let javaBoundaryWalls = [
      GridRegion(rows: 0..<4, columns: 0..<60), .init(rows: 56..<60, columns: 0..<60),
      .init(rows: 4..<56, columns: 0..<4), .init(rows: 4..<56, columns: 56..<60),
    ]
    let walls = javaBoundaryWalls.map {
      tile(
        $0,
        $0.columns == 0..<4
          ? LevelFourRenderAssets.wallLeft
          : ($0.columns == 56..<60
            ? LevelFourRenderAssets.wallRight : LevelFourRenderAssets.wallFront))
    }
    return .init(
      levelID: .levelFour, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelFourRenderAssets.doorClosed,
          coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3)
      ])
  }
}

@MainActor final class LevelFourSimulation: LevelOneSimulation {
  private var boss: EnemyState?
  private var bossHitByCurrentHook = false
  override var levelID: LevelID { .levelFour }
  override var levelName: String { "Level 4" }
  override var renderSnapshot: GameRenderSnapshot {
    let s = super.renderSnapshot
    let bossRender = boss.map { b in
      let orientation = RenderOrientation(rawValue: b.facing.rawValue) ?? .right
      return RenderEntitySnapshot(
        id: b.id, asset: b.archetype.asset, coordinate: b.position,
        renderSize: b.archetype.renderSize, anchor: .center, zPosition: 7, orientation: orientation,
        animation: .init(
          animationID: LevelFourRenderAnimations.minotaur(orientation),
          frameIndex: configuration.reducedMotion ? 0 : Int(b.animationTime / 0.12) % 3),
        opacity: 1, isHidden: false, health: .init(current: b.health, maximum: b.maximumHealth))
    }
    let open = boss == nil
    let doors = [
      RenderEntitySnapshot(
        id: EntityID(UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1))),
        asset: open ? LevelFourRenderAssets.doorOpen : LevelFourRenderAssets.doorClosed,
        coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
        anchor: .bottomLeft, zPosition: 3),
      RenderEntitySnapshot(
        id: EntityID(UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2))),
        asset: open ? LevelFourRenderAssets.doorOpenSide : LevelFourRenderAssets.doorClosedRight,
        coordinate: .init(row: 28, column: 56), renderSize: .init(width: 4, height: 4),
        anchor: .bottomLeft, zPosition: 3),
    ]
    return .init(
      player: s.player, entities: s.entities + doors + (bossRender.map { [$0] } ?? []),
      grapple: s.grapple, effects: s.effects)
  }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 4, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    boss = .init(
      id: EntityID(), archetype: .minotaur, position: .init(row: 25, column: 25), facing: .right,
      health: 10, maximumHealth: 10, behaviorState: .seek, decisionAccumulator: 0, animationTime: 0)
    let start: GridPosition =
      switch entryPosition {
      case .top: .init(row: 5, column: 27)
      case .right: .init(row: 29, column: 52)
      case .bottom: .init(row: 50, column: 27)
      }
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: start, entities: [])
    if completedLevelIDs.contains(.levelFour) { boss = nil }
    level = LevelFourDefinition.make()
    presentationDefinition = LevelFourPresentationDefinition.make(from: level)
    chestStates = []
    try validateInitialPlayerFootprint()
  }
  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    updateBoss(deltaTime)
    checkLevelFourDoors()
  }
  private func updateBoss(_ dt: TimeInterval) {
    guard var b = boss, outcome == nil else { return }
    b.animationTime += dt
    b.decisionAccumulator += dt
    if b.decisionAccumulator >= b.archetype.seekInterval {
      b.decisionAccumulator = 0
      let dirs = GridDirection.allCases
      if let best = dirs.filter({ dir in
        let region = b.archetype.footprint.region(at: b.position.moved(dir))
        return region.cells.allSatisfy(level.isInside)
          && !level.walls.contains { $0.intersects(region) }
      }).min(by: { a, c in
        hypot(
          Double(b.position.moved(a).row - player.position.row),
          Double(b.position.moved(a).column - player.position.column))
          < hypot(
            Double(b.position.moved(c).row - player.position.row),
            Double(b.position.moved(c).column - player.position.column))
      }) {
        b.facing = best
        b.position = b.position.moved(best)
      }
    }
    boss = b
    if b.archetype.footprint.region(at: b.position).intersects(
      CollisionProfile.player.region(at: player.position))
    {
      guard player.damageCooldown <= 0 else { return }
      player.health -= 1
      player.damageCooldown = 0.75
      emit(.healthLost(amount: 1, source: .enemy(.minotaur)), at: player.position)
      checkLoss()
    }
    guard let head = player.hookshot.head, player.hookshot.phase == .extending else {
      if player.hookshot.phase == .idle { bossHitByCurrentHook = false }
      return
    }
    if !bossHitByCurrentHook
      && b.archetype.footprint.region(at: b.position).intersects(
        CollisionProfile.hookHead.region(at: head))
    {
      bossHitByCurrentHook = true
      b.health -= 1
      player.score += 10
      emit(
        .enemyHit(archetype: .minotaur, points: 10, remainingHealth: max(0, b.health)),
        at: b.position)
      player.hookshot.phase = .retracting
      if b.health <= 0 {
        let id = emit(.enemyDefeated(archetype: .minotaur), at: b.position)
        effectEvents.append(
          .init(
            id: id, coordinate: b.position,
            descriptor: .enemyDefeat(reducedMotion: configuration.reducedMotion),
            createdAt: simulationTime))
        boss = nil
      } else {
        boss = b
      }
    }
  }
  private func checkLevelFourDoors() {
    guard outcome == nil else { return }
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(level.entryRegion) {
      cancelAllInput()
      let carry = PlayerCarryoverState(
        characterID: player.id, health: player.health, score: player.score,
        completedLevelIDs: completedLevelIDs, worldState: worldState)
      onLevelTransition?(
        LevelTransitionRequest(
          sourceLevelID: .levelFour, destinationLevelID: .levelThree, destinationEntry: .top,
          carryover: carry, reason: .returnedBackward))
    } else if boss == nil
      && (region.intersects(level.exitRegion)
        || region.intersects(LevelFourDefinition.rightExitRegion))
    {
      if !completedLevelIDs.contains(.levelFour) {
        player.score += 100
        completedLevelIDs.insert(.levelFour)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      if region.intersects(LevelFourDefinition.rightExitRegion) {
        cancelAllInput()
        let carry = PlayerCarryoverState(
          characterID: player.id, health: player.health, score: player.score,
          completedLevelIDs: completedLevelIDs, worldState: worldState)
        onLevelTransition?(
          LevelTransitionRequest(
            sourceLevelID: .levelFour, destinationLevelID: .levelFive, destinationEntry: .bottom,
            carryover: carry))
      } else {
        cancelAllInput()
        let carry = PlayerCarryoverState(
          characterID: player.id, health: player.health, score: player.score,
          completedLevelIDs: completedLevelIDs, worldState: worldState)
        onLevelTransition?(
          LevelTransitionRequest(
            sourceLevelID: .levelFour, destinationLevelID: .levelSix, destinationEntry: .bottom,
            carryover: carry))
      }
    }
  }
}

// Java LevelFive uses 40-pixel environment tiles on a 600-pixel board. Native gameplay keeps
// the established 60-cell logical grid, so every Java pixel anchor is divided by ten here.
enum LevelFiveDefinition {
  static let wallAnchors: [GridPosition] =
    stride(from: 32, to: 52, by: 4).map { .init(row: 12, column: $0) }
    + stride(from: 32, to: 44, by: 4).map { .init(row: 16, column: $0) }
    + stride(from: 8, to: 28, by: 4).map { .init(row: 16, column: $0) }
    + stride(from: 4, to: 28, by: 4).map { .init(row: 24, column: $0) }
    + stride(from: 12, to: 28, by: 4).map { .init(row: 32, column: $0) }
    + stride(from: 32, to: 56, by: 4).map { .init(row: $0, column: 32) }
    + stride(from: 20, to: 40, by: 4).flatMap { row in
      [44, 48].map { GridPosition(row: row, column: $0) }
    }
    + stride(from: 8, to: 16, by: 4).map { .init(row: $0, column: 16) }
    + [
      .init(row: 8, column: 32), .init(row: 44, column: 52), .init(row: 52, column: 36),
      .init(row: 32, column: 36), .init(row: 36, column: 36), .init(row: 40, column: 28),
      .init(row: 32, column: 4), .init(row: 36, column: 4), .init(row: 52, column: 4),
      .init(row: 52, column: 28), .init(row: 8, column: 28),
    ]
  static let lavaAnchors: [GridPosition] =
    stride(from: 40, to: 52, by: 4).flatMap { row in
      stride(from: 4, to: 30, by: 4).map { .init(row: row, column: $0) }
    }
    + stride(from: 40, to: 52, by: 4).flatMap { row in
      stride(from: 40, to: 52, by: 4).map { .init(row: row, column: $0) }
    }
    + stride(from: 20, to: 32, by: 4).flatMap { row in
      stride(from: 32, to: 40, by: 4).map { .init(row: row, column: $0) }
    }
    + stride(from: 4, to: 12, by: 4).flatMap { row in
      stride(from: 40, to: 52, by: 4).map { .init(row: row, column: $0) }
    }
    + stride(from: 8, to: 20, by: 4).map { .init(row: 20, column: $0) }
    + stride(from: 24, to: 36, by: 4).map { .init(row: $0, column: 28) }
    + stride(from: 12, to: 24, by: 4).map { .init(row: 36, column: $0) }
    + stride(from: 12, to: 24, by: 4).map { .init(row: 52, column: $0) }
    + [
      .init(row: 4, column: 4), .init(row: 4, column: 8), .init(row: 8, column: 12),
      .init(row: 4, column: 24), .init(row: 8, column: 24), .init(row: 20, column: 40),
      .init(row: 24, column: 40),
    ]
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<27), .init(rows: 0..<4, columns: 33..<60)],
      bottomWallRegions: [.init(rows: 56..<60, columns: 0..<60)],
      leftWallRegions: [.init(rows: 4..<8, columns: 0..<4), .init(rows: 12..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 27..<33),
      bottomDoorRegion: .init(rows: 8..<12, columns: 0..<4))
    return .init(
      grid: .init(rows: 60, columns: 60), start: .init(row: 8, column: 7),
      exitAnchor: .init(row: 0, column: 27), entryAnchor: .init(row: 8, column: 0),
      chestAnchor: .init(row: 52, column: 4), boundary: boundary,
      walls: boundary.wallRegions
        + wallAnchors.map {
          .init(rows: $0.row..<($0.row + 4), columns: $0.column..<($0.column + 4))
        },
      lava: lavaAnchors.map {
        .init(rows: $0.row..<($0.row + 4), columns: $0.column..<($0.column + 4))
      },
      internalWallAnchors: wallAnchors, displayName: "Level 5")
  }
}

enum LevelFiveRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-five.floor"),
    lava = RenderAssetID(rawValue: "level-five.lava"),
    wallFront = RenderAssetID(rawValue: "level-five.wall.front"),
    wallLeft = RenderAssetID(rawValue: "level-five.wall.left"),
    wallRight = RenderAssetID(rawValue: "level-five.wall.right"),
    exitDoor = RenderAssetID(rawValue: "level-five.door.open"),
    entryDoor = RenderAssetID(rawValue: "level-five.door.closed.left"),
    chest = RenderAssetID(rawValue: "level-five.chest.side"),
    smoke = RenderAssetID(rawValue: "level-five.smoke")
}
extension LevelAssetManifest {
  static let levelFive = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelFiveRenderAssets.floor, LevelFiveRenderAssets.lava, LevelFiveRenderAssets.wallFront,
      LevelFiveRenderAssets.wallLeft, LevelFiveRenderAssets.wallRight,
      LevelFiveRenderAssets.exitDoor, LevelFiveRenderAssets.entryDoor, LevelFiveRenderAssets.smoke,
      LevelFiveRenderAssets.chest, LevelOneRenderAssets.mine, LevelOneRenderAssets.cabbage,
    ]).union(sharedPlayerTextureAssetIDs).union(sharedCoinTextureAssetIDs).union(
      sharedEnemyTextureAssetIDs),
    animationIDs: Set([
      LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up),
      LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left),
      LevelOneRenderAnimations.lidiaWalk(.right), LevelTwoRenderAnimations.enemy(.skeleton, .up),
      LevelTwoRenderAnimations.enemy(.skeleton, .down),
      LevelTwoRenderAnimations.enemy(.skeleton, .left),
      LevelTwoRenderAnimations.enemy(.skeleton, .right),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .up),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .down),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .left),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .right),
    ]))
}

enum LevelFivePresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ r: GridRegion, _ a: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: r.rows.lowerBound, column: r.columns.lowerBound),
        sizeInCells: .init(width: Double(r.columns.count), height: Double(r.rows.count)), asset: a,
        anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: 60, by: 10).flatMap { row in
      stride(from: 0, to: 60, by: 10).map { col in
        tile(
          .init(rows: row..<min(row + 10, 60), columns: col..<min(col + 10, 60)),
          LevelFiveRenderAssets.floor)
      }
    }
    return .init(
      levelID: .levelFive, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(
          id: .init(rawValue: "lava"), zPosition: 1,
          tiles: level.lava.map { tile($0, LevelFiveRenderAssets.lava) }),
        .init(
          id: .init(rawValue: "walls"), zPosition: 2,
          tiles: level.walls.map {
            tile(
              $0,
              $0.columns == 0..<4
                ? LevelFiveRenderAssets.wallLeft
                : ($0.columns == 56..<60
                  ? LevelFiveRenderAssets.wallRight : LevelFiveRenderAssets.wallFront))
          }),
      ],
      staticObjects: [
        .init(
          id: EntityID(), asset: LevelFiveRenderAssets.exitDoor,
          coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelFiveRenderAssets.entryDoor,
          coordinate: .init(row: 8, column: 0), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 3),
        .init(
          id: EntityID(), asset: LevelFiveRenderAssets.smoke,
          coordinate: .init(row: 55, column: 16), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
        .init(
          id: EntityID(), asset: LevelFiveRenderAssets.smoke,
          coordinate: .init(row: 26, column: 43), renderSize: .init(width: 4, height: 4),
          anchor: .bottomLeft, zPosition: 4),
      ])
  }
}

@MainActor final class LevelFiveSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelFive }
  override var levelName: String { "Level 5" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 5, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let start: GridPosition =
      entryPosition == .top ? .init(row: 5, column: 29) : .init(row: 8, column: 7)
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: start, entities: [])
    level = LevelFiveDefinition.make()
    presentationDefinition = LevelFivePresentationDefinition.make(from: level)
    chestStates = [
      .init(
        definition: .init(
          id: EntityID(), interactionAnchor: .init(row: 52, column: 4),
          renderAnchor: .init(row: 52, column: 8), closedAsset: LevelFiveRenderAssets.chest,
          openedAsset: LevelFiveRenderAssets.chest, renderSize: .init(width: 4, height: 4),
          renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100,
          healthReward: 2), isOpened: false)
    ]
    restoreOpenedChestStates()
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 28, column: 20), facing: .down,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 10, column: 40),
        facing: .left, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [
      .init(row: 5, column: 29), .init(row: 8, column: 7),
    ])
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x55)
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: [
        CollisionProfile.player.region(at: player.position),
        CollisionProfile.chest.region(at: level.chestAnchor),
        chestStates[0].definition.spawnExclusionRegion,
      ] + enemies.map { $0.archetype.footprint.region(at: $0.position) }, using: &rng)
    try validateInitialPlayerFootprint()
  }
  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateEnemySystem(deltaTime)
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(level.entryRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelFive, destinationLevelID: .levelFour, destinationEntry: .right,
          carryover: .init(
            characterID: player.id, health: player.health, score: player.score,
            completedLevelIDs: completedLevelIDs, worldState: worldState),
          reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      if !completedLevelIDs.contains(.levelFive) {
        player.score += 100
        completedLevelIDs.insert(.levelFive)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      setOutcome(.won)
    }
  }
}

// Java LevelSix uses the same 40-pixel environment tiles as LevelFive. Map design is retained,
// while the two enemies are separated from Java's overlapping top-exit spawn.
enum LevelSixDefinition {
  static let lavaAnchors: [GridPosition] =
    [8, 12, 16].map { .init(row: 4, column: $0) }
    + [8, 12, 16].flatMap { row in [20, 24, 28].map { .init(row: row, column: $0) } }
    + [20, 24, 28].flatMap { row in [40, 44, 48].map { .init(row: row, column: $0) } }
    + [40, 44, 48].flatMap { row in [20, 24, 28].map { .init(row: row, column: $0) } }
    + [24, 28].map { .init(row: $0, column: 52) }
    + [20, 24].map { .init(row: $0, column: 4) }
    + [32, 36, 40].map { .init(row: $0, column: 8) }
    + [40, 44, 48].map { .init(row: $0, column: 12) }
    + [40, 44].map { .init(row: $0, column: 4) }
    + [16, 20, 24].map { .init(row: 52, column: $0) }
    + [32, 36, 40, 48].map { .init(row: 32, column: $0) }
  static let wallAnchors: [GridPosition] =
    [20, 24].flatMap { row in [8, 12, 16].map { .init(row: row, column: $0) } }
    + [36, 40, 44, 48].flatMap { row in [40, 44, 48].map { .init(row: row, column: $0) } }
    + [4, 8, 12, 16].map { .init(row: 12, column: $0) }
    + [20, 24, 28].map { .init(row: 32, column: $0) }
    + [28, 32, 36].map { .init(row: 24, column: $0) }
    + [4, 8].map { .init(row: 52, column: $0) }
    + [28, 32, 36, 40, 44, 48].map { .init(row: $0, column: 16) }
    + [40, 44, 48, 52].map { .init(row: $0, column: 32) }
    + [8, 12, 16].map { .init(row: $0, column: 36) }
    + [4, 8, 12, 16].map { .init(row: $0, column: 48) }
    + [
      .init(row: 4, column: 28), .init(row: 12, column: 32),
      .init(row: 20, column: 28), .init(row: 32, column: 4),
      .init(row: 28, column: 12), .init(row: 32, column: 12),
      .init(row: 24, column: 24),
    ]
  static let bottomStart = GridPosition(row: 50, column: 27)
  static let topStart = GridPosition(row: 5, column: 53)
  static func make() -> LevelDefinition {
    let boundary = LevelBoundaryGeometry(
      topWallRegions: [.init(rows: 0..<4, columns: 0..<51), .init(rows: 0..<4, columns: 57..<60)],
      bottomWallRegions: [.init(rows: 56..<60, columns: 0..<27), .init(rows: 56..<60, columns: 33..<60)],
      leftWallRegions: [.init(rows: 4..<56, columns: 0..<4)],
      rightWallRegions: [.init(rows: 4..<56, columns: 56..<60)],
      topExitRegion: .init(rows: 0..<4, columns: 51..<57),
      bottomDoorRegion: .init(rows: 56..<60, columns: 27..<33))
    return .init(
      grid: .init(rows: 60, columns: 60), start: bottomStart,
      exitAnchor: .init(row: 0, column: 51), entryAnchor: .init(row: 56, column: 27),
      chestAnchor: .init(row: 4, column: 24), boundary: boundary,
      walls: boundary.wallRegions + wallAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }, lava: lavaAnchors.map {
        .init(rows: $0.row..<$0.row + 4, columns: $0.column..<$0.column + 4)
      }, internalWallAnchors: wallAnchors, displayName: "Level 6")
  }
}

enum LevelSixRenderAssets {
  static let floor = RenderAssetID(rawValue: "level-six.floor")
  static let lava = RenderAssetID(rawValue: "level-six.lava")
  static let wallFront = RenderAssetID(rawValue: "level-six.wall.front")
  static let wallLeft = RenderAssetID(rawValue: "level-six.wall.left")
  static let wallRight = RenderAssetID(rawValue: "level-six.wall.right")
  static let exitDoor = RenderAssetID(rawValue: "level-six.door.open")
  static let entryDoor = RenderAssetID(rawValue: "level-six.door.closed")
  static let chestSide = RenderAssetID(rawValue: "level-six.chest.side")
  static let chestFront = RenderAssetID(rawValue: "level-six.chest.front")
  static let smoke = RenderAssetID(rawValue: "level-six.smoke")
}

extension LevelAssetManifest {
  static let levelSix = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelSixRenderAssets.floor, LevelSixRenderAssets.lava, LevelSixRenderAssets.wallFront,
      LevelSixRenderAssets.wallLeft, LevelSixRenderAssets.wallRight, LevelSixRenderAssets.exitDoor,
      LevelSixRenderAssets.entryDoor, LevelSixRenderAssets.chestSide,
      LevelSixRenderAssets.chestFront, LevelSixRenderAssets.smoke, LevelOneRenderAssets.mine,
      LevelOneRenderAssets.cabbage,
    ]).union(sharedPlayerTextureAssetIDs).union(sharedCoinTextureAssetIDs).union(
      sharedEnemyTextureAssetIDs),
    animationIDs: LevelAssetManifest.levelFive.animationIDs)
}

enum LevelSixPresentationDefinition {
  static func make(from level: LevelDefinition) -> LevelPresentationDefinition {
    func tile(_ region: GridRegion, _ asset: RenderAssetID) -> TileRenderPlacement {
      .init(
        coordinate: .init(row: region.rows.lowerBound, column: region.columns.lowerBound),
        sizeInCells: .init(width: Double(region.columns.count), height: Double(region.rows.count)),
        asset: asset, anchor: .bottomLeft)
    }
    let floor = stride(from: 0, to: 60, by: 10).flatMap { row in
      stride(from: 0, to: 60, by: 10).map { column in
        tile(.init(rows: row..<min(row + 10, 60), columns: column..<min(column + 10, 60)), LevelSixRenderAssets.floor)
      }
    }
    let walls = level.walls.map {
      tile($0, $0.columns == 0..<4 ? LevelSixRenderAssets.wallLeft : ($0.columns == 56..<60 ? LevelSixRenderAssets.wallRight : LevelSixRenderAssets.wallFront))
    }
    return .init(
      levelID: .levelSix, logicalGridSize: level.grid, background: .init(colorName: "black"),
      tileLayers: [
        .init(id: .init(rawValue: "floor"), zPosition: 0, tiles: floor),
        .init(id: .init(rawValue: "lava"), zPosition: 1, tiles: level.lava.map { tile($0, LevelSixRenderAssets.lava) }),
        .init(id: .init(rawValue: "walls"), zPosition: 2, tiles: walls),
      ], staticObjects: [
        .init(id: EntityID(), asset: LevelSixRenderAssets.exitDoor, coordinate: .init(row: 0, column: 52), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 3),
        .init(id: EntityID(), asset: LevelSixRenderAssets.entryDoor, coordinate: .init(row: 56, column: 28), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 3),
        .init(id: EntityID(), asset: LevelSixRenderAssets.smoke, coordinate: .init(row: 13, column: 21), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
        .init(id: EntityID(), asset: LevelSixRenderAssets.smoke, coordinate: .init(row: 39, column: 53), renderSize: .init(width: 4, height: 4), anchor: .bottomLeft, zPosition: 4),
      ])
  }
}

@MainActor final class LevelSixSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelSix }
  override var levelName: String { "Level 6" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 6, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let start = entryPosition == .top ? LevelSixDefinition.topStart : LevelSixDefinition.bottomStart
    try super.init(configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover, startOverride: start, entities: [])
    level = LevelSixDefinition.make()
    presentationDefinition = LevelSixPresentationDefinition.make(from: level)
    chestStates = [
      .init(definition: .init(id: EntityID(), interactionAnchor: .init(row: 4, column: 24), renderAnchor: .init(row: 4, column: 24), closedAsset: LevelSixRenderAssets.chestSide, openedAsset: LevelSixRenderAssets.chestSide, renderSize: .init(width: 4, height: 4), renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100, healthReward: 2), isOpened: false),
      .init(definition: .init(id: EntityID(), interactionAnchor: .init(row: 44, column: 8), renderAnchor: .init(row: 44, column: 8), closedAsset: LevelSixRenderAssets.chestFront, openedAsset: LevelSixRenderAssets.chestFront, renderSize: .init(width: 4, height: 4), renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100, healthReward: 2), isOpened: false),
    ]
    restoreOpenedChestStates()
    enemies = [
      .init(id: EntityID(), archetype: .skeleton, position: .init(row: 22, column: 53), facing: .left, health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0, animationTime: 0),
      .init(id: EntityID(), archetype: .flyingTerror, position: .init(row: 10, column: 52), facing: .left, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0, animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [LevelSixDefinition.bottomStart, LevelSixDefinition.topStart])
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x66)
    let chestRegions = chestStates.flatMap {
      [CollisionProfile.chest.region(at: $0.definition.interactionAnchor),
        $0.definition.spawnExclusionRegion]
    }
    entities = try SpawnService.spawn(in: level, requirements: [.init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2), .init(kind: .coin, count: 10)], protectedRegions: [CollisionProfile.player.region(at: player.position)] + chestRegions + enemies.map { $0.archetype.footprint.region(at: $0.position) }, using: &rng)
    try validateInitialPlayerFootprint()
  }
  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateEnemySystem(deltaTime)
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(level.entryRegion) {
      cancelAllInput()
      onLevelTransition?(.init(sourceLevelID: .levelSix, destinationLevelID: .levelFour, destinationEntry: .top, carryover: .init(characterID: player.id, health: player.health, score: player.score, completedLevelIDs: completedLevelIDs, worldState: worldState), reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      if !completedLevelIDs.contains(.levelSix) {
        player.score += 100
        completedLevelIDs.insert(.levelSix)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      setOutcome(.won)
    }
  }
}
