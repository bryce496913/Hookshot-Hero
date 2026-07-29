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
        for original in ["not-json", #"{"schemaVersion":"one"}"#] {
            try write(original); XCTAssertEqual(repository.load(), .corrupt)
            XCTAssertEqual(String(data: try Data(contentsOf: repository.fileURL), encoding: .utf8), original)
        }
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
    private func write(_ value: String) throws { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); try Data(value.utf8).write(to: repository.fileURL) }
}
