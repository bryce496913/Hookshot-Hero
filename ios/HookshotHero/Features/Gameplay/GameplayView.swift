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
        ZStack {
            SpriteView(scene: scene, isPaused: !session.canSimulate)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                hud
                if session.configuration.controlHintsEnabled {
                    Text("Use Pause to suspend this development simulation.")
                        .font(.footnote).padding(8).background(.ultraThinMaterial, in: Capsule())
                        .accessibilityIdentifier("controlHint")
                }
                Spacer()
            }
            .safeAreaPadding(.horizontal)
            .safeAreaPadding(.top, 8)
        }
        .overlay { if session.isPaused { pauseOverlay } }
        .navigationBarBackButtonHidden()
    }

    private var hud: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { health; score; Spacer(minLength: 8); pauseButton }
            VStack(spacing: 10) {
                HStack { health; Spacer(); score }
                pauseButton.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("gameplayHUD")
    }

    private var health: some View {
        Text("Health \(session.health)")
            .accessibilityLabel("Health").accessibilityValue("\(session.health)")
            .accessibilityIdentifier("healthValue")
    }
    private var score: some View {
        Text("Score \(session.score)")
            .accessibilityLabel("Score").accessibilityValue("\(session.score)")
            .accessibilityIdentifier("scoreValue")
    }
    private var pauseButton: some View {
        Button(session.isPaused ? "Resume" : "Pause") { session.isPaused ? session.resume() : session.pause() }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(session.isPaused ? "Resume game" : "Pause game")
            .accessibilityIdentifier(session.isPaused ? "resumeButton" : "pauseButton")
    }
    private var pauseOverlay: some View {
        VStack(spacing: 20) {
            Text("Paused").font(.largeTitle.bold()).accessibilityIdentifier("pauseOverlay")
            Button("Resume") { session.resume() }
                .accessibilityLabel("Resume game").accessibilityIdentifier("overlayResumeButton")
            Button("Return to Menu", role: .destructive, action: returnToMenu)
                .accessibilityIdentifier("returnToMenuButton")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game paused")
        .padding(32).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
