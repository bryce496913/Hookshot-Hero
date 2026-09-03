import Foundation

@MainActor final class LevelSixSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelSix }
  override var levelName: String { "Level 6" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 6, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let start: GridPosition =
      switch entryPosition {
      case .bottom: LevelSixDefinition.bottomStart
      case .top: LevelSixDefinition.topStart
      case .left, .right: throw GameLoadingError.invalidInitialState(.levelSix)
      }
    try super.init(configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover, startOverride: start, entities: [])
    level = LevelSixDefinition.make()
    presentationDefinition = LevelSixPresentationDefinition.make(from: level)
    chestStates = [
      .init(definition: .init(id: EntityID(), interactionAnchor: .init(row: 4, column: 24), renderAnchor: .init(row: 4, column: 24), closedAsset: LevelSixRenderAssets.chestSide, openedAsset: LevelSixRenderAssets.chestSide, renderSize: .init(width: 4, height: 4), renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100, healthReward: 2), isOpened: false),
      .init(definition: .init(id: EntityID(), interactionAnchor: .init(row: 44, column: 8), renderAnchor: .init(row: 44, column: 8), closedAsset: LevelSixRenderAssets.chestFront, openedAsset: LevelSixRenderAssets.chestFront, renderSize: .init(width: 4, height: 4), renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100, healthReward: 2), isOpened: false),
    ]
    restoreOpenedChestStates()
    enemies = [
      .init(id: EntityID(), archetype: .skeleton, position: .init(row: 22, column: 53), facing: .left, health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0, animationTime: 0),
      .init(id: EntityID(), archetype: .flyingTerror, position: .init(row: 10, column: 52), facing: .left, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0, animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [LevelSixDefinition.bottomStart, LevelSixDefinition.topStart])
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x66)
    let chestRegions = chestStates.flatMap {
      [CollisionProfile.chest.region(at: $0.definition.interactionAnchor),
        $0.definition.spawnExclusionRegion]
    }
    entities = try SpawnService.spawn(in: level, requirements: [.init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2), .init(kind: .coin, count: 10)], protectedRegions: [CollisionProfile.player.region(at: player.position)] + chestRegions + enemies.map { $0.archetype.footprint.region(at: $0.position) }, using: &rng)
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
          sourceLevelID: .levelSix, destinationLevelID: .levelFour, destinationEntry: .top,
          carryover: makeCarryoverState(), reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      if !completedLevelIDs.contains(.levelSix) {
        player.score += 100
        completedLevelIDs.insert(.levelSix)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelSix, destinationLevelID: .levelEight, destinationEntry: .left,
          carryover: makeCarryoverState(), reason: .completedForward))
    }
  }
}
