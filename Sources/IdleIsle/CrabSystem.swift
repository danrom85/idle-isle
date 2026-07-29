import Foundation

struct CrabState: Equatable, Sendable {
    enum Activity: String, Sendable {
        case hidden
        case emerging
        case foraging
        case watchingCastaway
        case resting
        case returningHome
    }

    var activity: Activity = .hidden
    var positionX: Double = 0.84
    var destinationX: Double = 0.84
    var activityTimeRemaining: TimeInterval = 4
    var nextAppearanceIn: TimeInterval = 5
    var familiarity: Double = 0
    var visits: Int = 0

    var isVisible: Bool { activity != .hidden }
}

final class CrabEngine {
    private(set) var state: CrabState
    private var random: SeededGenerator

    init(seed: UInt64 = 0x43524142, initialState: CrabState = CrabState()) {
        state = initialState
        random = SeededGenerator(seed: seed)
    }

    func advance(by deltaTime: TimeInterval, world: WorldState) -> CrabState {
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

        return state
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
