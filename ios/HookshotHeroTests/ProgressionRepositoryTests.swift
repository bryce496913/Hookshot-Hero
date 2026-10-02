import XCTest
@testable import HookshotHero

@MainActor final class ProgressionRepositoryTests: XCTestCase {
    private var directory: URL!; private var repository: ProgressionRepository!
    override func setUp() { directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString); repository = ProgressionRepository(fileURL: directory.appending(path: "save.json")) }
    override func tearDownWithError() throws { if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) } }
    func testMissingFileReturnsDefaults() { XCTAssertEqual(repository.load(), .missing(defaults: .defaults)) }
    func testCurrentSchemaRoundTripAndAtomicReplacement() throws {
        var expected = Progression.defaults; expected.highScore = 900; try repository.save(expected)
        XCTAssertEqual(repository.load(), .loaded(expected)); expected.highScore = 901; try repository.save(expected)
        XCTAssertEqual(repository.load(), .loaded(expected))
    }
    func testMigratesV0Fixture() throws {
        try write(#"{"schemaVersion":0,"highScore":12,"completedLevelIDs":["level-0"]}"#)
        var expected = Progression.defaults; expected.highScore = 12; expected.completedLevelIDs = [.init(rawValue: "level-0")]
        XCTAssertEqual(repository.load(), .migrated(expected, fromVersion: 0))
    }
    func testFutureVersionIsPreserved() throws {
        let original = #"{"schemaVersion":7,"future":"value"}"#; try write(original)
        XCTAssertEqual(repository.load(), .unsupportedVersion(7)); XCTAssertEqual(String(data: try Data(contentsOf: repository.fileURL), encoding: .utf8), original)
    }
    func testCorruptAndInvalidSchemaArePreserved() throws {
        for original in ["not-json", #"{"schemaVersion":"one"}"#, #"{"schemaVersion":-1}"#] {
            try write(original); XCTAssertEqual(repository.load(), .corrupt)
            XCTAssertEqual(String(data: try Data(contentsOf: repository.fileURL), encoding: .utf8), original)
        }
    }
    func testCorruptSaveIsQuarantinedByteForByteAndCanonicalCanBeReplaced() throws {
        let original = Data([0x00, 0xFF, 0x42, 0x10])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try original.write(to: repository.fileURL)

        let store = ProgressionStore(repository: repository)
        let quarantineURL = directory.appending(path: "save.corrupt.json")
        XCTAssertEqual(try Data(contentsOf: quarantineURL), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))

        store.record(result: result(score: 8))
        XCTAssertEqual(repository.load(), .loaded(store.progression))
        XCTAssertEqual(try Data(contentsOf: quarantineURL), original)
    }
    func testFutureSaveUsesCollisionSafeQuarantineName() throws {
        let original = Data(#"{"schemaVersion":7,"future":"value"}"#.utf8)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("existing".utf8).write(to: directory.appending(path: "save.unsupported-v7.json"))
        try original.write(to: repository.fileURL)

        _ = ProgressionStore(repository: repository)

        XCTAssertEqual(
            try Data(contentsOf: directory.appending(path: "save.unsupported-v7-2.json")), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }
    func testQuarantineFailureBlocksCanonicalOverwrite() throws {
        let original = Data("not-json".utf8)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try original.write(to: repository.fileURL)
        let blocked = ProgressionRepository(
            fileURL: repository.fileURL,
            quarantineOverride: { _ in throw TestError.expectedFailure })

        let store = ProgressionStore(repository: blocked)
        store.record(result: result(score: 9))

        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertNotNil(store.lastSaveError)
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
    }
    func testProgressionStoreRecordsHighScoreAndUniqueCompletion() {
        let store = ProgressionStore(repository: repository)
        let result = GameResult(sessionID: UUID(), levelID: .init(rawValue: "level-1"), missionID: .init(rawValue: "mission-1"), score: 42, elapsedTime: 3, outcome: .won)
        store.record(result: result); store.record(result: result)
        XCTAssertEqual(store.progression.highScore, 42); XCTAssertEqual(store.progression.completedLevelIDs.count, 1)
        XCTAssertEqual(store.progression.completedMissionIDs.count, 1); XCTAssertNil(store.lastSaveError)
    }
    func testSaveFailureIsReported() {
        let impossible = ProgressionRepository(fileURL: URL(filePath: "/dev/null/save.json"))
        let store = ProgressionStore(repository: impossible)
        store.record(result: .init(sessionID: UUID(), levelID: .init(rawValue: "level"), missionID: nil, score: 1, elapsedTime: 0, outcome: .lost))
        XCTAssertNotNil(store.lastSaveError)
    }
    func testFailedSaveIsDirtyAndSameResultRetriesWithoutDuplicatingProgress() throws {
        var attempts = 0
        let retrying = ProgressionRepository(fileURL: repository.fileURL, saveOverride: { value in
            attempts += 1
            if attempts == 1 { throw TestError.expectedFailure }
            try self.repository.save(value)
        })
        let store = ProgressionStore(repository: retrying)
        let gameResult = result(score: 42, outcome: .won)

        store.record(result: gameResult)
        XCTAssertEqual(attempts, 1)
        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertNotNil(store.lastSaveError)

        store.record(result: gameResult)
        XCTAssertEqual(attempts, 2)
        XCTAssertFalse(store.hasUnsavedChanges)
        XCTAssertNil(store.lastSaveError)
        XCTAssertEqual(store.progression.highScore, 42)
        XCTAssertEqual(store.progression.completedLevelIDs, Set([gameResult.levelID]))
        XCTAssertEqual(store.progression.completedMissionIDs, Set([gameResult.missionID!]))
        XCTAssertEqual(repository.load(), .loaded(store.progression))
    }
    func testExplicitFlushRetriesPendingSave() {
        var shouldFail = true
        let retrying = ProgressionRepository(fileURL: repository.fileURL, saveOverride: { value in
            if shouldFail { throw TestError.expectedFailure }
            try self.repository.save(value)
        })
        let store = ProgressionStore(repository: retrying)
        store.record(result: result(score: 12))
        shouldFail = false

        store.flushPendingSave()

        XCTAssertFalse(store.hasUnsavedChanges)
        XCTAssertNil(store.lastSaveError)
        XCTAssertEqual(repository.load(), .loaded(store.progression))
    }
    private func result(score: Int, outcome: GameOutcome = .lost) -> GameResult {
        GameResult(
            sessionID: UUID(), levelID: .init(rawValue: "level-1"),
            missionID: .init(rawValue: "mission-1"), score: score, elapsedTime: 3,
            outcome: outcome)
    }
    private func write(_ value: String) throws { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); try Data(value.utf8).write(to: repository.fileURL) }
}

private enum TestError: Error { case expectedFailure }
