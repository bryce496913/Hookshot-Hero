import Foundation

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
