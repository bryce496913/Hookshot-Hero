import Foundation

enum RoyalNPCType: String, CaseIterable, Sendable { case king, queen, princess, prince, aristocrat }
struct RoyalNPCState: Identifiable, Sendable {
  let id: EntityID
  let type: RoyalNPCType
  var position: GridPosition
  var facing: GridDirection = .down
  var movementAccumulator = 0.0
}

@MainActor final class HeroWelcomeSimulation: LevelOneSimulation {
  override var levelID: LevelID { .heroWelcome }
  override var levelName: String { "Hero's Welcome" }
  private(set) var royalNPCs: [RoyalNPCState]
  private var npcRNG: SeededRandomNumberGenerator

  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = 496_913, entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil
  ) throws {
    guard entryPosition == .bottom else { throw GameLoadingError.invalidInitialState(.heroWelcome) }
    let definition = HeroWelcomeDefinition.make()
    npcRNG = .init(seed: seed ^ 0xCA57_E)
    royalNPCs = [
      .init(id: EntityID(), type: .king, position: .init(row: 6, column: 27)),
      .init(id: EntityID(), type: .queen, position: .init(row: 6, column: 32)),
      .init(id: EntityID(), type: .princess, position: .init(row: 9, column: 33)),
      .init(id: EntityID(), type: .prince, position: .init(row: 9, column: 25)),
      .init(id: EntityID(), type: .aristocrat, position: .init(row: 18, column: 12)),
      .init(id: EntityID(), type: .aristocrat, position: .init(row: 20, column: 44)),
      .init(id: EntityID(), type: .aristocrat, position: .init(row: 32, column: 14)),
      .init(id: EntityID(), type: .aristocrat, position: .init(row: 37, column: 45)),
      .init(id: EntityID(), type: .aristocrat, position: .init(row: 47, column: 16)),
    ]
    try super.init(
      configuration: configuration, seed: seed, entryPosition: entryPosition, carryover: carryover,
      levelDefinition: definition,
      presentationDefinition: HeroWelcomePresentationDefinition.make(from: definition),
      initialPlayerPosition: HeroWelcomeDefinition.start, entities: [])
    chestStates = HeroWelcomeDefinition.chestAnchors.enumerated().map { index, anchor in
      .init(
        definition: .init(
          id: EntityID(), interactionAnchor: anchor, renderAnchor: anchor,
          closedAsset: index == 2
            ? HeroWelcomeRenderAssets.silverChest : LevelOneRenderAssets.chestClosed,
          openedAsset: LevelOneRenderAssets.chestOpen, renderSize: .init(width: 2.5, height: 2.9),
          renderAnchorPoint: .center, message: "Well done!", scoreReward: 100, healthReward: 2),
        isOpened: false)
    }
    restoreOpenedChestStates()
  }

  override var renderSnapshot: GameRenderSnapshot {
    let base = super.renderSnapshot
    let npcSnapshots = royalNPCs.map { npc in
      RenderEntitySnapshot(
        id: npc.id, asset: asset(for: npc.type), coordinate: npc.position,
        renderSize: .init(width: 3.2, height: 3.2), anchor: .center, zPosition: 7,
        orientation: RenderOrientation(rawValue: npc.facing.rawValue) ?? .none, animation: nil,
        opacity: 1, isHidden: false)
    }
    return .init(
      player: base.player, entities: base.entities + npcSnapshots, grapple: base.grapple,
      effects: base.effects)
  }

  override func update(deltaTime: TimeInterval) {
    super.update(deltaTime: deltaTime)
    guard outcome == nil else { return }
    updateRoyalNPCs(deltaTime: min(max(deltaTime, 0), 0.1))
    if CollisionProfile.player.region(at: player.position).intersects(
      HeroWelcomeDefinition.exitRegion)
    {
      completedLevelIDs.insert(.heroWelcome)
      setOutcome(.won)
    }
  }

  private func updateRoyalNPCs(deltaTime: TimeInterval) {
    for index in royalNPCs.indices {
      royalNPCs[index].movementAccumulator += deltaTime
      guard royalNPCs[index].movementAccumulator >= 0.5 else { continue }
      royalNPCs[index].movementAccumulator = 0
      let current = royalNPCs[index].position
      let distance =
        abs(current.row - player.position.row) + abs(current.column - player.position.column)
      let direction: GridDirection
      if distance <= 15 && distance > 3 {
        direction =
          abs(current.row - player.position.row) > abs(current.column - player.position.column)
          ? (current.row < player.position.row ? .down : .up)
          : (current.column < player.position.column ? .right : .left)
      } else {
        direction = GridDirection.allCases[Int.random(in: 0..<4, using: &npcRNG)]
      }
      royalNPCs[index].facing = direction
      guard distance > 3 else { continue }
      let candidate = current.moved(direction)
      let footprint = CollisionProfile.player.region(at: candidate)
      guard !level.isBlocked(footprint), !footprint.intersects(HeroWelcomeDefinition.exitRegion),
        !footprint.intersects(HeroWelcomeDefinition.doorwayRegion)
      else { continue }
      royalNPCs[index].position = candidate
    }
  }

  private func asset(for type: RoyalNPCType) -> RenderAssetID {
    switch type {
    case .king: HeroWelcomeRenderAssets.king
    case .queen: HeroWelcomeRenderAssets.queen
    case .princess: HeroWelcomeRenderAssets.princess
    case .prince: HeroWelcomeRenderAssets.prince
    case .aristocrat: HeroWelcomeRenderAssets.aristocrat
    }
  }
}
