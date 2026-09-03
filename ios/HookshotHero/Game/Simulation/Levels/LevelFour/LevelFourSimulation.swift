import Foundation

@MainActor final class LevelFourSimulation: LevelOneSimulation {
  private var boss: EnemyState?
  private var bossHitByCurrentHook = false
  override var levelID: LevelID { .levelFour }
  override var levelName: String { "Level 4" }
  override var renderSnapshot: GameRenderSnapshot {
    let s = super.renderSnapshot
    let bossRender = boss.map { b in
      let orientation = RenderOrientation(rawValue: b.facing.rawValue) ?? .right
      return RenderEntitySnapshot(
        id: b.id, asset: b.archetype.asset, coordinate: b.position,
        renderSize: b.archetype.renderSize, anchor: .center, zPosition: 7, orientation: orientation,
        animation: .init(
          animationID: LevelFourRenderAnimations.minotaur(orientation),
          frameIndex: configuration.reducedMotion ? 0 : Int(b.animationTime / 0.12) % 3),
        opacity: 1, isHidden: false, health: .init(current: b.health, maximum: b.maximumHealth))
    }
    let open = boss == nil
    let doors = [
      RenderEntitySnapshot(
        id: EntityID(UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 1))),
        asset: open ? LevelFourRenderAssets.doorOpen : LevelFourRenderAssets.doorClosed,
        coordinate: .init(row: 0, column: 28), renderSize: .init(width: 4, height: 4),
        anchor: .bottomLeft, zPosition: 3, orientation: .none, animation: nil, opacity: 1,
        isHidden: false),
      RenderEntitySnapshot(
        id: EntityID(UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2))),
        asset: open ? LevelFourRenderAssets.doorOpenSide : LevelFourRenderAssets.doorClosedRight,
        coordinate: .init(row: 28, column: 56), renderSize: .init(width: 4, height: 4),
        anchor: .bottomLeft, zPosition: 3, orientation: .none, animation: nil, opacity: 1,
        isHidden: false),
    ]
    return .init(
      player: s.player, entities: s.entities + doors + (bossRender.map { [$0] } ?? []),
      grapple: s.grapple, effects: s.effects)
  }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 4, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    boss = .init(
      id: EntityID(), archetype: .minotaur, position: .init(row: 25, column: 25), facing: .right,
      health: 10, maximumHealth: 10, behaviorState: .seek, decisionAccumulator: 0, animationTime: 0)
    let start: GridPosition =
      switch entryPosition {
      case .top: .init(row: 5, column: 27)
      case .right: .init(row: 29, column: 52)
      case .bottom: .init(row: 50, column: 27)
      case .left: throw GameLoadingError.invalidInitialState(.levelFour)
      }
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: start, entities: [])
    if completedLevelIDs.contains(.levelFour) { boss = nil }
    level = LevelFourDefinition.make()
    presentationDefinition = LevelFourPresentationDefinition.make(from: level)
    chestStates = []
    try validateInitialPlayerFootprint()
  }
  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    updateBoss(deltaTime)
    checkLevelFourDoors()
  }
  private func updateBoss(_ dt: TimeInterval) {
    guard var b = boss, outcome == nil else { return }
    b.animationTime += dt
    b.decisionAccumulator += dt
    if b.decisionAccumulator >= b.archetype.seekInterval {
      b.decisionAccumulator = 0
      let dirs = GridDirection.allCases
      if let best = dirs.filter({ dir in
        let region = b.archetype.footprint.region(at: b.position.moved(dir))
        return region.cells.allSatisfy(level.isInside)
          && !level.walls.contains { $0.intersects(region) }
      }).min(by: { a, c in
        hypot(
          Double(b.position.moved(a).row - player.position.row),
          Double(b.position.moved(a).column - player.position.column))
          < hypot(
            Double(b.position.moved(c).row - player.position.row),
            Double(b.position.moved(c).column - player.position.column))
      }) {
        b.facing = best
        b.position = b.position.moved(best)
      }
    }
    boss = b
    if b.archetype.footprint.region(at: b.position).intersects(
      CollisionProfile.player.region(at: player.position))
    {
      guard player.damageCooldown <= 0 else { return }
      player.health -= 1
      player.damageCooldown = 0.75
      emit(.healthLost(amount: 1, source: .enemy(.minotaur)), at: player.position)
      checkLoss()
    }
    guard let head = player.hookshot.head, player.hookshot.phase == .extending else {
      if player.hookshot.phase == .idle { bossHitByCurrentHook = false }
      return
    }
    if !bossHitByCurrentHook
      && b.archetype.footprint.region(at: b.position).intersects(
        CollisionProfile.hookHead.region(at: head))
    {
      bossHitByCurrentHook = true
      b.health -= 1
      player.score += 10
      emit(
        .enemyHit(archetype: .minotaur, points: 10, remainingHealth: max(0, b.health)),
        at: b.position)
      player.hookshot.phase = .retracting
      if b.health <= 0 {
        let id = emit(.enemyDefeated(archetype: .minotaur), at: b.position)
        effectEvents.append(
          .init(
            id: id, coordinate: b.position,
            descriptor: .enemyDefeat(reducedMotion: configuration.reducedMotion),
            createdAt: simulationTime))
        boss = nil
      } else {
        boss = b
      }
    }
  }
  private func checkLevelFourDoors() {
    guard outcome == nil else { return }
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(level.entryRegion) {
      cancelAllInput()
      onLevelTransition?(
        LevelTransitionRequest(
          sourceLevelID: .levelFour, destinationLevelID: .levelThree, destinationEntry: .top,
          carryover: makeCarryoverState(), reason: .returnedBackward))
    } else if boss == nil
      && (region.intersects(level.exitRegion)
        || region.intersects(LevelFourDefinition.rightExitRegion))
    {
      if !completedLevelIDs.contains(.levelFour) {
        player.score += 100
        completedLevelIDs.insert(.levelFour)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      if region.intersects(LevelFourDefinition.rightExitRegion) {
        cancelAllInput()
        onLevelTransition?(
          LevelTransitionRequest(
            sourceLevelID: .levelFour, destinationLevelID: .levelFive, destinationEntry: .bottom,
            carryover: makeCarryoverState()))
      } else {
        cancelAllInput()
        onLevelTransition?(
          LevelTransitionRequest(
            sourceLevelID: .levelFour, destinationLevelID: .levelSix, destinationEntry: .bottom,
            carryover: makeCarryoverState()))
      }
    }
  }
}

// Java LevelFive uses 40-pixel environment tiles on a 600-pixel board. Native gameplay keeps
// the established 60-cell logical grid, so every Java pixel anchor is divided by ten here.
