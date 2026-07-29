import SpriteKit
import SwiftUI

struct GameplayView: View {
    @ObservedObject var session: GameSession
    let returnToMenu: () -> Void
    @State private var scene: GameScene

    init(session: GameSession, returnToMenu: @escaping () -> Void) {
        self.session = session
        self.returnToMenu = returnToMenu
        _scene = State(initialValue: GameScene(size: CGSize(width: 390, height: 844), session: session))
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene, isPaused: !session.canSimulate)
                .ignoresSafeArea()
                .accessibilityIdentifier("gameplayScene")
            HStack {
                Text("Health \(session.health)")
                Spacer()
                Text("Score \(session.score)")
                Button(session.isPaused ? "Resume" : "Pause") {
                    session.isPaused ? session.resume() : session.pause()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(session.isPaused ? "resumeButton" : "pauseButton")
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .overlay {
            if session.isPaused {
                VStack(spacing: 20) {
                    Text("Paused").font(.largeTitle.bold()).accessibilityIdentifier("pauseOverlay")
                    Button("Resume") { session.resume() }.accessibilityIdentifier("overlayResumeButton")
                    Button("Return to Menu", role: .destructive, action: returnToMenu)
                        .accessibilityIdentifier("returnToMenuButton")
                }
                .padding(32).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .navigationBarBackButtonHidden()
        .onDisappear { session.dispose(); scene.isPaused = true }
    }
}
