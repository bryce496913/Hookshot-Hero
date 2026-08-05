import Combine
import SpriteKit
import UIKit

enum SpriteSheet {
  static func normalizedRect(
    x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, sheetWidth: CGFloat,
    sheetHeight: CGFloat
  ) -> CGRect {
    .init(
      x: x / sheetWidth, y: 1 - ((y + height) / sheetHeight), width: width / sheetWidth,
      height: height / sheetHeight)
  }
}

enum MineDestructionEffectStyle: Equatable { case standard, reducedMotion }
struct MineDestructionEffectDescriptor: Equatable {
  let style: MineDestructionEffectStyle
  let duration: TimeInterval
  let initialRadius: CGFloat
  let finalScale: CGFloat
  var isVisible: Bool { initialRadius > 0 && duration > 0 }
  var scales: Bool { finalScale != 1 }
  static func make(reducedMotion: Bool, duration: TimeInterval) -> Self {
    .init(
      style: reducedMotion ? .reducedMotion : .standard, duration: duration, initialRadius: 1.8,
      finalScale: reducedMotion ? 1 : 1.8)
  }
}

enum TextureCatalogError: LocalizedError {
  case missingAsset(RenderAssetID)
  case invalidRegion(RenderAssetID)
  var errorDescription: String? {
    switch self {
    case .missingAsset(let id): "Required render asset is missing: \(id.rawValue)"
    case .invalidRegion(let id): "Invalid texture region: \(id.rawValue)"
    }
  }
}

struct TextureCatalogEntry {
  let filename: String
  let source: TextureSourceRect?
}
protocol TextureCatalogProviding: AnyObject {
  func texture(for assetID: RenderAssetID) throws -> SKTexture
}
protocol AnimationCatalogProviding: AnyObject {
  func frames(for animationID: RenderAnimationID) throws -> [SKTexture]
}

final class TextureCatalog: TextureCatalogProviding {
  private var cache: [String: SKTexture] = [:]
  private let entries: [RenderAssetID: TextureCatalogEntry]
  init(entries: [RenderAssetID: TextureCatalogEntry] = LevelOneTextureCatalog.entries) {
    self.entries = entries
  }
  func texture(for assetID: RenderAssetID) throws -> SKTexture {
    if let cached = cache[assetID.rawValue] { return cached }
    guard let entry = entries[assetID] else { throw TextureCatalogError.missingAsset(assetID) }
    let texture = try load(entry, assetID: assetID)
    cache[assetID.rawValue] = texture
    return texture
  }
  private func load(_ entry: TextureCatalogEntry, assetID: RenderAssetID) throws -> SKTexture {
    guard let url = Bundle.main.url(forResource: entry.filename, withExtension: nil) else {
      throw TextureCatalogError.missingAsset(assetID)
    }
    let base = SKTexture(imageNamed: url.lastPathComponent)
    base.filteringMode = .nearest
    guard let r = entry.source else { return base }
    guard r.x >= 0, r.y >= 0, r.x + r.width <= r.sheetWidth, r.y + r.height <= r.sheetHeight else {
      throw TextureCatalogError.invalidRegion(assetID)
    }
    let rect = CGRect(
      x: CGFloat(r.x / r.sheetWidth), y: CGFloat(1 - ((r.y + r.height) / r.sheetHeight)),
      width: CGFloat(r.width / r.sheetWidth), height: CGFloat(r.height / r.sheetHeight))
    let slice = SKTexture(rect: rect, in: base)
    slice.filteringMode = .nearest
    return slice
  }
}

final class LevelOneAnimationCatalog: AnimationCatalogProviding {
  private let textureCatalog: any TextureCatalogProviding
  init(textureCatalog: any TextureCatalogProviding) { self.textureCatalog = textureCatalog }
  func frames(for animationID: RenderAnimationID) throws -> [SKTexture] {
    let assets: [RenderAssetID]
    if animationID == LevelOneRenderAnimations.coinSpin {
      assets = (1...9).map { RenderAssetID(rawValue: "level-one.coin.\($0)") }
    } else if animationID.rawValue.hasPrefix("character.lidia.walk.") {
      let direction = String(animationID.rawValue.split(separator: ".").last ?? "right")
      let row = ["up": 0, "left": 1, "down": 2, "right": 3][direction] ?? 3
      assets = (0..<9).map { RenderAssetID(rawValue: "character.lidia.\(row)-\($0)") }
    } else if animationID.rawValue.hasPrefix("enemy.skeleton.walk.") {
      let direction = String(animationID.rawValue.split(separator: ".").last ?? "right")
      let row = ["up": 8, "left": 9, "down": 10, "right": 11][direction] ?? 11
      assets = (0..<9).map { RenderAssetID(rawValue: "enemy.skeleton.\(row)-\($0)") }
    } else if animationID.rawValue.hasPrefix("enemy.flying-terror.walk.") {
      let direction = String(animationID.rawValue.split(separator: ".").last ?? "right")
      let row = ["left": 0, "up": 2, "right": 4, "down": 6][direction] ?? 4
      assets = (0..<10).map { RenderAssetID(rawValue: "enemy.flying-terror.\(row)-\($0)") }
    } else {
      throw TextureCatalogError.missingAsset(.init(rawValue: animationID.rawValue))
    }
    return try assets.map { try textureCatalog.texture(for: $0) }
  }
}

enum LevelOneTextureCatalog {
  static let entries: [RenderAssetID: TextureCatalogEntry] = {
    var e: [RenderAssetID: TextureCatalogEntry] = [:]
    func add(_ id: RenderAssetID, _ file: String, _ r: TextureSourceRect? = nil) {
      e[id] = .init(filename: file, source: r)
    }
    add(.init(rawValue: "level-one.floor"), "floor.png")
    add(.init(rawValue: "level-one.lava"), "lava.png")
    add(.init(rawValue: "level-one.wall.front"), "wallGreyFront.png")
    add(.init(rawValue: "level-one.wall.left"), "wallGreyLeftSide.png")
    add(.init(rawValue: "level-one.wall.right"), "wallGreyRightSide.png")
    add(.init(rawValue: "level-one.door.open"), "DoorGreyOpen.png")
    add(.init(rawValue: "level-one.door.closed"), "DoorGreyClosed.png")
    add(
      .init(rawValue: "level-one.mine"), "bomb.png",
      .init(x: 0, y: 0, width: 20, height: 26, sheetWidth: 120, sheetHeight: 26))
    add(
      .init(rawValue: "level-one.cabbage"), "barrels.png",
      .init(x: 64, y: 32, width: 32, height: 32, sheetWidth: 128, sheetHeight: 64))
    add(
      .init(rawValue: "level-one.chest.closed"), "chests.png",
      .init(x: 291, y: 67, width: 25, height: 25, sheetWidth: 320, sheetHeight: 384))
    add(
      .init(rawValue: "level-one.chest.open"), "chests.png",
      .init(x: 291, y: 95, width: 25, height: 29, sheetWidth: 320, sheetHeight: 384))
    for i in 1...9 { add(.init(rawValue: "level-one.coin.\(i)"), "goldCoin\(i).png") }
    add(.init(rawValue: "level-one.coin"), "goldCoin1.png")
    let directions = [0, 1, 2, 3]
    for direction in directions {
      for frame in 0..<9 {
        add(
          .init(rawValue: "character.lidia.\(direction)-\(frame)"), "lidia.png",
          .init(
            x: Double(frame * 64), y: Double(direction * 64), width: 64, height: 64,
            sheetWidth: 576, sheetHeight: 256))
      }
    }
    add(
      .init(rawValue: "character.lidia"), "lidia.png",
      .init(x: 0, y: 192, width: 64, height: 64, sheetWidth: 576, sheetHeight: 256))
    add(.init(rawValue: "level-two.floor"), "floor.png")
    add(.init(rawValue: "level-two.lava"), "lava.png")
    add(.init(rawValue: "level-two.wall.front"), "wallGreyFront.png")
    add(.init(rawValue: "level-two.wall.left"), "wallGreyLeftSide.png")
    add(.init(rawValue: "level-two.wall.right"), "wallGreyRightSide.png")
    add(.init(rawValue: "level-two.door.open"), "DoorGreyOpen.png")
    add(.init(rawValue: "level-two.door.closed"), "DoorGreyClosed.png")
    add(.init(rawValue: "level-two.smoke"), "smoke1.png")
    add(.init(rawValue: "level-three.floor"), "floor.png")
    add(.init(rawValue: "level-three.lava"), "lava.png")
    add(.init(rawValue: "level-three.wall.front"), "wallGreyFront.png")
    add(.init(rawValue: "level-three.wall.left"), "wallGreyLeftSide.png")
    add(.init(rawValue: "level-three.wall.right"), "wallGreyRightSide.png")
    add(.init(rawValue: "level-three.door.open"), "DoorGreyOpen.png")
    add(.init(rawValue: "level-three.door.closed"), "DoorGreyClosed.png")
    add(.init(rawValue: "level-three.smoke"), "smoke1.png")
    add(
      .init(rawValue: "enemy.skeleton"), "skeleton.png",
      .init(x: 0, y: 704, width: 64, height: 64, sheetWidth: 832, sheetHeight: 1344))
    for row in [8, 9, 10, 11] {
      for frame in 0..<9 {
        add(
          .init(rawValue: "enemy.skeleton.\(row)-\(frame)"), "skeleton.png",
          .init(
            x: Double(frame * 64), y: Double(row * 64), width: 64, height: 64, sheetWidth: 832,
            sheetHeight: 1344))
      }
    }
    add(
      .init(rawValue: "enemy.flying-terror"), "flying_terror.png",
      .init(x: 0, y: 512, width: 128, height: 128, sheetWidth: 4480, sheetHeight: 1024))
    for row in [0, 2, 4, 6] {
      for frame in 0..<10 {
        add(
          .init(rawValue: "enemy.flying-terror.\(row)-\(frame)"), "flying_terror.png",
          .init(
            x: Double(frame * 128), y: Double(row * 128), width: 128, height: 128, sheetWidth: 4480,
            sheetHeight: 1024))
      }
    }
    return e
  }()
}

struct RenderLayoutContext {
  let gridSize: GridSize
  func point(_ p: GridPosition) -> CGPoint {
    .init(x: CGFloat(p.column) + 0.5, y: CGFloat(gridSize.rows - p.row) - 0.5)
  }
  func bottomLeft(_ p: GridPosition, height: Double) -> CGPoint {
    .init(x: CGFloat(p.column), y: CGFloat(gridSize.rows - p.row) - CGFloat(height))
  }
}

@MainActor final class GameScene: SKScene {
  private let session: GameSession
  let runtimeGeneration: Int
  let levelID: LevelID
  private let presentation: LevelPresentationDefinition
  private let catalog: any TextureCatalogProviding
  private let animationCatalog: any AnimationCatalogProviding
  private var effectNodes: [UUID: SKNode] = [:]
  private var completedEffectIDs: Set<UUID> = []
  private(set) var clock = SimulationClock()
  private let world = SKNode()
  private(set) var staticAssetIDs: [RenderAssetID] = []
  private var nodes: [EntityID: SKSpriteNode] = [:]
  private var healthNodes: [EntityID: SKNode] = [:]
  private let chain = SKShapeNode()
  private let hook = SKShapeNode(circleOfRadius: 3)
  private var observation: AnyCancellable?
  private var layout: RenderLayoutContext
  init(
    size: CGSize = .init(width: 600, height: 600), session: GameSession,
    runtime: GameLevelRuntime, generation: Int
  ) {
    self.session = session
    self.runtimeGeneration = generation
    presentation = runtime.presentation
    levelID = runtime.presentation.levelID
    self.catalog = runtime.textureCatalog
    self.animationCatalog = runtime.animationCatalog
    layout = .init(gridSize: presentation.logicalGridSize)
    super.init(size: size)
    scaleMode = .resizeFill
    backgroundColor = .black
  }
  required init?(coder: NSCoder) { nil }
  override func didMove(to view: SKView) {
    build()
    session.runtimeSceneDidAttach(generation: runtimeGeneration, levelID: levelID)
    observation = session.$state.sink { [weak self] _ in self?.clock.reset() }
    clock.reset()
  }
  override func didChangeSize(_ oldSize: CGSize) {
    super.didChangeSize(oldSize)
    layoutWorld()
  }
  override func update(_ currentTime: TimeInterval) {
    guard session.canSimulate else {
      clock.reset()
      return
    }
    session.advance(by: clock.delta(at: currentTime))
    let snapshot = session.simulation.renderSnapshot
    session.consumeDiagnosticPosition(from: snapshot)
    synchronize(using: snapshot)
  }
  override func willMove(from view: SKView) {
    observation?.cancel()
    observation = nil
    clock.reset()
    cleanup()
  }
  private func build() {
    guard world.parent == nil else { return }
    addChild(world)
    do {
      for layer in presentation.tileLayers {
        for tile in layer.tiles {
          try add(
            asset: tile.asset, at: tile.coordinate, size: tile.sizeInCells, anchor: tile.anchor,
            z: layer.zPosition)
          staticAssetIDs.append(tile.asset)
        }
      }
      for item in presentation.staticObjects {
        try add(
          asset: item.asset, at: item.coordinate, size: item.renderSize, anchor: item.anchor,
          z: item.zPosition)
        staticAssetIDs.append(item.asset)
      }
      chain.strokeColor = .white
      chain.lineWidth = 0.35
      hook.fillColor = .systemYellow
      hook.setScale(0.15)
      world.addChild(chain)
      world.addChild(hook)
      layoutWorld()
    } catch {
      AppLog.rendering.error(
        "Static presentation failed: \(error.localizedDescription,privacy:.public)")
    }
  }
  private func cleanup() {
    removeAllActions()
    world.removeAllActions()
    world.removeAllChildren()
    world.removeFromParent()
    nodes.removeAll()
    healthNodes.removeAll()
    effectNodes.removeAll()
    completedEffectIDs.removeAll()
    staticAssetIDs.removeAll()
    chain.path = nil
  }
  private func add(
    asset: RenderAssetID, at coordinate: GridPosition, size: LogicalRenderSize,
    anchor: RenderAnchor, z: Double
  ) throws {
    let n = SKSpriteNode(texture: try catalog.texture(for: asset))
    n.anchorPoint = .init(x: CGFloat(anchor.x), y: CGFloat(anchor.y))
    n.position =
      anchor == .bottomLeft
      ? layout.bottomLeft(coordinate, height: size.height) : layout.point(coordinate)
    n.size = .init(width: CGFloat(size.width), height: CGFloat(size.height))
    n.zPosition = CGFloat(z)
    world.addChild(n)
  }
  private func synchronize(using snapshot: GameRenderSnapshot) {
    sync([snapshot.player] + snapshot.entities)
    syncEffects(snapshot.effects)
    if let g = snapshot.grapple {
      hook.isHidden = false
      chain.isHidden = false
      hook.position = layout.point(g.head)
      let p = CGMutablePath()
      p.move(to: layout.point(g.origin))
      p.addLine(to: hook.position)
      chain.path = p
    } else {
      hook.isHidden = true
      chain.isHidden = true
      chain.path = nil
    }
  }
  private func sync(_ entities: [RenderEntitySnapshot]) {
    let active = Set(entities.map(\.id))
    removeStaleNodes(from: &nodes, keeping: active)
    removeStaleNodes(from: &healthNodes, keeping: active)
    for entity in entities {
      do {
        let node = nodes[entity.id] ?? SKSpriteNode()
        if node.parent == nil {
          world.addChild(node)
          nodes[entity.id] = node
        }
        node.texture =
          try entity.animation.map { animation in
            let frames = try animationCatalog.frames(for: animation.animationID)
            guard !frames.isEmpty else {
              throw TextureCatalogError.missingAsset(
                .init(rawValue: animation.animationID.rawValue))
            }
            return frames[animation.frameIndex % frames.count]
          } ?? catalog.texture(for: entity.asset)
        node.position = layout.point(entity.coordinate)
        node.size = CGSize(
          width: CGFloat(entity.renderSize.width), height: CGFloat(entity.renderSize.height))
        node.anchorPoint = .init(x: CGFloat(entity.anchor.x), y: CGFloat(entity.anchor.y))
        node.zPosition = CGFloat(entity.zPosition)
        node.alpha = CGFloat(entity.opacity)
        node.isHidden = entity.isHidden
        syncHealth(for: entity)
      } catch {
        AppLog.rendering.error(
          "Dynamic asset failed: \(error.localizedDescription,privacy:.public)")
      }
    }
  }

  private func syncHealth(for entity: RenderEntitySnapshot) {
    guard let health = entity.health, health.maximum > 0, !entity.isHidden else {
      healthNodes[entity.id]?.removeFromParent()
      healthNodes.removeValue(forKey: entity.id)
      return
    }
    let container = healthNodes[entity.id] ?? SKNode()
    if container.parent == nil {
      world.addChild(container)
      healthNodes[entity.id] = container
    }
    container.removeAllChildren()
    container.position = layout.point(entity.coordinate)
    container.zPosition = CGFloat(entity.zPosition + 0.5)
    let width = CGFloat(max(entity.renderSize.width, 2.0))
    let y = CGFloat(entity.renderSize.height / 2 + 0.45)
    let background = SKShapeNode(rectOf: CGSize(width: width, height: 0.35), cornerRadius: 0.08)
    background.position = CGPoint(x: 0, y: y)
    background.fillColor = .darkGray
    background.strokeColor = .black
    background.lineWidth = 0.05
    let ratio = CGFloat(max(0, min(health.current, health.maximum))) / CGFloat(health.maximum)
    let fill = SKShapeNode(
      rectOf: CGSize(width: max(0.05, width * ratio), height: 0.23), cornerRadius: 0.06)
    fill.position = CGPoint(x: -(width - width * ratio) / 2, y: y)
    fill.fillColor = ratio > 0.4 ? .systemGreen : .systemRed
    fill.strokeColor = .clear
    container.addChild(background)
    container.addChild(fill)
  }

  private func syncEffects(_ effects: [RenderEffectSnapshot]) {
    let incoming = Set(effects.map(\.id))
    let active = incoming.union(effectNodes.keys.filter { !completedEffectIDs.contains($0) })
    removeStaleNodes(from: &effectNodes, keeping: active)
    for effect in effects
    where effectNodes[effect.id] == nil && !completedEffectIDs.contains(effect.id) {
      let node = SKShapeNode(circleOfRadius: CGFloat(effect.descriptor.initialRadius))
      node.position = layout.point(effect.coordinate)
      node.zPosition = CGFloat(effect.descriptor.zPosition)
      node.fillColor = .systemOrange
      node.strokeColor = .systemYellow
      node.alpha = 0.9
      world.addChild(node)
      effectNodes[effect.id] = node
      var actions: [SKAction] = []
      if effect.descriptor.scales {
        actions.append(
          .scale(to: CGFloat(effect.descriptor.finalScale), duration: effect.descriptor.duration))
      }
      actions.append(.fadeOut(withDuration: effect.descriptor.duration))
      node.run(
        .sequence([
          .group(actions),
          .run { [weak self, weak node] in
            node?.removeFromParent()
            self?.effectNodes.removeValue(forKey: effect.id)
            self?.completedEffectIDs.insert(effect.id)
          },
        ]))
    }
  }
  private func removeStaleNodes<ID: Hashable, Node: SKNode>(
    from nodes: inout [ID: Node], keeping activeIDs: Set<ID>
  ) {
    let staleIDs = nodes.keys.filter { !activeIDs.contains($0) }
    for id in staleIDs {
      nodes[id]?.removeFromParent()
      nodes.removeValue(forKey: id)
    }
  }
  private func layoutWorld() {
    let side = min(size.width, size.height)
    let scale =
      side / CGFloat(max(presentation.logicalGridSize.rows, presentation.logicalGridSize.columns))
    world.setScale(scale)
    world.position = .init(x: (size.width - side) / 2, y: (size.height - side) / 2)
  }
}
