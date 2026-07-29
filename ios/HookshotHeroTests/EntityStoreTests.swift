import XCTest
@testable import HookshotHero

@MainActor final class EntityStoreTests: XCTestCase {
    private final class Entity: GameEntity {
        let identifier: UUID; var updates = 0; var onUpdate: (() -> Void)?
        init(identifier: UUID = UUID()) { self.identifier = identifier }
        func update(deltaTime: TimeInterval) { updates += 1; onUpdate?() }
    }

    func testPendingAdditionAndRemoval() {
        let store = EntityStore(), entity = Entity(); store.add(entity)
        XCTAssertTrue(store.entities.isEmpty); store.update(deltaTime: 1); XCTAssertEqual(entity.updates, 1)
        store.remove(identifier: entity.identifier); store.update(deltaTime: 1); XCTAssertTrue(store.entities.isEmpty)
    }
    func testMutationDuringIterationIsDeferred() {
        let store = EntityStore(), first = Entity(), second = Entity()
        first.onUpdate = { store.add(second); store.remove(identifier: first.identifier) }
        store.add(first); store.update(deltaTime: 1)
        XCTAssertEqual(store.entities.map(\.identifier), [second.identifier]); XCTAssertEqual(second.updates, 0)
    }
    func testRemovalWinsOverPendingAddition() {
        let store = EntityStore(), entity = Entity(); store.add(entity); store.remove(identifier: entity.identifier)
        store.update(deltaTime: 0); XCTAssertTrue(store.entities.isEmpty)
    }
    func testRemovalWinsDuringSameUpdate() {
        let store = EntityStore(), first = Entity(), second = Entity()
        first.onUpdate = { store.add(second); store.remove(identifier: second.identifier) }
        store.add(first); store.update(deltaTime: 0); XCTAssertEqual(store.entities.map(\.identifier), [first.identifier])
    }
    func testDuplicatePendingAndActiveIdentifiersAreIgnored() {
        let id = UUID(), store = EntityStore(), first = Entity(identifier: id), duplicate = Entity(identifier: id)
        store.add(first); store.add(duplicate); store.applyPendingChanges(); store.add(duplicate); store.applyPendingChanges()
        XCTAssertEqual(store.entities.count, 1); XCTAssertTrue(store.entities.first === first)
    }
    func testRepeatedRemovalIsIdempotentAndOrderingStable() {
        let store = EntityStore(), first = Entity(), second = Entity()
        store.add(first); store.add(second); store.remove(identifier: UUID()); store.remove(identifier: first.identifier)
        store.remove(identifier: first.identifier); store.applyPendingChanges()
        XCTAssertEqual(store.entities.map(\.identifier), [second.identifier])
    }
}
