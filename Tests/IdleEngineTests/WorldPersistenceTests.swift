import XCTest
@testable import IdleEngine

final class WorldPersistenceTests: XCTestCase {
    func testSaveAndLoadRoundTripsState() throws {
        let (persistence, _) = makePersistence()

        var state = WorldState()
        state.schemaVersion = WorldState.currentSchemaVersion
        state.elapsedTime = 123.5
        state.memory.fishCaught = 4
        state.fish = WorldState.Fish(state: .cooking, cookingProgress: 0.5)

        try persistence.save(state)

        let loaded = try XCTUnwrap(persistence.load())
        XCTAssertEqual(loaded, state)
        XCTAssertEqual(loaded.schemaVersion, WorldState.currentSchemaVersion)
    }

    func testLegacySaveWithoutSchemaVersionIsUpgraded() throws {
        let (persistence, fileURL) = makePersistence()

        var state = WorldState()
        state.schemaVersion = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(state).write(to: fileURL)

        let loaded = try XCTUnwrap(persistence.load())
        XCTAssertEqual(loaded.elapsedTime, state.elapsedTime)
        XCTAssertEqual(loaded.memory, state.memory)
        XCTAssertEqual(loaded.schemaVersion, WorldState.currentSchemaVersion)
    }

    func testCorruptSaveIsBackedUpAndWorldRestarts() throws {
        let (persistence, fileURL) = makePersistence()

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{ not a world".utf8).write(to: fileURL)

        XCTAssertNil(persistence.load())

        let backupURL = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
        XCTAssertEqual(try Data(contentsOf: backupURL), Data("{ not a world".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        // The next save starts from a clean slate.
        try persistence.save(WorldState())
        XCTAssertNotNil(persistence.load())
    }

    func testResetRemovesExistingSave() throws {
        let (persistence, fileURL) = makePersistence()
        try persistence.save(WorldState())
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try persistence.reset()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        // Resetting again without a file must not throw.
        try persistence.reset()
    }

    private func makePersistence() -> (WorldPersistence, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdleIslePersistenceTests-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("world-state.json")
        return (WorldPersistence(fileURL: url), url)
    }
}
