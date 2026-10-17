import Foundation

/// Exact historical filenames, including resources deliberately reserved in native single player.
enum GameAudioAsset: String, CaseIterable, Sendable {
  case atmosphere = "Atmosphere.wav", lava = "lava.wav", prettyMaiden = "pretty-maiden-mageonduty.wav"
  case explosion = "explosion.wav", crunch = "crunch.wav", walk = "walk.wav", hit = "hit.wav"
  case step = "step.wav", whip = "whip.wav", coin = "coin.wav", monsterDamage = "monsterdamage.wav"
  case skeleton = "skeleton.wav", flyingTerror = "ft.wav", start = "start.wav"
  case lidiaHealed = "t3-healed3.wav", shuraHealed = "t2-healed3.wav", avaHealed = "t1-healed3.wav"
  case lidiaDamaged = "t3-damaged1.wav", shuraDamaged = "t2-damaged1.wav", avaDamaged = "t1-damaged1.wav"
  case lidiaAttack = "t3-attack3.wav", shuraAttack = "t2-attack3.wav"

  var url: URL? { url(in: .main) }
  func url(in bundle: Bundle) -> URL? {
    bundle.url(forResource: String(rawValue.dropLast(4)), withExtension: "wav")
  }
  static var required: Set<Self> {
    Set(GameMusicTrack.allCases.map(\.asset) + GameSoundEffect.allCases.map(\.asset))
  }
  static func missing(in bundle: Bundle = .main, requiredOnly: Bool = true) -> [Self] {
    allCases.filter { (!requiredOnly || required.contains($0)) && $0.url(in: bundle) == nil }
  }
}

enum GameMusicTrack: CaseIterable, Hashable, Sendable {
  case atmosphere, lava, prettyMaiden
  var asset: GameAudioAsset {
    switch self { case .atmosphere: .atmosphere; case .lava: .lava; case .prettyMaiden: .prettyMaiden }
  }
  static func forLevel(_ level: LevelID) -> Self? {
    switch level {
    case .levelOne, .levelTwo, .levelThree, .levelFive, .levelSix, .levelSeven, .levelEight, .levelNine: .atmosphere
    case .levelFour, .levelTen: .lava
    case .countryRoad, .heroWelcome: .prettyMaiden
    default: nil
    }
  }
}

enum GameSoundEffect: CaseIterable, Hashable, Sendable {
  case walk, whip, coin, crunch, explosion, hit, monsterDamage, skeleton, flyingTerror
  case lidiaHealed, lidiaDamaged, lidiaAttack
  var asset: GameAudioAsset {
    switch self {
    case .walk: .walk; case .whip: .whip; case .coin: .coin; case .crunch: .crunch
    case .explosion: .explosion; case .hit: .hit; case .monsterDamage: .monsterDamage
    case .skeleton: .skeleton; case .flyingTerror: .flyingTerror
    case .lidiaHealed: .lidiaHealed; case .lidiaDamaged: .lidiaDamaged; case .lidiaAttack: .lidiaAttack
    }
  }
  var volume: Float {
    switch self {
    case .walk: GameAudioVolume.movement
    case .lidiaHealed, .lidiaDamaged, .lidiaAttack: GameAudioVolume.voice
    default: GameAudioVolume.effect
    }
  }
  static func forEvent(_ event: GameAudioEvent) -> [Self] {
    switch event {
    case .playerStep: return [.walk]
    case .grappleFired: return [.whip]
    case .coinCollected: return [.coin]
    // Java World.HandleCollision and hooked cabbage explicitly request a voice even at full health.
    case .healthPickup: return [.crunch, .lidiaHealed]
    case .chestHealed: return [.lidiaHealed]
    case .mineExploded: return [.explosion]
    case .playerDamaged(.mine): return [.explosion, .lidiaDamaged]
    case .playerDamaged(.lava): return [.hit, .lidiaDamaged]
    case .playerDamaged: return [.lidiaDamaged]
    case .projectileImpact: return [.hit]
    case .enemyDamaged(let enemy):
      // Preserve the second strike whip; GhostWizard's Java enemy-specific request is commented out.
      let impact: [Self] = switch enemy {
        case .skeleton: [.skeleton]
        case .flyingTerror: [.flyingTerror]
        case .minotaur: [.monsterDamage]
        case .ghostWizard: []
      }
      return [.whip] + impact + [.lidiaAttack]
    }
  }
}

enum GameAudioVolume {
  static let music: Float = 0.20
  static let movement: Float = 0.035
  static let effect: Float = 0.25
  static let voice: Float = 0.40
}
