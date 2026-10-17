import AVFoundation
import CryptoKit
import XCTest

@testable import HookshotHero

final class GameAudioCatalogTests: XCTestCase {
  func testEveryLevelHasTheExplicitJavaThemeIncludingDirectEntry() {
    let expected: [(LevelID, GameMusicTrack)] = [
      (.levelOne, .atmosphere), (.levelTwo, .atmosphere), (.levelThree, .atmosphere),
      (.levelFour, .lava), (.levelFive, .atmosphere), (.levelSix, .atmosphere),
      (.levelSeven, .atmosphere), (.levelEight, .atmosphere), (.levelNine, .atmosphere),
      (.levelTen, .lava), (.countryRoad, .prettyMaiden), (.heroWelcome, .prettyMaiden)
    ]
    for (level, track) in expected { XCTAssertEqual(GameMusicTrack.forLevel(level), track) }
    XCTAssertNil(GameMusicTrack.forLevel(.init(rawValue: "unsupported")))
  }
  func testAllTwentyTwoWAVsResolveDecodeAndMatchOriginalJavaBytes() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let java = root.appendingPathComponent("Java/resources")
    let actual = Set(try FileManager.default.contentsOfDirectory(atPath: java.path).filter { $0.lowercased().hasSuffix(".wav") })
    XCTAssertEqual(actual, Set(GameAudioAsset.allCases.map(\.rawValue)))
    XCTAssertEqual(actual.count, 22)
    XCTAssertTrue(GameAudioAsset.missing().isEmpty)
    XCTAssertTrue(GameAudioAsset.missing(requiredOnly: false).isEmpty)
    for asset in GameAudioAsset.allCases {
      let bundled = try XCTUnwrap(asset.url)
      let source = try Data(contentsOf: java.appendingPathComponent(asset.rawValue))
      let copy = try Data(contentsOf: bundled)
      XCTAssertEqual(SHA256.hash(data: source), SHA256.hash(data: copy), asset.rawValue)
      let file = try AVAudioFile(forReading: bundled)
      XCTAssertGreaterThan(file.length, 0)
      XCTAssertGreaterThan(file.processingFormat.sampleRate, 0)
    }
    for effect in GameSoundEffect.allCases { XCTAssertNotNil(effect.asset.url) }
    for track in GameMusicTrack.allCases { XCTAssertNotNil(track.asset.url) }
  }
  func testJavaEffectVoiceAndGhostWizardReachabilityDecisions() {
    XCTAssertEqual(GameSoundEffect.forEvent(.coinCollected), [.coin])
    XCTAssertEqual(GameSoundEffect.forEvent(.healthPickup), [.crunch, .lidiaHealed])
    XCTAssertEqual(GameSoundEffect.forEvent(.chestHealed), [.lidiaHealed])
    XCTAssertEqual(GameSoundEffect.forEvent(.playerDamaged(.mine)), [.explosion, .lidiaDamaged])
    XCTAssertEqual(GameSoundEffect.forEvent(.playerDamaged(.lava)), [.hit, .lidiaDamaged])
    XCTAssertEqual(GameSoundEffect.forEvent(.enemyDamaged(.skeleton)), [.whip, .skeleton, .lidiaAttack])
    XCTAssertEqual(GameSoundEffect.forEvent(.enemyDamaged(.flyingTerror)), [.whip, .flyingTerror, .lidiaAttack])
    XCTAssertEqual(GameSoundEffect.forEvent(.enemyDamaged(.minotaur)), [.whip, .monsterDamage, .lidiaAttack])
    XCTAssertEqual(GameSoundEffect.forEvent(.enemyDamaged(.ghostWizard)), [.whip, .lidiaAttack])
    XCTAssertFalse(GameAudioAsset.required.contains(.step))
    XCTAssertFalse(GameAudioAsset.required.contains(.start))
    XCTAssertFalse(GameAudioAsset.required.contains(.avaDamaged))
    XCTAssertLessThan(GameAudioVolume.movement, GameAudioVolume.effect)
    XCTAssertLessThan(GameAudioVolume.effect, GameAudioVolume.voice)
    XCTAssertTrue(GameSoundEffect.allCases.allSatisfy { (0...1).contains($0.volume) })
  }
}

@MainActor final class GameAudioPlaybackTests: XCTestCase {
  func testOneMusicPlayerSameThemeDoesNotRestartAndDifferentThemeSwitches() {
    var created: [MockAudioPlayer] = []
    let backend = AVGameAudioBackend(musicFactory: { _ in
      let player = MockAudioPlayer(); created.append(player); return player
    }, effectFactory: { _ in MockAudioPlayer() }, activateSession: {}, observeNotifications: false)
    backend.playMusic(.atmosphere)
    backend.playMusic(.atmosphere)
    XCTAssertEqual(created.count, 1)
    XCTAssertEqual(created[0].playCount, 1)
    XCTAssertEqual(created[0].loops, -1)
    backend.pauseMusic()
    backend.playMusic(.atmosphere)
    XCTAssertEqual(created.count, 1)
    XCTAssertEqual(created[0].playCount, 2)
    backend.playMusic(.lava)
    XCTAssertEqual(created.count, 2)
    XCTAssertEqual(created[0].stopCount, 1)
    XCTAssertFalse(created[0].isPlaying)
    backend.stopMusic()
    XCTAssertFalse(created[1].isPlaying)
  }
  func testSessionRuntimeInstallationKeepsAdjacentThemesAndStopsOnTerminal() throws {
    var players: [MockAudioPlayer] = []
    let backend = AVGameAudioBackend(musicFactory: { _ in
      let player = MockAudioPlayer(); players.append(player); return player
    }, effectFactory: { _ in MockAudioPlayer() }, activateSession: {}, observeNotifications: false)
    let factory = DefaultGameLevelRuntimeFactory()
    let configuration = GameConfiguration(reducedMotion: false, controlHintsEnabled: true)
    let session = GameSession(runtime: try factory.makeRuntime(levelID: .levelOne, configuration: configuration, seed: 1),
                              audioService: GameAudioService(backend: backend))
    session.initializeWorld(); session.start()
    for destination in [LevelID.levelTwo, .levelFour, .levelFive, .levelTen, .countryRoad, .heroWelcome] {
      session.simulation.onLevelTransition?(.init(sourceLevelID: session.levelID, destinationLevelID: destination,
        destinationEntry: .bottom, carryover: .init(characterID: EntityID(), health: 3, score: 0, completedLevelIDs: []),
        reason: .completedForward))
      session.installRuntime(try factory.makeRuntime(levelID: destination, configuration: configuration, seed: 1))
      session.runtimeSceneDidAttach(generation: session.runtimeGeneration, levelID: destination)
      let expectedCount: Int
      switch destination { case .levelTwo: expectedCount = 1; case .levelFour: expectedCount = 2
        case .levelFive: expectedCount = 3; case .levelTen: expectedCount = 4; default: expectedCount = 5 }
      XCTAssertEqual(players.count, expectedCount)
      XCTAssertEqual(players.filter(\.isPlaying).count, 1)
    }
    for _ in 0..<3 { session.pause(); session.resume() }
    XCTAssertEqual(players.count, 5)
    XCTAssertEqual(players.last?.playCount, 1)
    session.lose()
    XCTAssertTrue(players.allSatisfy { !$0.isPlaying })
    session.dispose()
  }

  func testConcurrentEffectsReuseFinishedPlayersAndHaveBoundedRetention() {
    var created: [MockAudioPlayer] = []
    let pool = GameSoundPlayerPool(factory: { _ in
      let player = MockAudioPlayer(); created.append(player); return player
    })
    pool.preload([.whip])
    XCTAssertEqual(pool.idleCount, 1)
    pool.play(.whip); pool.play(.whip)
    XCTAssertEqual(created.count, 2)
    XCTAssertEqual(pool.activeCount, 2)
    XCTAssertTrue(created.allSatisfy(\.isPlaying))
    created[0].finish(); created[1].finish()
    XCTAssertEqual(pool.activeCount, 0)
    XCTAssertEqual(pool.idleCount, 1)
    pool.play(.whip)
    XCTAssertEqual(created.count, 2)
    for _ in 0..<30 { pool.play(.coin) }
    XCTAssertEqual(pool.activeCount, GameSoundPlayerPool.maximumActive)
    pool.reset()
    XCTAssertEqual(pool.activeCount, 0)
    XCTAssertEqual(pool.idleCount, 0)
    XCTAssertTrue(created.allSatisfy { !$0.isPlaying })
  }
  func testSettingsLifecycleInterruptionsRouteAndResultsPolicyWithoutSpeakers() {
    let backend = RecordingAudioBackend()
    let service = GameAudioService(backend: backend)
    service.beginGameplay(levelID: .levelEight)
    XCTAssertEqual(backend.tracks.last, .atmosphere)
    var settings = GameSettings.defaults
    settings.musicEnabled = false
    service.updateSettings(settings)
    XCTAssertGreaterThan(backend.pauses, 0)
    service.handle(.coinCollected)
    XCTAssertEqual(backend.effects, [.coin])
    settings.musicEnabled = true; settings.soundEffectsEnabled = false
    service.updateSettings(settings)
    XCTAssertEqual(backend.tracks.last, .atmosphere)
    service.handle(.grappleFired)
    XCTAssertEqual(backend.effects, [.coin])
    settings.soundEffectsEnabled = true; service.updateSettings(settings)
    let pausesBeforeBackground = backend.pauses
    service.setApplicationActive(false)
    XCTAssertGreaterThan(backend.pauses, pausesBeforeBackground)
    service.handle(.coinCollected)
    XCTAssertEqual(backend.effects.count, 1)
    service.setApplicationActive(true)
    service.changeLevel(.levelTen)
    XCTAssertEqual(backend.tracks.last, .lava)
    backend.onEnvironmentEvent?(.interruptionBegan)
    service.handle(.playerStep)
    XCTAssertEqual(backend.effects.count, 1)
    let beforeResume = backend.tracks.count
    backend.onEnvironmentEvent?(.interruptionEnded(shouldResume: false))
    XCTAssertEqual(backend.tracks.count, beforeResume)
    settings.musicEnabled = false; service.updateSettings(settings)
    settings.musicEnabled = true; service.updateSettings(settings)
    XCTAssertEqual(backend.tracks.last, .lava)
    backend.onEnvironmentEvent?(.routeDisconnected)
    let beforeForeground = backend.tracks.count
    service.setApplicationActive(false); service.setApplicationActive(true)
    XCTAssertEqual(backend.tracks.count, beforeForeground, "Do not unexpectedly resume on speakers")
    service.beginGameplay(levelID: .heroWelcome)
    XCTAssertEqual(backend.tracks.last, .prettyMaiden)
    backend.onEnvironmentEvent?(.interruptionBegan)
    backend.onEnvironmentEvent?(.interruptionEnded(shouldResume: true))
    XCTAssertEqual(backend.tracks.last, .prettyMaiden)
    backend.onEnvironmentEvent?(.mediaServicesReset)
    service.endGameplay()
    let stopped = backend.tracks.count
    service.setApplicationActive(false); service.setApplicationActive(true)
    service.handle(.coinCollected)
    XCTAssertEqual(backend.tracks.count, stopped)
    XCTAssertEqual(backend.effects.count, 1)
  }
  func testActivationFailureCannotPreventGameplayOrCreatePlayers() throws {
    var created = 0
    let backend = AVGameAudioBackend(musicFactory: { _ in created += 1; return MockAudioPlayer() },
      effectFactory: { _ in created += 1; return MockAudioPlayer() },
      activateSession: { throw AudioTestError.expected }, observeNotifications: false)
    let service = GameAudioService(backend: backend)
    let session = GameSession(simulation: try LevelOneSimulation(entities: []), audioService: service)
    XCTAssertTrue(session.initializeWorld()); XCTAssertTrue(session.start())
    session.simulation.inputController.send(.fireHook)
    session.advance(by: 0.05)
    XCTAssertEqual(session.state, .running)
    XCTAssertEqual(created, 0)
    session.dispose()
  }
  func testPersistedSettingsPublisherImmediatelyUpdatesAudioPolicy() {
    let suite = "AudioTests-\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = SettingsStore(repository: UserDefaultsSettingsRepository(defaults: defaults))
    let backend = RecordingAudioBackend(), directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let router = AppRouter(progressionStore: ProgressionStore(repository: .init(fileURL: directory.appendingPathComponent("save.json"))),
                           audioService: GameAudioService(backend: backend))
    router.bindAudioSettings(settings)
    router.startNewGame()
    let pauses = backend.pauses
    settings.settings.musicEnabled = false
    XCTAssertGreaterThan(backend.pauses, pauses)
    settings.settings.musicEnabled = true
    XCTAssertEqual(backend.tracks.last, .atmosphere)
    router.returnToMenu()
    let stopped = backend.tracks.count
    router.applicationDidBecomeActive()
    XCTAssertEqual(backend.tracks.count, stopped)
  }
}

@MainActor final class GameAudioSimulationTests: XCTestCase {
  private func running(_ simulation: LevelOneSimulation) -> (GameSession, RecordingAudioBackend) {
    let backend = RecordingAudioBackend()
    let session = GameSession(simulation: simulation, audioService: GameAudioService(backend: backend))
    XCTAssertTrue(session.initializeWorld()); XCTAssertTrue(session.start())
    return (session, backend)
  }
  func testOnlyCommittedWalkingAndAcceptedGrappleEmitSounds() throws {
    let simulation = try LevelOneSimulation(entities: [])
    let (session, audio) = running(simulation)
    session.simulation.inputController.send(.move(.up)); session.advance(by: 0.05)
    XCTAssertEqual(audio.effects, [.walk])
    simulation.player.position = .init(row: 50, column: 4)
    simulation.attemptMove(.left)
    XCTAssertEqual(audio.effects, [.walk], "Blocked movement is silent")
    session.pause()
    simulation.fireHook() // Domain callback is gated by the session even if a fixture invokes it directly.
    XCTAssertEqual(audio.effects, [.walk])
    session.resume()
    simulation.player.hookshot = HookshotState()
    simulation.fireHook(); simulation.fireHook()
    XCTAssertEqual(audio.effects, [.walk, .whip])
    session.openDialogue("test")
    simulation.emit(.coinCollected(points: 10), at: simulation.player.position)
    XCTAssertEqual(audio.effects, [.walk, .whip])
  }
  func testHeldMovementProducesOneSoundPerStepAndPullingIsSilent() throws {
    let simulation = try LevelOneSimulation(entities: [])
    let (session, audio) = running(simulation)
    simulation.input.send(.beginMove(.right))
    for _ in 0..<4 { session.advance(by: 0.1) }
    XCTAssertEqual(audio.effects.filter { $0 == .walk }.count, simulation.player.position.column - 27)
    simulation.cancelAllInput()
    simulation.player.facing = .down
    simulation.fireHook()
    let walks = audio.effects.filter { $0 == .walk }.count
    XCTAssertGreaterThan(walks, 0)
    for _ in 0..<20 { session.advance(by: 0.1) }
    XCTAssertEqual(audio.effects.filter { $0 == .walk }.count, walks)
    XCTAssertGreaterThan(simulation.player.position.row, 50)
  }
  func testPickupsMinesAndChestUseAuthoritativeEventsOnce() throws {
    for (kind, health, expected) in [
      (EntityKind.coin, 3, [GameSoundEffect.coin]),
      (.cabbage, 3, [.crunch, .lidiaHealed]),
      (.cabbage, 6, [.crunch, .lidiaHealed]),
      (.mine, 3, [.explosion, .lidiaDamaged])
    ] {
      let simulation = try LevelOneSimulation(entities: [.init(id: EntityID(), kind: kind, position: .init(row: 49, column: 27))])
      let (session, audio) = running(simulation)
      simulation.player.health = health
      simulation.input.send(.move(.up)); session.advance(by: 0.05)
      XCTAssertEqual(audio.effects, [.walk] + expected)
      session.advance(by: 0.05)
      XCTAssertEqual(audio.effects, [.walk] + expected)
    }
    let simulation = try LevelOneSimulation(entities: [])
    let (session, audio) = running(simulation)
    simulation.player.position = simulation.level.chestAnchor
    simulation.player.health = 3
    simulation.activateChestAndExit()
    XCTAssertEqual(audio.effects, [.lidiaHealed])
    simulation.activateChestAndExit()
    XCTAssertEqual(audio.effects, [.lidiaHealed])
    XCTAssertNotNil(session.dialogue)
  }
  func testFullHealthChestHasNoFoodEffectOrHealVoice() throws {
    let simulation = try LevelOneSimulation(entities: [])
    let (session, audio) = running(simulation)
    simulation.player.health = 6
    simulation.player.position = simulation.level.chestAnchor
    simulation.activateChestAndExit()
    XCTAssertTrue(audio.effects.isEmpty)
    XCTAssertNotNil(session.dialogue)
  }

  func testLavaDamageCooldownDoesNotRepeatImpactOrVoice() throws {
    let simulation = try LevelOneSimulation(entities: [])
    let (session, audio) = running(simulation)
    simulation.player.position = .init(row: 23, column: 10)
    simulation.player.lastSafePosition = simulation.player.position
    simulation.attemptMove(.down)
    XCTAssertEqual(audio.effects, [.hit, .lidiaDamaged])
    simulation.attemptMove(.down)
    XCTAssertEqual(audio.effects, [.hit, .lidiaDamaged])
    XCTAssertEqual(session.health, 2)
  }

  func testHookMineAndEnemyDamageProduceNoDuplicateDefeatSound() throws {
    let mine = try LevelOneSimulation(entities: [.init(id: EntityID(), kind: .mine, position: .init(row: 50, column: 32))])
    let (session, audio) = running(mine)
    mine.player.facing = .right; mine.fireHook()
    for _ in 0..<3 { session.advance(by: 0.1) }
    XCTAssertEqual(audio.effects, [.whip, .explosion])
    for archetype in [EnemyArchetype.skeleton, .flyingTerror, .minotaur] {
      let simulation = try LevelOneSimulation(entities: [])
      simulation.enemies = [.init(id: EntityID(), archetype: archetype, position: .init(row: 50, column: 32),
        facing: .left, health: 1, maximumHealth: 1, behaviorState: .patrol, decisionAccumulator: 0, animationTime: 0)]
      let (enemySession, enemyAudio) = running(simulation)
      simulation.player.facing = .right; simulation.fireHook()
      for _ in 0..<3 { enemySession.advance(by: 0.1) }
      XCTAssertEqual(enemyAudio.effects, [.whip] + GameSoundEffect.forEvent(.enemyDamaged(archetype)))
    }
  }
  func testGhostWizardStrikePreservesSecondWhipAndVoiceWithoutInventedEnemyClip() throws {
    let simulation = try LevelTenSimulation()
    simulation.entities = []
    let (session, audio) = running(simulation)
    simulation.player.position = .init(row: 40, column: 40)
    simulation.fireHook()
    simulation.player.hookshot.head = try XCTUnwrap(simulation.boss).position
    session.advance(by: 0)
    XCTAssertEqual(audio.effects, [.whip, .whip, .lidiaAttack])
    XCTAssertEqual(simulation.boss?.health, 9)
    session.advance(by: 0)
    XCTAssertEqual(audio.effects, [.whip, .whip, .lidiaAttack])
  }

  func testProjectileImpactVoiceAndCooldownAndTerminalDamage() throws {
    let simulation = try LevelTenSimulation()
    simulation.entities = []
    let (session, audio) = running(simulation)
    simulation.fireProjectileForTesting(at: simulation.player.position, direction: .left)
    session.advance(by: 0.05)
    XCTAssertEqual(audio.effects, [.hit, .lidiaDamaged])
    simulation.fireProjectileForTesting(at: simulation.player.position, direction: .left)
    session.advance(by: 0.05)
    XCTAssertEqual(audio.effects, [.hit, .lidiaDamaged])
    simulation.player.damageCooldown = 0; simulation.player.health = 1
    simulation.fireProjectileForTesting(at: simulation.player.position, direction: .left)
    session.advance(by: 0.05)
    XCTAssertEqual(audio.effects, [.hit, .lidiaDamaged, .hit, .lidiaDamaged])
    XCTAssertEqual(session.state, .lost)
    let before = audio.effects
    session.advance(by: 0.1)
    XCTAssertEqual(audio.effects, before)
  }
}

@MainActor private final class RecordingAudioBackend: GameAudioBackend {
  var onEnvironmentEvent: ((GameAudioEnvironmentEvent) -> Void)?
  var tracks: [GameMusicTrack] = []
  var effects: [GameSoundEffect] = []
  var pauses = 0, stops = 0, effectStops = 0
  func playMusic(_ track: GameMusicTrack) { tracks.append(track) }
  func pauseMusic() { pauses += 1 }
  func stopMusic() { stops += 1 }
  func playEffect(_ effect: GameSoundEffect) { effects.append(effect) }
  func stopEffects() { effectStops += 1 }
}
@MainActor private final class MockAudioPlayer: GameAudioPlaying {
  var volume: Float = 0
  var loops = 0
  var onCompletion: (() -> Void)?
  var isPlaying = false
  var playCount = 0, stopCount = 0
  func prepare() -> Bool { true }
  func play() -> Bool { playCount += 1; isPlaying = true; return true }
  func pause() { isPlaying = false }
  func stop() { stopCount += 1; isPlaying = false }
  func finish() { isPlaying = false; onCompletion?() }
}
private enum AudioTestError: Error { case expected }
