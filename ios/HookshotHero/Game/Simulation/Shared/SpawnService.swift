import Foundation

struct SeededRandomNumberGenerator: RandomNumberGenerator {
  private var state: UInt64
  init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
  mutating func next() -> UInt64 {
    state ^= state >> 12
    state ^= state << 25
    state ^= state >> 27
    return state &* 2_685_821_657_736_338_717
  }
}
struct EntitySpawnRequirement: Equatable, Sendable {
  let kind: EntityKind
  let count: Int
}

enum SpawnError: LocalizedError {
  case insufficientCapacity
  var errorDescription: String? {
    "Level 1 does not contain enough footprint-safe space for its items."
  }
}
enum SpawnService {
  static func spawn<R: RandomNumberGenerator>(in level: LevelDefinition, using rng: inout R) throws
    -> [WorldEntity]
  {
    try spawn(
      in: level,
      requirements: [
        .init(kind: .mine, count: 3), .init(kind: .cabbage, count: 2),
        .init(kind: .coin, count: 10),
      ], protectedRegions: [], using: &rng)
  }
  static func spawn<R: RandomNumberGenerator>(
    in level: LevelDefinition, requirements: [EntitySpawnRequirement],
    protectedRegions extraProtected: [GridRegion], using rng: inout R
  ) throws -> [WorldEntity] {
    let kinds = requirements.flatMap { Array(repeating: $0.kind, count: $0.count) }
    var candidates = (4..<56).flatMap { r in (4..<56).map { GridPosition(row: r, column: $0) } }
    candidates.shuffle(using: &rng)
    let protected = [
      CollisionProfile.player.region(at: level.start),
      CollisionProfile.chest.region(at: level.chestAnchor), level.exitRegion, level.entryRegion,
    ] + extraProtected
    var result: [WorldEntity] = []
    for kind in kinds {
      let footprint = CollisionProfile.footprint(for: kind)
      guard
        let index = candidates.firstIndex(where: { p in
          let region = footprint.region(at: p)
          return !level.isBlocked(region) && !level.overlapsLava(region)
            && !protected.contains(where: { $0.intersects(region) })
            && !result.contains(where: {
              CollisionProfile.footprint(for: $0.kind).region(at: $0.position).intersects(region)
            })
        })
      else { throw SpawnError.insufficientCapacity }
      result.append(.init(id: EntityID(), kind: kind, position: candidates.remove(at: index)))
    }
    return result
  }
}
