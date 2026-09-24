import Foundation

@MainActor final class LevelNineSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelNine }
  override var levelName: String { "Level 9" }

  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 9, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    guard entryPosition == .bottom || entryPosition == .left else {
      throw GameLoadingError.invalidInitialState(.levelNine)
    }
    let definition = LevelNineDefinition.make()
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      levelDefinition: definition,
      presentationDefinition: LevelNinePresentationDefinition.make(from: definition),
      initialPlayerPosition: entryPosition == .left
        ? LevelNineDefinition.leftStart : LevelNineDefinition.bottomStart, entities: [])
    chestStates = [
      .init(
        definition: .init(
          id: EntityID(), interactionAnchor: LevelNineDefinition.chestAnchor,
          renderAnchor: LevelNineDefinition.chestAnchor,
          closedAsset: LevelNineRenderAssets.chestSide,
          openedAsset: LevelNineRenderAssets.chestSide, renderSize: .init(width: 4, height: 4),
          renderAnchorPoint: .bottomLeft, message: "You made it!", scoreReward: 100, healthReward: 2
        ), isOpened: false)
    ]
    restoreOpenedChestStates()
    // Java's single-player builder places both enemies at NextLevels[0].Exit (7,1).
    // Separate native footprints keep that doorway reachable while retaining both archetypes.
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 9, column: 9), facing: .right,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 13, column: 16),
        facing: .left, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [
      LevelNineDefinition.bottomStart, LevelNineDefinition.leftStart,
    ])
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x99)
    let protected =
      [
        CollisionProfile.player.region(at: player.position), LevelNineDefinition.forwardDoorRegion,
        LevelNineDefinition.bottomDoorRegion,
      ]
      + chestStates.flatMap {
        [
          CollisionProfile.chest.region(at: $0.definition.interactionAnchor),
          $0.definition.spawnExclusionRegion,
        ]
      }
      + enemies.map { $0.archetype.footprint.region(at: $0.position) }
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ], protectedRegions: protected, using: &rng)
  }

  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateEnemySystem(deltaTime)
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(LevelNineDefinition.bottomDoorRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelNine, destinationLevelID: .levelEight,
          destinationEntry: .top, carryover: makeCarryoverState(), reason: .returnedBackward))
    } else if region.intersects(LevelNineDefinition.forwardDoorRegion) {
      if !completedLevelIDs.contains(.levelNine) {
        player.score += 100
        completedLevelIDs.insert(.levelNine)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelNine, destinationLevelID: .levelTen,
          destinationEntry: .right, carryover: makeCarryoverState(), reason: .completedForward))
    }
  }
}
