import XCTest
@testable import IdleIsle

final class SimulationEngineTests: XCTestCase {
    func testDayPhaseBoundaries() {
        XCTAssertEqual(SimulationEngine.phase(for: 5.5), .dawn)
        XCTAssertEqual(SimulationEngine.phase(for: 8), .day)
        XCTAssertEqual(SimulationEngine.phase(for: 18), .sunset)
        XCTAssertEqual(SimulationEngine.phase(for: 23), .night)
    }

    func testSimulationIsDeterministicForSameSeed() {
        let first = SimulationEngine(seed: 42)
        let second = SimulationEngine(seed: 42)

        for _ in 0..<500 {
            _ = first.advance(by: 1.0 / 30.0)
            _ = second.advance(by: 1.0 / 30.0)
        }

        XCTAssertEqual(first.state, second.state)
    }

    func testSimulationHourAdvances() {
        let engine = SimulationEngine(seed: 1)
        let initialHour = engine.state.simulatedHour
        _ = engine.advance(by: 0.1)
        XCTAssertGreaterThan(engine.state.simulatedHour, initialHour)
    }
}
