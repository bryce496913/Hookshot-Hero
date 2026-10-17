import Foundation

/// Ephemeral domain events: not UI animation, save data or AVFoundation state.
enum GameAudioEvent: Equatable, Sendable {
  case playerStep, grappleFired, coinCollected, healthPickup, chestHealed
  case mineExploded, playerDamaged(DamageSource), enemyDamaged(EnemyArchetype), projectileImpact

  static func feedback(_ kind: GameplayFeedbackKind) -> Self? {
    switch kind {
    case .coinCollected: .coinCollected
    case .healthItemCollected, .healthAlreadyFull: .healthPickup
    case .chestReward(_, let health): health > 0 ? .chestHealed : nil
    case .mineDestroyed: .mineExploded
    case .healthLost(_, let source): .playerDamaged(source)
    case .enemyHit(let archetype, _, _): .enemyDamaged(archetype)
    case .enemyDefeated, .levelCompleted: nil
    }
  }
}
