import SpriteKit

@MainActor
final class GameScene: SKScene {
    private let session: GameSession
    private var clock = SimulationClock()
    private let playerNode = SKShapeNode(circleOfRadius: 22)

    init(size: CGSize, session: GameSession) {
        self.session = session
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .init(red: 0.08, green: 0.14, blue: 0.22, alpha: 1)
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        guard session.state == .loading else { return }
        playerNode.fillColor = .systemCyan
        playerNode.strokeColor = .white
        playerNode.position = CGPoint(x: frame.midX, y: frame.midY)
        playerNode.name = "development-player-placeholder"
        addChild(playerNode)
        _ = session.initializeWorld()
        _ = session.start()
        AppLog.rendering.info("GameScene presented")
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = clock.delta(at: currentTime)
        guard session.canSimulate else { return }
        session.advance(by: deltaTime)
        playerNode.position.x += 20 * deltaTime
        if playerNode.position.x > frame.maxX + 22 { playerNode.position.x = frame.minX - 22 }
    }

    override func willMove(from view: SKView) {
        clock.reset()
        removeAllActions()
        session.dispose()
        AppLog.rendering.info("GameScene removed")
    }
}
