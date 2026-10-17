import Foundation

@MainActor protocol GameAudioServicing: AnyObject {
  func beginGameplay(levelID: LevelID)
  func changeLevel(_ levelID: LevelID)
  func endGameplay()
  func stopAll()
  func handle(_ event: GameAudioEvent)
  func updateSettings(_ settings: GameSettings)
  func setApplicationActive(_ active: Bool)
}

@MainActor final class SilentGameAudioService: GameAudioServicing {
  static let shared = SilentGameAudioService()
  func beginGameplay(levelID: LevelID) {}
  func changeLevel(_ levelID: LevelID) {}
  func endGameplay() {}
  func stopAll() {}
  func handle(_ event: GameAudioEvent) {}
  func updateSettings(_ settings: GameSettings) {}
  func setApplicationActive(_ active: Bool) {}
}

enum GameAudioEnvironmentEvent: Sendable {
  case interruptionBegan, interruptionEnded(shouldResume: Bool), routeDisconnected, mediaServicesReset
}
@MainActor protocol GameAudioBackend: AnyObject {
  var onEnvironmentEvent: ((GameAudioEnvironmentEvent) -> Void)? { get set }
  func playMusic(_ track: GameMusicTrack)
  func pauseMusic()
  func stopMusic()
  func playEffect(_ effect: GameSoundEffect)
  func stopEffects()
}

/// Playback policy is independent of hardware, AVFoundation and simulation timing.
@MainActor final class GameAudioService: GameAudioServicing {
  private let backend: any GameAudioBackend
  private var settings: GameSettings
  private var active = true
  private var interrupted = false
  private var needsExplicitResume = false
  private var gameplayActive = false
  private var track: GameMusicTrack?

  init(backend: any GameAudioBackend, settings: GameSettings = .defaults) {
    self.backend = backend; self.settings = settings
    backend.onEnvironmentEvent = { [weak self] event in self?.environmentChanged(event) }
  }
  func beginGameplay(levelID: LevelID) {
    backend.stopEffects()
    gameplayActive = true
    needsExplicitResume = false
    track = GameMusicTrack.forLevel(levelID)
    reconcileMusic()
  }
  func changeLevel(_ levelID: LevelID) {
    gameplayActive = true // Also resumes a retained session after successful loading-failure Retry.
    track = GameMusicTrack.forLevel(levelID)
    reconcileMusic()
  }
  func endGameplay() {
    gameplayActive = false
    track = nil
    backend.stopMusic()
    // A terminal damage voice may finish; no new effects are accepted after this point.
  }
  func stopAll() { endGameplay(); backend.stopEffects() }
  func handle(_ event: GameAudioEvent) {
    guard gameplayActive, active, !interrupted, !needsExplicitResume, settings.soundEffectsEnabled else { return }
    GameSoundEffect.forEvent(event).forEach(backend.playEffect)
  }
  func updateSettings(_ settings: GameSettings) {
    if !self.settings.musicEnabled && settings.musicEnabled { needsExplicitResume = false }
    self.settings = settings
    if !settings.soundEffectsEnabled { backend.stopEffects() }
    reconcileMusic()
  }
  func setApplicationActive(_ active: Bool) {
    self.active = active
    if !active { backend.stopEffects() }
    reconcileMusic()
  }
  private func reconcileMusic() {
    guard gameplayActive, let track else { backend.stopMusic(); return }
    guard active, !interrupted, !needsExplicitResume, settings.musicEnabled else { backend.pauseMusic(); return }
    backend.playMusic(track)
  }
  private func environmentChanged(_ event: GameAudioEnvironmentEvent) {
    switch event {
    case .interruptionBegan:
      interrupted = true
      backend.stopEffects()
    case .interruptionEnded(let shouldResume):
      interrupted = false
      if !shouldResume { needsExplicitResume = true }
    case .routeDisconnected:
      needsExplicitResume = true
      backend.stopEffects()
    case .mediaServicesReset:
      backend.stopMusic()
      backend.stopEffects()
    }
    reconcileMusic()
  }
}

@MainActor protocol GameAudioPlaying: AnyObject {
  var isPlaying: Bool { get }
  var volume: Float { get set }
  var loops: Int { get set }
  var onCompletion: (() -> Void)? { get set }
  @discardableResult func prepare() -> Bool
  @discardableResult func play() -> Bool
  func pause()
  func stop()
}

/// Bounded concurrent one-shots; finished players leave the active set immediately.
@MainActor final class GameSoundPlayerPool {
  static let maximumActive = 16
  static let maximumIdlePerEffect = 1
  private let factory: (GameSoundEffect) throws -> any GameAudioPlaying
  private let diagnostic: (String) -> Void
  private var active: [UUID: (GameSoundEffect, any GameAudioPlaying)] = [:]
  private var idle: [GameSoundEffect: [any GameAudioPlaying]] = [:]
  var activeCount: Int { active.count }
  var idleCount: Int { idle.values.reduce(0) { $0 + $1.count } }

  init(factory: @escaping (GameSoundEffect) throws -> any GameAudioPlaying,
       diagnostic: @escaping (String) -> Void = { _ in }) {
    self.factory = factory; self.diagnostic = diagnostic
  }
  func preload(_ effects: [GameSoundEffect]) {
    for effect in effects where idle[effect, default: []].isEmpty {
      do {
        let player = try factory(effect)
        if player.prepare() { idle[effect] = [player] }
      } catch { diagnostic("Could not preload \(effect.asset.rawValue): \(error.localizedDescription)") }
    }
  }
  func play(_ effect: GameSoundEffect) {
    guard active.count < Self.maximumActive else { return } // Drop new excess sounds; never cut off a preceding sound.
    do {
      let player: any GameAudioPlaying
      if var available = idle[effect], let cached = available.popLast() {
        player = cached; idle[effect] = available
      } else { player = try factory(effect) }
      let token = UUID()
      player.volume = effect.volume; player.loops = 0
      player.onCompletion = { [weak self] in self?.finished(token) }
      active[token] = (effect, player)
      if !player.play() { active.removeValue(forKey: token); player.onCompletion = nil }
    } catch { diagnostic("Could not play \(effect.asset.rawValue): \(error.localizedDescription)") }
  }
  private func finished(_ token: UUID) {
    guard let (effect, player) = active.removeValue(forKey: token) else { return }
    player.onCompletion = nil
    player.stop()
    if idle[effect, default: []].count < Self.maximumIdlePerEffect { idle[effect, default: []].append(player) }
  }
  func stopAll() {
    let players = active.values.map { $0.1 }
    active.removeAll()
    for player in players { player.onCompletion = nil; player.stop() }
  }
  func reset() { stopAll(); idle.removeAll() }
}
