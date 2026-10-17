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
  @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
  @ObservedObject var session: GameSession
  let controlLayout: ControlLayout
  let returnToMenu: () -> Void
  @State private var scene: GameScene
  @StateObject private var announcementCoordinator = FeedbackAnnouncementCoordinator()
  init(
    session: GameSession, controlLayout: ControlLayout = .standard,
    returnToMenu: @escaping () -> Void
  ) {
    self.session = session
    self.controlLayout = controlLayout
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
        GameSceneView(scene: scene).aspectRatio(1, contentMode: .fit)
          .background(AppTheme.Colors.background).accessibilityHidden(true)
          .accessibilityIdentifier("gameBoard")
          .overlay {
            ArcadeFeedbackOverlay(
              feedback: session.uiSnapshot.feedback,
              gridSize: session.runtime.presentation.logicalGridSize,
              reducedMotion: session.configuration.reducedMotion || systemReducedMotion)
              .id(session.runtimeGeneration)
          }
        .aspectRatio(1, contentMode: .fit)
        .background(AppTheme.Colors.background)
        .overlay { Rectangle().stroke(AppTheme.Colors.divider.opacity(0.5), lineWidth: 1)
          .allowsHitTesting(false) }
        .shadow(color: AppTheme.Colors.shadow, radius: 6, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        GameControlsView(
          canMove: session.uiSnapshot.canMove, canGrapple: session.uiSnapshot.canGrapple,
          showsHints: session.configuration.controlHintsEnabled, compact: compact,
          controlLayout: controlLayout,
          inputController: session.simulation.inputController,
          diagnosticPosition: session.uiSnapshot.diagnosticPlayerPosition)
          .id(controlLayout)
      }
      .allowsHitTesting(!hasModalOverlay)
      .accessibilityHidden(hasModalOverlay)
      .padding(.horizontal, compact ? 8 : 12)
      .padding(.bottom, compact ? 4 : 8)
    }.appScreenBackground()
      .environment(\.appReducedMotion, session.configuration.reducedMotion)
      .navigationBarBackButtonHidden().appNavigationStyle().onAppear {
        announcementCoordinator.update(feedback: session.uiSnapshot.feedback)
      }.onChange(of: session.runtimeGeneration) { _, generation in
        scene = GameScene(session: session, runtime: session.runtime, generation: generation)
      }.onChange(of: session.uiSnapshot.feedback) { _, feedback in
        announcementCoordinator.update(feedback: feedback)
      }.onChange(of: controlLayout) { _, _ in
        // A layout update must never carry a held movement or in-progress gesture to the new side.
        session.simulation.cancelAllInput()
      }.onDisappear { session.simulation.cancelAllInput() }.overlay {
        if previewsLoadingOverlay {
          LevelLoadingOverlay(levelName: "Level 7")
        } else if let text = session.dialogue {
          DialogueOverlay(text: text, continueAction: session.continueDialogue)
        } else if case .transitioning(let levelID) = session.state {
          LevelLoadingOverlay(levelName: levelID.displayName)
        } else if session.isPaused {
          pauseOverlay
        }
      }
  }
  // UI-test presentation fixture: does not hold or delay an actual level transition.
  private var previewsLoadingOverlay: Bool {
    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      return arguments.contains("--ui-testing") && arguments.contains("--preview-level-loading-overlay")
    #else
      return false
    #endif
  }

  private var hasModalOverlay: Bool {
    if previewsLoadingOverlay { return true }
    if case .transitioning = session.state { return true }
    return session.isPaused || session.dialogue != nil
  }

  private var hud: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: AppTheme.Spacing.sm) {
        levelTitle
        Spacer(minLength: 0)
        stats
        pauseButton
      }
      VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
        HStack { levelTitle; Spacer(minLength: 0); pauseButton }
        ViewThatFits(in: .horizontal) {
          HStack(spacing: AppTheme.Spacing.sm) { stats }
          VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) { stats }
        }
      }
    }
    .padding(.horizontal, AppTheme.Spacing.sm)
    .padding(.vertical, AppTheme.Spacing.xs)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("gameplayHUD")
  }

  private var levelTitle: some View {
    Text(session.uiSnapshot.levelName).appTextStyle(.h3)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityIdentifier("levelTitle")
  }

  @ViewBuilder private var stats: some View {
    GameplayStatPill(title: "Health", value: session.uiSnapshot.health, identifier: "healthValue") {
      HealthIcon()
    }
    GameplayStatPill(title: "Score", value: session.uiSnapshot.score, identifier: "scoreValue") {
      Image(systemName: "sparkle").foregroundStyle(AppTheme.Colors.highlight)
    }
  }

  private var pauseButton: some View {
    AppIconButton(title: session.isPaused ? "Resume game" : "Pause game",
                  systemImage: session.isPaused ? "play.fill" : "pause.fill") {
      if session.isPaused { _ = session.resume() } else { _ = session.pause() }
    }
    .accessibilityIdentifier(session.isPaused ? "resumeButton" : "pauseButton")
  }

  private var pauseOverlay: some View {
    GameplayModalPanel {
      Image(systemName: "pause.circle").appTextStyle(.heroTitle)
        .foregroundStyle(AppTheme.Colors.accent).accessibilityHidden(true)
      Text("Paused").appTextStyle(.h1).accessibilityIdentifier("pauseOverlay")
      Text("Your adventure can wait.").appTextStyle(.paragraph)
        .foregroundStyle(AppTheme.Colors.textSecondary)
      Button("Resume") { session.resume() }.buttonStyle(AppPrimaryButtonStyle())
        .accessibilityIdentifier("overlayResumeButton")
      Button("Return to Menu", role: .destructive, action: returnToMenu)
        .buttonStyle(AppSecondaryButtonStyle()).accessibilityIdentifier("returnToMenuButton")
    }
  }
}

/// Hosts SpriteKit without `SpriteView`'s focus coordinator. The game board is display-only—all
/// input is handled by the SwiftUI controls below it—so the backing view must not participate in
/// UIKit focus or gesture handling.
final class NonFocusableGameSKView: SKView {
  override var canBecomeFocused: Bool { false }

  override init(frame: CGRect) {
    super.init(frame: frame)
    configureAsDisplayOnly()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    configureAsDisplayOnly()
  }

  private func configureAsDisplayOnly() {
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    accessibilityElementsHidden = true
  }
}

struct GameSceneView: UIViewRepresentable {
  let scene: SKScene

  func makeUIView(context: Context) -> NonFocusableGameSKView {
    Self.makeGameView(presenting: scene)
  }

  static func makeGameView(presenting scene: SKScene) -> NonFocusableGameSKView {
    let view = NonFocusableGameSKView(frame: .zero)
    view.presentScene(scene)
    return view
  }

  func updateUIView(_ view: NonFocusableGameSKView, context: Context) {
    guard view.scene !== scene else { return }
    view.presentScene(scene)
  }

  static func dismantleUIView(_ view: NonFocusableGameSKView, coordinator: ()) {
    view.presentScene(nil)
  }
}

/// Loads the legacy heart as a bundled file rather than asking CoreUI for an asset-catalog image.
/// The resource is intentionally shipped beside the SpriteKit textures, not in `Assets.xcassets`.
private struct HealthIcon: View {
  private static let image: UIImage? = Bundle.main.url(
    forResource: "heart", withExtension: "png"
  ).flatMap { UIImage(contentsOfFile: $0.path) }

  var body: some View {
    Group {
      if let image = Self.image {
        Image(uiImage: image).resizable().interpolation(.none)
      } else {
        Image(systemName: "heart.fill").resizable().foregroundStyle(AppTheme.Colors.highlight)
      }
    }
    .scaledToFit()
    .frame(width: 20, height: 20)
  }
}

/// Presentation geometry shared by both thumb controls. Input thresholds/timing stay controller-owned.
enum GameplayControlMetrics {
  static let compactDiameter: CGFloat = 132
  static let regularDiameter: CGFloat = 148
  static let knobRatio: CGFloat = 0.44

  static func diameter(compact: Bool) -> CGFloat {
    compact ? compactDiameter : regularDiameter
  }

  static func knobDiameter(for diameter: CGFloat) -> CGFloat {
    (diameter * knobRatio).rounded()
  }

  static func usableRadius(for diameter: CGFloat) -> CGFloat {
    (diameter - knobDiameter(for: diameter)) / 2
  }

  static func markerSize(for diameter: CGFloat) -> CGFloat { (diameter * 0.09).rounded() }
  static func markerInset(for diameter: CGFloat) -> CGFloat { diameter * 0.12 }
  static func minimumGap(compact: Bool) -> CGFloat { compact ? 16 : 24 }
  static func horizontalPadding(compact: Bool) -> CGFloat { compact ? 10 : 12 }
}

struct GameControlsView: View {
  let canMove: Bool
  let canGrapple: Bool
  let showsHints: Bool
  let compact: Bool
  let controlLayout: ControlLayout
  let inputController: GameInputController
  let diagnosticPosition: GridPosition?
  private let haptics: any GameControlHaptics = UIKitGameControlHaptics()
  var body: some View {
    HStack(alignment: .center, spacing: 0) {
      leadingControl
      Spacer(minLength: GameplayControlMetrics.minimumGap(compact: compact))
      trailingControl
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, GameplayControlMetrics.horizontalPadding(compact: compact))
    .padding(.vertical, AppTheme.Spacing.xs)
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

  @ViewBuilder private var leadingControl: some View {
    if controlLayout.joystickIsLeading { joystickControl } else { grappleControl }
  }

  @ViewBuilder private var trailingControl: some View {
    if controlLayout.joystickIsLeading { grappleControl } else { joystickControl }
  }

  private var joystickControl: some View {
    dockControl(hint: "Move", identifier: "moveControlHint") {
      VirtualJoystickView(
        input: inputController, isEnabled: canMove, size: GameplayControlMetrics.diameter(compact: compact),
        haptics: haptics)
    }
  }

  private var grappleControl: some View {
    dockControl(hint: "Grapple", identifier: "grappleControlHint") {
      GrappleControlView(
        input: inputController, isEnabled: canGrapple, size: GameplayControlMetrics.diameter(compact: compact),
        haptics: haptics)
    }
  }

  private func dockControl<Control: View>(
    hint: String, identifier: String, @ViewBuilder control: () -> Control
  ) -> some View {
    VStack(spacing: 2) {
      control()
      if showsHints {
        Text(hint).appTextStyle(.caption).foregroundStyle(AppTheme.Colors.textSecondary)
          .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(identifier)
      }
    }
    .frame(width: GameplayControlMetrics.diameter(compact: compact))
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
          AppTheme.Colors.highlight.opacity(controller.state.isPressed ? 0.85 : 1))
        Circle().stroke(
          AppTheme.Colors.text.opacity(controller.state.isPressed ? 0.9 : 0.45),
          lineWidth: controller.state.isPressed ? 4 : 2)
        Image(systemName: directionSymbol)
          .font(.system(size: controller.state.selectedDirection == nil ? 30 : 36, weight: .bold))
          .foregroundStyle(AppTheme.Colors.background)
      }
      .shadow(color: AppTheme.Colors.highlight.opacity(
        controller.state.isPressed ? 0.45 : 0.15), radius: controller.state.isPressed ? 12 : 5)
      .overlay {
        if controller.state.selectedDirection != nil {
          Circle().stroke(AppTheme.Colors.accent, lineWidth: 4).allowsHitTesting(false)
        }
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
  private var knobSize: CGFloat { GameplayControlMetrics.knobDiameter(for: size) }
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.appReducedMotion) private var appReducedMotion
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
      Circle().fill(AppTheme.Colors.backgroundElevated)
      Circle().stroke(
        AppTheme.Colors.accent.opacity(controller.state.activeDirection == nil ? 0.45 : 1),
        lineWidth: controller.state.activeDirection == nil ? 2 : 3)
      cardinalMarkers
      Circle()
        .fill(
          controller.state.activeDirection == nil
            ? AppTheme.Colors.surfaceElevated : AppTheme.Colors.accent
        )
        .frame(width: knobSize, height: knobSize)
        .overlay(Circle().stroke(AppTheme.Colors.text.opacity(0.35), lineWidth: 1))
        .shadow(color: AppTheme.Colors.shadow, radius: 4, y: 2)
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
    .animation((reduceMotion || appReducedMotion) ? nil : .easeOut(duration: 0.12), value: controller.state.displacement)
  }

  private var cardinalMarkers: some View {
    ForEach(GridDirection.allCases, id: \.rawValue) { direction in
      Image(systemName: symbol(for: direction))
        .font(.system(size: GameplayControlMetrics.markerSize(for: size), weight: .bold))
        .foregroundStyle(
          controller.state.activeDirection == direction
            ? AppTheme.Colors.highlight : AppTheme.Colors.textMuted
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
        displacement: displacement, usableRadius: GameplayControlMetrics.usableRadius(for: size),
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
    case .up: .init(width: 0, height: -(size / 2 - GameplayControlMetrics.markerInset(for: size)))
    case .down: .init(width: 0, height: size / 2 - GameplayControlMetrics.markerInset(for: size))
    case .left: .init(width: -(size / 2 - GameplayControlMetrics.markerInset(for: size)), height: 0)
    case .right: .init(width: size / 2 - GameplayControlMetrics.markerInset(for: size), height: 0)
    }
  }
}

struct DialogueOverlay: View {
  let text: String
  let continueAction: () -> Bool
  var body: some View {
    GameplayModalPanel {
      Image(systemName: "text.bubble").appTextStyle(.h2)
        .foregroundStyle(AppTheme.Colors.accent).accessibilityHidden(true)
      Text("Message").appTextStyle(.h2).accessibilityIdentifier("chestDialogue")
      Text(text).appTextStyle(.paragraph).multilineTextAlignment(.center)
      Button("Continue") { _ = continueAction() }.buttonStyle(AppPrimaryButtonStyle())
        .accessibilityIdentifier("dialogueContinueButton")
    }
  }
}

/// Compact numeric stats keep their established label/value semantics without redundant visual words.
private struct GameplayStatPill<Icon: View>: View {
  let title: String
  let value: Int
  let identifier: String
  @ViewBuilder let icon: () -> Icon

  var body: some View {
    HStack(spacing: AppTheme.Spacing.xs) {
      icon().accessibilityHidden(true)
      Text(value.formatted()).appTextStyle(.caption).fontWeight(.semibold).monospacedDigit()
        .accessibilityLabel(title).accessibilityValue(String(value))
        .accessibilityIdentifier(identifier)
    }
    .fixedSize(horizontal: true, vertical: false)
    .padding(.horizontal, AppTheme.Spacing.sm).padding(.vertical, AppTheme.Spacing.xs)
    .background(AppTheme.Colors.surface, in: Capsule())
  }
}

/// Full-screen scrim consumes touches; scrolling keeps modal actions reachable at large text sizes.
struct GameplayModalPanel<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    ZStack {
      AppTheme.Colors.background.opacity(0.8).ignoresSafeArea().contentShape(Rectangle())
      ScrollView {
        VStack(spacing: AppTheme.Spacing.md) { content() }
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
          .padding(AppTheme.Spacing.lg)
          .appSurface(style: .elevated)
          .frame(maxWidth: 420)
          .padding(AppTheme.Spacing.lg)
          .frame(maxWidth: .infinity)
      }
      .defaultScrollAnchor(.center, for: .alignment)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
  }
}

struct LevelLoadingOverlay: View {
  let levelName: String

  var body: some View {
    GameplayModalPanel {
      ProgressView().tint(AppTheme.Colors.accent).accessibilityHidden(true)
      Text("Entering \(levelName)").appTextStyle(.h3)
        .accessibilityIdentifier("levelLoadingOverlay")
    }
  }
}
