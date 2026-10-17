import SwiftUI

/// Visual copy only. Detailed semantics remain in GameplayFeedbackKind.accessibilityAnnouncement.
struct ArcadeFeedbackPresentation: Equatable {
  enum Tone: Equatable { case score, damage, health, completion, neutral }
  let text: String
  let secondaryText: String?
  let tone: Tone

  init(_ kind: GameplayFeedbackKind) {
    secondaryText = if case .chestReward(_, let health) = kind, health > 0 { "+\(health) HP" } else { nil }
    switch kind {
    case .coinCollected(let points), .mineDestroyed(let points), .enemyHit(_, let points, _):
      text = "+\(points)"; tone = .score
    case .chestReward(let score, _): text = "+\(score)"; tone = .score
    case .healthLost(let amount, _): text = "-\(amount)"; tone = .damage
    case .healthItemCollected(let amount): text = "+\(amount) HP"; tone = .health
    case .healthAlreadyFull: text = "FULL"; tone = .neutral
    case .levelCompleted(let points): text = "+\(points)"; tone = .completion
    case .enemyDefeated: text = "KO"; tone = .completion
    }
  }
}

enum ArcadeFeedbackLayout {
  static let travel: CGFloat = 32
  static let maximumScale: CGFloat = 1.16

  static func lanes(for feedback: [GameplayFeedback], previous: [UUID: Int]) -> [UUID: Int] {
    var result = previous.filter { id, _ in feedback.contains { $0.id == id } }
    for event in feedback where result[event.id] == nil {
      let occupied = Set(feedback.filter { $0.coordinate == event.coordinate }
        .compactMap { result[$0.id] })
      var lane = 0
      while occupied.contains(lane) { lane += 1 }
      result[event.id] = lane
    }
    return result
  }

  static func anchor(_ coordinate: GridPosition?, grid: GridSize, board: CGSize) -> CGPoint {
    guard let coordinate, grid.rows > 0, grid.columns > 0 else {
      return CGPoint(x: board.width / 2, y: board.height / 2)
    }
    // RenderLayoutContext.point flips logical rows into SpriteKit's upward Y axis;
    // layoutWorld applies one uniform cell scale. Flip back here for SwiftUI.
    // On square grids this is (column + .5) / columns and (row + .5) / rows.
    let side = min(board.width, board.height)
    let cell = side / CGFloat(max(grid.rows, grid.columns))
    return CGPoint(x: (board.width - side) / 2 + (CGFloat(coordinate.column) + 0.5) * cell,
                   y: (board.height - side) / 2 + side - CGFloat(grid.rows) * cell
                     + (CGFloat(coordinate.row) + 0.5) * cell)
  }

  static func center(anchor: CGPoint, board: CGSize, label: CGSize, lane: Int,
                     reducedMotion: Bool) -> CGPoint {
    let halfWidth = min(board.width / 2, label.width * maximumScale / 2 + 6)
    let halfHeight = min(board.height / 2, label.height * maximumScale / 2 + 6)
    let rise = reducedMotion ? CGFloat.zero : travel
    let lowerY = min(board.height / 2, halfHeight + rise)
    let upperY = max(lowerY, board.height - halfHeight)
    // Stack toward the board interior, after clamping the subject's base position.
    // Reserve a two-line pitch so chest health and a neighboring event stay distinct.
    let baseY = min(max(anchor.y, lowerY), upperY)
    let direction: CGFloat = anchor.y < board.height / 2 ? 1 : -1
    let offset = CGFloat(lane) * (max(label.height, 64) * maximumScale + 8)
    return CGPoint(x: min(max(anchor.x, halfWidth), max(halfWidth, board.width - halfWidth)),
                   y: min(max(baseY + direction * offset, lowerY), upperY))
  }
}

struct ArcadeFeedbackMotion: Equatable {
  let scale: CGFloat
  let rise: CGFloat
  let opacity: Double

  init(age: TimeInterval, duration: TimeInterval, reducedMotion: Bool) {
    let progress = min(1, max(0, age / max(duration, 0.001)))
    opacity = min(1, progress / 0.04) * min(1, (1 - progress) / 0.25)
    if reducedMotion {
      scale = 1; rise = 0
    } else {
      scale = progress < 0.08 ? 0.78 + CGFloat(progress / 0.08) * 0.38
        : progress < 0.18 ? 1.16 - CGFloat((progress - 0.08) / 0.1) * 0.16 : 1
      rise = ArcadeFeedbackLayout.travel * CGFloat(progress)
    }
  }
}

struct ArcadeFeedbackOverlay: View {
  let feedback: [GameplayFeedback]
  let gridSize: GridSize
  let reducedMotion: Bool

  @State private var lanes: [UUID: Int]

  init(feedback: [GameplayFeedback], gridSize: GridSize, reducedMotion: Bool) {
    self.feedback = feedback; self.gridSize = gridSize; self.reducedMotion = reducedMotion
    _lanes = State(initialValue: ArcadeFeedbackLayout.lanes(for: feedback, previous: [:]))
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        ForEach(feedback) { event in
          ArcadeFeedbackPopout(event: event, grid: gridSize, board: geometry.size,
                               lane: lanes[event.id] ?? 0,
                               reducedMotion: reducedMotion)
        }
      }.frame(width: geometry.size.width, height: geometry.size.height)
    }
    .onChange(of: feedback) { _, events in
      lanes = ArcadeFeedbackLayout.lanes(for: events, previous: lanes)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true) // The coordinator announces every event once, with full context.
  }
}

private struct ArcadeFeedbackPopout: View {
  let event: GameplayFeedback
  let grid: GridSize
  let board: CGSize
  let reducedMotion: Bool
  let lane: Int
  @State private var appearedAt = Date()
  @State private var labelSize = CGSize(width: 80, height: 32)

  init(event: GameplayFeedback, grid: GridSize, board: CGSize, lane: Int, reducedMotion: Bool) {
    self.event = event; self.grid = grid; self.board = board; self.reducedMotion = reducedMotion
    self.lane = lane
  }

  var body: some View {
    let presentation = ArcadeFeedbackPresentation(event.kind)
    let center = ArcadeFeedbackLayout.center(
      anchor: ArcadeFeedbackLayout.anchor(event.coordinate, grid: grid, board: board),
      board: board, label: labelSize, lane: lane, reducedMotion: reducedMotion)
    TimelineView(.animation) { context in
      let motion = ArcadeFeedbackMotion(age: context.date.timeIntervalSince(appearedAt),
                                         duration: event.duration, reducedMotion: reducedMotion)
      VStack(spacing: 2) {
        Text(presentation.text).foregroundStyle(color(presentation.tone))
        if let secondary = presentation.secondaryText {
          Text(secondary).foregroundStyle(AppTheme.Colors.success)
        }
      }
      .appTextStyle(.h3).fontWeight(.heavy).monospacedDigit()
      .multilineTextAlignment(.center)
      .frame(maxWidth: max(0, board.width / ArcadeFeedbackLayout.maximumScale - 12))
      .fixedSize(horizontal: true, vertical: true)
      .background {
        GeometryReader { proxy in
          Color.clear.onAppear { labelSize = proxy.size }
            .onChange(of: proxy.size) { _, size in labelSize = size }
        }
      }
      .shadow(color: .black, radius: 2, y: 1)
      .scaleEffect(motion.scale).opacity(motion.opacity)
      .position(x: center.x, y: center.y - motion.rise)
    }
  }

  private func color(_ tone: ArcadeFeedbackPresentation.Tone) -> Color {
    switch tone {
    case .score: AppTheme.Colors.accent
    case .damage: AppTheme.Colors.danger
    case .health, .completion: AppTheme.Colors.success
    case .neutral: AppTheme.Colors.text
    }
  }
}
