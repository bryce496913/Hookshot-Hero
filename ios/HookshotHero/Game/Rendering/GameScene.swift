import Combine
import SpriteKit

@MainActor
final class GameScene: SKScene {
    private let session: GameSession
    private(set) var clock = SimulationClock()
    private let playerNode = SKShapeNode(circleOfRadius: 22)
    private var stateObservation: AnyCancellable?

    init(size: CGSize, session: GameSession) {
        self.session = session
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .init(red: 0.08, green: 0.14, blue: 0.22, alpha: 1)
    }

    required init?(coder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        installPresentationIfNeeded()
        bindSessionState()
        clock.reset()
        isPaused = !session.canSimulate
        if session.state == .loading { _ = session.initializeWorld() }
        if session.state == .initialized { _ = session.start() }
        isPaused = !session.canSimulate
    }

    override func update(_ currentTime: TimeInterval) {
        guard session.canSimulate else { return }
        let deltaTime = clock.delta(at: currentTime)
        session.advance(by: deltaTime)
        guard !session.configuration.reducedMotion else { return }
        playerNode.position.x += 20 * deltaTime
        if playerNode.position.x > frame.maxX + 22 { playerNode.position.x = frame.minX - 22 }
    }

    override func willMove(from view: SKView) {
        clock.reset()
        stateObservation?.cancel()
        stateObservation = nil
        removeAllActions()
        isPaused = true
    }

    private func installPresentationIfNeeded() {
        guard playerNode.parent == nil else { return }
        playerNode.fillColor = .systemCyan
        playerNode.strokeColor = .white
        playerNode.position = CGPoint(x: frame.midX, y: frame.midY)
        playerNode.name = "development-player-placeholder"
        addChild(playerNode)
    }

    private func bindSessionState() {
        stateObservation?.cancel()
        stateObservation = session.$state.sink { [weak self] state in
            guard let self else { return }
            self.clock.reset()
            self.isPaused = state != .running
            if [.won, .lost, .disposed].contains(state) { self.removeAllActions() }
        }
    }
}
