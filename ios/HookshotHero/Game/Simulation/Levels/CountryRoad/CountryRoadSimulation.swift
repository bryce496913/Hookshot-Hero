import Foundation

enum CountryRoadNPCArchetype: String, CaseIterable, Sendable {
  case child
  case olderResident
  case townfolk
}

struct CountryRoadNPCState: Identifiable, Sendable {
  let id: EntityID
  let archetype: CountryRoadNPCArchetype
  var position: GridPosition
  var facing: GridDirection
  var movementAccumulator = 0.0
}

@MainActor final class CountryRoadSimulation: LevelOneSimulation {
  override var levelID: LevelID { .countryRoad }
  override var levelName: String { "Country Road" }
  private var didRequestHeroWelcome = false
  private(set) var npcStates: [CountryRoadNPCState]
  private var npcRNG: SeededRandomNumberGenerator

  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 496_913, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    guard entryPosition == .bottom else { throw GameLoadingError.invalidInitialState(.countryRoad) }
    let definition = CountryRoadDefinition.make()
    npcRNG = .init(seed: seed ^ 0xB6C0_29)
    npcStates = Self.makeNPCStates()
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
      ] + npcStates.map { CollisionProfile.player.region(at: $0.position) }, using: &rng)
  }

  override var renderSnapshot: GameRenderSnapshot {
    let base = super.renderSnapshot
    let npcSnapshots = npcStates.map { npc in
      RenderEntitySnapshot(
        id: npc.id, asset: asset(for: npc.archetype), coordinate: npc.position,
        renderSize: .init(width: 2.4, height: 3.2), anchor: .center, zPosition: 7,
        orientation: RenderOrientation(rawValue: npc.facing.rawValue) ?? .none, animation: nil,
        opacity: 1, isHidden: false)
    }
    return .init(
      player: base.player, entities: base.entities + npcSnapshots, grapple: base.grapple,
      effects: base.effects)
  }

  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil, !didRequestHeroWelcome else { return }
    updateNPCs(deltaTime: min(max(deltaTime, 0), 0.1))
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

  private static func makeNPCStates() -> [CountryRoadNPCState] {
    func states(
      _ archetype: CountryRoadNPCArchetype, _ coordinates: [(row: Int, column: Int)]
    ) -> [CountryRoadNPCState] {
      coordinates.enumerated().map { index, coordinate in
        .init(
          id: EntityID(), archetype: archetype,
          position: .init(row: coordinate.row, column: coordinate.column),
          facing: GridDirection.allCases[index % GridDirection.allCases.count])
      }
    }
    return states(
      .child,
      [
        (7, 6), (7, 25), (7, 35), (12, 6), (12, 27), (17, 27), (17, 35), (22, 27),
        (22, 50),
      ])
      + states(
        .olderResident,
        [(10, 35), (17, 6), (24, 6), (40, 25), (46, 45)])
      + states(
        .townfolk,
        [
          (6, 15), (6, 40), (11, 31), (12, 40), (18, 12), (18, 22), (23, 15), (23, 35),
          (28, 8), (28, 20), (28, 35), (34, 28), (42, 10), (40, 35), (46, 15),
        ])
  }

  private func updateNPCs(deltaTime: TimeInterval) {
    for index in npcStates.indices {
      npcStates[index].movementAccumulator += deltaTime
      let reactionTime =
        distance(from: npcStates[index].position, to: player.position) <= 15
        ? 0.15 : 0.5
      guard npcStates[index].movementAccumulator >= reactionTime else { continue }
      npcStates[index].movementAccumulator = 0
      let current = npcStates[index].position
      let playerDistance = distance(from: current, to: player.position)
      let direction: GridDirection
      if playerDistance <= 15 && playerDistance > 3 {
        direction =
          abs(current.row - player.position.row) > abs(current.column - player.position.column)
          ? (current.row < player.position.row ? .down : .up)
          : (current.column < player.position.column ? .right : .left)
      } else {
        direction = GridDirection.allCases[Int.random(in: 0..<4, using: &npcRNG)]
      }
      npcStates[index].facing = direction
      guard playerDistance > 3 else { continue }
      let candidate = current.moved(direction)
      let footprint = CollisionProfile.player.region(at: candidate)
      let obstructsNPC = npcStates.indices.contains { otherIndex in
        otherIndex != index
          && footprint.intersects(
            CollisionProfile.player.region(at: npcStates[otherIndex].position))
      }
      guard footprint.cells.allSatisfy(level.isInside), !level.isBlocked(footprint),
        !footprint.intersects(CountryRoadDefinition.exitRegion),
        !footprint.intersects(CountryRoadDefinition.doorwayRegion), !obstructsNPC
      else { continue }
      npcStates[index].position = candidate
    }
  }

  private func distance(from first: GridPosition, to second: GridPosition) -> Int {
    abs(first.row - second.row) + abs(first.column - second.column)
  }

  private func asset(for archetype: CountryRoadNPCArchetype) -> RenderAssetID {
    switch archetype {
    case .child: CountryRoadRenderAssets.child
    case .olderResident: CountryRoadRenderAssets.olderResident
    case .townfolk: CountryRoadRenderAssets.townfolk
    }
  }
}
