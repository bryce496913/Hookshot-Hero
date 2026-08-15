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
    let firstRow = renderAnchor.row - Int(Double(height) * renderAnchorPoint.y)
    let firstColumn = renderAnchor.column - Int(Double(width) * renderAnchorPoint.x)
    return .init(
      rows: firstRow..<firstRow + height, columns: firstColumn..<firstColumn + width)
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
