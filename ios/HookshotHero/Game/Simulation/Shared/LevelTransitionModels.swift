import Foundation

enum DamageSource: Equatable, Sendable {
  case lava, mine
  case enemy(EnemyArchetype)
}

enum LevelEntryPosition: Hashable, Sendable { case bottom, top, right }
struct OpenedChestID: Hashable, Sendable {
  let levelID: LevelID
  let interactionAnchor: GridPosition
}
struct WorldCarryoverState: Hashable, Sendable {
  var openedChestIDs: Set<OpenedChestID> = []
}
struct PlayerCarryoverState: Hashable, Sendable {
  let characterID: EntityID
  let health: Int
  let score: Int
  let completedLevelIDs: Set<LevelID>
  var worldState: WorldCarryoverState = .init()
}
enum LevelTransitionReason: Hashable, Sendable { case completedForward, returnedBackward }
struct LevelTransitionRequest: Hashable, Sendable {
  let sourceLevelID: LevelID
  let destinationLevelID: LevelID
  let destinationEntry: LevelEntryPosition
  let carryover: PlayerCarryoverState
  let reason: LevelTransitionReason
  init(
    sourceLevelID: LevelID, destinationLevelID: LevelID, destinationEntry: LevelEntryPosition,
    carryover: PlayerCarryoverState, reason: LevelTransitionReason = .completedForward
  ) {
    self.sourceLevelID = sourceLevelID
    self.destinationLevelID = destinationLevelID
    self.destinationEntry = destinationEntry
    self.carryover = carryover
    self.reason = reason
  }
}
enum LevelDestination: Equatable, Sendable {
  case level(LevelID, entry: LevelEntryPosition)
  case currentContentComplete(nextLevelID: LevelID?)
}
