import XCTest
@testable import IdleEngine

final class PresenceEngineTests: XCTestCase {
    func testVisitorArrivesAndEventuallyLeaves() {
        var presence = PresenceState()
        presence.nextArrivalIn = 0

        let engine = PresenceEngine(seed: 21, initialState: presence)
        var world = WorldState()
        world.dayPhase = .day
        world.wind = 0.2
        world.cloudCover = 0.2

        _ = engine.advance(by: 0.1, world: world)
        XCTAssertTrue(engine.state.isPresent)
        XCTAssertEqual(engine.state.visitCount, 1)

        var completedFirstVisit = false
        for _ in 0..<400 {
            _ = engine.advance(by: 0.1, world: world)
            if engine.state.phase == .absent && engine.state.visitCount == 1 {
                completedFirstVisit = true
                break
            }
        }

        XCTAssertTrue(completedFirstVisit)
        XCTAssertEqual(engine.state.phase, .absent)
        XCTAssertEqual(engine.state.visitor, .none)
        XCTAssertGreaterThan(engine.state.nextArrivalIn, 0)
    }

    func testPresenceIsDeterministicForSameSeed() {
        var initial = PresenceState()
        initial.nextArrivalIn = 0

        let first = PresenceEngine(seed: 99, initialState: initial)
        let second = PresenceEngine(seed: 99, initialState: initial)
        var world = WorldState()
        world.dayPhase = .sunset
        world.wind = 0.3

        for _ in 0..<250 {
            _ = first.advance(by: 0.1, world: world)
            _ = second.advance(by: 0.1, world: world)
        }

        XCTAssertEqual(first.state, second.state)
    }

    func testHighWindDayAvoidsButterflies() {
        var initial = PresenceState()
        initial.nextArrivalIn = 0

        let engine = PresenceEngine(seed: 5, initialState: initial)
        var world = WorldState()
        world.dayPhase = .day
        world.wind = 0.9
        world.cloudCover = 0.1

        _ = engine.advance(by: 0.1, world: world)

        XCTAssertNotEqual(engine.state.visitor, .butterflies)
    }
}
