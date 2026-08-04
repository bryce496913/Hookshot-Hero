import SpriteKit
import SwiftUI

struct GameplayView: View {
    @ObservedObject var session: GameSession; let returnToMenu: () -> Void
    @State private var scene: GameScene
    init(session: GameSession, returnToMenu: @escaping () -> Void) { self.session=session;self.returnToMenu=returnToMenu;_scene=State(initialValue:GameScene(session:session)) }
    var body: some View {
        VStack(spacing:8) { hud
            if let error=session.initializationError { ContentUnavailableView("Level 1 unavailable",systemImage:"exclamationmark.triangle",description:Text(error)) }
            else { ZStack { SpriteView(scene:scene).aspectRatio(1,contentMode:.fit).background(.black).accessibilityHidden(true).accessibilityIdentifier("levelOneBoard"); if let simulation = session.simulation { GameplayFeedbackOverlay(feedback: simulation.feedbackEvents, reducedMotion: session.configuration.reducedMotion) } } }
            if session.configuration.controlHintsEnabled { Text("Move with the direction pad. Face a direction and tap Grapple.").font(.caption).multilineTextAlignment(.center).accessibilityIdentifier("controlHint") }
            if let sim=session.simulation { GameControlsView(simulation:sim, disabled:!session.canSimulate) }
        }.padding(.horizontal,8).padding(.bottom,4).navigationBarBackButtonHidden().onDisappear { session.simulation?.cancelAllInput() }.overlay { if session.isPaused { pauseOverlay }; if let text=session.dialogue { DialogueOverlay(text:text, continueAction:session.continueDialogue) } }
    }
    private var hud:some View { HStack { Text("Level 1").bold().accessibilityIdentifier("levelTitle");Image("heart.png").resizable().scaledToFit().frame(width:20,height:20).accessibilityHidden(true);Text("Health \(session.health)").accessibilityLabel("Health").accessibilityValue("\(session.health)").accessibilityIdentifier("healthValue");Text("Score \(session.score)").accessibilityLabel("Score").accessibilityValue("\(session.score)").accessibilityIdentifier("scoreValue");Spacer();pauseButton }.padding(10).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)).accessibilityIdentifier("gameplayHUD") }
    private var pauseButton:some View { Button(session.isPaused ? "Resume":"Pause") { if session.isPaused { _ = session.resume() } else { _ = session.pause() } }.buttonStyle(.borderedProminent).accessibilityLabel(session.isPaused ? "Resume game":"Pause game").accessibilityIdentifier(session.isPaused ? "resumeButton":"pauseButton") }
    private var pauseOverlay:some View { VStack(spacing:18){Text("Paused").font(.largeTitle.bold()).accessibilityIdentifier("pauseOverlay");Button("Resume"){session.resume()}.accessibilityIdentifier("overlayResumeButton");Button("Return to Menu",role:.destructive,action:returnToMenu).accessibilityIdentifier("returnToMenuButton")}.padding(30).background(.regularMaterial,in:RoundedRectangle(cornerRadius:20)).zIndex(5) }
}

struct GameControlsView: View {
    @ObservedObject var simulation: LevelOneSimulation; let disabled:Bool
    var body:some View { HStack(spacing:24){ VStack(spacing:2){ DirectionButton(direction:.up,input:simulation.input,isEnabled:!disabled);HStack(spacing:2){DirectionButton(direction:.left,input:simulation.input,isEnabled:!disabled);DirectionButton(direction:.down,input:simulation.input,isEnabled:!disabled);DirectionButton(direction:.right,input:simulation.input,isEnabled:!disabled)}}
        Button("Grapple"){simulation.input.send(.fireHook)}.font(.title3.bold()).frame(minWidth:96,minHeight:60).buttonStyle(.borderedProminent).tint(.orange).disabled(disabled || simulation.player.hookshot.phase != .idle).accessibilityLabel("Fire grapple").accessibilityValue(simulation.player.hookshot.phase.rawValue).accessibilityIdentifier("grappleButton")
    }.frame(maxWidth:.infinity).disabled(disabled).accessibilityElement(children:.contain)
    #if DEBUG
    .overlay { Text("Player row \(simulation.player.position.row) column \(simulation.player.position.column)").font(.caption2).opacity(0.01).accessibilityIdentifier("playerPosition") }
    #endif
    }
}
struct DirectionButton: View {
    let direction: GridDirection
    @ObservedObject var input: GameInputController
    let isEnabled: Bool
    @State private var pressed = false
    @State private var physicalPress = false

    var body: some View {
        Button { if !physicalPress && isEnabled { input.send(.move(direction)) } } label: {
            Image(systemName: symbol).frame(width: 52, height: 44).contentShape(Rectangle())
                .background(.blue.opacity(pressed ? 0.7 : 0.2), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if isEnabled && !pressed { pressed = true; physicalPress = true; input.send(.beginMove(direction)) } }
            .onEnded { _ in resetPressState() })
        .onChange(of: isEnabled) { _, enabled in if !enabled { resetPressState() } }
        .onChange(of: input.cancellationGeneration) { _, _ in resetPressState() }
        .onDisappear(perform: resetPressState)
        .accessibilityLabel("Move \(direction.rawValue)")
        .accessibilityIdentifier("move\(direction.rawValue.capitalized)Button")
    }

    private func resetPressState() {
        let wasPressed = pressed || physicalPress
        pressed = false; physicalPress = false
        if wasPressed { input.send(.endMove(direction)) }
    }
    private var symbol: String { switch direction { case .up: "arrow.up"; case .down: "arrow.down"; case .left: "arrow.left"; case .right: "arrow.right" } }
}

struct GameplayFeedbackOverlay: View {
    let feedback: [GameplayFeedback]
    let reducedMotion: Bool
    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(feedback.enumerated()), id: \.element.id) { _, event in
                Text(event.message)
                    .font(.callout.bold()).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.black.opacity(0.78), in: Capsule()).shadow(radius: 2)
                    .transition(reducedMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel(event.accessibilityAnnouncement)
            }
            Spacer()
        }
        .padding(.top, 12).padding(.horizontal, 8)
        .allowsHitTesting(false).animation(reducedMotion ? nil : .easeOut(duration: 0.2), value: feedback.map(\.id))
    }
}

struct DialogueOverlay:View { let text:String;let continueAction:()->Bool
    var body:some View { VStack(spacing:16){Text("Talking Chest").font(.headline).accessibilityIdentifier("chestDialogue");Text(text).font(.body);Button("Continue"){_ = continueAction()}.buttonStyle(.borderedProminent).accessibilityIdentifier("dialogueContinueButton")}.padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:16)).padding(24).accessibilityElement(children:.contain).accessibilityLabel("Talking Chest. \(text)").zIndex(10) }
}
