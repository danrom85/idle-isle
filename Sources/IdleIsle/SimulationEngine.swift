import Foundation

struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func unitInterval() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

final class SimulationEngine {
    private(set) var state: WorldState
    private var random: SeededGenerator

    init(seed: UInt64 = 0x1D1E15E, initialState: WorldState = WorldState()) {
        state = initialState
        random = SeededGenerator(seed: seed)
    }

    func advance(by deltaTime: TimeInterval) -> WorldState {
        let delta = min(max(deltaTime, 0), 0.1)
        state.elapsedTime += delta
        state.simulatedHour = (state.simulatedHour + delta * 0.12).truncatingRemainder(dividingBy: 24)
        state.dayPhase = Self.phase(for: state.simulatedHour)

        updateCharacter(by: delta)
        updateActivity(by: delta)
        updateAmbientEvents(by: delta)

        return state
    }

    static func phase(for hour: Double) -> WorldState.DayPhase {
        switch hour {
        case 5..<7: return .dawn
        case 7..<17: return .day
        case 17..<20: return .sunset
        default: return .night
        }
    }

    private func updateCharacter(by delta: TimeInterval) {
        switch state.activity {
        case .walking:
            let direction = state.destinationX >= state.characterX ? 1.0 : -1.0
            state.characterX += direction * delta * 0.085
            if abs(state.destinationX - state.characterX) < 0.01 {
                state.characterX = state.destinationX
                chooseActivity()
            }
        case .fishing, .watchingOcean:
            state.energy = max(0, state.energy - delta * 0.004)
        case .sleeping, .resting:
            state.energy = min(1, state.energy + delta * 0.018)
        case .idle:
            state.energy = max(0, state.energy - delta * 0.001)
        }
    }

    private func updateActivity(by delta: TimeInterval) {
        state.activityTimeRemaining -= delta
        guard state.activityTimeRemaining <= 0 else { return }
        chooseActivity()
    }

    private func chooseActivity() {
        if state.dayPhase == .night && state.energy < 0.9 {
            begin(.sleeping, duration: randomDuration(6...11))
            return
        }

        if state.energy < 0.28 {
            begin(.resting, duration: randomDuration(4...7))
            return
        }

        let roll = random.unitInterval()
        switch roll {
        case 0..<0.28:
            state.destinationX = randomRange(0.26...0.72)
            begin(.walking, duration: 12)
        case 0.28..<0.48:
            state.characterX = 0.24
            begin(.fishing, duration: randomDuration(5...9))
        case 0.48..<0.68:
            begin(.watchingOcean, duration: randomDuration(4...8))
        case 0.68..<0.84:
            begin(.resting, duration: randomDuration(3...6))
        default:
            begin(.idle, duration: randomDuration(2...5))
        }
    }

    private func begin(_ activity: WorldState.Activity, duration: TimeInterval) {
        state.activity = activity
        state.activityTimeRemaining = duration
    }

    private func updateAmbientEvents(by delta: TimeInterval) {
        state.nextAmbientEventIn -= delta
        guard state.nextAmbientEventIn <= 0 else { return }

        let candidates: [WorldState.AmbientEvent]
        if state.dayPhase == .night {
            candidates = [.shootingStar, .fishJumps, .crabVisits, .none]
        } else {
            candidates = [.gullPasses, .fishJumps, .coconutFalls, .crabVisits, .none]
        }

        state.ambientEvent = candidates[Int(random.next() % UInt64(candidates.count))]
        state.nextAmbientEventIn = randomDuration(4...9)
    }

    private func randomDuration(_ range: ClosedRange<Double>) -> Double {
        randomRange(range)
    }

    private func randomRange(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + random.unitInterval() * (range.upperBound - range.lowerBound)
    }
}
