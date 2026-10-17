import AVFoundation
import Foundation
import OSLog

@MainActor final class AVGameAudioPlayer: NSObject, GameAudioPlaying, AVAudioPlayerDelegate {
  private let player: AVAudioPlayer
  var onCompletion: (() -> Void)?
  init(url: URL) throws {
    player = try AVAudioPlayer(contentsOf: url)
    super.init()
    player.delegate = self
  }
  var isPlaying: Bool { player.isPlaying }
  var volume: Float { get { player.volume } set { player.volume = newValue } }
  var loops: Int { get { player.numberOfLoops } set { player.numberOfLoops = newValue } }
  func prepare() -> Bool { player.prepareToPlay() }
  func play() -> Bool { player.play() }
  func pause() { player.pause() }
  func stop() { player.stop(); player.currentTime = 0 }
  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor [weak self] in self?.onCompletion?() }
  }
  nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    Task { @MainActor [weak self] in self?.onCompletion?() }
  }
}

/// One looping music player plus an independently pooled set of one-shot effects.
@MainActor final class AVGameAudioBackend: GameAudioBackend {
  var onEnvironmentEvent: ((GameAudioEnvironmentEvent) -> Void)?
  private let bundle: Bundle
  private let musicFactory: (GameMusicTrack) throws -> any GameAudioPlaying
  private let activateSession: () throws -> Void
  private var activated = false
  private var music: (track: GameMusicTrack, player: any GameAudioPlaying)?
  private let effects: GameSoundPlayerPool
  private let observers = AudioNotificationTokens()
  private let logger = Logger(subsystem: "HookshotHero", category: "audio")

  init(bundle: Bundle = .main,
       musicFactory: ((GameMusicTrack) throws -> any GameAudioPlaying)? = nil,
       effectFactory: ((GameSoundEffect) throws -> any GameAudioPlaying)? = nil,
       activateSession: (() throws -> Void)? = nil, observeNotifications: Bool = true) {
    self.bundle = bundle
    self.musicFactory = musicFactory ?? { track in
      guard let url = track.asset.url(in: bundle) else { throw AudioError.missing(track.asset.rawValue) }
      return try AVGameAudioPlayer(url: url)
    }
    effects = GameSoundPlayerPool(factory: effectFactory ?? { effect in
      guard let url = effect.asset.url(in: bundle) else { throw AudioError.missing(effect.asset.rawValue) }
      return try AVGameAudioPlayer(url: url)
    }, diagnostic: { message in
      Logger(subsystem: "HookshotHero", category: "audio").error("\(message, privacy: .public)")
    })
    self.activateSession = activateSession ?? {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.ambient, mode: .default, options: [])
      try session.setActive(true)
    }
    for asset in GameAudioAsset.missing(in: bundle) {
      logger.error("Required audio resource missing: \(asset.rawValue, privacy: .public)")
    }
    if observeNotifications { observeAudioSession() }
    // Short, frequent clips only. The unchanged legacy enemy files can be very long.
    if effectFactory == nil {
      // prepareToPlay may acquire audio hardware; establish ambient policy before warming players.
      do {
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        effects.preload([.walk, .whip, .coin, .crunch, .hit, .explosion, .lidiaHealed, .lidiaDamaged, .lidiaAttack])
      } catch {
        logger.error("Audio preparation unavailable; gameplay continues: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
  private func activate() -> Bool {
    if activated { return true }
    do { try activateSession(); activated = true; return true }
    catch { logger.error("Audio session unavailable; gameplay continues: \(error.localizedDescription, privacy: .public)"); return false }
  }
  func playMusic(_ track: GameMusicTrack) {
    guard activate() else { return }
    if let music, music.track == track {
      if !music.player.isPlaying && !music.player.play() {
        logger.error("Music could not resume: \(track.asset.rawValue, privacy: .public)")
      }
      return
    }
    stopMusic()
    do {
      let player = try musicFactory(track)
      player.volume = GameAudioVolume.music; player.loops = -1
      _ = player.prepare()
      if player.play() { music = (track, player) }
      else { logger.error("Music could not start: \(track.asset.rawValue, privacy: .public)") }
    } catch { logger.error("Music unavailable: \(track.asset.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)") }
  }
  func pauseMusic() { music?.player.pause(); activated = false }
  func stopMusic() { music?.player.stop(); music = nil }
  func playEffect(_ effect: GameSoundEffect) { if activate() { effects.play(effect) } }
  func stopEffects() { effects.stopAll() }

  private func observeAudioSession() {
    let center = NotificationCenter.default
    observers.values.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
      let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
      let raw = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
      let resume = AVAudioSession.InterruptionOptions(rawValue: raw).contains(.shouldResume)
      Task { @MainActor [weak self] in
        self?.activated = false
        self?.onEnvironmentEvent?(began ? .interruptionBegan : .interruptionEnded(shouldResume: resume))
      }
    })
    observers.values.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
      let disconnected = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
      if disconnected { Task { @MainActor [weak self] in self?.onEnvironmentEvent?(.routeDisconnected) } }
    })
    observers.values.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.activated = false
        self?.effects.reset()
        self?.onEnvironmentEvent?(.mediaServicesReset)
      }
    })
  }
  private enum AudioError: Error { case missing(String) }
}

/// NotificationCenter removal is thread-safe; this owner also cleans up when a backend is released.
private final class AudioNotificationTokens {
  var values: [NSObjectProtocol] = []
  deinit { for observer in values { NotificationCenter.default.removeObserver(observer) } }
}
