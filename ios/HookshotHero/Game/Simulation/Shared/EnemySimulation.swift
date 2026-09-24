import Foundation

enum EnemyArchetype: Equatable, Sendable {
  case skeleton, flyingTerror, minotaur, ghostWizard
  var displayName: String {
    switch self {
    case .skeleton: "Skeleton"
    case .flyingTerror: "Flying Terror"
    case .minotaur: "Minotaur"
    case .ghostWizard: "Ghost Wizard"
    }
  }
  var asset: RenderAssetID {
    switch self {
    case .skeleton: RenderAssetID(rawValue: "enemy.skeleton")
    case .flyingTerror: RenderAssetID(rawValue: "enemy.flying-terror")
    case .minotaur: RenderAssetID(rawValue: "enemy.minotaur")
    case .ghostWizard: LevelTenRenderAssets.ghostWizard
    }
  }
  var maximumHealth: Int {
    switch self {
    case .skeleton: 3
    case .flyingTerror: 5
    case .minotaur, .ghostWizard: 10
    }
  }
  var sight: Double {
    switch self {
    case .skeleton, .minotaur: 19
    case .flyingTerror: 39
    case .ghostWizard: 25
    }
  }
  var patrolInterval: TimeInterval {
    switch self {
    case .skeleton: 0.7
    case .flyingTerror: 0.3
    case .minotaur: 0.45
    case .ghostWizard: 0.5
    }
  }
  var seekInterval: TimeInterval {
    switch self {
    case .skeleton: 0.5
    case .flyingTerror: 0.3
    case .minotaur: 0.35
    case .ghostWizard: 0.15
    }
  }
  var footprint: CollisionFootprint {
    switch self {
    case .flyingTerror: .init(rowOffsets: -3..<5, columnOffsets: -3..<5)
    case .skeleton, .minotaur, .ghostWizard: .init(rowOffsets: -2..<3, columnOffsets: -2..<3)
    }
  }
  var renderSize: LogicalRenderSize {
    switch self {
    case .skeleton: .init(width: 4.9, height: 4.7)
    case .flyingTerror: .init(width: 12.8, height: 12.8)
    case .minotaur: .init(width: 4.8, height: 6.4)
    case .ghostWizard: .init(width: 3, height: 5.8)
    }
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
