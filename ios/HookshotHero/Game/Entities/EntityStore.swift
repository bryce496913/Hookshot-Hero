import Foundation

protocol GameEntity: AnyObject {
    var identifier: UUID { get }
    func update(deltaTime: TimeInterval)
}

@MainActor
final class EntityStore {
    private(set) var entities: [any GameEntity] = []
    private var pendingAdditions: [any GameEntity] = []
    private var pendingRemovalIDs: Set<UUID> = []
    private(set) var isUpdating = false

    func add(_ entity: any GameEntity) { pendingAdditions.append(entity) }
    func remove(identifier: UUID) { pendingRemovalIDs.insert(identifier) }

    func update(deltaTime: TimeInterval) {
        precondition(!isUpdating, "Entity updates must not be reentrant")
        applyPendingChanges()
        isUpdating = true
        for entity in entities { entity.update(deltaTime: deltaTime) }
        isUpdating = false
        applyPendingChanges()
    }

    func applyPendingChanges() {
        precondition(!isUpdating, "Collection mutation is only valid at a safe point")
        entities.removeAll { pendingRemovalIDs.contains($0.identifier) }
        pendingRemovalIDs.removeAll()
        entities.append(contentsOf: pendingAdditions)
        pendingAdditions.removeAll()
    }
}
