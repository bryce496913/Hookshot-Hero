import XCTest

@testable import HookshotHero

@MainActor
final class CrossLevelCarryoverTests: XCTestCase {
  private let seed: UInt64 = 496_913

  private struct ExpectedState {
    let characterID: EntityID
    var health: Int
    var score: Int
    var completedLevelIDs: Set<LevelID>
    var openedChestIDs: Set<OpenedChestID>
  }

  func testForwardAndReverseMainPathPreservesCarryoverAndPreventsChestFarming() throws {
    let (levelFour, forwardState) = try makeForwardChain()

    let levelThree = try transition(
      from: levelFour, at: .init(row: 57, column: 29), to: .levelThree, entry: .top,
      reason: .returnedBackward, expected: forwardState)
    try assertChestCannotRewardAgain(in: levelThree, expected: forwardState)

    let levelTwo = try transition(
      from: levelThree, at: .init(row: 57, column: 29), to: .levelTwo, entry: .top,
      reason: .returnedBackward, expected: forwardState)
    let levelOne = try transition(
      from: levelTwo, at: .init(row: 57, column: 29), to: .levelOne, entry: .top,
      reason: .returnedBackward, expected: forwardState)
    try assertChestCannotRewardAgain(in: levelOne, expected: forwardState)
  }

  func testLevelFiveBranchPreservesEveryPriorChestAndPreventsRewardFarming() throws {
    let (levelFour, forwardState) = try makeForwardChain()
    let levelFive = try transition(
      from: levelFour, at: .init(row: 29, column: 57), to: .levelFive, entry: .bottom,
      reason: .completedForward, expected: forwardState)

    var branchState = forwardState
    try openChest(in: levelFive, index: 0, expected: &branchState)
    let returnedLevelFour = try transition(
      from: levelFive, at: .init(row: 9, column: 3), to: .levelFour, entry: .right,
      reason: .returnedBackward, expected: branchState)
    let revisitedLevelFive = try transition(
      from: returnedLevelFour, at: .init(row: 29, column: 57), to: .levelFive, entry: .bottom,
      reason: .completedForward, expected: branchState)
    try assertChestCannotRewardAgain(in: revisitedLevelFive, expected: branchState)
  }

  func testLevelSixBranchPreservesBothChestsAndPreventsRewardFarming() throws {
    let (levelFour, forwardState) = try makeForwardChain()
    let levelSix = try transition(
      from: levelFour, at: .init(row: 3, column: 29), to: .levelSix, entry: .bottom,
      reason: .completedForward, expected: forwardState)

    var branchState = forwardState
    try openChest(in: levelSix, index: 0, expected: &branchState)
    try openChest(in: levelSix, index: 1, expected: &branchState)
    let returnedLevelFour = try transition(
      from: levelSix, at: .init(row: 57, column: 29), to: .levelFour, entry: .top,
      reason: .returnedBackward, expected: branchState)
    let revisitedLevelSix = try transition(
      from: returnedLevelFour, at: .init(row: 3, column: 29), to: .levelSix, entry: .bottom,
      reason: .completedForward, expected: branchState)
    try assertChestCannotRewardAgain(in: revisitedLevelSix, expected: branchState, index: 0)
    try assertChestCannotRewardAgain(in: revisitedLevelSix, expected: branchState, index: 1)
  }

  func testMakeSimulationRejectsUnsupportedLevelID() {
    let unsupported = LevelID(rawValue: "level-test-unsupported")
    let carryover = PlayerCarryoverState(
      characterID: EntityID(), health: 2, score: 37, completedLevelIDs: [])

    XCTAssertThrowsError(
      try makeSimulation(levelID: unsupported, entryPosition: .bottom, carryover: carryover)
    ) {
      XCTAssertEqual($0 as? GameLoadingError, .unsupportedLevel(unsupported))
    }
  }

  private func makeForwardChain() throws -> (LevelFourSimulation, ExpectedState) {
    let characterID = EntityID()
    var expected = ExpectedState(
      characterID: characterID, health: 2, score: 37,
      completedLevelIDs: [.levelFour], openedChestIDs: [])
    let initialCarryover = PlayerCarryoverState(
      characterID: characterID, health: expected.health, score: expected.score,
      completedLevelIDs: expected.completedLevelIDs)
    let levelOne = try LevelOneSimulation(seed: seed, carryover: initialCarryover, entities: [])

    try openChest(in: levelOne, index: 0, expected: &expected)
    expected.score += 100
    expected.completedLevelIDs.insert(.levelOne)
    let levelTwo = try transition(
      from: levelOne, at: .init(row: 3, column: 29), to: .levelTwo, entry: .bottom,
      reason: .completedForward, expected: expected)

    expected.score += 100
    expected.completedLevelIDs.insert(.levelTwo)
    let levelThree = try transition(
      from: levelTwo, at: .init(row: 3, column: 29), to: .levelThree, entry: .bottom,
      reason: .completedForward, expected: expected)
    try openChest(in: levelThree, index: 0, expected: &expected)
    expected.score += 100
    expected.completedLevelIDs.insert(.levelThree)
    let levelFour = try transition(
      from: levelThree, at: .init(row: 3, column: 29), to: .levelFour, entry: .bottom,
      reason: .completedForward, expected: expected)
    return (levelFour as! LevelFourSimulation, expected)
  }

  private func transition(
    from source: LevelOneSimulation, at position: GridPosition, to destination: LevelID,
    entry: LevelEntryPosition, reason: LevelTransitionReason, expected: ExpectedState,
    file: StaticString = #filePath, line: UInt = #line
  ) throws -> LevelOneSimulation {
    var emittedRequest: LevelTransitionRequest?
    source.onLevelTransition = { emittedRequest = $0 }
    source.player.position = position
    source.update(deltaTime: 0.01)

    let request = try XCTUnwrap(
      emittedRequest, "No transition emitted from \(source.levelID)", file: file, line: line)
    XCTAssertEqual(request.sourceLevelID, source.levelID, file: file, line: line)
    XCTAssertEqual(request.destinationLevelID, destination, file: file, line: line)
    XCTAssertEqual(request.destinationEntry, entry, file: file, line: line)
    XCTAssertEqual(request.reason, reason, file: file, line: line)
    assertCarryover(
      request.carryover, from: source.levelID, to: destination, expected: expected, file: file,
      line: line)

    let restored = try makeSimulation(
      levelID: destination, entryPosition: request.destinationEntry, carryover: request.carryover)
    assertSimulation(restored, from: source.levelID, expected: expected, file: file, line: line)
    return restored
  }

  private func makeSimulation(
    levelID: LevelID, entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState
  ) throws -> LevelOneSimulation {
    switch levelID {
    case .levelOne:
      try LevelOneSimulation(
        seed: seed, entryPosition: entryPosition, carryover: carryover, entities: [])
    case .levelTwo:
      try LevelTwoSimulation(seed: seed, entryPosition: entryPosition, carryover: carryover)
    case .levelThree:
      try LevelThreeSimulation(seed: seed, entryPosition: entryPosition, carryover: carryover)
    case .levelFour:
      try LevelFourSimulation(seed: seed, entryPosition: entryPosition, carryover: carryover)
    case .levelFive:
      try LevelFiveSimulation(seed: seed, entryPosition: entryPosition, carryover: carryover)
    case .levelSix:
      try LevelSixSimulation(seed: seed, entryPosition: entryPosition, carryover: carryover)
    default:
      throw GameLoadingError.unsupportedLevel(levelID)
    }
  }

  private func openChest(
    in simulation: LevelOneSimulation, index: Int, expected: inout ExpectedState,
    file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let chest = try XCTUnwrap(simulation.chestStates[safe: index], file: file, line: line)
    simulation.player.position = chest.definition.interactionAnchor
    simulation.activateChestAndExit()
    expected.score += chest.definition.scoreReward
    expected.health = min(
      simulation.player.maximumHealth, expected.health + chest.definition.healthReward)
    expected.openedChestIDs.insert(
      .init(levelID: simulation.levelID, interactionAnchor: chest.definition.interactionAnchor))
    XCTAssertTrue(simulation.chestStates[index].isOpened, file: file, line: line)
    assertSimulation(
      simulation, from: simulation.levelID, expected: expected, file: file, line: line)
  }

  private func assertChestCannotRewardAgain(
    in simulation: LevelOneSimulation, expected: ExpectedState, index: Int = 0,
    file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let chest = try XCTUnwrap(simulation.chestStates[safe: index], file: file, line: line)
    XCTAssertTrue(chest.isOpened, file: file, line: line)
    let rewardCount = simulation.feedbackEvents.filter {
      if case .chestReward = $0.kind { return true }
      return false
    }.count
    simulation.player.position = chest.definition.interactionAnchor
    simulation.activateChestAndExit()
    XCTAssertEqual(
      simulation.feedbackEvents.filter {
        if case .chestReward = $0.kind { return true }
        return false
      }.count, rewardCount, file: file, line: line)
    assertSimulation(
      simulation, from: simulation.levelID, expected: expected, file: file, line: line)
  }

  private func assertCarryover(
    _ carryover: PlayerCarryoverState, from source: LevelID, to destination: LevelID,
    expected: ExpectedState, file: StaticString, line: UInt
  ) {
    let context = diagnostic(
      source: source, destination: destination, carryover: carryover, expected: expected)
    XCTAssertEqual(carryover.characterID, expected.characterID, context, file: file, line: line)
    XCTAssertEqual(carryover.health, expected.health, context, file: file, line: line)
    XCTAssertEqual(carryover.score, expected.score, context, file: file, line: line)
    XCTAssertEqual(
      carryover.completedLevelIDs, expected.completedLevelIDs, context, file: file, line: line)
    XCTAssertEqual(
      carryover.worldState.openedChestIDs, expected.openedChestIDs, context, file: file, line: line)
  }

  private func assertSimulation(
    _ simulation: LevelOneSimulation, from source: LevelID, expected: ExpectedState,
    file: StaticString, line: UInt
  ) {
    assertCarryover(
      simulation.makeCarryoverState(), from: source, to: simulation.levelID,
      expected: expected, file: file, line: line)
  }

  private func diagnostic(
    source: LevelID, destination: LevelID, carryover: PlayerCarryoverState,
    expected: ExpectedState
  ) -> String {
    """
    Transition \(source) -> \(destination): character=\(carryover.characterID), health=\(carryover.health), score=\(carryover.score), completed=\(carryover.completedLevelIDs), expected opened chests=\(expected.openedChestIDs), actual opened chests=\(carryover.worldState.openedChestIDs)
    """
  }
}

extension Collection {
  fileprivate subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
