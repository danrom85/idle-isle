import XCTest
@testable import IdleEngine

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

    func testLegacyCrabEventIsClearedWhenStateLoads() {
        var state = WorldState()
        state.ambientEvent = .crabVisits

        let engine = SimulationEngine(seed: 19, initialState: state)

        XCTAssertEqual(engine.state.ambientEvent, .none)
    }

    func testFishingCreatesSharedFishAndStartsCarryHome() {
        var state = WorldState()
        state.activity = .fishing
        state.hunger = 0.8
        state.activityTimeRemaining = 0.05
        state.characterX = 0.24

        let engine = SimulationEngine(seed: 7, initialState: state)
        _ = engine.advance(by: 0.1)

        XCTAssertEqual(engine.state.activity, .carryingFish)
        XCTAssertEqual(engine.state.fish?.state, .carried)
        XCTAssertEqual(engine.state.memory.fishCaught, 1)
        XCTAssertEqual(engine.state.destinationX, 0.59, accuracy: 0.001)
        XCTAssertGreaterThan(engine.state.hunger, 0.79)
    }

    func testFishIsCookedAndEatenBeforeHungerFalls() {
        var state = WorldState()
        state.activity = .cookingFish
        state.hunger = 0.8
        state.characterX = 0.59
        state.activityTimeRemaining = 0.05
        state.fish = WorldState.Fish(state: .cooking, cookingProgress: 0.99)

        let engine = SimulationEngine(seed: 23, initialState: state)
        _ = engine.advance(by: 0.1)

        XCTAssertEqual(engine.state.activity, .eatingFish)
        XCTAssertEqual(engine.state.fish?.state, .cooked)

        let hungerBeforeEating = engine.state.hunger
        for _ in 0..<20 { _ = engine.advance(by: 0.1) }

        XCTAssertLessThan(engine.state.hunger, hungerBeforeEating)
    }

    func testFinishingMealClearsFishAndRecordsMemory() {
        var state = WorldState()
        state.activity = .eatingFish
        state.hunger = 0.8
        state.activityTimeRemaining = 0.05
        state.fish = WorldState.Fish(state: .cooked, cookingProgress: 1)

        let engine = SimulationEngine(seed: 29, initialState: state)
        _ = engine.advance(by: 0.1)

        XCTAssertNil(engine.state.fish)
        XCTAssertEqual(engine.state.memory.mealsEaten, 1)
        XCTAssertLessThan(engine.state.hunger, 0.8)
    }

    func testSleepingRestoresEnergy() {
        var state = WorldState()
        state.activity = .sleeping
        state.energy = 0.2
        state.activityTimeRemaining = 20

        let engine = SimulationEngine(seed: 9, initialState: state)
        for _ in 0..<100 { _ = engine.advance(by: 0.1) }

        XCTAssertGreaterThan(engine.state.energy, 0.2)
    }

    func testWalkingCreatesPathWear() {
        var state = WorldState()
        state.activity = .walking
        state.characterX = 0.30
        state.destinationX = 0.72
        state.activityTimeRemaining = 100

        let engine = SimulationEngine(seed: 13, initialState: state)
        for _ in 0..<100 { _ = engine.advance(by: 0.1) }

        XCTAssertGreaterThan(engine.state.memory.walkingDistance, 0)
        XCTAssertGreaterThan(engine.state.memory.pathWear, 0)
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

    func testTideChangesSmoothlyAndStaysBounded() {
        var state = WorldState()
        state.tidePhase = 0.1
        state.tideLevel = 0.5

        let engine = SimulationEngine(seed: 17, initialState: state)
        let previousLevel = engine.state.tideLevel
        _ = engine.advance(by: 0.1)

        XCTAssertNotEqual(engine.state.tideLevel, previousLevel)
        XCTAssertGreaterThanOrEqual(engine.state.tideLevel, 0)
        XCTAssertLessThanOrEqual(engine.state.tideLevel, 1)
        XCTAssertLessThan(abs(engine.state.tideLevel - previousLevel), 0.5)
    }

    func testWorldStateRoundTripsThroughPersistence() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = temporaryDirectory.appendingPathComponent("world-state.json")
        let persistence = WorldPersistence(fileURL: fileURL)

        var state = WorldState()
        state.schemaVersion = WorldState.currentSchemaVersion
        state.memory.fishingTrips = 7
        state.memory.fishCaught = 3
        state.memory.mealsEaten = 2
        state.memory.walkingDistance = 1.25
        state.characterX = 0.63
        state.tidePhase = 0.77
        state.tideLevel = 0.12
        state.fish = WorldState.Fish(state: .cooking, cookingProgress: 0.4)

        try persistence.save(state)
        let loaded = persistence.load()

        XCTAssertEqual(loaded, state)
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}
