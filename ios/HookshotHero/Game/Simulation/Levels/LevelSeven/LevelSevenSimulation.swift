import Foundation

@MainActor final class LevelSevenSimulation: LevelOneSimulation {
  /// The complete 5 x 5 footprint is in bounds, wall-safe, and separated from starts,
  /// doors, chests, and the other enemy. Lava overlap is permitted for Java parity.
  static let skeletonStart = GridPosition(row: 10, column: 40)

  override var levelID: LevelID { .levelSeven }
  override var levelName: String { "Level 7" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 7, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let levelDefinition = LevelSevenDefinition.make()
    let presentationDefinition = LevelSevenPresentationDefinition.make(from: levelDefinition)
    let start: GridPosition =
      switch entryPosition {
      case .bottom: LevelSevenDefinition.bottomStart
      case .top: LevelSevenDefinition.topStart
      case .left, .right: throw GameLoadingError.invalidInitialState(.levelSeven)
      }
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      levelDefinition: levelDefinition, presentationDefinition: presentationDefinition,
      initialPlayerPosition: start, entities: [])
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
        id: EntityID(), archetype: .skeleton, position: Self.skeletonStart, facing: .down,
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
    let enemyRegions = enemies.map { $0.archetype.footprint.region(at: $0.position) }
    let protectedLevelRegions = [
      level.entryRegion, level.exitRegion,
      CollisionProfile.chest.region(at: chestStates[0].definition.interactionAnchor),
      CollisionProfile.chest.region(at: chestStates[1].definition.interactionAnchor),
    ]
    guard !enemyRegions[0].intersects(enemyRegions[1]),
      enemyRegions.allSatisfy({ region in
        !protectedLevelRegions.contains(where: region.intersects)
      })
    else {
      throw GameLoadingError.invalidInitialState(.levelSeven)
    }
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
        CollisionProfile.player.region(at: LevelSevenDefinition.bottomStart),
        CollisionProfile.player.region(at: LevelSevenDefinition.topStart), level.exitRegion,
        level.entryRegion,
      ] + chestRegions + enemies.map { $0.archetype.footprint.region(at: $0.position) }, using: &rng
    )
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
      if !completedLevelIDs.contains(.levelSeven) {
        player.score += 100
        completedLevelIDs.insert(.levelSeven)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelSeven, destinationLevelID: .levelEight,
          destinationEntry: .bottom, carryover: makeCarryoverState(),
          reason: .completedForward))
    }
  }
}
