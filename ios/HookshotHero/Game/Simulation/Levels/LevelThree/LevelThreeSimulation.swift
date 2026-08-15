import Foundation

@MainActor final class LevelThreeSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelThree }
  override var levelName: String { "Level 3" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 3, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: entryPosition == .top ? .init(row: 5, column: 29) : .init(row: 50, column: 29),
      entities: [])
    level = LevelThreeDefinition.make()
    presentationDefinition = LevelThreePresentationDefinition.make(from: level)
    chestStates = [Self.standardChest(at: level.chestAnchor, message: "You made it!")]
    restoreOpenedChestStates()
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 16, column: 29), facing: .right,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 18, column: 42),
        facing: .left, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [
      .init(row: 5, column: 29), .init(row: 50, column: 29),
    ])
    try validateInitialPlayerFootprint()
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0x33)
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: enemies.map { $0.archetype.footprint.region(at: $0.position) } + [
        .init(rows: 9..<13, columns: 5..<9), .init(rows: 56..<60, columns: 20..<24),
        .init(rows: 42..<46, columns: 49..<53),
      ], using: &rng)
  }
  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateEnemySystem(deltaTime)
    checkDoors()
  }
  private func checkDoors() {
    let region = CollisionProfile.player.region(at: player.position)
    if region.intersects(level.entryRegion) {
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelThree, destinationLevelID: .levelTwo, destinationEntry: .top,
          carryover: makeCarryoverState(),
          reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      if !completedLevelIDs.contains(.levelThree) {
        player.score += 100
        completedLevelIDs.insert(.levelThree)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelThree, destinationLevelID: .levelFour, destinationEntry: .bottom,
          carryover: makeCarryoverState()))
    }
  }
}
