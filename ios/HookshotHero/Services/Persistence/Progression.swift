import Combine
import Foundation

struct Progression: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2
    var schemaVersion: Int = currentSchemaVersion
    /// Legacy best raw gameplay score; ranking uses HighScoreEntry.totalScore instead.
    var highScore = 0
    var completedLevelIDs: Set<LevelID> = []
    var completedMissionIDs: Set<MissionID> = []
    var unlockedContentIDs: Set<UnlockID> = []
    var highScoreEntries: [HighScoreEntry] = []
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
    private let saveOverride: ((Progression) throws -> Void)?
    private let quarantineOverride: ((ProgressionLoadResult) throws -> URL)?

    init(fileURL: URL, fileManager: FileManager = .default,
         saveOverride: ((Progression) throws -> Void)? = nil,
         quarantineOverride: ((ProgressionLoadResult) throws -> URL)? = nil) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.saveOverride = saveOverride
        self.quarantineOverride = quarantineOverride
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
                var progression = try JSONDecoder().decode(Progression.self, from: data)
                progression.highScoreEntries = HighScoreScoring.topEntries(progression.highScoreEntries)
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
        var canonical = progression
        canonical.highScoreEntries = HighScoreScoring.topEntries(canonical.highScoreEntries)
        if let saveOverride { return try saveOverride(canonical) }
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(canonical).write(to: fileURL, options: .atomic)
    }

    /// Moves an unreadable save aside before the canonical URL can be written again.
    /// `moveItem` preserves the original bytes and ensures there is never a window in which
    /// defaults can replace an unpreserved source file.
    func quarantineUnreadableSave(for result: ProgressionLoadResult) throws -> URL {
        switch result {
        case .corrupt, .unsupportedVersion:
            return try quarantine(result)
        default:
            throw ProgressionError.invalidQuarantineRequest
        }
    }

    private func quarantine(_ result: ProgressionLoadResult) throws -> URL {
        if let quarantineOverride { return try quarantineOverride(result) }
        let suffix: String
        switch result {
        case .corrupt: suffix = "corrupt"
        case .unsupportedVersion(let version): suffix = "unsupported-v\(version)"
        default: throw ProgressionError.invalidQuarantineRequest
        }
        let directory = fileURL.deletingLastPathComponent()
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension
        var collision = 1
        while true {
            let discriminator = collision == 1 ? "" : "-\(collision)"
            let name = "\(stem).\(suffix)\(discriminator)"
                + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
            let destination = directory.appending(path: name)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: fileURL, to: destination)
                return destination
            }
            collision += 1
        }
    }

    private func migrate(data: Data, from originalVersion: Int) throws -> ProgressionLoadResult {
        var version = originalVersion
        var migrationData = data
        while version < Progression.currentSchemaVersion {
            switch version {
            case 0:
                let old = try JSONDecoder().decode(ProgressionV0.self, from: migrationData)
                let v1 = ProgressionV1(schemaVersion: 1, highScore: old.highScore,
                    completedLevelIDs: Set(old.completedLevelIDs.map { LevelID(rawValue: $0) }),
                    completedMissionIDs: [], unlockedContentIDs: [])
                migrationData = try JSONEncoder().encode(v1)
                version = 1
            case 1:
                let old = try JSONDecoder().decode(ProgressionV1.self, from: migrationData)
                let current = Progression(highScore: old.highScore,
                    completedLevelIDs: old.completedLevelIDs,
                    completedMissionIDs: old.completedMissionIDs,
                    unlockedContentIDs: old.unlockedContentIDs, highScoreEntries: [])
                migrationData = try JSONEncoder().encode(current)
                version = 2
            default:
                throw ProgressionError.noMigration(version)
            }
        }
        return .migrated(try JSONDecoder().decode(Progression.self, from: migrationData), fromVersion: originalVersion)
    }
}

private struct SchemaEnvelope: Decodable { let schemaVersion: Int }
private struct ProgressionV1: Codable {
    let schemaVersion: Int
    let highScore: Int
    let completedLevelIDs: Set<LevelID>
    let completedMissionIDs: Set<MissionID>
    let unlockedContentIDs: Set<UnlockID>
}
private struct ProgressionV0: Codable { let schemaVersion: Int; let highScore: Int; let completedLevelIDs: [String] }
private enum ProgressionError: Error {
    case invalidSchemaForSave(Int), noMigration(Int), invalidQuarantineRequest
}

@MainActor
final class ProgressionStore: ObservableObject {
    @Published private(set) var progression: Progression
    @Published private(set) var loadResult: ProgressionLoadResult
    @Published private(set) var lastSaveError: String?
    @Published private(set) var hasUnsavedChanges = false
    private let repository: ProgressionRepository
    private var pendingRecovery: ProgressionLoadResult?

    init(repository: ProgressionRepository) {
        self.repository = repository
        let result = repository.load()
        loadResult = result
        AppLog.persistence.info("Progression load classified as \(result.logClassification, privacy: .public)")
        switch result {
        case .loaded(let value), .migrated(let value, _), .missing(defaults: let value): progression = value
        case .unsupportedVersion, .corrupt:
            progression = .defaults
            pendingRecovery = result
            preserveUnreadableSave()
        }
        if case .migrated = result {
            hasUnsavedChanges = true
            flushPendingSave()
        }
    }

    func record(result: GameResult, leaderboardEligible: Bool = false) {
        var changed = false
        if result.score > progression.highScore { progression.highScore = result.score; changed = true }
        if result.outcome == .won {
            changed = progression.completedLevelIDs.insert(result.levelID).inserted || changed
            if let missionID = result.missionID {
                changed = progression.completedMissionIDs.insert(missionID).inserted || changed
            }
        }
        // Intermediate progression records call this with the default false eligibility.
        if leaderboardEligible, result.outcome == .won, result.levelID == .heroWelcome,
           !progression.highScoreEntries.contains(where: { $0.id == result.sessionID }),
           let entry = HighScoreEntry.completedRun(result) {
            let ranked = HighScoreScoring.topEntries(progression.highScoreEntries + [entry])
            if ranked != progression.highScoreEntries {
                progression.highScoreEntries = ranked
                changed = true
            }
        }
        if changed { hasUnsavedChanges = true }
        guard changed || hasUnsavedChanges else { return }
        flushPendingSave()
    }

    func flushPendingSave() {
        if pendingRecovery != nil {
            preserveUnreadableSave()
        }
        guard pendingRecovery == nil, hasUnsavedChanges else { return }
        do {
            try repository.save(progression)
            hasUnsavedChanges = false
            lastSaveError = nil
        }
        catch {
            lastSaveError = error.localizedDescription
            AppLog.persistence.error("Could not save progression: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func preserveUnreadableSave() {
        guard let pendingRecovery else { return }
        do {
            let destination = try repository.quarantineUnreadableSave(for: pendingRecovery)
            self.pendingRecovery = nil
            lastSaveError = nil
            AppLog.persistence.info(
                "Unreadable progression quarantined as \(destination.lastPathComponent, privacy: .public)")
        } catch {
            lastSaveError = error.localizedDescription
            AppLog.persistence.error(
                "Could not quarantine progression; canonical save remains protected: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private extension ProgressionLoadResult {
    var logClassification: String {
        switch self {
        case .loaded: return "loaded"
        case .missing: return "missing"
        case .migrated(_, let version): return "migrated-v\(version)"
        case .unsupportedVersion(let version): return "unsupported-v\(version)"
        case .corrupt: return "corrupt"
        }
    }
}
