import XCTest
@testable import HookshotHero

@MainActor final class EntityStoreTests: XCTestCase {
    private final class Entity: GameEntity {
        let identifier = UUID(); var updates = 0; var onUpdate: (() -> Void)?
        func update(deltaTime: TimeInterval) { updates += 1; onUpdate?() }
    }
    func testPendingAdditionIsAppliedAtSafePoint() {
        let store = EntityStore(), entity = Entity(); store.add(entity)
        XCTAssertTrue(store.entities.isEmpty); store.update(deltaTime: 1); XCTAssertEqual(entity.updates, 1)
    }
    func testPendingRemovalIsAppliedAtSafePoint() {
        let store = EntityStore(), entity = Entity(); store.add(entity); store.applyPendingChanges(); store.remove(identifier: entity.identifier)
        XCTAssertEqual(store.entities.count, 1); store.update(deltaTime: 1); XCTAssertTrue(store.entities.isEmpty)
    }
    func testMutationRequestedDuringIterationIsDeferred() {
        let store = EntityStore(), first = Entity(), second = Entity()
        first.onUpdate = { store.add(second); store.remove(identifier: first.identifier); XCTAssertTrue(store.isUpdating) }
        store.add(first); store.update(deltaTime: 1)
        XCTAssertEqual(store.entities.map(\.identifier), [second.identifier]); XCTAssertEqual(second.updates, 0)
    }
}
