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

    func testFishingSatisfiesHunger() {
        var state = WorldState()
        state.activity = .fishing
        state.hunger = 0.8
        state.activityTimeRemaining = 20

        let engine = SimulationEngine(seed: 7, initialState: state)
        for _ in 0..<100 {
            _ = engine.advance(by: 0.1)
        }

        XCTAssertLessThan(engine.state.hunger, 0.8)
    }

    func testSleepingRestoresEnergy() {
        var state = WorldState()
        state.activity = .sleeping
        state.energy = 0.2
        state.activityTimeRemaining = 20

        let engine = SimulationEngine(seed: 9, initialState: state)
        for _ in 0..<100 {
            _ = engine.advance(by: 0.1)
        }

        XCTAssertGreaterThan(engine.state.energy, 0.2)
    }

    func testWeatherMovesTowardTargetsWithoutJumping() {
        var state = WorldState()
        state.wind = 0.1
        state.targetWind = 0.8
        state.cloudCover = 0.2
        state.targetCloudCover = 0.7
        state.nextWeatherChangeIn = 100

        let engine = SimulationEngine(seed: 11, initialState: state)
        _ = engine.advance(by: 0.1)

        XCTAssertGreaterThan(engine.state.wind, 0.1)
        XCTAssertLessThan(engine.state.wind, 0.8)
        XCTAssertGreaterThan(engine.state.cloudCover, 0.2)
        XCTAssertLessThan(engine.state.cloudCover, 0.7)
    }
}
