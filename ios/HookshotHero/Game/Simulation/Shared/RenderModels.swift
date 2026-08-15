import Foundation

struct RenderAssetID: Hashable, Codable, Sendable { let rawValue: String }
struct RenderAnimationID: Hashable, Codable, Sendable { let rawValue: String }
struct RenderLayerID: Hashable, Codable, Sendable { let rawValue: String }
struct LogicalRenderSize: Equatable, Sendable {
  let width: Double
  let height: Double
}
struct RenderAnchor: Equatable, Sendable {
  let x: Double
  let y: Double
  static let center = Self(x: 0.5, y: 0.5)
  static let bottomLeft = Self(x: 0, y: 0)
}
enum RenderOrientation: String, Sendable { case up, down, left, right, none }
struct TextureSourceRect: Equatable, Sendable {
  let x, y, width, height, sheetWidth, sheetHeight: Double
}
struct RenderAnimationSnapshot: Equatable, Sendable {
  let animationID: RenderAnimationID
  let frameIndex: Int
}
struct BackgroundRenderDescriptor: Sendable { let colorName: String }
struct TileRenderPlacement: Sendable {
  let coordinate: GridPosition
  let sizeInCells: LogicalRenderSize
  let asset: RenderAssetID
  let anchor: RenderAnchor
}
struct TileLayerRenderDescriptor: Sendable {
  let id: RenderLayerID
  let zPosition: Double
  let tiles: [TileRenderPlacement]
}
struct StaticRenderDescriptor: Sendable {
  let id: EntityID
  let asset: RenderAssetID
  let coordinate: GridPosition
  let renderSize: LogicalRenderSize
  let anchor: RenderAnchor
  let zPosition: Double
  let animationID: RenderAnimationID?
  init(
    id: EntityID, asset: RenderAssetID, coordinate: GridPosition, renderSize: LogicalRenderSize,
    anchor: RenderAnchor, zPosition: Double, animationID: RenderAnimationID? = nil
  ) {
    self.id = id
    self.asset = asset
    self.coordinate = coordinate
    self.renderSize = renderSize
    self.anchor = anchor
    self.zPosition = zPosition
    self.animationID = animationID
  }
}
struct LevelPresentationDefinition: Sendable {
  let levelID: LevelID
  let logicalGridSize: GridSize
  let background: BackgroundRenderDescriptor
  let tileLayers: [TileLayerRenderDescriptor]
  let staticObjects: [StaticRenderDescriptor]
}
struct RenderEntitySnapshot: Identifiable, Sendable {
  let id: EntityID
  let asset: RenderAssetID
  let coordinate: GridPosition
  let renderSize: LogicalRenderSize
  let anchor: RenderAnchor
  let zPosition: Double
  let orientation: RenderOrientation
  let animation: RenderAnimationSnapshot?
  let opacity: Double
  let isHidden: Bool
  let health: RenderHealthSnapshot?
  init(
    id: EntityID, asset: RenderAssetID, coordinate: GridPosition, renderSize: LogicalRenderSize,
    anchor: RenderAnchor, zPosition: Double, orientation: RenderOrientation,
    animation: RenderAnimationSnapshot?, opacity: Double, isHidden: Bool,
    health: RenderHealthSnapshot? = nil
  ) {
    self.id = id
    self.asset = asset
    self.coordinate = coordinate
    self.renderSize = renderSize
    self.anchor = anchor
    self.zPosition = zPosition
    self.orientation = orientation
    self.animation = animation
    self.opacity = opacity
    self.isHidden = isHidden
    self.health = health
  }
}
struct RenderHealthSnapshot: Equatable, Sendable {
  let current: Int
  let maximum: Int
}
struct GrappleRenderSnapshot: Sendable {
  let origin: GridPosition
  let head: GridPosition
}
struct RenderEffectDescriptor: Equatable, Sendable {
  let duration: TimeInterval
  let initialRadius: Double
  let finalScale: Double
  let zPosition: Double
  var scales: Bool { finalScale != 1 }
  static func mineDestruction(reducedMotion: Bool) -> Self {
    .init(duration: 0.35, initialRadius: 1.8, finalScale: reducedMotion ? 1 : 1.8, zPosition: 9)
  }
  static func enemyDefeat(reducedMotion: Bool) -> Self {
    .init(duration: 0.4, initialRadius: 2.2, finalScale: reducedMotion ? 1 : 2, zPosition: 9)
  }
}
struct RenderEffectSnapshot: Identifiable, Equatable, Sendable {
  let id: UUID
  let coordinate: GridPosition
  let descriptor: RenderEffectDescriptor
  let createdAt: TimeInterval
}
struct GameRenderSnapshot: Sendable {
  let player: RenderEntitySnapshot
  let entities: [RenderEntitySnapshot]
  let grapple: GrappleRenderSnapshot?
  let effects: [RenderEffectSnapshot]
}
