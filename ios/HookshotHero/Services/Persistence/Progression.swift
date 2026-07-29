import Combine
import Foundation

struct Progression: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int = currentSchemaVersion
    var highScore = 0
    var completedLevelIDs: Set<LevelID> = []
    var completedMissionIDs: Set<MissionID> = []
    var unlockedContentIDs: Set<UnlockID> = []
    static let defaults = Progression()
}

enum ProgressionLoadResult: Equatable {
    case loaded(Progression)
    case missing(defaults: Progression)
    case migrated(Progression, fromVersion: Int)
    case unsupportedVersion(Int)
    case corrupt
}

@MainActor
struct ProgressionRepository {
    let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    static func applicationRepository(fileManager: FileManager = .default) throws -> ProgressionRepository {
        let directory = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                            appropriateFor: nil, create: true)
        return ProgressionRepository(fileURL: directory.appending(path: "progression-v1.json"), fileManager: fileManager)
    }

    func load() -> ProgressionLoadResult {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .missing(defaults: .defaults) }
        do {
            let data = try Data(contentsOf: fileURL)
            let envelope = try JSONDecoder().decode(SchemaEnvelope.self, from: data)
            if envelope.schemaVersion > Progression.currentSchemaVersion {
                return .unsupportedVersion(envelope.schemaVersion)
            }
            if envelope.schemaVersion < 0 { return .corrupt }
            if envelope.schemaVersion == Progression.currentSchemaVersion {
                let progression = try JSONDecoder().decode(Progression.self, from: data)
                guard progression.schemaVersion == Progression.currentSchemaVersion else { return .corrupt }
                return .loaded(progression)
            }
            return try migrate(data: data, from: envelope.schemaVersion)
        } catch {
            AppLog.persistence.error("Progression load failed; original file retained: \(error.localizedDescription, privacy: .public)")
            return .corrupt
        }
    }

    func save(_ progression: Progression) throws {
        guard progression.schemaVersion == Progression.currentSchemaVersion else {
            throw ProgressionError.invalidSchemaForSave(progression.schemaVersion)
        }
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(progression).write(to: fileURL, options: .atomic)
    }

    private func migrate(data: Data, from originalVersion: Int) throws -> ProgressionLoadResult {
        var version = originalVersion
        var migrationData = data
        while version < Progression.currentSchemaVersion {
            switch version {
            case 0:
                let old = try JSONDecoder().decode(ProgressionV0.self, from: migrationData)
                let current = Progression(highScore: old.highScore,
                                          completedLevelIDs: Set(old.completedLevelIDs.map { LevelID(rawValue: $0) }))
                migrationData = try JSONEncoder().encode(current)
                version = 1
            default:
                throw ProgressionError.noMigration(version)
            }
        }
        return .migrated(try JSONDecoder().decode(Progression.self, from: migrationData), fromVersion: originalVersion)
    }
}

private struct SchemaEnvelope: Decodable { let schemaVersion: Int }
private struct ProgressionV0: Codable { let schemaVersion: Int; let highScore: Int; let completedLevelIDs: [String] }
private enum ProgressionError: Error { case invalidSchemaForSave(Int), noMigration(Int) }

@MainActor
final class ProgressionStore: ObservableObject {
    @Published private(set) var progression: Progression
    @Published private(set) var loadResult: ProgressionLoadResult
    @Published private(set) var lastSaveError: String?
    private let repository: ProgressionRepository

    init(repository: ProgressionRepository) {
        self.repository = repository
        let result = repository.load()
        loadResult = result
        switch result {
        case .loaded(let value), .migrated(let value, _), .missing(defaults: let value): progression = value
        case .unsupportedVersion, .corrupt: progression = .defaults
        }
    }

    func record(result: GameResult) {
        var changed = false
        if result.score > progression.highScore { progression.highScore = result.score; changed = true }
        if result.outcome == .won {
            changed = progression.completedLevelIDs.insert(result.levelID).inserted || changed
            if let missionID = result.missionID {
                changed = progression.completedMissionIDs.insert(missionID).inserted || changed
            }
        }
        guard changed else { return }
        do { try repository.save(progression); lastSaveError = nil }
        catch {
            lastSaveError = error.localizedDescription
            AppLog.persistence.error("Could not save progression: \(error.localizedDescription, privacy: .public)")
        }
    }
}
