import XCTest
@testable import IdleEngine

final class WorldRuntimeTests: XCTestCase {
    func testDriverAdvancesWorldTime() {
        let runtime = WorldRuntime(
            role: .driver,
            initialState: WorldState()
        )

        let initialElapsedTime = runtime.state.elapsedTime
        _ = runtime.advance(by: 0.1)

        XCTAssertTrue(runtime.canAdvanceTime)
        XCTAssertGreaterThan(runtime.state.elapsedTime, initialElapsedTime)
    }

    func testObserverCannotAdvanceWorldTime() {
        var initialState = WorldState()
        initialState.elapsedTime = 42
        initialState.characterX = 0.61
        initialState.activity = .fishing

        let runtime = WorldRuntime(
            role: .observer,
            initialState: initialState
        )

        let snapshot = runtime.advance(by: 10)

        XCTAssertFalse(runtime.canAdvanceTime)
        XCTAssertEqual(snapshot, initialState)
        XCTAssertEqual(runtime.state.elapsedTime, 42)
        XCTAssertEqual(runtime.state.characterX, 0.61)
        XCTAssertEqual(runtime.state.activity, .fishing)
    }
}
