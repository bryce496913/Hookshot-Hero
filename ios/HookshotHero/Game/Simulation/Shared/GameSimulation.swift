import Foundation

@MainActor protocol GameSimulation: AnyObject {
  var levelID: LevelID { get }
  var levelName: String { get }
  var presentationDefinition: LevelPresentationDefinition { get }
  var outcome: GameOutcome? { get }
  var finalStatus: PlayerStatusSnapshot { get }
  var uiSnapshot: GameplayUISnapshot { get }
  var renderSnapshot: GameRenderSnapshot { get }
  var inputController: GameInputController { get }
  var onUISnapshotChange: ((GameplayUISnapshot) -> Void)? { get set }
  var onOutcome: ((GameOutcome) -> Void)? { get set }
  var onLevelTransition: ((LevelTransitionRequest) -> Void)? { get set }
  var onDialogue: ((String) -> Void)? { get set }
  func update(deltaTime: TimeInterval)
  func continueDialogue()
  func setPaused(_ paused: Bool)
  func cancelAllInput()
  func dispose()
}

enum GameLoadingError: LocalizedError, Equatable, Sendable {
  case unsupportedLevel(LevelID)
  case invalidLevelDefinition(LevelID)
  case missingRequiredAsset(String)
  case invalidTextureRegion(String)
  case spawnFailure(LevelID)
  case invalidInitialState(LevelID)
  var errorDescription: String? {
    switch self {
    case .unsupportedLevel(let id): "Unsupported level: \(id.rawValue)."
    case .invalidLevelDefinition(let id): "Invalid definition for \(id.rawValue)."
    case .missingRequiredAsset(let id): "Missing required asset \(id)."
    case .invalidTextureRegion(let id): "Invalid texture region \(id)."
    case .spawnFailure(let id): "Could not spawn \(id.rawValue)."
    case .invalidInitialState(let id): "Invalid initial state for \(id.rawValue)."
    }
  }
  var diagnosticCode: String {
    switch self {
    case .unsupportedLevel: "unsupported-level"
    case .invalidLevelDefinition: "invalid-definition"
    case .missingRequiredAsset: "missing-asset"
    case .invalidTextureRegion: "invalid-texture-region"
    case .spawnFailure: "spawn-failure"
    case .invalidInitialState: "invalid-initial-state"
    }
  }
}
struct LevelAssetManifest: Equatable, Sendable {
  let textureAssetIDs: Set<RenderAssetID>
  let animationIDs: Set<RenderAnimationID>
}
@MainActor struct GameLevelRuntime {
  let simulation: any GameSimulation
  let presentation: LevelPresentationDefinition
  let textureCatalog: any TextureCatalogProviding
  let animationCatalog: any AnimationCatalogProviding
  let assetManifest: LevelAssetManifest
}
@MainActor protocol AssetPreflighting {
  func validate(
    manifest: LevelAssetManifest, textureCatalog: any TextureCatalogProviding,
    animationCatalog: any AnimationCatalogProviding) throws
}
@MainActor struct DefaultAssetPreflight: AssetPreflighting {
  func validate(
    manifest: LevelAssetManifest, textureCatalog: any TextureCatalogProviding,
    animationCatalog: any AnimationCatalogProviding
  ) throws {
    for assetID in manifest.textureAssetIDs { _ = try textureCatalog.texture(for: assetID) }
    for animationID in manifest.animationIDs {
      let frames = try animationCatalog.frames(for: animationID)
      if frames.isEmpty { throw GameLoadingError.missingRequiredAsset(animationID.rawValue) }
    }
  }
}
@MainActor protocol GameLevelRuntimeFactory {
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> GameLevelRuntime
  func makeRuntime(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws -> GameLevelRuntime
}
@MainActor struct DefaultGameLevelRuntimeFactory: GameLevelRuntimeFactory {
  let simulationFactory: any GameSimulationFactory
  let preflight: any AssetPreflighting
  init(
    simulationFactory: any GameSimulationFactory = DefaultGameSimulationFactory(),
    preflight: any AssetPreflighting = DefaultAssetPreflight()
  ) {
    self.simulationFactory = simulationFactory
    self.preflight = preflight
  }
  func makeRuntime(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> GameLevelRuntime
  {
    try makeRuntime(
      levelID: levelID, configuration: configuration, seed: seed, entryPosition: .bottom,
      carryover: nil)
  }
  func makeRuntime(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws -> GameLevelRuntime {
    let simulation = try simulationFactory.makeSimulation(
      levelID: levelID, configuration: configuration, seed: seed, entryPosition: entryPosition,
      carryover: carryover)
    let textureCatalog = TextureCatalog(entries: LevelOneTextureCatalog.entries)
    let animationCatalog = LevelOneAnimationCatalog(textureCatalog: textureCatalog)
    let manifest = try LevelAssetManifest.manifest(for: levelID)
    do {
      try preflight.validate(
        manifest: manifest, textureCatalog: textureCatalog, animationCatalog: animationCatalog)
    } catch let e as TextureCatalogError {
      simulation.dispose()
      throw e.gameLoadingError
    } catch let e as GameLoadingError {
      simulation.dispose()
      throw e
    } catch {
      simulation.dispose()
      throw GameLoadingError.invalidLevelDefinition(levelID)
    }
    return .init(
      simulation: simulation, presentation: simulation.presentationDefinition,
      textureCatalog: textureCatalog, animationCatalog: animationCatalog, assetManifest: manifest)
  }
}
extension TextureCatalogError {
  var gameLoadingError: GameLoadingError {
    switch self {
    case .missingAsset(let id): .missingRequiredAsset(id.rawValue)
    case .invalidRegion(let id): .invalidTextureRegion(id.rawValue)
    }
  }
}
extension LevelAssetManifest {
  static func manifest(for levelID: LevelID) throws -> LevelAssetManifest {
    switch levelID {
    case .levelOne: levelOne
    case .levelTwo: levelTwo
    case .levelThree: levelThree
    case .levelFour: levelFour
    case .levelFive: levelFive
    case .levelSix: levelSix
    case .levelSeven: levelSeven
    case .levelEight: levelEight
    default: throw GameLoadingError.unsupportedLevel(levelID)
    }
  }
  static let levelOne = LevelAssetManifest(
    textureAssetIDs: Set(
      [
        LevelOneRenderAssets.floor, LevelOneRenderAssets.lava, LevelOneRenderAssets.wallFront,
        LevelOneRenderAssets.wallLeft, LevelOneRenderAssets.wallRight,
        LevelOneRenderAssets.exitDoor,
        LevelOneRenderAssets.entryDoor, LevelOneRenderAssets.lidia, LevelOneRenderAssets.coin,
        LevelOneRenderAssets.cabbage, LevelOneRenderAssets.mine, LevelOneRenderAssets.chestClosed,
        LevelOneRenderAssets.chestOpen,
      ] + (1...9).map { RenderAssetID(rawValue: "level-one.coin.\($0)") }
        + (0..<4).flatMap { row in
          (0..<9).map { RenderAssetID(rawValue: "character.lidia.\(row)-\($0)") }
        }),
    animationIDs: Set([
      LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up),
      LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left),
      LevelOneRenderAnimations.lidiaWalk(.right),
    ]))
  static let sharedPlayerTextureAssetIDs = Set(
    (0..<4).flatMap { row in
      (0..<9).map { RenderAssetID(rawValue: "character.lidia.\(row)-\($0)") }
    } + [LevelOneRenderAssets.lidia])
  static let sharedCoinTextureAssetIDs = Set(
    (1...9).map { RenderAssetID(rawValue: "level-one.coin.\($0)") } + [LevelOneRenderAssets.coin])
  static let sharedEnemyTextureAssetIDs = Set(
    [EnemyArchetype.skeleton.asset, EnemyArchetype.flyingTerror.asset]
      + [8, 9, 10, 11].flatMap { row in
        (0..<9).map { RenderAssetID(rawValue: "enemy.skeleton.\(row)-\($0)") }
      }
      + [0, 2, 4, 6].flatMap { row in
        (0..<10).map { RenderAssetID(rawValue: "enemy.flying-terror.\(row)-\($0)") }
      })
  static let levelTwo = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelTwoRenderAssets.floor, LevelTwoRenderAssets.lava, LevelTwoRenderAssets.wallFront,
      LevelTwoRenderAssets.wallLeft, LevelTwoRenderAssets.wallRight, LevelTwoRenderAssets.exitDoor,
      LevelTwoRenderAssets.entryDoor, LevelTwoRenderAssets.smoke, LevelOneRenderAssets.mine,
      LevelOneRenderAssets.cabbage,
    ])
    .union(sharedPlayerTextureAssetIDs)
    .union(sharedCoinTextureAssetIDs)
    .union(sharedEnemyTextureAssetIDs)
    .union((1...3).map { RenderAssetID(rawValue: "level-two.smoke.\($0)") }),
    animationIDs: Set([
      LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up),
      LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left),
      LevelOneRenderAnimations.lidiaWalk(.right), LevelTwoRenderAnimations.enemy(.skeleton, .up),
      LevelTwoRenderAnimations.enemy(.skeleton, .down),
      LevelTwoRenderAnimations.enemy(.skeleton, .left),
      LevelTwoRenderAnimations.enemy(.skeleton, .right),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .up),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .down),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .left),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .right),
    ]))
  static let levelThree = LevelAssetManifest(
    textureAssetIDs: Set([
      LevelThreeRenderAssets.floor, LevelThreeRenderAssets.lava, LevelThreeRenderAssets.wallFront,
      LevelThreeRenderAssets.wallLeft, LevelThreeRenderAssets.wallRight,
      LevelThreeRenderAssets.exitDoor,
      LevelThreeRenderAssets.entryDoor, LevelThreeRenderAssets.smoke, LevelOneRenderAssets.mine,
      LevelOneRenderAssets.cabbage, LevelOneRenderAssets.chestClosed,
      LevelOneRenderAssets.chestOpen,
    ])
    .union(sharedPlayerTextureAssetIDs)
    .union(sharedCoinTextureAssetIDs)
    .union(sharedEnemyTextureAssetIDs)
    .union((1...3).map { RenderAssetID(rawValue: "level-three.smoke.\($0)") }),
    animationIDs: Set([
      LevelOneRenderAnimations.coinSpin, LevelOneRenderAnimations.lidiaWalk(.up),
      LevelOneRenderAnimations.lidiaWalk(.down), LevelOneRenderAnimations.lidiaWalk(.left),
      LevelOneRenderAnimations.lidiaWalk(.right), LevelThreeRenderAnimations.smokeLoop,
      LevelTwoRenderAnimations.enemy(.skeleton, .up),
      LevelTwoRenderAnimations.enemy(.skeleton, .down),
      LevelTwoRenderAnimations.enemy(.skeleton, .left),
      LevelTwoRenderAnimations.enemy(.skeleton, .right),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .up),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .down),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .left),
      LevelTwoRenderAnimations.enemy(.flyingTerror, .right),
    ]))
}
@MainActor protocol GameSimulationFactory {
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> any GameSimulation
  func makeSimulation(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws
    -> any GameSimulation
}
struct DefaultGameSimulationFactory: GameSimulationFactory {
  func makeSimulation(levelID: LevelID, configuration: GameConfiguration, seed: UInt64?) throws
    -> any GameSimulation
  {
    try makeSimulation(
      levelID: levelID, configuration: configuration, seed: seed, entryPosition: .bottom,
      carryover: nil)
  }
  func makeSimulation(
    levelID: LevelID, configuration: GameConfiguration, seed: UInt64?,
    entryPosition: LevelEntryPosition, carryover: PlayerCarryoverState?
  ) throws -> any GameSimulation {
    do {
      switch levelID {
      case .levelOne:
        return try LevelOneSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelTwo:
        return try LevelTwoSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelThree:
        return try LevelThreeSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelFour:
        return try LevelFourSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelFive:
        return try LevelFiveSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelSix:
        return try LevelSixSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelSeven:
        return try LevelSevenSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      case .levelEight:
        return try LevelEightSimulation(
          configuration: configuration, seed: seed ?? UInt64.random(in: 1...UInt64.max),
          entryPosition: entryPosition, carryover: carryover)
      default:
        throw GameLoadingError.unsupportedLevel(levelID)
      }
    } catch let e as GameLoadingError { throw e } catch {
      throw GameLoadingError.spawnFailure(levelID)
    }
  }
}
