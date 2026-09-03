import Foundation

@MainActor final class LevelFiveSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelFive }
  override var levelName: String { "Level 5" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 5, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let start: GridPosition =
      switch entryPosition {
      // `.bottom` remains only as the generic direct DEBUG/test launch entry. Production
      // progression from Level 4 enters through Level 5's left-side doorway.
      case .bottom, .left: .init(row: 8, column: 7)
      case .top: .init(row: 5, column: 29)
      case .right: throw GameLoadingError.invalidInitialState(.levelFive)
      }
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: start, entities: [])
    level = LevelFiveDefinition.make()
    presentationDefinition = LevelFivePresentationDefinition.make(from: level)
    chestStates = [
      .init(
        definition: .init(
          id: EntityID(), interactionAnchor: .init(row: 52, column: 4),
          renderAnchor: .init(row: 52, column: 8), closedAsset: LevelFiveRenderAssets.chest,
          openedAsset: LevelFiveRenderAssets.chest, renderSize: .init(width: 4, height: 4),
          renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100,
          healthReward: 2), isOpened: false)
    ]
    restoreOpenedChestStates()
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 28, column: 20), facing: .down,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 10, column: 40),
        facing: .left, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [
      .init(row: 5, column: 29), .init(row: 8, column: 7),
    ])
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x55)
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: [
        CollisionProfile.player.region(at: player.position),
        CollisionProfile.chest.region(at: level.chestAnchor),
        chestStates[0].definition.spawnExclusionRegion,
      ] + enemies.map { $0.archetype.footprint.region(at: $0.position) }, using: &rng)
    try validateInitialPlayerFootprint()
  }
  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateEnemySystem(deltaTime)
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(level.entryRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelFive, destinationLevelID: .levelFour, destinationEntry: .right,
          carryover: makeCarryoverState(),
          reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      if !completedLevelIDs.contains(.levelFive) {
        player.score += 100
        completedLevelIDs.insert(.levelFive)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelFive, destinationLevelID: .levelSeven,
          destinationEntry: .bottom, carryover: makeCarryoverState(),
          reason: .completedForward))
    }
  }
}

// Java LevelSix uses the same 40-pixel environment tiles as LevelFive. Map design is retained,
// while the two enemies are separated from Java's overlapping top-exit spawn.
