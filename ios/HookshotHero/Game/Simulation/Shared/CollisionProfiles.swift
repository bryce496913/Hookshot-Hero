import Foundation

/// A device-independent hit box whose offsets are relative to the sprite's centered grid anchor.
struct CollisionFootprint: Equatable, Sendable {
  let rowOffsets: Range<Int>
  let columnOffsets: Range<Int>
  func region(at anchor: GridPosition) -> GridRegion {
    .init(
      rows: (anchor.row + rowOffsets.lowerBound)..<(anchor.row + rowOffsets.upperBound),
      columns: (anchor.column + columnOffsets.lowerBound)..<(anchor.column
        + columnOffsets.upperBound))
  }
  var isEmpty: Bool { rowOffsets.isEmpty || columnOffsets.isEmpty }
}

enum CollisionProfile {
  // Deliberately exclude transparent canvas padding while following the centered render anchor.
  static let player = CollisionFootprint(rowOffsets: -1..<2, columnOffsets: -1..<2)
  static let coin = CollisionFootprint(rowOffsets: 0..<1, columnOffsets: 0..<1)
  static let cabbage = CollisionFootprint(rowOffsets: -1..<2, columnOffsets: -1..<2)
  static let mine = CollisionFootprint(rowOffsets: -1..<1, columnOffsets: -1..<1)
  static let chest = CollisionFootprint(rowOffsets: -1..<2, columnOffsets: -1..<2)
  static let hookHead = CollisionFootprint(rowOffsets: 0..<1, columnOffsets: 0..<1)
  static func footprint(for kind: EntityKind) -> CollisionFootprint {
    switch kind {
    case .coin: coin
    case .cabbage: cabbage
    case .mine: mine
    }
  }
}
