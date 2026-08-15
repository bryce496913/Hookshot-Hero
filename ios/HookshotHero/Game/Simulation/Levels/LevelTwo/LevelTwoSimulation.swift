import Foundation

@MainActor final class LevelTwoSimulation: LevelOneSimulation {
  override var levelID: LevelID { .levelTwo }
  override var levelName: String { "Level 2" }
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 2, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    let streams = LevelRandomStreams(seed: seed)
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      startOverride: entryPosition == .top ? .init(row: 5, column: 27) : .init(row: 50, column: 27),
      entities: [])
    level = LevelTwoDefinition.make()
    presentationDefinition = LevelTwoPresentationDefinition.make(from: level)
    chestStates = []
    enemies = [
      .init(
        id: EntityID(), archetype: .skeleton, position: .init(row: 6, column: 23), facing: .right,
        health: 3, maximumHealth: 3, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
      .init(
        id: EntityID(), archetype: .flyingTerror, position: .init(row: 5, column: 33),
        facing: .right, health: 5, maximumHealth: 5, behaviorState: .patrol, decisionAccumulator: 0,
        animationTime: 0),
    ]
    try validateEnemyFootprints(entryPositions: [
      .init(row: 5, column: 27), .init(row: 50, column: 27),
    ])
    try validateInitialPlayerFootprint()
    var rng = streams.itemSpawn
    entities = try SpawnService.spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ],
      protectedRegions: enemies.map { $0.archetype.footprint.region(at: $0.position) } + [
        .init(rows: 39..<43, columns: 5..<9), .init(rows: 55..<59, columns: 50..<54),
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
          sourceLevelID: .levelTwo, destinationLevelID: .levelOne, destinationEntry: .top,
          carryover: makeCarryoverState(), reason: .returnedBackward))
    } else if region.intersects(level.exitRegion) {
      if !completedLevelIDs.contains(.levelTwo) {
        player.score += 100
        completedLevelIDs.insert(.levelTwo)
        emit(.levelCompleted(points: 100), at: player.position)
      }
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .levelTwo, destinationLevelID: .levelThree, destinationEntry: .bottom,
          carryover: makeCarryoverState()))
    }
  }
}
