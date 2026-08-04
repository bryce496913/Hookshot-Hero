import Combine
import SpriteKit
import UIKit

enum MineDestructionEffectStyle: Equatable { case standard, reducedMotion }
struct MineDestructionEffectDescriptor: Equatable {
    let style: MineDestructionEffectStyle; let duration: TimeInterval; let initialRadius: CGFloat; let finalScale: CGFloat
    var isVisible: Bool { initialRadius > 0 && duration > 0 }
    var scales: Bool { finalScale != 1 }
    static func make(reducedMotion: Bool, duration: TimeInterval) -> Self {
        .init(style: reducedMotion ? .reducedMotion : .standard, duration: duration,
              initialRadius: 1.8, finalScale: reducedMotion ? 1 : 1.8)
    }
}

private enum LegacyAssetMetrics {
    static let lidiaSheet = CGSize(width: 576, height: 256)
    static let bombSheet = CGSize(width: 120, height: 26)
    static let barrelsSheet = CGSize(width: 128, height: 64)
    static let chestsSheet = CGSize(width: 320, height: 384)
}

enum TextureError: LocalizedError {
    case missing(String)
    case invalidSlice(name: String, rect: CGRect, sheetSize: CGSize)

    var errorDescription: String? {
        switch self {
        case .missing(let name):
            return "Required Level 1 texture is missing: \(name)"
        case .invalidSlice(let name, let rect, let sheetSize):
            return "Texture slice \(rect) is outside \(name) (\(sheetSize.width)×\(sheetSize.height))."
        }
    }
}

final class LegacyTextureLoader {
    private var cache: [String: SKTexture] = [:]

    func texture(_ name: String) throws -> SKTexture {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            throw TextureError.missing(name)
        }
        let texture = SKTexture(imageNamed: url.lastPathComponent)
        texture.filteringMode = .nearest
        cache[name] = texture
        return texture
    }

    func slice(
        _ name: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        sheetWidth: CGFloat,
        sheetHeight: CGFloat
    ) throws -> SKTexture {
        let sourceRect = CGRect(x: x, y: y, width: width, height: height)
        let sheetSize = CGSize(width: sheetWidth, height: sheetHeight)
        guard sourceRect.minX >= 0,
              sourceRect.minY >= 0,
              sourceRect.maxX <= sheetWidth,
              sourceRect.maxY <= sheetHeight else {
            throw TextureError.invalidSlice(name: name, rect: sourceRect, sheetSize: sheetSize)
        }

        let base = try texture(name)
        let normalizedRect = SpriteSheet.normalizedRect(
            x: x,
            y: y,
            width: width,
            height: height,
            sheetWidth: sheetWidth,
            sheetHeight: sheetHeight
        )
        let texture = SKTexture(rect: normalizedRect, in: base)
        texture.filteringMode = .nearest
        return texture
    }
}

enum SpriteSheet {
    static func normalizedRect(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        sheetWidth: CGFloat,
        sheetHeight: CGFloat
    ) -> CGRect {
        .init(
            x: x / sheetWidth,
            y: 1 - ((y + height) / sheetHeight),
            width: width / sheetWidth,
            height: height / sheetHeight
        )
    }
}

@MainActor
final class GameScene: SKScene {
    private let session: GameSession
    private let loader = LegacyTextureLoader()
    private(set) var clock = SimulationClock()

    private let world = SKNode()
    private let chain = SKShapeNode()
    private let hook = SKShapeNode(circleOfRadius: 3)
    private var playerNode = SKSpriteNode()
    private var entityNodes: [EntityID: SKNode] = [:]
    private var feedbackNodes: [UUID: SKNode] = [:]
    private var stateObservation: AnyCancellable?

    private var cellSize: CGFloat = 1
    private var boardOrigin = CGPoint.zero

    init(size: CGSize = .init(width: 600, height: 600), session: GameSession) {
        self.session = session
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        build()
        bind()
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
        renderDynamic()
    }

    override func willMove(from view: SKView) {
        clock.reset()
        stateObservation?.cancel()
        stateObservation = nil
    }

    private func bind() {
        stateObservation?.cancel()
        stateObservation = session.$state.sink { [weak self] _ in
            self?.clock.reset()
        }
    }

    private func build() {
        guard world.parent == nil else { return }
        removeAllChildren()
        addChild(world)

        let snapshot = session.simulation.renderSnapshot

        do {
            try buildFloor()
            try buildLava(snapshot.level.lava)
            try buildBoundaryWalls(snapshot.level.boundary)
            try buildInternalWalls(snapshot.level.internalWallAnchors)
            try buildDoors(snapshot.level.boundary)
            try buildChest(at: snapshot.level.chestAnchor)
            try buildPlayer(snapshot.player)
            buildGrapplePresentation()
            try buildEntities(snapshot.entities)
            layoutWorld()
            renderDynamic()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func buildFloor() throws {
        let texture = try loader.texture("floor.png")
        let grid = session.simulation.renderSnapshot.level.grid
        for row in stride(from: 0, to: grid.rows, by: 10) {
            for column in stride(from: 0, to: grid.columns, by: 10) {
                addTile(
                    rows: row..<min(row + 10, grid.rows),
                    columns: column..<min(column + 10, grid.columns),
                    texture: texture,
                    zPosition: 0
                )
            }
        }
    }

    private func buildLava(_ lavaRegions: [GridRegion]) throws {
        let texture = try loader.texture("lava.png")
        for region in lavaRegions {
            addTile(region, texture: texture, zPosition: 1)
        }
    }

    private func buildBoundaryWalls(_ geometry: LevelBoundaryGeometry) throws {
        let frontTexture = try loader.texture("wallGreyFront.png")
        let leftTexture = try loader.texture("wallGreyLeftSide.png")
        let rightTexture = try loader.texture("wallGreyRightSide.png")

        geometry.topWallRegions.forEach { addTile($0, texture: frontTexture, zPosition: 2) }
        geometry.bottomWallRegions.forEach { addTile($0, texture: frontTexture, zPosition: 2) }
        geometry.leftWallRegions.forEach { addTile($0, texture: leftTexture, zPosition: 2) }
        geometry.rightWallRegions.forEach { addTile($0, texture: rightTexture, zPosition: 2) }
    }

    private func buildInternalWalls(_ anchors: [GridPosition]) throws {
        let texture = try loader.texture("wallGreyFront.png")
        for anchor in anchors {
            addTile(
                rows: anchor.row..<anchor.row + 4,
                columns: anchor.column..<anchor.column + 4,
                texture: texture,
                zPosition: 2
            )
        }
    }

    private func buildDoors(_ geometry: LevelBoundaryGeometry) throws {
        let openDoor = SKSpriteNode(texture: try loader.texture("DoorGreyOpen.png"))
        openDoor.anchorPoint = .zero
        openDoor.position = topLeftPoint(row: geometry.topExitRegion.rows.lowerBound, column: geometry.topExitRegion.columns.lowerBound, height: geometry.topExitRegion.rows.count)
        openDoor.size = .init(width: CGFloat(geometry.topExitRegion.columns.count), height: CGFloat(geometry.topExitRegion.rows.count))
        openDoor.zPosition = 3
        openDoor.name = "levelExitDoor"
        world.addChild(openDoor)

        let closedDoor = SKSpriteNode(texture: try loader.texture("DoorGreyClosed.png"))
        closedDoor.anchorPoint = .zero
        closedDoor.position = topLeftPoint(row: geometry.bottomDoorRegion.rows.lowerBound, column: geometry.bottomDoorRegion.columns.lowerBound, height: geometry.bottomDoorRegion.rows.count)
        closedDoor.size = .init(width: CGFloat(geometry.bottomDoorRegion.columns.count), height: CGFloat(geometry.bottomDoorRegion.rows.count))
        closedDoor.zPosition = 3
        closedDoor.name = "levelEntryDoor"
        world.addChild(closedDoor)
    }

    private func buildChest(at position: GridPosition) throws {
        let texture = try loader.slice(
            "chests.png",
            x: 291,
            y: 67,
            width: 25,
            height: 25,
            sheetWidth: LegacyAssetMetrics.chestsSheet.width,
            sheetHeight: LegacyAssetMetrics.chestsSheet.height
        )
        let chest = SKSpriteNode(texture: texture)
        chest.name = "chest"
        chest.position = point(position)
        chest.size = .init(width: 2.5, height: 2.5)
        chest.zPosition = 5
        world.addChild(chest)
    }

    private func buildPlayer(_ player: PlayerState) throws {
        playerNode = SKSpriteNode(texture: try lidiaTexture(player.facing))
        playerNode.size = .init(width: 5.4, height: 4.4)
        playerNode.zPosition = 8
        playerNode.name = "playerSprite"
        world.addChild(playerNode)
    }

    private func buildGrapplePresentation() {
        chain.strokeColor = .white
        chain.lineWidth = 0.35
        chain.zPosition = 7
        hook.fillColor = .systemYellow
        hook.strokeColor = .white
        hook.setScale(0.15)
        hook.zPosition = 8
        world.addChild(chain)
        world.addChild(hook)
    }

    private func buildEntities(_ entities: [WorldEntity]) throws {
        for entity in entities {
            let entityNode = try node(entity)
            entityNodes[entity.id] = entityNode
            world.addChild(entityNode)
        }
    }

    private func addTile(_ region: GridRegion, texture: SKTexture, zPosition: CGFloat) {
        addTile(
            rows: region.rows,
            columns: region.columns,
            texture: texture,
            zPosition: zPosition
        )
    }

    private func addTile(
        rows: Range<Int>,
        columns: Range<Int>,
        texture: SKTexture,
        zPosition: CGFloat
    ) {
        let node = SKSpriteNode(texture: texture)
        node.anchorPoint = .zero
        node.position = topLeftPoint(
            row: rows.lowerBound,
            column: columns.lowerBound,
            height: rows.count
        )
        node.size = .init(width: CGFloat(columns.count), height: CGFloat(rows.count))
        node.zPosition = zPosition
        world.addChild(node)
    }

    private func node(_ entity: WorldEntity) throws -> SKNode {
        let texture: SKTexture
        let logicalSize: CGSize

        switch entity.kind {
        case .coin:
            texture = try loader.texture("goldCoin1.png")
            logicalSize = .init(width: 2, height: 2)
        case .mine:
            texture = try loader.slice(
                "bomb.png",
                x: 0,
                y: 0,
                width: 20,
                height: 26,
                sheetWidth: LegacyAssetMetrics.bombSheet.width,
                sheetHeight: LegacyAssetMetrics.bombSheet.height
            )
            logicalSize = .init(width: 2, height: 2.6)
        case .cabbage:
            texture = try loader.slice(
                "barrels.png",
                x: 64,
                y: 32,
                width: 32,
                height: 32,
                sheetWidth: LegacyAssetMetrics.barrelsSheet.width,
                sheetHeight: LegacyAssetMetrics.barrelsSheet.height
            )
            logicalSize = .init(width: 3.2, height: 3.2)
        }

        let node = SKSpriteNode(texture: texture)
        node.position = point(entity.position)
        node.size = logicalSize
        node.zPosition = 6
        node.name = "entity-\(entity.id.rawValue.uuidString)"
        return node
    }

    private func lidiaTexture(_ direction: GridDirection, frame: Int = 0) throws -> SKTexture {
        let row: CGFloat = [.up: 0, .left: 1, .down: 2, .right: 3][direction] ?? 3
        return try loader.slice(
            "lidia.png",
            x: CGFloat(frame % 9) * 64,
            y: row * 64,
            width: 64,
            height: 64,
            sheetWidth: LegacyAssetMetrics.lidiaSheet.width,
            sheetHeight: LegacyAssetMetrics.lidiaSheet.height
        )
    }

    private func point(_ position: GridPosition) -> CGPoint {
        .init(
            x: CGFloat(position.column) + 0.5,
            y: CGFloat(session.simulation.renderSnapshot.level.grid.rows - position.row) - 0.5
        )
    }

    private func topLeftPoint(row: Int, column: Int, height: Int) -> CGPoint {
        .init(x: CGFloat(column), y: CGFloat(session.simulation.renderSnapshot.level.grid.rows - row - height))
    }

    private func renderDynamic() {
        let snapshot = session.simulation.renderSnapshot

        playerNode.position = point(snapshot.player.position)
        let walking = snapshot.player.movementDirection != nil
            && snapshot.player.hookshot.phase == .idle
        let frame = session.configuration.reducedMotion || !walking
            ? 0
            : Int(snapshot.player.animationTime / 0.09) % 9
        if let texture = try? lidiaTexture(snapshot.player.facing, frame: frame) {
            playerNode.texture = texture
        }

        let activeIDs = Set(snapshot.entities.map(\.id))
        let staleIDs = entityNodes.keys.filter { !activeIDs.contains($0) }
        for id in staleIDs {
            entityNodes[id]?.removeFromParent()
            entityNodes.removeValue(forKey: id)
        }

        synchronizeFeedback(snapshot.feedback)

        if !session.configuration.reducedMotion {
            let coinFrame = Int(snapshot.player.animationTime / 0.08) % 9
            for entity in snapshot.entities where entity.kind == .coin {
                if let sprite = entityNodes[entity.id] as? SKSpriteNode {
                    sprite.texture = try? loader.texture("goldCoin\(coinFrame + 1).png")
                }
            }
        }

        if snapshot.chestOpen,
           let chest = world.childNode(withName: "chest") as? SKSpriteNode,
           let openTexture = try? loader.slice(
               "chests.png",
               x: 291,
               y: 95,
               width: 25,
               height: 29,
               sheetWidth: LegacyAssetMetrics.chestsSheet.width,
               sheetHeight: LegacyAssetMetrics.chestsSheet.height
           ) {
            chest.texture = openTexture
            chest.size = .init(width: 2.5, height: 2.9)
        }

        let hookshot = snapshot.player.hookshot
        if hookshot.phase != .idle, let head = hookshot.head {
            hook.isHidden = false
            chain.isHidden = false
            hook.position = point(head)
            let path = CGMutablePath()
            path.move(to: playerNode.position)
            path.addLine(to: hook.position)
            chain.path = path
        } else {
            hook.isHidden = true
            chain.isHidden = true
            chain.path = nil
        }
    }

    private func synchronizeFeedback(_ feedback: [GameplayFeedback]) {
        let activeIDs = Set(feedback.map(\.id))
        let staleIDs = feedbackNodes.keys.filter { !activeIDs.contains($0) }
        for id in staleIDs { feedbackNodes[id]?.removeFromParent(); feedbackNodes.removeValue(forKey: id) }
        for event in feedback where feedbackNodes[event.id] == nil {
            let container = SKNode(); container.name = "feedback-\(event.id.uuidString)"; container.position = point(event.coordinate ?? session.simulation.renderSnapshot.player.position); container.zPosition = 20
            if case .mineDestroyed = event.kind {
                let descriptor = MineDestructionEffectDescriptor.make(reducedMotion: session.configuration.reducedMotion, duration: event.duration)
                let burst = SKShapeNode(circleOfRadius: descriptor.initialRadius); burst.strokeColor = .systemOrange; burst.lineWidth = 0.5; burst.fillColor = .systemRed.withAlphaComponent(0.35); container.addChild(burst)
                let fade = SKAction.fadeOut(withDuration: descriptor.duration)
                burst.run(descriptor.scales ? .group([.scale(to: descriptor.finalScale, duration: descriptor.duration), fade]) : fade)
            }
            feedbackNodes[event.id] = container; world.addChild(container)
            UIAccessibility.post(notification: .announcement, argument: event.accessibilityAnnouncement)
        }
    }

    private func layoutWorld() {
        let side = min(size.width, size.height)
        let grid = session.simulation.renderSnapshot.level.grid
        cellSize = side / CGFloat(max(grid.rows, grid.columns))
        boardOrigin = .init(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2
        )
        world.setScale(cellSize)
        world.position = boardOrigin
    }

    private func showError(_ message: String) {
        removeAllChildren()
        let box = SKShapeNode(
            rectOf: .init(width: max(size.width - 30, 100), height: 100),
            cornerRadius: 12
        )
        box.fillColor = .systemRed
        box.position = .init(x: size.width / 2, y: size.height / 2)

        let label = SKLabelNode(text: message)
        label.fontSize = 14
        label.numberOfLines = 3
        label.preferredMaxLayoutWidth = max(size.width - 60, 80)
        label.verticalAlignmentMode = .center
        box.addChild(label)
        addChild(box)
    }
}
