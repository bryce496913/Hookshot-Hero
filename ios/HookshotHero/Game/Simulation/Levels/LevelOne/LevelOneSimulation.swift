import Combine
import Foundation

@MainActor final class GameInputController: ObservableObject {
  private var queue: [GameCommand] = []
  @Published private(set) var heldDirection: GridDirection?
  @Published private(set) var cancellationGeneration = 0
  func send(_ command: GameCommand) {
    if case .beginMove(let d) = command { heldDirection = d }
    if case .endMove(let d) = command, heldDirection == d { heldDirection = nil }
    queue.append(command)
  }
  func drain() -> [GameCommand] {
    defer { queue.removeAll() }
    return queue
  }
  func cancelAllInput() {
    queue.removeAll()
    heldDirection = nil
    cancellationGeneration &+= 1
  }
}

@MainActor class LevelOneSimulation: GameSimulation {
  static let chestMessage =
    "Welcome Heroine!! Tap Grapple to launch in the direction you are facing. Use it to cross lava, attack mines, and collect items. Chests and food barrels can restore health or add score. Beware of bombs."
  var level: LevelDefinition
  var presentationDefinition: LevelPresentationDefinition
  let input = GameInputController()
  let configuration: GameConfiguration
  let seed: UInt64
  var player: PlayerState
  var entities: [WorldEntity]
  var enemies: [EnemyState] = []
  private var enemiesHitByCurrentHook: Set<EntityID> = []
  private var skeletonRNG: SeededRandomNumberGenerator
  private var flyingRNG: SeededRandomNumberGenerator
  var chestStates: [LevelChestState] = []
  var chestOpen: Bool { chestStates.first?.isOpened ?? false }
  private(set) var feedbackEvents: [GameplayFeedback] = []
  var effectEvents: [RenderEffectSnapshot] = []
  private var movementAccumulator = 0.0
  var simulationTime = 0.0
  private(set) var outcome: GameOutcome?
  private var lastPublishedStatus: PlayerStatusSnapshot
  private var lastPublishedUISnapshot: GameplayUISnapshot
  var completedLevelIDs: Set<LevelID> = []
  var worldState = WorldCarryoverState()
  var onStatusChange: ((PlayerStatusSnapshot) -> Void)?
  var onUISnapshotChange: ((GameplayUISnapshot) -> Void)?
  var onOutcome: ((GameOutcome) -> Void)?
  var onLevelTransition: ((LevelTransitionRequest) -> Void)?
  var onDialogue: ((String) -> Void)?
  init(
    configuration: GameConfiguration = .init(reducedMotion: false, controlHintsEnabled: true),
    seed: UInt64 = UInt64.random(in: 1...UInt64.max), entryPosition: LevelEntryPosition = .bottom,
    carryover: PlayerCarryoverState? = nil, startOverride: GridPosition? = nil,
    entities fixture: [WorldEntity]? = nil
  ) throws {
    self.configuration = configuration
    self.seed = seed
    skeletonRNG = .init(seed: seed ^ 0x5151)
    flyingRNG = .init(seed: seed ^ 0x7171)
    level = LevelOneDefinition.make()
    presentationDefinition = LevelOnePresentationDefinition.make(from: level)
    let entryStart = entryPosition == .top ? GridPosition(row: 5, column: 23) : level.start
    let initial = startOverride ?? entryStart
    player = .init(
      id: carryover?.characterID ?? EntityID(), position: initial, lastSafePosition: initial)
    player.health = carryover?.health ?? 3
    player.score = carryover?.score ?? 0
    completedLevelIDs = carryover?.completedLevelIDs ?? []
    worldState = carryover?.worldState ?? .init()
    lastPublishedStatus = .init(health: player.health, score: player.score)
    lastPublishedUISnapshot = .init(
      levelID: .levelOne, levelName: "Level 1", health: 3, maximumHealth: 5, score: 0,
      canMove: true, canGrapple: true, isPaused: false, dialogue: nil, feedback: [],
      diagnosticPlayerPosition: nil)
    var rng = SeededRandomNumberGenerator(seed: seed)
    entities = try fixture ?? SpawnService.spawn(in: level, using: &rng)
    chestStates = [Self.standardChest(at: level.chestAnchor, message: Self.chestMessage)]
    restoreOpenedChestStates()
    try validateInitialPlayerFootprint()
  }
  static func standardChest(at anchor: GridPosition, message: String) -> LevelChestState {
    .init(
      definition: .init(
        id: EntityID(), interactionAnchor: anchor, renderAnchor: anchor,
        closedAsset: LevelOneRenderAssets.chestClosed, openedAsset: LevelOneRenderAssets.chestOpen,
        renderSize: .init(width: 2.5, height: 2.5), renderAnchorPoint: .center,
        message: message, scoreReward: 100, healthReward: 2), isOpened: false)
  }
  func validateInitialPlayerFootprint() throws {
    let region = CollisionProfile.player.region(at: player.position)
    guard !level.isBlocked(region), !level.overlapsLava(region) else {
      throw GameLoadingError.invalidInitialState(levelID)
    }
  }
  func restoreOpenedChestStates() {
    for index in chestStates.indices {
      let definition = chestStates[index].definition
      chestStates[index].isOpened = worldState.openedChestIDs.contains(
        .init(levelID: levelID, interactionAnchor: definition.interactionAnchor))
    }
  }
  func makeCarryoverState() -> PlayerCarryoverState {
    PlayerCarryoverState(
      characterID: player.id, health: player.health, score: player.score,
      completedLevelIDs: completedLevelIDs, worldState: worldState)
  }
  var levelID: LevelID { .levelOne }
  var levelName: String { level.displayName }
  var finalStatus: PlayerStatusSnapshot { .init(health: player.health, score: player.score) }
  var inputController: GameInputController { input }
  var uiSnapshot: GameplayUISnapshot {
    .init(
      levelID: levelID, levelName: levelName, health: player.health,
      maximumHealth: player.maximumHealth, score: player.score, canMove: outcome == nil,
      canGrapple: outcome == nil && player.hookshot.phase == .idle, isPaused: false, dialogue: nil,
      feedback: feedbackEvents, diagnosticPlayerPosition: nil)
  }
  var renderSnapshot: GameRenderSnapshot {
    let orientation = RenderOrientation(rawValue: player.facing.rawValue) ?? .none
    let walking = player.movementDirection != nil && player.hookshot.phase == .idle
    let playerRender = RenderEntitySnapshot(
      id: player.id, asset: LevelOneRenderAssets.lidia, coordinate: player.position,
      renderSize: .init(width: 5.4, height: 4.4), anchor: .center, zPosition: 8,
      orientation: orientation,
      animation: .init(
        animationID: LevelOneRenderAnimations.lidiaWalk(orientation),
        frameIndex: configuration.reducedMotion || !walking
          ? 0 : Int(player.animationTime / 0.09) % 9), opacity: 1, isHidden: false)
    let world = entities.map { entity -> RenderEntitySnapshot in
      let data: (RenderAssetID, LogicalRenderSize, RenderAnimationSnapshot?) =
        switch entity.kind {
        case .coin:
          (
            LevelOneRenderAssets.coin, .init(width: 2, height: 2),
            .init(
              animationID: LevelOneRenderAnimations.coinSpin,
              frameIndex: configuration.reducedMotion ? 0 : Int(player.animationTime / 0.08) % 9)
          )
        case .mine: (LevelOneRenderAssets.mine, .init(width: 2, height: 2.6), nil)
        case .cabbage: (LevelOneRenderAssets.cabbage, .init(width: 3.2, height: 3.2), nil)
        }
      return .init(
        id: entity.id, asset: data.0, coordinate: entity.position, renderSize: data.1,
        anchor: .center, zPosition: 6, orientation: .none, animation: data.2, opacity: 1,
        isHidden: false)
    }
    let grapple =
      player.hookshot.phase != .idle && player.hookshot.head != nil
      ? GrappleRenderSnapshot(origin: player.position, head: player.hookshot.head!) : nil
    let chestSnapshots = chestStates.map { chest in
      RenderEntitySnapshot(
        id: chest.id,
        asset: chest.isOpened ? chest.definition.openedAsset : chest.definition.closedAsset,
        coordinate: chest.definition.renderAnchor, renderSize: chest.definition.renderSize,
        anchor: chest.definition.renderAnchorPoint, zPosition: 5, orientation: .none,
        animation: nil, opacity: 1, isHidden: false)
    }
    return .init(
      player: playerRender, entities: world + chestSnapshots + enemyRenderSnapshots,
      grapple: grapple, effects: effectEvents)
  }
  func update(deltaTime raw: TimeInterval) {
    guard outcome == nil else { return }
    let dt = min(max(raw, 0), 0.1)
    simulationTime += dt
    player.damageCooldown = max(0, player.damageCooldown - dt)
    player.animationTime += dt
    feedbackEvents.removeAll { $0.createdAt + $0.duration <= simulationTime }
    effectEvents.removeAll { $0.createdAt + $0.descriptor.duration <= simulationTime }
    consumeCommands()
    guard outcome == nil else { return }
    updateHeldMovement(dt)
    guard outcome == nil else { return }
    updateHook(dt)
    guard outcome == nil else { return }
    checkChestAndExit()
    guard outcome == nil else { return }
    publishStatusIfChanged()
    publishUISnapshotIfChanged()
  }
  func continueDialogue() { publishUISnapshotIfChanged() }
  func setPaused(_ paused: Bool) { if paused { cancelAllInput() } }
  func dispose() {
    cancelAllInput()
    onUISnapshotChange = nil
    onOutcome = nil
    onLevelTransition = nil
    onDialogue = nil
  }
  func cancelAllInput() {
    input.cancelAllInput()
    player.movementDirection = nil
    movementAccumulator = 0
  }
  private func consumeCommands() {
    for command in input.drain() {
      guard outcome == nil else { break }
      process(command)
    }
  }
  private func process(_ command: GameCommand) {
    guard outcome == nil else { return }
    switch command {
    case .move(let d):
      player.facing = d
      attemptMove(d)
    case .beginMove(let d):
      player.facing = d
      player.movementDirection = d
      movementAccumulator = 0
      attemptMove(d)
    case .endMove(let d): if player.movementDirection == d { player.movementDirection = nil }
    case .fireHook: fireHook()
    case .fireHookInDirection(let direction):
      player.facing = direction
      fireHook()
    }
  }
  private func updateHeldMovement(_ dt: Double) {
    guard outcome == nil, let d = player.movementDirection, player.hookshot.phase == .idle else {
      return
    }
    movementAccumulator += dt
    while movementAccumulator >= 0.14 {
      guard outcome == nil else { return }
      movementAccumulator -= 0.14
      attemptMove(d)
    }
  }
  func attemptMove(_ d: GridDirection) {
    guard outcome == nil, player.hookshot.phase == .idle else { return }
    let next = player.position.moved(d)
    let region = CollisionProfile.player.region(at: next)
    guard !level.isBlocked(region) else { return }
    if level.overlapsLava(region) {
      damageFromLava()
      return
    }
    player.position = next
    player.lastSafePosition = next
    interact(region, hooked: false)
    publishStatusIfChanged()
  }
  private func damageFromLava() {
    guard outcome == nil, player.damageCooldown <= 0 else { return }
    player.health -= 1
    player.damageCooldown = 0.75
    player.position = player.lastSafePosition
    emit(.healthLost(amount: 1, source: .lava), at: player.position)
    publishStatusIfChanged()
    checkLoss()
  }
  func fireHook() {
    guard outcome == nil, player.hookshot.phase == .idle else { return }
    player.movementDirection = nil
    player.hookshot = .init(
      phase: .extending, origin: player.position, head: player.position, direction: player.facing)
  }
  private func updateHook(_ dt: Double) {
    guard outcome == nil, player.hookshot.phase != .idle else { return }
    player.hookshot.accumulator += dt * 18
    while player.hookshot.accumulator >= 1, player.hookshot.phase != .idle {
      guard outcome == nil else { return }
      player.hookshot.accumulator -= 1
      hookStep()
    }
  }
  private func hookStep() {
    guard outcome == nil else { return }
    switch player.hookshot.phase {
    case .extending:
      guard let head = player.hookshot.head else {
        finishHook()
        return
      }
      let next = head.moved(player.hookshot.direction)
      if !level.isInside(next) || level.isWall(next) {
        player.hookshot.phase = .latched
        player.hookshot.head = next
        return
      }
      player.hookshot.head = next
      player.hookshot.travelled += 1
      interact(CollisionProfile.hookHead.region(at: next), hooked: true)
      if player.hookshot.travelled >= HookshotState.maximumRange {
        player.hookshot.phase = .retracting
      }
    case .latched: player.hookshot.phase = .pulling
    case .pulling:
      let next = player.position.moved(player.hookshot.direction)
      if level.isBlocked(CollisionProfile.player.region(at: next)) {
        finishHook()
      } else {
        player.position = next
        interact(CollisionProfile.player.region(at: next), hooked: true)
      }
    case .retracting: finishHook()
    case .idle: break
    }
    publishStatusIfChanged()
  }
  private func finishHook() {
    if !level.overlapsLava(CollisionProfile.player.region(at: player.position)) {
      player.lastSafePosition = player.position
    }
    player.hookshot = HookshotState()
  }
  private func interact(_ contact: GridRegion, hooked: Bool) {
    // Entity array order is the deterministic collision order. A terminal contact short-circuits the remainder.
    let hits = entities.filter {
      CollisionProfile.footprint(for: $0.kind).region(at: $0.position).intersects(contact)
    }
    for entity in hits {
      guard outcome == nil else { return }
      entities.removeAll { $0.id == entity.id }
      switch entity.kind {
      case .coin:
        player.score += 10
        emit(.coinCollected(points: 10), at: entity.position)
      case .cabbage:
        let old = player.health
        player.health = min(player.maximumHealth, player.health + 1)
        emit(
          player.health > old ? .healthItemCollected(amount: 1) : .healthAlreadyFull,
          at: entity.position)
      case .mine:
        if hooked {
          player.score += 10
          let effectID = emit(.mineDestroyed(points: 10), at: entity.position)
          effectEvents.append(
            .init(
              id: effectID, coordinate: entity.position,
              descriptor: .mineDestruction(reducedMotion: configuration.reducedMotion),
              createdAt: simulationTime))
        } else {
          player.health -= 1
          emit(.healthLost(amount: 1, source: .mine), at: entity.position)
          publishStatusIfChanged()
          checkLoss()
          if outcome != nil { return }
        }
      }
    }
  }
  var enemyRenderSnapshots: [RenderEntitySnapshot] {
    enemies.map { enemy in
      let orientation = RenderOrientation(rawValue: enemy.facing.rawValue) ?? .right
      return .init(
        id: enemy.id, asset: enemy.archetype.asset, coordinate: enemy.position,
        renderSize: enemy.archetype.renderSize, anchor: .center, zPosition: 7,
        orientation: orientation,
        animation: .init(
          animationID: LevelTwoRenderAnimations.enemy(enemy.archetype, orientation),
          frameIndex: configuration.reducedMotion
            ? 0 : Int(enemy.animationTime / 0.08) % (enemy.archetype == .skeleton ? 9 : 10)),
        opacity: 1, isHidden: false,
        health: .init(current: enemy.health, maximum: enemy.maximumHealth))
    }
  }
  func validateEnemyFootprints(entryPositions: [GridPosition]) throws {
    let entryRegions = entryPositions.map { CollisionProfile.player.region(at: $0) }
    for enemy in enemies {
      let region = enemy.archetype.footprint.region(at: enemy.position)
      guard region.cells.allSatisfy(level.isInside),
        enemy.archetype == .flyingTerror || !level.isBlocked(region),
        !entryRegions.contains(where: region.intersects)
      else {
        throw GameLoadingError.invalidInitialState(levelID)
      }
    }
  }
  func updateEnemySystem(_ rawDeltaTime: TimeInterval) {
    guard outcome == nil else { return }
    let dt = min(max(rawDeltaTime, 0), 0.1)
    updateEnemyGrappleHits()
    for index in enemies.indices {
      enemies[index].animationTime += dt
      enemies[index].behaviorState =
        enemyDistance(enemies[index].position) <= enemies[index].archetype.sight ? .seek : .patrol
      enemies[index].decisionAccumulator += dt
      let interval =
        enemies[index].behaviorState == .seek
        ? enemies[index].archetype.seekInterval : enemies[index].archetype.patrolInterval
      if enemies[index].decisionAccumulator >= interval {
        enemies[index].decisionAccumulator.formTruncatingRemainder(dividingBy: interval)
        stepEnemy(index)
      }
      if enemies[index].archetype.footprint.region(at: enemies[index].position).intersects(
        CollisionProfile.player.region(at: player.position))
      {
        damageFromEnemy(enemies[index].archetype)
      }
    }
  }
  private func stepEnemy(_ index: Int) {
    let directions = GridDirection.allCases
    func canMove(_ direction: GridDirection) -> Bool {
      let region = enemies[index].archetype.footprint.region(
        at: enemies[index].position.moved(direction))
      return region.cells.allSatisfy(level.isInside)
        && (enemies[index].archetype == .flyingTerror
          || !level.walls.contains { $0.intersects(region) })
    }
    let direction: GridDirection?
    if enemies[index].behaviorState == .seek {
      direction = directions.filter(canMove).min { lhs, rhs in
        let left = enemyDistance(enemies[index].position.moved(lhs))
        let right = enemyDistance(enemies[index].position.moved(rhs))
        return left == right
          ? directions.firstIndex(of: lhs)! < directions.firstIndex(of: rhs)! : left < right
      }
    } else {
      let random = enemies[index].archetype == .skeleton ? skeletonRNG.next() : flyingRNG.next()
      let start = Int(random % UInt64(directions.count))
      direction = (0..<directions.count).map { directions[($0 + start) % directions.count] }.first(
        where: canMove)
    }
    guard let direction else { return }
    enemies[index].facing = direction
    enemies[index].position = enemies[index].position.moved(direction)
  }
  private func enemyDistance(_ position: GridPosition) -> Double {
    hypot(
      Double(position.row - player.position.row), Double(position.column - player.position.column))
  }
  private func updateEnemyGrappleHits() {
    guard let head = player.hookshot.head, player.hookshot.phase == .extending else {
      if player.hookshot.phase == .idle { enemiesHitByCurrentHook.removeAll() }
      return
    }
    let hookRegion = CollisionProfile.hookHead.region(at: head)
    guard
      let index = enemies.firstIndex(where: {
        !enemiesHitByCurrentHook.contains($0.id)
          && $0.archetype.footprint.region(at: $0.position).intersects(hookRegion)
      })
    else { return }
    enemiesHitByCurrentHook.insert(enemies[index].id)
    enemies[index].health -= 1
    player.score += 10
    let enemy = enemies[index]
    emit(
      .enemyHit(archetype: enemy.archetype, points: 10, remainingHealth: max(0, enemy.health)),
      at: enemy.position)
    if enemy.health <= 0 {
      enemies.remove(at: index)
      let effectID = emit(.enemyDefeated(archetype: enemy.archetype), at: enemy.position)
      effectEvents.append(
        .init(
          id: effectID, coordinate: enemy.position,
          descriptor: .enemyDefeat(reducedMotion: configuration.reducedMotion),
          createdAt: simulationTime))
    }
    player.hookshot.phase = .retracting
  }
  private func damageFromEnemy(_ archetype: EnemyArchetype) {
    guard player.damageCooldown <= 0 else { return }
    player.health -= 1
    player.damageCooldown = 0.75
    emit(.healthLost(amount: 1, source: .enemy(archetype)), at: player.position)
    checkLoss()
  }
  func activateChestAndExit() { checkChestAndExit() }
  private func checkChestAndExit() {
    guard outcome == nil else { return }
    let playerRegion = CollisionProfile.player.region(at: player.position)
    if let index = chestStates.firstIndex(where: {
      !$0.isOpened
        && playerRegion.intersects(CollisionProfile.chest.region(at: $0.definition.interactionAnchor))
    }) {
      guard outcome == nil else { return }
      chestStates[index].isOpened = true
      let chest = chestStates[index].definition
      worldState.openedChestIDs.insert(
        .init(levelID: levelID, interactionAnchor: chest.interactionAnchor))
      player.score += chest.scoreReward
      let gain = min(chest.healthReward, player.maximumHealth - player.health)
      player.health += gain
      emit(.chestReward(score: chest.scoreReward, health: gain), at: chest.interactionAnchor)
      publishStatusIfChanged()
      cancelAllInput()
      if let message = chest.message { onDialogue?(message) }
    }
    guard outcome == nil, levelID == .levelOne else { return }
    if playerRegion.intersects(level.exitRegion) {
      completeLevel()
    }
  }
  private func completeLevel() {
    if !completedLevelIDs.contains(levelID) {
      player.score += 100
      completedLevelIDs.insert(levelID)
      emit(.levelCompleted(points: 100), at: player.position)
    }
    publishStatusIfChanged()
    cancelAllInput()
    onLevelTransition?(
      LevelTransitionRequest(
        sourceLevelID: .levelOne, destinationLevelID: .levelTwo, destinationEntry: .bottom,
        carryover: makeCarryoverState(), reason: .completedForward))
  }
  func checkLoss() {
    if player.health <= 0 {
      publishStatusIfChanged()
      setOutcome(.lost)
    }
  }
  func setOutcome(_ value: GameOutcome) {
    guard outcome == nil else { return }
    outcome = value
    cancelAllInput()
    player.hookshot = HookshotState()
    publishUISnapshotIfChanged()
    onOutcome?(value)
  }
  private func publishStatusIfChanged() {
    guard outcome == nil else { return }
    let status = PlayerStatusSnapshot(health: player.health, score: player.score)
    guard status != lastPublishedStatus else { return }
    lastPublishedStatus = status
    onStatusChange?(status)
  }
  private func publishUISnapshotIfChanged() {
    let snapshot = uiSnapshot
    guard snapshot != lastPublishedUISnapshot else { return }
    lastPublishedUISnapshot = snapshot
    onUISnapshotChange?(snapshot)
  }
  @discardableResult func emit(_ kind: GameplayFeedbackKind, at coordinate: GridPosition?) -> UUID {
    guard outcome == nil else { return UUID() }
    let id = UUID()
    feedbackEvents.append(
      .init(
        id: id, kind: kind, coordinate: coordinate, createdAt: simulationTime, duration: 2.4))
    publishUISnapshotIfChanged()
    return id
  }
}
