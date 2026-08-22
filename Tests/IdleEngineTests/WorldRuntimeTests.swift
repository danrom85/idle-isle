import XCTest
@testable import IdleEngine

final class WorldRuntimeTests: XCTestCase {
    func testDriverAdvancesWorldTime() {
        let runtime = WorldRuntime(
            role: .driver,
            initialState: WorldState(),
            autosaveInterval: nil
        )

        let initialElapsedTime = runtime.state.elapsedTime
        _ = runtime.advance(by: 0.1)

        XCTAssertTrue(runtime.canAdvanceTime)
        XCTAssertGreaterThan(runtime.state.elapsedTime, initialElapsedTime)
    }

    func testObserverCannotAdvanceWorldTime() {
        var initialState = WorldState()
        initialState.schemaVersion = WorldState.currentSchemaVersion
        initialState.elapsedTime = 42
        initialState.characterX = 0.61
        initialState.activity = .fishing

        let runtime = WorldRuntime(
            role: .observer,
            persistence: WorldPersistence(fileURL: Self.temporaryFileURL()),
            initialState: initialState,
            autosaveInterval: nil
        )

        let snapshot = runtime.advance(by: 10)

        XCTAssertFalse(runtime.canAdvanceTime)
        XCTAssertEqual(snapshot, initialState)
        XCTAssertEqual(runtime.state.elapsedTime, 42)
        XCTAssertEqual(runtime.state.characterX, 0.61)
        XCTAssertEqual(runtime.state.activity, .fishing)
    }

    func testDriverAutosavesAfterReachingInterval() throws {
        let fileURL = Self.temporaryFileURL()
        let persistence = WorldPersistence(fileURL: fileURL)
        let runtime = WorldRuntime(
            role: .driver,
            persistence: persistence,
            initialState: WorldState(),
            autosaveInterval: 5
        )

        XCTAssertNil(persistence.load())

        _ = runtime.advance(by: 2.5)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        _ = runtime.advance(by: 3)

        let saved = try XCTUnwrap(persistence.load())
        XCTAssertEqual(saved, runtime.state)
    }

    func testAdvanceSpanCatchesUpInSimulationSteps() {
        let runtime = WorldRuntime(
            role: .driver,
            initialState: WorldState(),
            autosaveInterval: nil
        )

        _ = runtime.advanceSpan(by: 25)

        XCTAssertEqual(runtime.state.elapsedTime, 25, accuracy: 0.001)
    }

    func testAdvanceSpanIsCapped() {
        let runtime = WorldRuntime(
            role: .driver,
            initialState: WorldState(),
            autosaveInterval: nil
        )

        _ = runtime.advanceSpan(by: 100_000)

        XCTAssertLessThanOrEqual(runtime.state.elapsedTime, 600.5)
    }

    private static func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("IdleIsleRuntimeTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("world-state.json")
    }
}
