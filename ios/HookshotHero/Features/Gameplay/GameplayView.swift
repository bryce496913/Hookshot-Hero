import SpriteKit
import SwiftUI
import UIKit

@MainActor protocol AccessibilityAnnouncing { func announce(_ message: String) }
@MainActor struct UIKitAccessibilityAnnouncer: AccessibilityAnnouncing { func announce(_ message: String) { UIAccessibility.post(notification: .announcement, argument: message) } }
@MainActor final class FeedbackAnnouncementCoordinator: ObservableObject {
    private var announced: Set<UUID> = []
    private let announcer: any AccessibilityAnnouncing
    init(announcer: any AccessibilityAnnouncing = UIKitAccessibilityAnnouncer()) { self.announcer = announcer }
    func update(feedback: [GameplayFeedback]) {
        for event in feedback.sorted(by: { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }) where !announced.contains(event.id) {
            announced.insert(event.id); announcer.announce(event.kind.accessibilityAnnouncement)
        }
    }
}

struct GameplayView: View {
    @ObservedObject var session: GameSession; let returnToMenu: () -> Void
    @State private var scene: GameScene
    @StateObject private var announcementCoordinator = FeedbackAnnouncementCoordinator()
    init(session: GameSession, returnToMenu: @escaping () -> Void) { self.session=session;self.returnToMenu=returnToMenu;_scene=State(initialValue:GameScene(session:session,catalog:session.runtime.textureCatalog,animationCatalog:session.runtime.animationCatalog)) }
    var body: some View {
        VStack(spacing:8) { hud
            ZStack { SpriteView(scene:scene).aspectRatio(1,contentMode:.fit).background(.black).accessibilityHidden(true).accessibilityIdentifier("gameBoard"); GameplayFeedbackOverlay(feedback: session.uiSnapshot.feedback, reducedMotion: session.configuration.reducedMotion) }
            if session.configuration.controlHintsEnabled { Text("Move with the direction pad. Face a direction and tap Grapple.").font(.caption).multilineTextAlignment(.center).accessibilityIdentifier("controlHint") }
            GameControlsView(canMove: session.uiSnapshot.canMove, canGrapple: session.uiSnapshot.canGrapple, inputController: session.simulation.inputController, diagnosticPosition: session.uiSnapshot.diagnosticPlayerPosition)
        }.padding(.horizontal,8).padding(.bottom,4).navigationBarBackButtonHidden().onAppear { announcementCoordinator.update(feedback: session.uiSnapshot.feedback) }.onChange(of: session.runtimeGeneration) { _, _ in scene = GameScene(session: session, catalog: session.runtime.textureCatalog, animationCatalog: session.runtime.animationCatalog) }.onChange(of: session.uiSnapshot.feedback) { _, feedback in announcementCoordinator.update(feedback: feedback) }.onDisappear { session.simulation.cancelAllInput() }.overlay { if session.isPaused { pauseOverlay }; if case .transitioning(let levelID) = session.state { Text("Loading \(levelID == .levelTwo ? "Level 2" : "Level 1")").padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:12)).accessibilityIdentifier("levelLoadingOverlay") }; if let text=session.dialogue { DialogueOverlay(text:text, continueAction:session.continueDialogue) } }
    }
    private var hud:some View { HStack { Text(session.uiSnapshot.levelName).bold().accessibilityIdentifier("levelTitle");Image("heart.png").resizable().scaledToFit().frame(width:20,height:20).accessibilityHidden(true);Text("Health \(session.uiSnapshot.health)").accessibilityLabel("Health").accessibilityValue("\(session.uiSnapshot.health)").accessibilityIdentifier("healthValue");Text("Score \(session.uiSnapshot.score)").accessibilityLabel("Score").accessibilityValue("\(session.uiSnapshot.score)").accessibilityIdentifier("scoreValue");Spacer();pauseButton }.padding(10).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:12)).accessibilityIdentifier("gameplayHUD") }
    private var pauseButton:some View { Button(session.isPaused ? "Resume":"Pause") { if session.isPaused { _ = session.resume() } else { _ = session.pause() } }.buttonStyle(.borderedProminent).accessibilityLabel(session.isPaused ? "Resume game":"Pause game").accessibilityIdentifier(session.isPaused ? "resumeButton":"pauseButton") }
    private var pauseOverlay:some View { VStack(spacing:18){Text("Paused").font(.largeTitle.bold()).accessibilityIdentifier("pauseOverlay");Button("Resume"){session.resume()}.accessibilityIdentifier("overlayResumeButton");Button("Return to Menu",role:.destructive,action:returnToMenu).accessibilityIdentifier("returnToMenuButton")}.padding(30).background(.regularMaterial,in:RoundedRectangle(cornerRadius:20)).zIndex(5) }
}

struct GameControlsView: View {
    let canMove: Bool
    let canGrapple: Bool
    let inputController: GameInputController
    let diagnosticPosition: GridPosition?
    var body: some View {
        HStack(spacing:24) {
            VStack(spacing:2) {
                DirectionButton(direction:.up,input:inputController,isEnabled:canMove)
                HStack(spacing:2) {
                    DirectionButton(direction:.left,input:inputController,isEnabled:canMove)
                    DirectionButton(direction:.down,input:inputController,isEnabled:canMove)
                    DirectionButton(direction:.right,input:inputController,isEnabled:canMove)
                }
            }
            Button("Grapple") { inputController.send(.fireHook) }
                .font(.title3.bold()).frame(minWidth:96,minHeight:60)
                .buttonStyle(.borderedProminent).tint(.orange).disabled(!canGrapple)
                .accessibilityLabel("Fire grapple").accessibilityIdentifier("grappleButton")
        }
        .frame(maxWidth:.infinity).accessibilityElement(children:.contain)
        #if DEBUG
        .overlay {
            if let position = diagnosticPosition {
                Text("Player row \(position.row) column \(position.column)").font(.caption2).opacity(0.01).accessibilityIdentifier("playerPosition")
            }
        }
        #endif
    }
}
struct DirectionButton: View {
    let direction: GridDirection
    @ObservedObject var input: GameInputController
    let isEnabled: Bool

    var body: some View {
        Button { if isEnabled { input.send(.move(direction)) } } label: {
            Image(systemName: symbol).frame(width: 52, height: 44).contentShape(Rectangle())
        }.buttonStyle(DirectionPressButtonStyle(direction: direction, input: input, isEnabled: isEnabled,
                                                cancellationGeneration: input.cancellationGeneration))
.disabled(!isEnabled)
        .accessibilityLabel("Move \(direction.rawValue)")
        .accessibilityIdentifier("move\(direction.rawValue.capitalized)Button")
    }
    private var symbol: String { switch direction { case .up: "arrow.up"; case .down: "arrow.down"; case .left: "arrow.left"; case .right: "arrow.right" } }
}

enum DirectionPressState: Equatable { case idle, pressed, holding }
enum DirectionPressEvent: Equatable { case moveOnce(GridDirection), beginHold(GridDirection), endHold(GridDirection) }
struct DirectionPressController: Equatable {
    private(set) var state: DirectionPressState = .idle
    mutating func press(_ direction: GridDirection) -> [DirectionPressEvent] { guard state == .idle else{return []};state = .pressed;return [] }
    mutating func holdThreshold(_ direction: GridDirection) -> [DirectionPressEvent] { guard state == .pressed else{return []};state = .holding;return [.beginHold(direction)] }
    mutating func release(_ direction: GridDirection) -> [DirectionPressEvent] { defer{state = .idle};switch state{case .pressed:return [.moveOnce(direction)];case .holding:return [.endHold(direction)];case .idle:return []} }
    mutating func cancel(_ direction: GridDirection) -> [DirectionPressEvent] { defer{state = .idle};return state == .holding ? [.endHold(direction)] : [] }
}

private struct DirectionPressButtonStyle: PrimitiveButtonStyle {
    let direction: GridDirection; let input: GameInputController; let isEnabled: Bool; let cancellationGeneration: Int
    func makeBody(configuration: Configuration) -> some View {
        DirectionPressBody(configuration: configuration, direction: direction, input: input,
                           isEnabled: isEnabled, cancellationGeneration: cancellationGeneration)
    }
}

private struct DirectionPressBody: View {
    let configuration: PrimitiveButtonStyleConfiguration; let direction: GridDirection
    @ObservedObject var input: GameInputController; let isEnabled: Bool; let cancellationGeneration: Int
    @State private var controller = DirectionPressController(); @State private var holdTask: Task<Void, Never>?
    var body: some View {
        configuration.label.background(.blue.opacity(controller.state == .idle ? 0.2 : 0.7), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged{_ in begin()}.onEnded{_ in finish()})
            .onChange(of:isEnabled){_,enabled in if !enabled{cancel()}}.onChange(of:cancellationGeneration){_,_ in cancel()}.onDisappear(perform:cancel)
    }
    private func begin(){guard isEnabled,controller.state == .idle else{return};_ = controller.press(direction);holdTask=Task{@MainActor in try? await Task.sleep(for:.milliseconds(300));guard !Task.isCancelled else{return};dispatch(controller.holdThreshold(direction))}}
    private func finish(){holdTask?.cancel();holdTask=nil;dispatch(controller.release(direction))}
    private func cancel(){holdTask?.cancel();holdTask=nil;dispatch(controller.cancel(direction))}
    private func dispatch(_ events:[DirectionPressEvent]){for event in events{switch event{case .moveOnce:configuration.trigger();case .beginHold(let d):input.send(.beginMove(d));case .endHold(let d):input.send(.endMove(d))}}}
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
