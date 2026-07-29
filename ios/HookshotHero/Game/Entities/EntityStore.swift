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

    func add(_ entity: any GameEntity) {
        guard !entities.contains(where: { $0.identifier == entity.identifier }),
              !pendingAdditions.contains(where: { $0.identifier == entity.identifier }) else {
            AppLog.errors.error("Duplicate entity identifier ignored")
            return
        }
        pendingAdditions.append(entity)
    }
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
        let removals = pendingRemovalIDs
        entities.removeAll { removals.contains($0.identifier) }
        var acceptedIDs = Set(entities.map(\.identifier))
        for addition in pendingAdditions where !removals.contains(addition.identifier) {
            if acceptedIDs.insert(addition.identifier).inserted { entities.append(addition) }
        }
        pendingAdditions.removeAll()
        pendingRemovalIDs.removeAll()
    }
}
