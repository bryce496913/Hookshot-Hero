import XCTest
@testable import HookshotHero

final class ProgressionRepositoryTests: XCTestCase {
    private var directory: URL!; private var repository: ProgressionRepository!
    override func setUpWithError() throws { directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString); repository = ProgressionRepository(fileURL: directory.appending(path: "save.json")) }
    override func tearDownWithError() throws { if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) } }
    func testMissingFileReturnsDefaults() { XCTAssertEqual(repository.load(), .missing(defaults: .defaults)) }
    func testSaveReloadAndSchemaVersion() throws {
        let expected = Progression(schemaVersion: 7, highScore: 900, completedLevelIDs: [.init(rawValue: "level-1")])
        try repository.save(expected); XCTAssertEqual(repository.load(), .loaded(expected))
    }
    func testCorruptFileIsRetainedAndNotOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); let corrupt = Data("not-json".utf8); try corrupt.write(to: repository.fileURL)
        XCTAssertEqual(repository.load(), .corrupt); XCTAssertEqual(try Data(contentsOf: repository.fileURL), corrupt)
    }
    func testAtomicReplacementUpdatesExistingFile() throws {
        try repository.save(.defaults); var updated = Progression.defaults; updated.highScore = 42; try repository.save(updated)
        XCTAssertEqual(repository.load(), .loaded(updated))
    }
}
