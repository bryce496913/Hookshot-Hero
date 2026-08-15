import Foundation

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
