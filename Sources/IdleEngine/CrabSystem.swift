import Foundation

public struct CrabState: Equatable, Sendable {
    public init() {}
    public enum Activity: String, Sendable {
        case hidden
        case emerging
        case foraging
        case watchingCastaway
        case resting
        case returningHome
    }

    public var activity: Activity = .hidden
    public var positionX: Double = 0.84
    public var destinationX: Double = 0.84
    public var activityTimeRemaining: TimeInterval = 4
    public var nextAppearanceIn: TimeInterval = 5
    public var familiarity: Double = 0
    public var visits: Int = 0

    public var isVisible: Bool { activity != .hidden }
}

public struct HermitCrabState: Equatable, Sendable {
    public enum Activity: String, Sendable {
        case hidden
        case emerging
        case wandering
        case watchingCastaway
        case returningHome
    }

    public var activity: Activity = .hidden
    public var positionX: Double = 0.80
    public var destinationX: Double = 0.80
    public var activityTimeRemaining: TimeInterval = 4
    public var nextAppearanceIn: TimeInterval = 45

    public var isVisible: Bool { activity != .hidden }

    public init() {}
}

public final class CrabEngine {
    public private(set) var state: CrabState

    /// A shy neighbor in a borrowed shell. Only shows up once the red crab
    /// has grown familiar with the castaway.
    public private(set) var hermit = HermitCrabState()
    private var hermitRandom: SeededGenerator
    private var random: SeededGenerator

    public init(seed: UInt64 = 0x43524142, initialState: CrabState = CrabState()) {
        state = initialState
        random = SeededGenerator(seed: seed)
        hermitRandom = SeededGenerator(seed: seed &* 2 &+ 0x4845524D)
    }

    @discardableResult
    public func advance(by deltaTime: TimeInterval, world: WorldState) -> CrabState {
        let delta = min(max(deltaTime, 0), 0.1)

        if state.activity == .hidden {
            state.nextAppearanceIn -= delta
            let favorableTide = world.tideLevel < 0.62
            if state.nextAppearanceIn <= 0 && favorableTide && world.dayPhase != .night {
                state.activity = .emerging
                state.positionX = 0.90
                state.destinationX = 0.72
                state.activityTimeRemaining = 4
                state.visits += 1
            }
            return state
        }

        switch state.activity {
        case .hidden:
            break

        case .emerging, .returningHome:
            let direction = state.destinationX >= state.positionX ? 1.0 : -1.0
            state.positionX += direction * delta * 0.055
            state.activityTimeRemaining -= delta

            if abs(state.destinationX - state.positionX) < 0.015 || state.activityTimeRemaining <= 0 {
                state.positionX = state.destinationX
                if state.activity == .returningHome {
                    hide()
                } else {
                    chooseVisibleActivity(world: world)
                }
            }

        case .foraging:
            state.activityTimeRemaining -= delta
            state.positionX += sin(state.activityTimeRemaining * 2.7) * delta * 0.012
            state.familiarity = min(1, state.familiarity + delta * 0.0018)
            if state.activityTimeRemaining <= 0 { chooseVisibleActivity(world: world) }

        case .watchingCastaway:
            state.activityTimeRemaining -= delta
            state.familiarity = min(1, state.familiarity + delta * 0.004)
            if state.activityTimeRemaining <= 0 { chooseVisibleActivity(world: world) }

        case .resting:
            state.activityTimeRemaining -= delta
            state.familiarity = min(1, state.familiarity + delta * 0.001)
            if state.activityTimeRemaining <= 0 { chooseVisibleActivity(world: world) }
        }

        if world.tideLevel > 0.74 && state.activity != .returningHome {
            beginReturnHome()
        }

        advanceHermit(by: delta, world: world)

        return state
    }

    private func advanceHermit(by delta: TimeInterval, world: WorldState) {
        switch hermit.activity {
        case .hidden:
            hermit.nextAppearanceIn -= delta
            let crabIsComfortable = state.familiarity > 0.35 && state.isVisible
            let favorable = world.dayPhase != .night && world.tideLevel < 0.62 && world.rain < 0.5
            if hermit.nextAppearanceIn <= 0 && crabIsComfortable && favorable {
                hermit.activity = .emerging
                hermit.positionX = 0.82
                hermit.destinationX = max(0.60, min(0.78, state.positionX + 0.06))
                hermit.activityTimeRemaining = 6
            }

        case .emerging, .returningHome:
            let direction = hermit.destinationX >= hermit.positionX ? 1.0 : -1.0
            hermit.positionX += direction * delta * 0.032
            hermit.activityTimeRemaining -= delta
            if abs(hermit.destinationX - hermit.positionX) < 0.01 || hermit.activityTimeRemaining <= 0 {
                hermit.positionX = hermit.destinationX
                if hermit.activity == .returningHome {
                    hermit.activity = .hidden
                    hermit.positionX = 0.84
                    hermit.destinationX = 0.84
                    hermit.nextAppearanceIn = hermitRange(50...110)
                } else {
                    chooseHermitActivity(world: world)
                }
            }

        case .wandering:
            hermit.activityTimeRemaining -= delta
            if hermit.activityTimeRemaining <= 0 { chooseHermitActivity(world: world) }

        case .watchingCastaway:
            hermit.activityTimeRemaining -= delta
            if hermit.activityTimeRemaining <= 0 { chooseHermitActivity(world: world) }
        }

        // Rain or high tide sends everyone home.
        if hermit.isVisible && (world.tideLevel > 0.74 || world.rain > 0.6),
           hermit.activity != .returningHome {
            beginHermitReturnHome()
        }
    }

    private func chooseHermitActivity(world: WorldState) {
        let roll = hermitRandom.unitInterval()
        if roll < 0.45 {
            hermit.activity = .wandering
            hermit.destinationX = hermitRange(0.58...0.78)
            hermit.activityTimeRemaining = hermitRange(8...16)
        } else if roll < 0.8 {
            hermit.activity = .watchingCastaway
            hermit.activityTimeRemaining = hermitRange(6...12)
        } else {
            beginHermitReturnHome()
        }
    }

    private func beginHermitReturnHome() {
        hermit.activity = .returningHome
        hermit.destinationX = 0.84
        hermit.activityTimeRemaining = 8
    }

    private func hermitRange(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + hermitRandom.unitInterval() * (range.upperBound - range.lowerBound)
    }

    private func chooseVisibleActivity(world: WorldState) {
        let castawayIsNearby = abs(world.characterX - state.positionX) < 0.18
        let roll = random.unitInterval()

        if castawayIsNearby && roll < 0.58 {
            state.activity = .watchingCastaway
            state.activityTimeRemaining = randomRange(8...15)
        } else if roll < 0.72 {
            state.activity = .foraging
            state.destinationX = randomRange(0.58...0.82)
            state.activityTimeRemaining = randomRange(10...18)
        } else if roll < 0.90 {
            state.activity = .resting
            state.activityTimeRemaining = randomRange(7...13)
        } else {
            beginReturnHome()
        }
    }

    private func beginReturnHome() {
        state.activity = .returningHome
        state.destinationX = 0.92
        state.activityTimeRemaining = 6
    }

    private func hide() {
        state.activity = .hidden
        state.positionX = 0.92
        state.destinationX = 0.92
        state.nextAppearanceIn = randomRange(12...28)
    }

    private func randomRange(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + random.unitInterval() * (range.upperBound - range.lowerBound)
    }
}
