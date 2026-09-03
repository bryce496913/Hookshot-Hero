import Foundation

@MainActor final class LevelSevenSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelSeven }
  override var levelName: String { "Level 7" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 7, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let start: GridPosition =
      switch entryPosition {
      case .bottom: LevelSevenDefinition.bottomStart
      case .top: LevelSevenDefinition.topStart
      case .left, .right: throw GameLoadingError.invalidInitialState(.levelSeven)
      }
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: start, entities: [])
    level = LevelSevenDefinition.make()
    presentationDefinition = LevelSevenPresentationDefinition.make(from: level)
    chestStates = [
      .init(
        definition: .init(
          id: EntityID(), interactionAnchor: .init(row: 4, column: 4),
          renderAnchor: .init(row: 4, column: 4), closedAsset: LevelSevenRenderAssets.chestSide,
          openedAsset: LevelSevenRenderAssets.chestSide, renderSize: .init(width: 4, height: 4),
          renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100, healthReward: 2
        ), isOpened: false),
      .init(
        definition: .init(
          id: EntityID(), interactionAnchor: .init(row: 52, column: 4),
          renderAnchor: .init(row: 52, column: 4), closedAsset: LevelSevenRenderAssets.chestBack,
          openedAsset: LevelSevenRenderAssets.chestBack, renderSize: .init(width: 4, height: 4),
          renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100, healthReward: 2
        ), isOpened: false),
    ]
    restoreOpenedChestStates()
    // Java's exit-derived spawns overlap. These deterministic anchors separate both enemies and leave the exit clear.
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 10, column: 40), facing: .down,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 8, column: 50),
        facing: .left, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [
      LevelSevenDefinition.bottomStart, LevelSevenDefinition.topStart,
    ])
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x77)
    let chestRegions = chestStates.flatMap {
      [
        CollisionProfile.chest.region(at: $0.definition.interactionAnchor),
        $0.definition.spawnExclusionRegion,
      ]
    }
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: [
        CollisionProfile.player.region(at: player.position),
        CollisionProfile.player.region(at: LevelSevenDefinition.topStart), level.exitRegion,
        level.entryRegion,
      ] + chestRegions + enemies.map { $0.archetype.footprint.region(at: $0.position) }, using: &rng
    )
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
          sourceLevelID: .levelSeven, destinationLevelID: .levelFive, destinationEntry: .top,
          carryover: makeCarryoverState(), reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      // Java continues to Level 8; until that level exists this is the current-content boundary.
      if !completedLevelIDs.contains(.levelSeven) {
        player.score += 100
        completedLevelIDs.insert(.levelSeven)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      setOutcome(.won)
    }
  }
}
