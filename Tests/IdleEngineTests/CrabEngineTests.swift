import XCTest
@testable import IdleEngine

final class CrabEngineTests: XCTestCase {
    func testCrabEmergesAtFavorableTide() {
        var crab = CrabState()
        crab.nextAppearanceIn = 0

        var world = WorldState()
        world.dayPhase = .day
        world.tideLevel = 0.3

        let engine = CrabEngine(seed: 3, initialState: crab)
        _ = engine.advance(by: 0.1, world: world)

        XCTAssertEqual(engine.state.activity, .emerging)
        XCTAssertTrue(engine.state.isVisible)
        XCTAssertEqual(engine.state.visits, 1)
    }

    func testCrabStaysHiddenAtHighTide() {
        var crab = CrabState()
        crab.nextAppearanceIn = 0

        var world = WorldState()
        world.dayPhase = .day
        world.tideLevel = 0.9

        let engine = CrabEngine(seed: 3, initialState: crab)
        _ = engine.advance(by: 0.1, world: world)

        XCTAssertEqual(engine.state.activity, .hidden)
        XCTAssertFalse(engine.state.isVisible)
    }

    func testHighTideSendsVisibleCrabHome() {
        var crab = CrabState()
        crab.activity = .foraging
        crab.positionX = 0.70
        crab.activityTimeRemaining = 12

        var world = WorldState()
        world.dayPhase = .day
        world.tideLevel = 0.9

        let engine = CrabEngine(seed: 8, initialState: crab)
        _ = engine.advance(by: 0.1, world: world)

        XCTAssertEqual(engine.state.activity, .returningHome)
        XCTAssertEqual(engine.state.destinationX, 0.92)
    }

    func testWatchingCastawayBuildsFamiliarity() {
        var crab = CrabState()
        crab.activity = .watchingCastaway
        crab.positionX = 0.70
        crab.activityTimeRemaining = 10

        var world = WorldState()
        world.dayPhase = .day
        world.tideLevel = 0.4
        world.characterX = 0.70

        let engine = CrabEngine(seed: 9, initialState: crab)
        let initialFamiliarity = engine.state.familiarity
        _ = engine.advance(by: 0.1, world: world)

        XCTAssertGreaterThan(engine.state.familiarity, initialFamiliarity)
    }

    func testHermitCrabStaysHiddenUntilRedCrabIsFamiliar() {
        let engine = CrabEngine(seed: 21)

        // Unfamiliar red crab: hermit never emerges no matter how long passes.
        for _ in 0..<2000 { _ = engine.advance(by: 0.1, world: WorldState()) }
        XCTAssertFalse(engine.hermit.isVisible)
    }

    func testHermitCrabEmergesOnceCrabIsComfortable() {
        var state = CrabState()
        state.activity = .foraging
        state.familiarity = 0.9
        state.positionX = 0.70
        state.destinationX = 0.70
        let engine = CrabEngine(seed: 21, initialState: state)

        var world = WorldState()
        world.dayPhase = .day
        world.tideLevel = 0.4

        for _ in 0..<1200 { _ = engine.advance(by: 0.1, world: world) }

        XCTAssertTrue(engine.hermit.isVisible || engine.hermit.nextAppearanceIn < 45,
                      "hermit should have had a chance to visit")
    }
}
