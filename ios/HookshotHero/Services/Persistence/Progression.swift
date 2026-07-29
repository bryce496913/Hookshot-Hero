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
    case corrupt
}

struct ProgressionRepository: Sendable {
    let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    static func applicationRepository(fileManager: FileManager = .default) throws -> ProgressionRepository {
        let directory = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return ProgressionRepository(fileURL: directory.appending(path: "progression-v1.json"), fileManager: fileManager)
    }

    func load() -> ProgressionLoadResult {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .missing(defaults: .defaults) }
        do { return .loaded(try JSONDecoder().decode(Progression.self, from: Data(contentsOf: fileURL))) }
        catch {
            AppLog.persistence.error("Progression decode failed; original file retained: \(error.localizedDescription, privacy: .public)")
            return .corrupt
        }
    }

    func save(_ progression: Progression) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(progression)
        try data.write(to: fileURL, options: .atomic)
    }
}
