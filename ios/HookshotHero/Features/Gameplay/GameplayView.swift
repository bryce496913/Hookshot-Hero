import SpriteKit
import SwiftUI

struct GameplayView: View {
    @ObservedObject var session: GameSession; let returnToMenu: () -> Void
    @State private var scene: GameScene
    init(session: GameSession, returnToMenu: @escaping () -> Void) { self.session=session;self.returnToMenu=returnToMenu;_scene=State(initialValue:GameScene(session:session)) }
    var body: some View {
        VStack(spacing:8) { hud
            if let error=session.initializationError { ContentUnavailableView("Level 1 unavailable",systemImage:"exclamationmark.triangle",description:Text(error)) }
            else { SpriteView(scene:scene).aspectRatio(1,contentMode:.fit).background(.black).accessibilityHidden(true).accessibilityIdentifier("levelOneBoard") }
            if session.configuration.controlHintsEnabled { Text("Move with the direction pad. Face a direction and tap Hook to grapple.").font(.caption).multilineTextAlignment(.center).accessibilityIdentifier("controlHint") }
            if let sim=session.simulation { GameControlsView(simulation:sim, disabled:!session.canSimulate) }
        }.padding(.horizontal,8).padding(.bottom,4).navigationBarBackButtonHidden().overlay { if session.isPaused { pauseOverlay }; if let sim=session.simulation { DialogueOverlay(simulation:sim) } }
    }
    private var hud:some View { HStack { Text("Level 1").bold().accessibilityIdentifier("levelTitle");Text("Health \(session.health)").accessibilityLabel("Health").accessibilityValue("\(session.health)").accessibilityIdentifier("healthValue");Text("Score \(session.score)").accessibilityLabel("Score").accessibilityValue("\(session.score)").accessibilityIdentifier("scoreValue");Spacer();pauseButton }.padding(10).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)).accessibilityIdentifier("gameplayHUD") }
    private var pauseButton:some View { Button(session.isPaused ? "Resume":"Pause") { if session.isPaused { _ = session.resume() } else { _ = session.pause() } }.buttonStyle(.borderedProminent).accessibilityLabel(session.isPaused ? "Resume game":"Pause game").accessibilityIdentifier(session.isPaused ? "resumeButton":"pauseButton") }
    private var pauseOverlay:some View { VStack(spacing:18){Text("Paused").font(.largeTitle.bold()).accessibilityIdentifier("pauseOverlay");Button("Resume"){session.resume()}.accessibilityIdentifier("overlayResumeButton");Button("Return to Menu",role:.destructive,action:returnToMenu).accessibilityIdentifier("returnToMenuButton")}.padding(30).background(.regularMaterial,in:RoundedRectangle(cornerRadius:20)).zIndex(5) }
}

struct GameControlsView: View {
    @ObservedObject var simulation: LevelOneSimulation; let disabled:Bool
    var body:some View { HStack(spacing:24){ VStack(spacing:2){ DirectionButton(direction:.up,input:simulation.input);HStack(spacing:2){DirectionButton(direction:.left,input:simulation.input);DirectionButton(direction:.down,input:simulation.input);DirectionButton(direction:.right,input:simulation.input)}}
        Button("Hook"){simulation.input.send(.fireHook)}.font(.title3.bold()).frame(minWidth:88,minHeight:60).buttonStyle(.borderedProminent).tint(.orange).disabled(disabled || simulation.player.hookshot.phase != .idle).accessibilityLabel("Fire hook").accessibilityValue(simulation.player.hookshot.phase.rawValue).accessibilityIdentifier("hookButton")
    }.frame(maxWidth:.infinity).disabled(disabled).accessibilityElement(children:.contain)
    #if DEBUG
    .accessibilityValue("Player row \(simulation.player.position.row) column \(simulation.player.position.column); hook \(simulation.player.hookshot.phase.rawValue)")
    #endif
    }
}
struct DirectionButton:View { let direction:GridDirection;let input:GameInputController;@State private var pressed=false
    var body:some View { Image(systemName:symbol).frame(width:52,height:44).contentShape(Rectangle()).background(.blue.opacity(pressed ? 0.7:0.2),in:RoundedRectangle(cornerRadius:9)).gesture(DragGesture(minimumDistance:0).onChanged{_ in if !pressed{pressed=true;input.send(.beginMove(direction))}}.onEnded{_ in pressed=false;input.send(.endMove(direction))}).accessibilityLabel("Move \(direction.rawValue)").accessibilityIdentifier("move\(direction.rawValue.capitalized)Button") }
    var symbol:String { switch direction{case .up:"arrow.up";case .down:"arrow.down";case .left:"arrow.left";case .right:"arrow.right"} }
}
struct DialogueOverlay:View { @ObservedObject var simulation:LevelOneSimulation
    var body:some View { if let text=simulation.dialogue { VStack(spacing:16){Text("Talking Chest").font(.headline);Text(text).font(.body);Button("Continue"){simulation.dialogue=nil}.buttonStyle(.borderedProminent)}.padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:16)).padding(24).accessibilityElement(children:.contain).accessibilityLabel("Talking Chest. \(text)").zIndex(10) } }
}
