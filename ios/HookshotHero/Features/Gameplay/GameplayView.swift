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
    GeometryReader { geometry in
      let compact = geometry.size.height < 700 || geometry.size.width < 360
      VStack(spacing: compact ? 5 : 8) {
        hud
        ZStack {
          SpriteView(scene: scene).id(scene.runtimeGeneration).aspectRatio(1, contentMode: .fit)
            .background(AppTheme.Colors.background).accessibilityHidden(true)
            .accessibilityIdentifier("gameBoard")
          GameplayFeedbackOverlay(
            feedback: session.uiSnapshot.feedback,
            reducedMotion: session.configuration.reducedMotion)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        GameControlsView(
          canMove: session.uiSnapshot.canMove, canGrapple: session.uiSnapshot.canGrapple,
          showsHints: session.configuration.controlHintsEnabled, compact: compact,
          inputController: session.simulation.inputController,
          diagnosticPosition: session.uiSnapshot.diagnosticPlayerPosition)
      }
      .padding(.horizontal, compact ? 8 : 12)
      .padding(.bottom, compact ? 4 : 8)
    }.background(AppTheme.Colors.background)
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
  let showsHints: Bool
  let compact: Bool
  let inputController: GameInputController
  let diagnosticPosition: GridPosition?
  private let haptics: any GameControlHaptics = UIKitGameControlHaptics()
  var body: some View {
    HStack(alignment: .center, spacing: compact ? 12 : 24) {
      dockControl(hint: "Move", identifier: "moveControlHint") {
        VirtualJoystickView(
          input: inputController, isEnabled: canMove, size: compact ? 116 : 124,
          haptics: haptics)
      }
      Spacer(minLength: compact ? 12 : 32)
      dockControl(hint: "Grapple", identifier: "grappleControlHint") {
        GrappleControlView(
          input: inputController, isEnabled: canGrapple, size: compact ? 80 : 88,
          haptics: haptics)
      }
    }
    .frame(maxWidth: .infinity, minHeight: compact ? 128 : 140)
    .padding(.horizontal, compact ? 10 : 16)
    .background(AppTheme.Colors.surface.opacity(0.42), in: RoundedRectangle(cornerRadius: 24))
    .overlay(
      RoundedRectangle(cornerRadius: 24).stroke(AppTheme.Colors.accent.opacity(0.18), lineWidth: 1)
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("gameControlDock")
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

  private func dockControl<Control: View>(
    hint: String, identifier: String, @ViewBuilder control: () -> Control
  ) -> some View {
    VStack(spacing: 2) {
      control()
      if showsHints {
        Text(hint).appTextStyle(.paragraph).foregroundStyle(AppTheme.Colors.text.opacity(0.62))
          .lineLimit(1).accessibilityIdentifier(identifier)
      }
    }
  }
}

struct GrappleGestureState: Equatable {
  var isPressed = false
  var selectedDirection: GridDirection?
}

@MainActor
struct GrappleGestureController {
  static let aimThreshold: CGFloat = 24
  private(set) var state = GrappleGestureState()
  private let haptics: any GameControlHaptics

  init(haptics: any GameControlHaptics = UIKitGameControlHaptics()) {
    self.haptics = haptics
  }

  mutating func begin(isEnabled: Bool) {
    guard isEnabled else { return }
    state = .init(isPressed: true, selectedDirection: nil)
  }

  mutating func update(translation: CGSize, isEnabled: Bool) {
    guard isEnabled, state.isPressed else {
      cancel()
      return
    }
    guard hypot(translation.width, translation.height) >= Self.aimThreshold else {
      state.selectedDirection = nil
      return
    }
    let direction: GridDirection
    if abs(translation.width) > abs(translation.height) {
      direction = translation.width < 0 ? .left : .right
    } else {
      direction = translation.height < 0 ? .up : .down
    }
    if direction != state.selectedDirection {
      state.selectedDirection = direction
      haptics.grappleAimingDirectionChanged()
    }
  }

  mutating func end(isEnabled: Bool) -> GameCommand? {
    guard isEnabled, state.isPressed else {
      cancel()
      return nil
    }
    let command = state.selectedDirection.map(GameCommand.fireHookInDirection) ?? .fireHook
    state = GrappleGestureState()
    haptics.grappleFired()
    return command
  }

  mutating func cancel() { state = GrappleGestureState() }
}

struct GrappleControlView: View {
  @Environment(\.scenePhase) private var scenePhase
  @ObservedObject var input: GameInputController
  let isEnabled: Bool
  let size: CGFloat
  let haptics: any GameControlHaptics
  @State private var controller: GrappleGestureController
  @GestureState private var gestureIsActive = false

  init(
    input: GameInputController, isEnabled: Bool, size: CGFloat,
    haptics: any GameControlHaptics = UIKitGameControlHaptics()
  ) {
    self.input = input
    self.isEnabled = isEnabled
    self.size = size
    self.haptics = haptics
    _controller = State(initialValue: GrappleGestureController(haptics: haptics))
  }

  var body: some View {
    Button(action: fireFacingForward) {
      ZStack {
        Circle().fill(
          AppTheme.Colors.highlight.opacity(controller.state.isPressed ? 0.72 : 1))
        Circle().stroke(
          AppTheme.Colors.text.opacity(controller.state.isPressed ? 0.9 : 0.45),
          lineWidth: controller.state.isPressed ? 4 : 2)
        VStack(spacing: 2) {
          Image(systemName: directionSymbol)
            .font(.system(size: 27, weight: .bold))
          Text(controller.state.selectedDirection == nil ? "Grapple" : "Aim")
            .appTextStyle(.paragraph)
        }
        .foregroundStyle(AppTheme.Colors.text)
      }
      .frame(width: size, height: size)
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.42)
    .disabled(!isEnabled)
    .highPriorityGesture(grappleGesture)
    .accessibilityLabel("Fire grapple")
    .accessibilityValue(accessibilityValue)
    .accessibilityIdentifier("grappleButton")
    .accessibilityAction(named: Text("Grapple Up")) { fire(.up) }
    .accessibilityAction(named: Text("Grapple Down")) { fire(.down) }
    .accessibilityAction(named: Text("Grapple Left")) { fire(.left) }
    .accessibilityAction(named: Text("Grapple Right")) { fire(.right) }
    .onChange(of: isEnabled) { _, enabled in if !enabled { cancel() } }
    .onChange(of: input.cancellationGeneration) { _, _ in cancel() }
    .onChange(of: scenePhase) { _, phase in if phase != .active { cancel() } }
    .onChange(of: gestureIsActive) { oldValue, active in
      if oldValue, !active, controller.state.isPressed { cancel() }
    }
    .onDisappear(perform: cancel)
  }

  private var grappleGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
      .updating($gestureIsActive) { _, active, _ in active = true }
      .onChanged { value in
        if !controller.state.isPressed { controller.begin(isEnabled: isEnabled) }
        controller.update(translation: value.translation, isEnabled: isEnabled)
      }
      .onEnded { _ in
        if let command = controller.end(isEnabled: isEnabled) { input.send(command) }
      }
  }

  private var directionSymbol: String {
    controller.state.selectedDirection.map { "arrow.\($0.rawValue)" } ?? "arrow.up.right.circle"
  }
  private var accessibilityValue: String {
    controller.state.selectedDirection.map { "Aiming \($0.rawValue)" }
      ?? (controller.state.isPressed ? "Pressed" : "Ready")
  }
  private func fireFacingForward() {
    if isEnabled {
      haptics.grappleFired()
      input.send(.fireHook)
    }
  }
  private func fire(_ direction: GridDirection) {
    if isEnabled {
      haptics.grappleFired()
      input.send(.fireHookInDirection(direction))
    }
  }
  private func cancel() { controller.cancel() }
}

struct VirtualJoystickState: Equatable {
  var displacement: CGVector = .zero
  var activeDirection: GridDirection?
}

@MainActor
struct VirtualJoystickController {
  static let deadZone: CGFloat = 0.22
  private(set) var state = VirtualJoystickState()
  private let haptics: any GameControlHaptics

  init(haptics: any GameControlHaptics = UIKitGameControlHaptics()) {
    self.haptics = haptics
  }

  static func direction(for displacement: CGVector, usableRadius: CGFloat) -> GridDirection? {
    guard usableRadius > 0,
      hypot(displacement.dx, displacement.dy) / usableRadius >= deadZone
    else { return nil }
    if abs(displacement.dx) > abs(displacement.dy) {
      return displacement.dx < 0 ? .left : .right
    }
    return displacement.dy < 0 ? .up : .down
  }

  mutating func update(
    displacement raw: CGVector, usableRadius: CGFloat, isEnabled: Bool = true
  ) -> [GameCommand] {
    guard isEnabled else { return cancel() }
    let length = hypot(raw.dx, raw.dy)
    let scale = length > usableRadius && length > 0 ? usableRadius / length : 1
    let clamped = CGVector(dx: raw.dx * scale, dy: raw.dy * scale)
    let direction = Self.direction(for: clamped, usableRadius: usableRadius)
    state.displacement = direction == nil ? .zero : clamped
    guard direction != state.activeDirection else { return [] }
    if direction != nil {
      if state.activeDirection == nil {
        haptics.directionEngaged()
      } else {
        haptics.directionChanged()
      }
    }
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
  private static let knobSize: CGFloat = 54
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ObservedObject var input: GameInputController
  let isEnabled: Bool
  let size: CGFloat
  @State private var controller: VirtualJoystickController

  init(
    input: GameInputController, isEnabled: Bool, size: CGFloat,
    haptics: any GameControlHaptics = UIKitGameControlHaptics()
  ) {
    self.input = input
    self.isEnabled = isEnabled
    self.size = size
    _controller = State(initialValue: VirtualJoystickController(haptics: haptics))
  }

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
    .frame(width: size, height: size)
    .contentShape(Circle())
    .opacity(isEnabled ? 1 : 0.42)
    .gesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .onChanged { value in
          guard isEnabled else { return }
          update(
            CGVector(
              dx: value.location.x - size / 2,
              dy: value.location.y - size / 2))
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
    dispatch(
      controller.update(
        displacement: displacement, usableRadius: (size - Self.knobSize) / 2,
        isEnabled: isEnabled))
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
    case .up: .init(width: 0, height: -(size / 2 - 15))
    case .down: .init(width: 0, height: size / 2 - 15)
    case .left: .init(width: -(size / 2 - 15), height: 0)
    case .right: .init(width: size / 2 - 15, height: 0)
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
