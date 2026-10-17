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

/// FNV-1a over the UUID's 16 ordered bytes, followed by SplitMix64 samples.
/// Neither Swift's process-randomized hashing nor rendering-time randomness is involved.
struct ArcadeFeedbackVariation: Equatable {
  static let minimumTravel: CGFloat = 22
  static let maximumTravel: CGFloat = 42
  static let maximumRotation = 7.0
  static let maximumScale: CGFloat = 1.12
  let direction: CGPoint
  let travel: CGFloat
  let lateralOffset: CGFloat
  let rotationDegrees: Double
  let initialScale: CGFloat
  let peakScale: CGFloat

  init(id: UUID) {
    var seed: UInt64 = 14_695_981_039_346_656_037
    let bytes = id.uuid
    withUnsafeBytes(of: bytes) { bytes in
      for byte in bytes { seed = (seed ^ UInt64(byte)) &* 1_099_511_628_211 }
    }
    func sample() -> Double {
      seed &+= 0x9E3779B97F4A7C15
      var value = seed
      value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
      value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
      value ^= value >> 31
      return Double(value >> 11) / 9_007_199_254_740_992
    }
    let angle = (-135 + 90 * sample()) * .pi / 180
    direction = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
    travel = Self.minimumTravel + CGFloat(sample()) * (Self.maximumTravel - Self.minimumTravel)
    lateralOffset = CGFloat(-4 + 8 * sample())
    rotationDegrees = -Self.maximumRotation + 2 * Self.maximumRotation * sample()
    initialScale = 0.86 + CGFloat(sample()) * 0.06
    peakScale = 1.06 + CGFloat(sample()) * (Self.maximumScale - 1.06)
  }
}

enum ArcadeFeedbackLayout {
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

  /// A group's reserved capacity can grow, but never shrinks while any peer is active.
  /// Expiration therefore neither renumbers lanes nor moves their reserved regions.
  static func capacities(for feedback: [GameplayFeedback], lanes: [UUID: Int],
                         previous: [GridPosition?: Int]) -> [GridPosition?: Int] {
    let coordinates = Set(feedback.map(\.coordinate))
    var result = previous.filter { coordinates.contains($0.key) }
    for event in feedback {
      result[event.coordinate] = max(result[event.coordinate] ?? 1, (lanes[event.id] ?? 0) + 1)
    }
    return result
  }

  static func trajectory(anchor: CGPoint, board: CGSize, label: CGSize, lane: Int,
                         capacity: Int, variation: ArcadeFeedbackVariation,
                         reducedMotion: Bool) -> ArcadeFeedbackTrajectory {
    let count = max(1, capacity)
    // Reserve a compact block around the subject instead of spreading a small group
    // across the whole board. A lone popout can use all available trajectory space.
    let blockHeight = count == 1 ? max(0, board.height) : min(max(0, board.height), CGFloat(count) * 64)
    let blockY = min(max(anchor.y - blockHeight / 2, 0), max(0, board.height - blockHeight))
    let bandHeight = blockHeight / CGFloat(count)
    // Nearest band belongs to lane zero. Further lanes expand locally toward available space.
    let bands = (0..<count).sorted { lhs, rhs in
      let left = abs(blockY + (CGFloat(lhs) + 0.5) * bandHeight - anchor.y)
      let right = abs(blockY + (CGFloat(rhs) + 0.5) * bandHeight - anchor.y)
      return left == right ? lhs < rhs : left < right
    }
    let band = bands[min(max(0, lane), count - 1)]
    let region = CGRect(x: 0, y: blockY + CGFloat(band) * bandHeight,
                        width: max(0, board.width), height: bandHeight)
    let margin = min(6, min(region.width, region.height) / 4)
    let rotation = reducedMotion ? 0 : variation.rotationDegrees
    let radians = rotation * .pi / 180
    let peak = reducedMotion ? CGFloat(1) : variation.peakScale
    // The constant rotation and maximum pop scale give an envelope valid for EVERY frame.
    let cosine = CGFloat(abs(cos(radians))), sine = CGFloat(abs(sin(radians)))
    let rotatedWidth = cosine * label.width + sine * label.height
    let rotatedHeight = sine * label.width + cosine * label.height
    let fitScale = min(1, min(max(0, region.width - 2 * margin) / max(1, rotatedWidth * peak),
                             max(0, region.height - 2 * margin) / max(1, rotatedHeight * peak)))
    let half = CGSize(width: rotatedWidth * peak * fitScale / 2,
                      height: rotatedHeight * peak * fitScale / 2)
    let minX = region.minX + margin + half.width
    let maxX = max(minX, region.maxX - margin - half.width)
    let minY = region.minY + margin + half.height
    let maxY = max(minY, region.maxY - margin - half.height)
    let start = CGPoint(x: min(max(anchor.x + (reducedMotion ? 0 : variation.lateralOffset), minX), maxX),
                        y: min(max(anchor.y, minY), maxY))
    var dx = variation.direction.x * variation.travel
    let dy = variation.direction.y * variation.travel
    // Mirror an outward launch when the opposite side offers more room.
    let available = dx < 0 ? start.x - minX : maxX - start.x
    let opposite = dx < 0 ? maxX - start.x : start.x - minX
    if abs(dx) > available && opposite > available { dx = -dx }
    let horizontalRoom = dx < 0 ? start.x - minX : maxX - start.x
    let horizontalFactor = abs(dx) > 0 ? horizontalRoom / abs(dx) : 1
    let verticalFactor = abs(dy) > 0 ? (start.y - minY) / abs(dy) : 1
    // Uniform reduction preserves the upward angle instead of flattening it at the top edge.
    let factor = reducedMotion ? CGFloat.zero : max(0, min(1, min(horizontalFactor, verticalFactor)))
    return .init(start: start, xTravel: dx * factor, yTravel: dy * factor,
                 rotationDegrees: rotation, fitScale: fitScale, halfExtents: half, region: region)
  }
}

struct ArcadeFeedbackTrajectory: Equatable {
  let start: CGPoint
  let xTravel: CGFloat
  let yTravel: CGFloat
  let rotationDegrees: Double
  let fitScale: CGFloat
  let halfExtents: CGSize
  let region: CGRect

  func envelope(at point: CGPoint) -> CGRect {
    CGRect(x: point.x - halfExtents.width, y: point.y - halfExtents.height,
           width: halfExtents.width * 2, height: halfExtents.height * 2)
  }
}

struct ArcadeFeedbackMotion: Equatable {
  let scale: CGFloat
  let xOffset: CGFloat
  let yOffset: CGFloat
  let rotationDegrees: Double
  let opacity: Double

  init(age: TimeInterval, duration: TimeInterval, variation: ArcadeFeedbackVariation,
       trajectory: ArcadeFeedbackTrajectory, reducedMotion: Bool) {
    let progress = min(1, max(0, age / max(duration, 0.001)))
    opacity = min(1, progress / 0.04) * min(1, (1 - progress) / 0.25)
    if reducedMotion {
      scale = 1; xOffset = 0; yOffset = 0; rotationDegrees = 0
    } else {
      scale = progress < 0.08
        ? variation.initialScale + CGFloat(progress / 0.08) * (variation.peakScale - variation.initialScale)
        : progress < 0.18 ? variation.peakScale - CGFloat((progress - 0.08) / 0.1) * (variation.peakScale - 1) : 1
      xOffset = trajectory.xTravel * CGFloat(progress)
      yOffset = trajectory.yTravel * CGFloat(progress)
      rotationDegrees = trajectory.rotationDegrees
    }
  }
}

struct ArcadeFeedbackOverlay: View {
  let feedback: [GameplayFeedback]
  let gridSize: GridSize
  let reducedMotion: Bool
  @State private var lanes: [UUID: Int]
  @State private var capacities: [GridPosition?: Int]

  init(feedback: [GameplayFeedback], gridSize: GridSize, reducedMotion: Bool) {
    self.feedback = feedback; self.gridSize = gridSize; self.reducedMotion = reducedMotion
    let lanes = ArcadeFeedbackLayout.lanes(for: feedback, previous: [:])
    _lanes = State(initialValue: lanes)
    _capacities = State(initialValue: ArcadeFeedbackLayout.capacities(for: feedback, lanes: lanes, previous: [:]))
  }

  var body: some View {
    // Resolve new arrivals before drawing their first frame; retain reservations after removal.
    let activeLanes = ArcadeFeedbackLayout.lanes(for: feedback, previous: lanes)
    let activeCapacities = ArcadeFeedbackLayout.capacities(for: feedback, lanes: activeLanes, previous: capacities)
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        ForEach(feedback) { event in
          ArcadeFeedbackPopout(event: event, grid: gridSize, board: geometry.size,
                               lane: activeLanes[event.id] ?? 0,
                               capacity: activeCapacities[event.coordinate] ?? 1,
                               reducedMotion: reducedMotion)
        }
      }.frame(width: geometry.size.width, height: geometry.size.height)
    }
    .onChange(of: feedback) { _, events in
      let next = ArcadeFeedbackLayout.lanes(for: events, previous: lanes)
      capacities = ArcadeFeedbackLayout.capacities(for: events, lanes: next, previous: capacities)
      lanes = next
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
  let capacity: Int
  let variation: ArcadeFeedbackVariation
  @State private var appearedAt = Date()
  @State private var labelSize = CGSize(width: 60, height: 28)

  init(event: GameplayFeedback, grid: GridSize, board: CGSize, lane: Int, capacity: Int, reducedMotion: Bool) {
    self.event = event; self.grid = grid; self.board = board; self.reducedMotion = reducedMotion
    self.lane = lane; self.capacity = capacity
    variation = ArcadeFeedbackVariation(id: event.id)
  }

  var body: some View {
    let presentation = ArcadeFeedbackPresentation(event.kind)
    // Geometry, rotation envelope and edge adjustment are outside the per-frame closure.
    let trajectory = ArcadeFeedbackLayout.trajectory(
      anchor: ArcadeFeedbackLayout.anchor(event.coordinate, grid: grid, board: board),
      board: board, label: labelSize, lane: lane, capacity: capacity,
      variation: variation, reducedMotion: reducedMotion)
    TimelineView(.animation) { context in
      let motion = ArcadeFeedbackMotion(age: context.date.timeIntervalSince(appearedAt),
        duration: event.duration, variation: variation, trajectory: trajectory, reducedMotion: reducedMotion)
      VStack(spacing: 2) {
        Text(presentation.text).foregroundStyle(color(presentation.tone))
        if let secondary = presentation.secondaryText {
          Text(secondary).foregroundStyle(AppTheme.Colors.success)
        }
      }
      .appTextStyle(.caption).fontWeight(presentation.tone == .completion ? .heavy : .bold).monospacedDigit()
      .multilineTextAlignment(.center)
      .frame(maxWidth: max(0, board.width - 12))
      .fixedSize(horizontal: true, vertical: true)
      .background {
        GeometryReader { proxy in
          Color.clear.onAppear { labelSize = proxy.size }
            .onChange(of: proxy.size) { _, size in labelSize = size }
        }
      }
      .shadow(color: .black, radius: 2, y: 1)
      .scaleEffect(motion.scale * trajectory.fitScale)
      .rotationEffect(.degrees(motion.rotationDegrees)).opacity(motion.opacity)
      .position(x: trajectory.start.x + motion.xOffset, y: trajectory.start.y + motion.yOffset)
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
