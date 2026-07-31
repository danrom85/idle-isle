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
    private static let defaultWorldSeed: UInt64 = 0x1D1E15E
    private nonisolated(unsafe) static weak var defaultWorldAuthority: SimulationEngine?

    private(set) var state: WorldState
    private var random: SeededGenerator
    private let participatesInDefaultWorld: Bool

    init(seed: UInt64 = 0x1D1E15E, initialState: WorldState = WorldState()) {
        var restoredState = initialState
        if restoredState.ambientEvent == .crabVisits {
            restoredState.ambientEvent = .none
        }

        state = restoredState
        random = SeededGenerator(seed: seed)
        participatesInDefaultWorld = seed == Self.defaultWorldSeed

        if participatesInDefaultWorld, Self.defaultWorldAuthority == nil {
            Self.defaultWorldAuthority = self
        }
    }

    func advance(by deltaTime: TimeInterval) -> WorldState {
        if participatesInDefaultWorld,
           let authority = Self.defaultWorldAuthority,
           authority !== self {
            state = authority.state
            return state
        }

        let delta = min(max(deltaTime, 0), 0.1)
        state.elapsedTime += delta
        state.simulatedHour = (state.simulatedHour + delta * 0.12).truncatingRemainder(dividingBy: 24)
        state.dayPhase = Self.phase(for: state.simulatedHour)

        updateWeather(by: delta)
        updateTide(by: delta)
        updateNeeds(by: delta)
        updateMemory(by: delta)
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

    private func updateWeather(by delta: TimeInterval) {
        state.nextWeatherChangeIn -= delta
        if state.nextWeatherChangeIn <= 0 {
            state.targetWind = randomRange(0.05...0.82)
            state.targetCloudCover = randomRange(0.05...0.88)
            state.nextWeatherChangeIn = randomDuration(10...22)
        }

        state.wind += (state.targetWind - state.wind) * delta * 0.12
        state.cloudCover += (state.targetCloudCover - state.cloudCover) * delta * 0.08
    }

    private func updateTide(by delta: TimeInterval) {
        state.tidePhase = (state.tidePhase + delta / 210).truncatingRemainder(dividingBy: 1)
        state.tideLevel = 0.5 + sin(state.tidePhase * Double.pi * 2) * 0.5
    }

    private func updateNeeds(by delta: TimeInterval) {
        guard state.activity != .sleeping else { return }
        state.hunger = min(1, state.hunger + delta * 0.005)
        state.curiosity = min(1, state.curiosity + delta * 0.003)
    }

    private func updateMemory(by delta: TimeInterval) {
        state.memory.totalLivedSeconds += delta

        switch state.activity {
        case .walking:
            let windResistance = 1 - state.wind * 0.18
            state.memory.walkingDistance += delta * 0.085 * windResistance
        case .fishing:
            state.memory.fishingSeconds += delta
        case .watchingOcean:
            state.memory.oceanWatchingSeconds += delta
        case .resting, .idle, .sleeping:
            break
        }

        if abs(state.characterX - 0.59) < 0.08 { state.memory.campfireSeconds += delta }
        if state.characterX > 0.68 { state.memory.palmShadeSeconds += delta }
    }

    private func updateCharacter(by delta: TimeInterval) {
        switch state.activity {
        case .walking:
            let direction = state.destinationX >= state.characterX ? 1.0 : -1.0
            let windResistance = 1 - state.wind * 0.18
            state.characterX += direction * delta * 0.085 * windResistance
            state.energy = max(0, state.energy - delta * 0.007)
            if abs(state.destinationX - state.characterX) < 0.01 {
                state.characterX = state.destinationX
                chooseActivity()
            }
        case .fishing:
            state.energy = max(0, state.energy - delta * 0.005)
            state.hunger = max(0, state.hunger - delta * 0.030)
            state.curiosity = max(0, state.curiosity - delta * 0.008)
        case .watchingOcean:
            state.energy = max(0, state.energy - delta * 0.001)
            state.curiosity = max(0, state.curiosity - delta * 0.024)
        case .sleeping:
            state.energy = min(1, state.energy + delta * 0.030)
            state.hunger = min(1, state.hunger + delta * 0.002)
        case .resting:
            state.energy = min(1, state.energy + delta * 0.020)
            state.curiosity = max(0, state.curiosity - delta * 0.004)
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
        if state.dayPhase == .night && state.energy < 0.92 {
            begin(.sleeping, duration: randomDuration(7...12))
            return
        }

        if state.hunger > 0.62 && state.dayPhase != .night {
            state.destinationX = 0.24
            if abs(state.characterX - state.destinationX) > 0.025 {
                begin(.walking, duration: 12)
            } else {
                begin(.fishing, duration: randomDuration(6...10))
            }
            return
        }

        if state.energy < 0.30 {
            if state.memory.palmShadeWear > 0.35 && state.characterX < 0.68 {
                state.destinationX = 0.72
                begin(.walking, duration: 12)
            } else {
                begin(.resting, duration: randomDuration(4...8))
            }
            return
        }

        if state.curiosity > 0.70 && state.wind < 0.68 {
            begin(.watchingOcean, duration: randomDuration(5...9))
            return
        }

        let roll = random.unitInterval()
        let walkingChance = max(0.12, 0.34 - state.wind * 0.20)
        let memoryBias = min(0.08, state.memory.oceanWatchingSeconds / 700)
        let watchingThreshold = walkingChance + 0.24 + (1 - state.cloudCover) * 0.08 + memoryBias
        let restingThreshold = watchingThreshold + 0.18 + state.wind * 0.08

        switch roll {
        case 0..<walkingChance:
            state.destinationX = randomRange(0.26...0.72)
            begin(.walking, duration: 12)
        case walkingChance..<watchingThreshold:
            begin(.watchingOcean, duration: randomDuration(4...8))
        case watchingThreshold..<restingThreshold:
            begin(.resting, duration: randomDuration(3...6))
        default:
            begin(.idle, duration: randomDuration(2...5))
        }
    }

    private func begin(_ activity: WorldState.Activity, duration: TimeInterval) {
        if activity != state.activity {
            if activity == .fishing { state.memory.fishingTrips += 1 }
            if activity == .sleeping { state.memory.nightsSlept += 1 }
            state.memory.lastRecordedActivity = activity
        }
        state.activity = activity
        state.activityTimeRemaining = duration
    }

    private func updateAmbientEvents(by delta: TimeInterval) {
        state.nextAmbientEventIn -= delta
        guard state.nextAmbientEventIn <= 0 else { return }

        let candidates: [WorldState.AmbientEvent]
        if state.dayPhase == .night {
            candidates = state.cloudCover < 0.55
                ? [.shootingStar, .fishJumps, .none]
                : [.fishJumps, .none, .none]
        } else if state.tideLevel < 0.38 {
            candidates = [.gullPasses, .coconutFalls, .fishJumps, .none]
        } else if state.tideLevel > 0.68 {
            candidates = [.fishJumps, .fishJumps, .gullPasses, .none]
        } else if state.wind > 0.62 {
            candidates = [.gullPasses, .coconutFalls, .fishJumps, .none]
        } else {
            candidates = [.gullPasses, .fishJumps, .none]
        }

        state.ambientEvent = candidates[Int(random.next() % UInt64(candidates.count))]
        if state.ambientEvent == .coconutFalls { state.memory.coconutFallsWitnessed += 1 }
        state.nextAmbientEventIn = randomDuration(4...9)
    }

    private func randomDuration(_ range: ClosedRange<Double>) -> Double { randomRange(range) }

    private func randomRange(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + random.unitInterval() * (range.upperBound - range.lowerBound)
    }
}
