import Combine
import SpriteKit

private enum LegacyAssetMetrics {
    static let logicalPixelsPerCell: CGFloat = 10

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

        guard let simulation = session.simulation else {
            showError(session.initializationError ?? "Level 1 could not be initialized.")
            return
        }

        do {
            try buildFloor()
            try buildLava(simulation.level.lava)
            try buildBoundaryWalls()
            try buildInternalWalls(simulation.level.internalWallAnchors)
            try buildDoors(level: simulation.level)
            try buildChest(at: simulation.level.chestAnchor)
            try buildPlayer(simulation.player)
            buildGrapplePresentation()
            try buildEntities(simulation.entities)
            layoutWorld()
            renderDynamic()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func buildFloor() throws {
        let floorTexture = try loader.texture("floor.png")
        for row in stride(from: 0, to: 60, by: 10) {
            for column in stride(from: 0, to: 60, by: 10) {
                addTile(
                    rows: row..<min(row + 10, 60),
                    columns: column..<min(column + 10, 60),
                    texture: floorTexture,
                    zPosition: 0
                )
            }
        }
    }

    private func buildLava(_ lavaRegions: [GridRegion]) throws {
        let lavaTexture = try loader.texture("lava.png")
        for region in lavaRegions {
            addTile(region, texture: lavaTexture, zPosition: 1)
        }
    }

    private func buildBoundaryWalls() throws {
        let frontTexture = try loader.texture("wallGreyFront.png")
        let leftTexture = try loader.texture("wallGreyLeftSide.png")
        let rightTexture = try loader.texture("wallGreyRightSide.png")

        // Java places 40×40 wall tiles every 40 pixels. The open top door occupies
        // the center tile; the closed bottom door is rendered over a solid boundary.
        for column in stride(from: 0, to: 60, by: 4) {
            if column != 28 {
                addTile(rows: 0..<4, columns: column..<column + 4, texture: frontTexture, zPosition: 2)
            }
            addTile(rows: 56..<60, columns: column..<column + 4, texture: frontTexture, zPosition: 2)
        }

        for row in stride(from: 4, to: 56, by: 4) {
            addTile(rows: row..<row + 4, columns: 0..<4, texture: leftTexture, zPosition: 2)
            addTile(rows: row..<row + 4, columns: 56..<60, texture: rightTexture, zPosition: 2)
        }
    }

    private func buildInternalWalls(_ anchors: [GridPosition]) throws {
        let wallTexture = try loader.texture("wallGreyFront.png")
        for anchor in anchors {
            addTile(
                rows: anchor.row..<anchor.row + 4,
                columns: anchor.column..<anchor.column + 4,
                texture: wallTexture,
                zPosition: 2
            )
        }
    }

    private func buildDoors(level: LevelDefinition) throws {
        let openDoor = SKSpriteNode(texture: try loader.texture("DoorGreyOpen.png"))
        openDoor.anchorPoint = .zero
        openDoor.position = topLeftPoint(row: 0, column: 28, height: 4)
        openDoor.size = .init(width: 4, height: 4)
        openDoor.zPosition = 3
        openDoor.name = "levelOneExitDoor"
        world.addChild(openDoor)

        let closedDoor = SKSpriteNode(texture: try loader.texture("DoorGreyClosed.png"))
        closedDoor.anchorPoint = .zero
        closedDoor.position = topLeftPoint(row: 56, column: 28, height: 4)
        closedDoor.size = .init(width: 4, height: 4)
        closedDoor.zPosition = 3
        closedDoor.name = "levelOneEntryDoor"
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
        node.size = .init(width: columns.count, height: rows.count)
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
        let row: CGFloat = [
            .up: 0,
            .left: 1,
            .down: 2,
            .right: 3
        ][direction] ?? 3

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
            y: CGFloat(60 - position.row) - 0.5
        )
    }

    private func topLeftPoint(row: Int, column: Int, height: Int) -> CGPoint {
        .init(x: CGFloat(column), y: CGFloat(60 - row - height))
    }

    private func renderDynamic() {
        guard let simulation = session.simulation else { return }

        playerNode.position = point(simulation.player.position)
        let walking = simulation.player.movementDirection != nil
            && simulation.player.hookshot.phase == .idle
        let frame = session.configuration.reducedMotion || !walking
            ? 0
            : Int(simulation.player.animationTime / 0.09) % 9

        if let texture = try? lidiaTexture(simulation.player.facing, frame: frame) {
            playerNode.texture = texture
        }

        let activeIDs = Set(simulation.entities.map(\.id))
        for (id, node) in entityNodes where !activeIDs.contains(id) {
            node.removeFromParent()
            entityNodes[id] = nil
        }

        if !session.configuration.reducedMotion {
            let coinFrame = Int(simulation.player.animationTime / 0.08) % 9
            for entity in simulation.entities where entity.kind == .coin {
                if let sprite = entityNodes[entity.id] as? SKSpriteNode {
                    sprite.texture = try? loader.texture("goldCoin\(coinFrame + 1).png")
                }
            }
        }

        if simulation.chestOpen,
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

        let hookshot = simulation.player.hookshot
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

    private func layoutWorld() {
        let side = min(size.width, size.height)
        cellSize = side / 60
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
