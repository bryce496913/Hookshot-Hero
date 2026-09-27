import Foundation

@MainActor final class CountryRoadSimulation: LevelOneSimulation {
  override var levelID: LevelID { .countryRoad }
  override var levelName: String { "Country Road" }
  private var didRequestHeroWelcome = false

  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 496_913, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    guard entryPosition == .bottom else { throw GameLoadingError.invalidInitialState(.countryRoad) }
    let definition = CountryRoadDefinition.make()
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition,
      carryover: carryover, levelDefinition: definition,
      presentationDefinition: CountryRoadPresentationDefinition.make(from: definition),
      initialPlayerPosition: CountryRoadDefinition.start, entities: [])
    var rng = SeededRandomNumberGenerator(seed: seed ^ 0xC017)
    entities = try SpawnService.spawn(
      in: level,
      requirements: [.init(kind: .cabbage, count: 5), .init(kind: .coin, count: 15)],
      protectedRegions: [
        CollisionProfile.player.region(at: CountryRoadDefinition.start),
        CountryRoadDefinition.exitRegion, CountryRoadDefinition.doorwayRegion,
      ], using: &rng)
  }

  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil, !didRequestHeroWelcome else { return }
    if CollisionProfile.player.region(at: player.position).intersects(
      CountryRoadDefinition.exitRegion)
    {
      didRequestHeroWelcome = true
      completedLevelIDs.insert(.countryRoad)
      cancelAllInput()
      onLevelTransition?(
        .init(
          sourceLevelID: .countryRoad, destinationLevelID: .heroWelcome,
          destinationEntry: .bottom, carryover: makeCarryoverState(),
          reason: .completedForward))
    }
  }
}
