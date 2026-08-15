import SpriteKit
import SwiftUI
import UIKit

@MainActor protocol AccessibilityAnnouncing { func announce(_ message: String) }
@MainActor struct UIKitAccessibilityAnnouncer: AccessibilityAnnouncing {
  func announce(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
  }
}
@MainActor final class FeedbackAnnouncementCoordinator: ObservableObject {
  private var announced: Set<UUID> = []
  private let announcer: any AccessibilityAnnouncing
  init(announcer: any AccessibilityAnnouncing = UIKitAccessibilityAnnouncer()) {
    self.announcer = announcer
  }
  func update(feedback: [GameplayFeedback]) {
    for event in feedback.sorted(by: {
      $0.createdAt == $1.createdAt
        ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
    }) where !announced.contains(event.id) {
      announced.insert(event.id)
      announcer.announce(event.kind.accessibilityAnnouncement)
    }
  }
}

struct GameplayView: View {
  @ObservedObject var session: GameSession
  let returnToMenu: () -> Void
  @State private var scene: GameScene
  @StateObject private var announcementCoordinator = FeedbackAnnouncementCoordinator()
  init(session: GameSession, returnToMenu: @escaping () -> Void) {
    self.session = session
    self.returnToMenu = returnToMenu
    _scene = State(
      initialValue: GameScene(
        session: session, runtime: session.runtime, generation: session.runtimeGeneration))
  }
  var body: some View {
    VStack(spacing: 8) {
      hud
      ZStack {
        SpriteView(scene: scene).id(scene.runtimeGeneration).aspectRatio(1, contentMode: .fit)
          .background(AppTheme.Colors.background).accessibilityHidden(true).accessibilityIdentifier(
            "gameBoard")
        GameplayFeedbackOverlay(
          feedback: session.uiSnapshot.feedback, reducedMotion: session.configuration.reducedMotion)
      }
      if session.configuration.controlHintsEnabled {
        Text(
          "Move with the joystick. Tap Grapple to fire in the direction you're facing."
        ).appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.text.opacity(0.7))
          .multilineTextAlignment(.center).accessibilityIdentifier("controlHint")
      }
      GameControlsView(
        canMove: session.uiSnapshot.canMove, canGrapple: session.uiSnapshot.canGrapple,
        inputController: session.simulation.inputController,
        diagnosticPosition: session.uiSnapshot.diagnosticPlayerPosition)
    }.padding(.horizontal, 8).padding(.bottom, 4).background(AppTheme.Colors.background)
      .navigationBarBackButtonHidden().appNavigationStyle().onAppear {
        announcementCoordinator.update(feedback: session.uiSnapshot.feedback)
      }.onChange(of: session.runtimeGeneration) { _, generation in
        scene = GameScene(session: session, runtime: session.runtime, generation: generation)
      }.onChange(of: session.uiSnapshot.feedback) { _, feedback in
        announcementCoordinator.update(feedback: feedback)
      }.onDisappear { session.simulation.cancelAllInput() }.overlay {
        if session.isPaused { pauseOverlay }
        if case .transitioning(let levelID) = session.state {
          Text(
            "Loading \(levelID.displayName)"
          ).appTextStyle(.h2).padding().appSurface(cornerRadius: 12)
            .accessibilityIdentifier("levelLoadingOverlay")
        }
        if let text = session.dialogue {
          DialogueOverlay(text: text, continueAction: session.continueDialogue)
        }
      }
  }
  private var hud: some View {
    HStack {
      Text(session.uiSnapshot.levelName).appTextStyle(.h2).accessibilityIdentifier("levelTitle")
      Image("heart.png").resizable().scaledToFit().frame(width: 20, height: 20).accessibilityHidden(
        true)
      Text("Health \(session.uiSnapshot.health)").appTextStyle(.h2).accessibilityLabel("Health")
        .accessibilityValue(
          "\(session.uiSnapshot.health)"
        ).accessibilityIdentifier("healthValue")
      Text("Score \(session.uiSnapshot.score)").appTextStyle(.h2).foregroundStyle(
        AppTheme.Colors.highlight
      ).accessibilityLabel("Score").accessibilityValue(
        "\(session.uiSnapshot.score)"
      ).accessibilityIdentifier("scoreValue")
      Spacer()
      pauseButton
    }.padding(10).appSurface(cornerRadius: 12)
      .accessibilityIdentifier("gameplayHUD")
  }
  private var pauseButton: some View {
    Button(session.isPaused ? "Resume" : "Pause") {
      if session.isPaused { _ = session.resume() } else { _ = session.pause() }
    }.buttonStyle(AppPrimaryButtonStyle()).accessibilityLabel(
      session.isPaused ? "Resume game" : "Pause game"
    ).accessibilityIdentifier(session.isPaused ? "resumeButton" : "pauseButton")
  }
  private var pauseOverlay: some View {
    VStack(spacing: 18) {
      Text("Paused").appTextStyle(.h1).accessibilityIdentifier("pauseOverlay")
      Button("Resume") { session.resume() }.buttonStyle(AppPrimaryButtonStyle())
        .accessibilityIdentifier("overlayResumeButton")
      Button("Return to Menu", role: .destructive, action: returnToMenu).buttonStyle(
        AppHighlightButtonStyle()
      ).accessibilityIdentifier(
        "returnToMenuButton")
    }.padding(30).appSurface(cornerRadius: 20).padding(24).background(
      AppTheme.Colors.background.opacity(0.72)
    ).zIndex(5)
  }
}

struct GameControlsView: View {
  let canMove: Bool
  let canGrapple: Bool
  let inputController: GameInputController
  let diagnosticPosition: GridPosition?
  var body: some View {
    HStack(spacing: 24) {
      VirtualJoystickView(input: inputController, isEnabled: canMove)
      Button("Grapple") { inputController.send(.fireHook) }
        .appTextStyle(.h3).frame(minWidth: 96, minHeight: 60)
        .buttonStyle(AppHighlightButtonStyle()).disabled(!canGrapple)
        .accessibilityLabel("Fire grapple").accessibilityIdentifier("grappleButton")
    }
    .frame(maxWidth: .infinity).accessibilityElement(children: .contain)
    #if DEBUG
      .overlay {
        if let position = diagnosticPosition {
          Text("Player row \(position.row) column \(position.column)").appTextStyle(.paragraph)
          .opacity(0.01)
          .accessibilityIdentifier("playerPosition")
        }
      }
    #endif
  }
}

struct VirtualJoystickState: Equatable {
  var displacement: CGVector = .zero
  var activeDirection: GridDirection?
}

struct VirtualJoystickController: Equatable {
  static let deadZone: CGFloat = 0.22
  private(set) var state = VirtualJoystickState()

  static func direction(for displacement: CGVector, usableRadius: CGFloat) -> GridDirection? {
    guard usableRadius > 0,
      hypot(displacement.dx, displacement.dy) / usableRadius >= deadZone
    else { return nil }
    if abs(displacement.dx) > abs(displacement.dy) {
      return displacement.dx < 0 ? .left : .right
    }
    return displacement.dy < 0 ? .up : .down
  }

  mutating func update(displacement raw: CGVector, usableRadius: CGFloat) -> [GameCommand] {
    let length = hypot(raw.dx, raw.dy)
    let scale = length > usableRadius && length > 0 ? usableRadius / length : 1
    let clamped = CGVector(dx: raw.dx * scale, dy: raw.dy * scale)
    let direction = Self.direction(for: clamped, usableRadius: usableRadius)
    state.displacement = direction == nil ? .zero : clamped
    guard direction != state.activeDirection else { return [] }
    var commands: [GameCommand] = []
    if let old = state.activeDirection { commands.append(.endMove(old)) }
    if let direction { commands.append(.beginMove(direction)) }
    state.activeDirection = direction
    return commands
  }

  mutating func cancel() -> [GameCommand] {
    defer { state = VirtualJoystickState() }
    return state.activeDirection.map { [.endMove($0)] } ?? []
  }
}

struct VirtualJoystickView: View {
  private static let baseSize: CGFloat = 124
  private static let knobSize: CGFloat = 54
  private static let usableRadius = (baseSize - knobSize) / 2
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ObservedObject var input: GameInputController
  let isEnabled: Bool
  @State private var controller = VirtualJoystickController()

  var body: some View {
    ZStack {
      Circle().fill(AppTheme.Colors.surface)
      Circle().stroke(
        AppTheme.Colors.accent.opacity(controller.state.activeDirection == nil ? 0.45 : 1),
        lineWidth: controller.state.activeDirection == nil ? 2 : 3)
      cardinalMarkers
      Circle()
        .fill(
          controller.state.activeDirection == nil
            ? AppTheme.Colors.text.opacity(0.82) : AppTheme.Colors.accent
        )
        .frame(width: Self.knobSize, height: Self.knobSize)
        .overlay(Circle().stroke(AppTheme.Colors.text.opacity(0.35), lineWidth: 1))
        .offset(x: controller.state.displacement.dx, y: controller.state.displacement.dy)
    }
    .frame(width: Self.baseSize, height: Self.baseSize)
    .contentShape(Circle())
    .opacity(isEnabled ? 1 : 0.42)
    .gesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .onChanged { value in
          guard isEnabled else { return }
          update(
            CGVector(
              dx: value.location.x - Self.baseSize / 2,
              dy: value.location.y - Self.baseSize / 2))
        }
        .onEnded { _ in cancel() }
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Movement joystick")
    .accessibilityIdentifier("movementJoystick")
    .accessibilityAddTraits(isEnabled ? AccessibilityTraits() : .isStaticText)
    .overlay { accessibilityButtons }
    .disabled(!isEnabled)
    .onChange(of: isEnabled) { _, enabled in if !enabled { cancel() } }
    .onChange(of: input.cancellationGeneration) { _, _ in cancel() }
    .onChange(of: scenePhase) { _, phase in if phase != .active { cancel() } }
    .onDisappear(perform: cancel)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: controller.state.displacement)
  }

  private var cardinalMarkers: some View {
    ForEach(GridDirection.allCases, id: \.rawValue) { direction in
      Image(systemName: symbol(for: direction))
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(
          controller.state.activeDirection == direction
            ? AppTheme.Colors.accent : AppTheme.Colors.text.opacity(0.55)
        )
        .offset(markerOffset(for: direction))
        .accessibilityHidden(true)
    }
  }

  private var accessibilityButtons: some View {
    ForEach(GridDirection.allCases, id: \.rawValue) { direction in
      Button("Move \(direction.rawValue.capitalized)") {
        if isEnabled { input.send(.move(direction)) }
      }
      .disabled(!isEnabled)
      .accessibilityIdentifier("move\(direction.rawValue.capitalized)Button")
      .frame(width: 1, height: 1).opacity(0.001)
    }
  }

  private func update(_ displacement: CGVector) {
    dispatch(controller.update(displacement: displacement, usableRadius: Self.usableRadius))
  }
  private func cancel() {
    dispatch(controller.cancel())
  }
  private func dispatch(_ commands: [GameCommand]) {
    commands.forEach(input.send)
  }
  private func symbol(for direction: GridDirection) -> String { "arrow.\(direction.rawValue)" }
  private func markerOffset(for direction: GridDirection) -> CGSize {
    switch direction {
    case .up: .init(width: 0, height: -47)
    case .down: .init(width: 0, height: 47)
    case .left: .init(width: -47, height: 0)
    case .right: .init(width: 47, height: 0)
    }
  }
}

struct GameplayFeedbackOverlay: View {
  let feedback: [GameplayFeedback]
  let reducedMotion: Bool
  var body: some View {
    VStack(spacing: 6) {
      ForEach(Array(feedback.enumerated()), id: \.element.id) { _, event in
        Text(event.message)
          .appTextStyle(feedbackStyle(for: event)).foregroundStyle(feedbackColor(for: event))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 10).padding(.vertical, 6)
          .background(AppTheme.Colors.surface.opacity(0.92), in: Capsule()).shadow(radius: 2)
          .transition(reducedMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
          .accessibilityLabel(event.accessibilityAnnouncement)
      }
      Spacer()
    }
    .padding(.top, 12).padding(.horizontal, 8)
    .allowsHitTesting(false).animation(
      reducedMotion ? nil : .easeOut(duration: 0.2), value: feedback.map(\.id))
  }
  private func feedbackStyle(for event: GameplayFeedback) -> AppTextStyle {
    switch event.kind {
    case .coinCollected, .chestReward, .mineDestroyed, .levelCompleted, .enemyHit, .enemyDefeated:
      return .h3
    default:
      return .paragraph
    }
  }

  private func feedbackColor(for event: GameplayFeedback) -> Color {
    switch event.kind {
    case .coinCollected, .healthItemCollected:
      return AppTheme.Colors.accent
    case .healthAlreadyFull:
      return AppTheme.Colors.text
    case .chestReward, .healthLost, .mineDestroyed, .levelCompleted, .enemyHit, .enemyDefeated:
      return AppTheme.Colors.highlight
    }
  }
}

struct DialogueOverlay: View {
  let text: String
  let continueAction: () -> Bool
  var body: some View {
    VStack(spacing: 16) {
      Text("Talking Chest").appTextStyle(.h2).foregroundStyle(AppTheme.Colors.highlight)
        .accessibilityIdentifier("chestDialogue")
      Text(text).appTextStyle(.paragraph).multilineTextAlignment(.center)
      Button("Continue") { _ = continueAction() }.buttonStyle(AppPrimaryButtonStyle())
        .accessibilityIdentifier("dialogueContinueButton")
    }.padding().appSurface(cornerRadius: 16).padding(24).background(
      AppTheme.Colors.background.opacity(0.58)
    )
    .accessibilityElement(children: .contain).accessibilityLabel("Talking Chest. \(text)").zIndex(
      10)
  }
}
