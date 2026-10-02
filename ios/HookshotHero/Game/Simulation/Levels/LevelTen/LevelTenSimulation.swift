import Foundation

struct GhostProjectileState: Identifiable, Equatable, Sendable {
  let id: EntityID
  var position: GridPosition
  let direction: GridDirection
  var stepAccumulator: TimeInterval
}

@MainActor final class LevelTenSimulation: LevelOneSimulation {
  private(set) var boss: EnemyState?
  private(set) var projectiles: [GhostProjectileState] = []
  private var bossHitByCurrentHook = false
  private var projectileAccumulator: TimeInterval = 0
  private var requiresEndingExitDeparture = false
  private var didRequestEndingTransition = false

  override var levelID: LevelID { .levelTen }
  override var levelName: String { "Level 10" }
  var isExitUnlocked: Bool { boss == nil }

  override var renderSnapshot: GameRenderSnapshot {
    let base = super.renderSnapshot
    let bossRender = boss.map { boss in
      RenderEntitySnapshot(
        id: boss.id, asset: LevelTenRenderAssets.ghostWizard,
        coordinate: boss.position, renderSize: boss.archetype.renderSize, anchor: .center,
        zPosition: 7, orientation: RenderOrientation(rawValue: boss.facing.rawValue) ?? .right,
        animation: .init(
          animationID: LevelTenRenderAnimations.ghostWizard(
            RenderOrientation(rawValue: boss.facing.rawValue) ?? .right),
          frameIndex: configuration.reducedMotion
            ? 0 : Int(boss.animationTime / 0.12) % LevelTenRenderAnimations.frameCount),
        opacity: 1, isHidden: false,
        health: .init(current: boss.health, maximum: boss.maximumHealth))
    }
    let shots = projectiles.map { shot in
      RenderEntitySnapshot(
        id: shot.id, asset: LevelTenRenderAssets.projectile,
        coordinate: shot.position, renderSize: .init(width: 1.2, height: 1.2), anchor: .center,
        zPosition: 7.5, orientation: .none, animation: nil, opacity: 1, isHidden: false)
    }
    return .init(
      player: base.player,
      entities: base.entities + (bossRender.map { [$0] } ?? []) + shots,
      grapple: base.grapple, effects: base.effects)
  }

  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 10, entryPosition: LevelEntryPosition = .right,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    guard entryPosition == .right || entryPosition == .bottom else {
      throw GameLoadingError.invalidInitialState(.levelTen)
    }
    let definition = LevelTenDefinition.make()
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition,
      carryover: carryover, levelDefinition: definition,
      presentationDefinition: LevelTenPresentationDefinition.make(from: definition),
      initialPlayerPosition: LevelTenDefinition.rightStart, entities: [])
    if !worldState.defeatedBossLevelIDs.contains(.levelTen) {
      boss = .init(
        id: EntityID(), archetype: .ghostWizard, position: LevelTenDefinition.bossStart,
        facing: .right, health: 10, maximumHealth: 10, behaviorState: .seek,
        decisionAccumulator: 0, animationTime: 0)
    }
    try EnemyInitialStateValidator.validate(
      boss.map { [$0] } ?? [], in: level, entryPositions: [LevelTenDefinition.rightStart],
      levelID: levelID)
    configureDefeatChest()

    // Match the standard Java single-player population while keeping every persistent or
    // phase-dependent Level 10 interaction clear. In particular, reserve the defeat chest even
    // while it is hidden so the same seeded population remains valid before and after the boss.
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0xAA)
    let bossRegion = EnemyArchetype.ghostWizard.footprint.region(at: LevelTenDefinition.bossStart)
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: [
        CollisionProfile.player.region(at: LevelTenDefinition.rightStart),
        LevelTenDefinition.rightDoorRegion, LevelTenDefinition.endingExitRegion,
        CollisionProfile.chest.region(at: LevelTenDefinition.chestAnchor),
        LevelTenDefinition.chestRenderRegion,
        bossRegion,
      ], using: &rng)
  }

  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateBoss(min(max(deltaTime, 0), 0.1))
    updateProjectiles(min(max(deltaTime, 0), 0.1))
    checkDoors()
  }

  /// Creates a deterministic shot for collision tests; production shots use the same state path.
  func fireProjectileForTesting(at position: GridPosition, direction: GridDirection) {
    projectiles.append(
      .init(
        id: EntityID(), position: position, direction: direction,
        stepAccumulator: 0))
  }

  /// Deterministic defeat fixture used by transition tests without weakening release gameplay.
  func defeatBossForTesting() {
    guard let defeated = boss else { return }
    finalizeBossDefeat(at: defeated.position)
  }

  private func finalizeBossDefeat(at position: GridPosition) {
    worldState.defeatedBossLevelIDs.insert(.levelTen)
    boss = nil
    projectiles = []
    requiresEndingExitDeparture = CollisionProfile.player.region(at: player.position).intersects(
      LevelTenDefinition.endingExitRegion)
    let id = emit(.enemyDefeated(archetype: .ghostWizard), at: position)
    effectEvents.append(
      .init(
        id: id, coordinate: position,
        descriptor: .enemyDefeat(reducedMotion: configuration.reducedMotion),
        createdAt: simulationTime))
    configureDefeatChest()
  }

  private func configureDefeatChest() {
    guard worldState.defeatedBossLevelIDs.contains(.levelTen) else {
      chestStates = []
      return
    }
    chestStates = [
      .init(
        definition: .init(
          id: EntityID(), interactionAnchor: LevelTenDefinition.chestAnchor,
          renderAnchor: LevelTenDefinition.chestAnchor,
          closedAsset: LevelTenRenderAssets.specialChest,
          openedAsset: LevelOneRenderAssets.chestOpen, renderSize: .init(width: 2.5, height: 2.5),
          renderAnchorPoint: .center, message: "The Ghost Wizard's treasure is yours.",
          scoreReward: 100, healthReward: 2), isOpened: false)
    ]
    restoreOpenedChestStates()
  }

  private func updateBoss(_ dt: TimeInterval) {
    guard var current = boss else { return }
    current.animationTime += dt
    current.decisionAccumulator += dt
    if current.decisionAccumulator >= 0.15 {
      current.decisionAccumulator = 0
      if let direction = GridDirection.allCases.filter({ d in
        let r = current.archetype.footprint.region(at: current.position.moved(d))
        return r.cells.allSatisfy(level.isInside) && !level.walls.contains(where: r.intersects)
      }).min(by: { distance(current.position.moved($0)) < distance(current.position.moved($1)) }) {
        current.facing = direction
        current.position = current.position.moved(direction)
      }
    }
    projectileAccumulator += dt
    if distance(current.position) <= current.archetype.sight && projectileAccumulator >= 3 {
      projectileAccumulator = 0
      projectiles.append(
        .init(
          id: EntityID(), position: current.position,
          direction: dominantDirection(from: current.position, to: player.position),
          stepAccumulator: 0))
    }
    if current.archetype.footprint.region(at: current.position).intersects(
      CollisionProfile.player.region(at: player.position))
    {
      damagePlayerFromGhost()
    }
    if let head = player.hookshot.head, player.hookshot.phase == .extending,
      !bossHitByCurrentHook,
      current.archetype.footprint.region(at: current.position).intersects(
        CollisionProfile.hookHead.region(at: head))
    {
      bossHitByCurrentHook = true
      current.health -= 1
      player.score += 10
      emit(
        .enemyHit(archetype: .ghostWizard, points: 10, remainingHealth: max(0, current.health)),
        at: current.position)
      player.hookshot.phase = .retracting
      if current.health <= 0 {
        finalizeBossDefeat(at: current.position)
      } else {
        boss = current
      }
    } else {
      if player.hookshot.phase == .idle { bossHitByCurrentHook = false }
      boss = current
    }
  }

  private func updateProjectiles(_ dt: TimeInterval) {
    for i in projectiles.indices { projectiles[i].stepAccumulator += dt }
    for i in projectiles.indices where projectiles[i].stepAccumulator >= 0.12 {
      projectiles[i].stepAccumulator = 0
      projectiles[i].position = projectiles[i].position.moved(projectiles[i].direction)
    }
    let playerRegion = CollisionProfile.player.region(at: player.position)
    let hits = Set(
      projectiles.filter {
        CollisionProfile.hookHead.region(at: $0.position).intersects(playerRegion)
      }.map(\.id))
    if !hits.isEmpty {
      projectiles.removeAll { hits.contains($0.id) }
      damagePlayerFromGhost()
    }
    projectiles.removeAll { !level.isInside($0.position) || level.isWall($0.position) }
  }

  private func checkDoors() {
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(LevelTenDefinition.rightDoorRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelTen, destinationLevelID: .levelNine,
          destinationEntry: .left, carryover: makeCarryoverState(), reason: .returnedBackward))
    } else if isExitUnlocked, requiresEndingExitDeparture {
      if !region.intersects(LevelTenDefinition.endingExitRegion) {
        requiresEndingExitDeparture = false
      }
    } else if region.intersects(LevelTenDefinition.endingExitRegion), isExitUnlocked,
      !didRequestEndingTransition
    {
      didRequestEndingTransition = true
      if !completedLevelIDs.contains(.levelTen) {
        player.score += 100
        completedLevelIDs.insert(.levelTen)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelTen, destinationLevelID: .countryRoad,
          destinationEntry: .bottom, carryover: makeCarryoverState(),
          reason: .completedForward))
    }
  }
  private func damagePlayerFromGhost() {
    guard player.damageCooldown <= 0 else { return }
    player.health -= 1
    player.damageCooldown = 0.75
    emit(.healthLost(amount: 1, source: .enemy(.ghostWizard)), at: player.position)
    checkLoss()
  }
  private func distance(_ p: GridPosition) -> Double {
    hypot(Double(p.row - player.position.row), Double(p.column - player.position.column))
  }
  private func dominantDirection(from: GridPosition, to: GridPosition) -> GridDirection {
    abs(to.column - from.column) >= abs(to.row - from.row)
      ? (to.column < from.column ? .left : .right) : (to.row < from.row ? .up : .down)
  }
}
