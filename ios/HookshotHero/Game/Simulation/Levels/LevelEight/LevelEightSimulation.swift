import Foundation

@MainActor final class LevelEightSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelEight }
  override var levelName: String { "Level 8" }

  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 8, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let start: GridPosition =
      switch entryPosition {
      case .left: LevelEightDefinition.fromLevelSixStart
      case .bottom: LevelEightDefinition.fromLevelSevenStart
      case .top: LevelEightDefinition.topReturnStart
      case .right: throw GameLoadingError.invalidInitialState(.levelEight)
      }
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: start, entities: [])
    level = LevelEightDefinition.make()
    presentationDefinition = LevelEightPresentationDefinition.make(from: level)

    // The exit-derived Java anchors collide with this level's dense upper-right geometry.
    // These are the closest separated footprint-safe anchors in the connected open areas.
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 50, column: 33), facing: .up,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 11, column: 19),
        facing: .right, health: 5, maximumHealth: 5, behaviorState: .patrol,
        decisionAccumulator: 0, animationTime: 0),
    ]
    let starts = [
      LevelEightDefinition.fromLevelSixStart, LevelEightDefinition.fromLevelSevenStart,
      LevelEightDefinition.topReturnStart,
    ]
    try validateEnemyFootprints(entryPositions: starts)
    let enemyRegions = enemies.map { $0.archetype.footprint.region(at: $0.position) }
    let doorRegions = [
      LevelEightDefinition.topDoorRegion, LevelEightDefinition.leftDoorRegion,
      LevelEightDefinition.bottomDoorRegion,
    ]
    guard !enemyRegions[0].intersects(enemyRegions[1]),
      enemyRegions.allSatisfy({ region in
        !level.isBlocked(region) && !level.overlapsLava(region)
          && !doorRegions.contains(where: region.intersects)
      })
    else { throw GameLoadingError.invalidInitialState(.levelEight) }

    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x88)
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: starts.map { CollisionProfile.player.region(at: $0) }
        + doorRegions + enemyRegions,
      using: &rng)
    try validateInitialPlayerFootprint()
  }

  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateEnemySystem(deltaTime)
    let playerRegion = CollisionProfile.player.region(at: player.position)
    if playerRegion.intersects(LevelEightDefinition.leftDoorRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelEight, destinationLevelID: .levelSix, destinationEntry: .top,
          carryover: makeCarryoverState(), reason: .returnedBackward))
      return
    }
    if playerRegion.intersects(LevelEightDefinition.bottomDoorRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelEight, destinationLevelID: .levelSeven, destinationEntry: .top,
          carryover: makeCarryoverState(), reason: .returnedBackward))
      return
    }
    guard playerRegion.intersects(LevelEightDefinition.topDoorRegion) else { return }
    if !completedLevelIDs.contains(.levelEight) {
      player.score += 100
      completedLevelIDs.insert(.levelEight)
      emit(.levelCompleted(points: 100), at: player.position)
    }
    setOutcome(.won)
  }
}
