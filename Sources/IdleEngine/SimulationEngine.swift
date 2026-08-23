import Foundation

public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    public mutating func unitInterval() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

public final class SimulationEngine {
    /// Island landmarks in normalized (u, v): u spans the sand 0...1 left
    /// to right, v spans 0...1 from the back edge to the waterline.
    /// Renderers derive every campfire and fishing-spot visual from these so
    /// the simulation and presentation can never drift apart.
    public static let fishingSpot = SIMD2<Double>(x: 0.24, y: 0.82)
    public static let campfire = SIMD2<Double>(x: 0.65, y: 0.52)
    /// Where he stands to tend the fire: just beside it, never inside it.
    public static let cookingSpot = SIMD2<Double>(x: 0.585, y: 0.56)
    public static let palmShade = SIMD2<Double>(x: 0.73, y: 0.36)

    /// One v unit covers far less screen distance than one u unit; this
    /// factor converts v into u-equivalents so walking speed feels uniform.
    static let vScale = 0.233

    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let dx = a.x - b.x
        let dy = (a.y - b.y) / vScale
        return norm(SIMD2(x: dx, y: dy))
    }

    static func norm(_ v: SIMD2<Double>) -> Double {
        (v.x * v.x + v.y * v.y).squareRoot()
    }

    public private(set) var state: WorldState
    private var random: SeededGenerator
    private var strollGenerator = SeededGenerator(seed: 0x57414C4B)

    public init(seed: UInt64 = 0x1D1E15E, initialState: WorldState = WorldState()) {
        var restoredState = initialState
        if restoredState.ambientEvent == .crabVisits {
            restoredState.ambientEvent = .none
        }

        state = restoredState
        random = SeededGenerator(seed: seed)
    }

    @discardableResult
    public func advance(by deltaTime: TimeInterval) -> WorldState {
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

    public static func phase(for hour: Double) -> WorldState.DayPhase {
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

            // Storms only gather under heavy cloud, and never fully soak
            // the island unless the sky is nearly covered.
            if state.targetCloudCover > 0.62,
               random.unitInterval() < 0.55 * (state.targetCloudCover - 0.6) / 0.4 {
                let ceiling = min(1, 0.45 + state.targetCloudCover * 0.65)
                state.targetRain = randomRange(0.25...ceiling)
            } else {
                state.targetRain = 0
            }

            state.nextWeatherChangeIn = randomDuration(10...22)
        }

        state.wind += (state.targetWind - state.wind) * delta * 0.12
        state.cloudCover += (state.targetCloudCover - state.cloudCover) * delta * 0.08
        // Rain drifts in slowly and lingers a little after the sky clears.
        state.rain += (state.targetRain - state.rain) * delta * 0.035
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
        case .walking, .carryingFish:
            let windResistance = 1 - state.wind * 0.18
            state.memory.walkingDistance += delta * 0.085 * windResistance
            // (position integration happens in updateCharacter)
        case .fishing:
            state.memory.fishingSeconds += delta
        case .watchingOcean:
            state.memory.oceanWatchingSeconds += delta
        case .idle, .cookingFish, .eatingFish, .reactingToCrab, .resting, .sleeping:
            break
        }

        // Time near the fire or tending it from beside counts as campfire time.
        let here = SIMD2(x: state.characterX, y: state.characterY)
        if Self.distance(here, Self.campfire) < 0.1 || Self.distance(here, Self.cookingSpot) < 0.04 {
            state.memory.campfireSeconds += delta
        }
        if state.characterX > 0.68 { state.memory.palmShadeSeconds += delta }
    }

    private func updateCharacter(by delta: TimeInterval) {
        switch state.activity {
        case .walking, .carryingFish:
            let windResistance = 1 - state.wind * 0.18
            walkToward(destination: SIMD2(x: state.destinationX, y: state.destinationY),
                       by: delta * windResistance)
            state.energy = max(0, state.energy - delta * 0.007)
            if Self.distance(
                SIMD2(x: state.characterX, y: state.characterY),
                SIMD2(x: state.destinationX, y: state.destinationY)
            ) < 0.008 {
                state.characterX = state.destinationX
                state.characterY = state.destinationY
                if state.activity == .carryingFish {
                    beginCooking()
                } else {
                    chooseActivity()
                }
            }

        case .fishing:
            state.energy = max(0, state.energy - delta * 0.005)
            state.curiosity = max(0, state.curiosity - delta * 0.008)

        case .cookingFish:
            state.energy = max(0, state.energy - delta * 0.001)
            if var fish = state.fish {
                fish.cookingProgress = min(1, fish.cookingProgress + delta / 7)
                state.fish = fish
            }

        case .eatingFish:
            state.hunger = max(0, state.hunger - delta * 0.14)
            state.energy = min(1, state.energy + delta * 0.012)

        case .reactingToCrab:
            state.energy = max(0, state.energy - delta * 0.003)

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

        switch state.activity {
        case .fishing:
            catchFish()
        case .cookingFish:
            finishCooking()
        case .eatingFish:
            finishMeal()
        case .reactingToCrab:
            chooseActivity()
        case .carryingFish:
            state.activityTimeRemaining = 1
        default:
            chooseActivity()
        }
    }

    private func chooseActivity() {
        if let fish = state.fish {
            switch fish.state {
            case .caught, .carried:
                state.fish?.state = .carried
                state.destinationX = Self.cookingSpot.x
                state.destinationY = Self.cookingSpot.y
                begin(.carryingFish, duration: 12)
                return
            case .cooking:
                begin(.cookingFish, duration: max(0.5, 7 * (1 - fish.cookingProgress)))
                return
            case .cooked:
                begin(.eatingFish, duration: 4)
                return
            case .eaten, .stolen:
                state.fish = nil
            }
        }

        if state.dayPhase == .night && state.energy < 0.92 {
            begin(.sleeping, duration: randomDuration(7...12))
            return
        }

        // A downpour sends him to wait beneath the palm until it eases.
        if state.rain > 0.55 {
            if distanceTo( Self.palmShade) > 0.03 {
                state.destinationX = Self.palmShade.x
                state.destinationY = Self.palmShade.y
                begin(.walking, duration: 12)
            } else {
                begin(.resting, duration: randomDuration(6...10))
            }
            return
        }

        if state.hunger > 0.62 && state.dayPhase != .night {
            state.destinationX = Self.fishingSpot.x
            state.destinationY = Self.fishingSpot.y
            if distanceTo( Self.fishingSpot) > 0.025 {
                begin(.walking, duration: 12)
            } else {
                begin(.fishing, duration: randomDuration(6...10))
            }
            return
        }

        if state.energy < 0.30 {
            if state.memory.palmShadeWear > 0.35
                && distanceTo( Self.palmShade) > 0.05 {
                state.destinationX = Self.palmShade.x
                state.destinationY = Self.palmShade.y
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
            let spot = randomStrollPoint()
            state.destinationX = spot.x
            state.destinationY = spot.y
            begin(.walking, duration: 12)
        case walkingChance..<watchingThreshold:
            begin(.watchingOcean, duration: randomDuration(4...8))
        case watchingThreshold..<restingThreshold:
            begin(.resting, duration: randomDuration(3...6))
        default:
            begin(.idle, duration: randomDuration(2...5))
        }
    }

    private func catchFish() {
        state.fish = WorldState.Fish(state: .carried, cookingProgress: 0)
        state.memory.fishCaught += 1
        state.destinationX = Self.cookingSpot.x
        state.destinationY = Self.cookingSpot.y
        begin(.carryingFish, duration: 12)
    }

    private func beginCooking() {
        guard state.fish != nil else {
            chooseActivity()
            return
        }
        state.fish?.state = .cooking
        begin(.cookingFish, duration: 7)
    }

    private func finishCooking() {
        guard state.fish != nil else {
            chooseActivity()
            return
        }
        state.fish?.state = .cooked
        state.fish?.cookingProgress = 1
        begin(.eatingFish, duration: 4)
    }

    private func finishMeal() {
        if state.fish != nil {
            state.fish?.state = .eaten
            state.memory.mealsEaten += 1
        }
        state.fish = nil
        chooseActivity()
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

    /// A stroll can go anywhere on the sand except inside the campfire.
    private func randomStrollPoint() -> SIMD2<Double> {
        for _ in 0..<24 {
            let u = 0.14 + strollGenerator.unitInterval() * 0.72
            let v = 0.16 + strollGenerator.unitInterval() * 0.68
            let du = (u - 0.5) / 0.42
            let dv = (v - 0.5) / 0.40
            guard du * du + dv * dv <= 1 else { continue }
            let spot = SIMD2(x: u, y: v)
            if Self.distance(spot, Self.campfire) > 0.09 {
                return spot
            }
        }
        return SIMD2(x: 0.35, y: 0.5)
    }

    /// Integrates movement toward a point, steering around the campfire so
    /// nobody walks through the flames.
    private func walkToward(destination: SIMD2<Double>, by delta: TimeInterval) {
        var here = SIMD2(x: state.characterX, y: state.characterY)
        var toDestination = destination - here
        toDestination.y /= Self.vScale

        // Repulsion from the fire: slide around it, never across it.
        let fromFire = here - Self.campfire
        let awayFromFire = SIMD2(x: fromFire.x, y: fromFire.y / Self.vScale)
        let fireDistance = Self.norm(awayFromFire)
        if fireDistance < 0.09, fireDistance > 1e-9 {
            let strength = (0.09 - fireDistance) * 6
            toDestination += SIMD2(
                x: awayFromFire.x / fireDistance * strength,
                y: awayFromFire.y / fireDistance * strength
            )
        }

        let remaining = Self.norm(toDestination)
        guard remaining > 1e-9 else { return }
        let step = min(remaining, delta * 0.085)
        let direction = toDestination / remaining
        here += direction * step
        here.y += (destination.y - here.y) * 0 // v handled below

        state.characterX = here.x
        // Convert the u-equivalent step back into v space.
        let vStep = direction.y * step * Self.vScale
        state.characterY += vStep
    }

    private func distanceTo(_ point: SIMD2<Double>) -> Double {
        Self.distance(SIMD2(x: state.characterX, y: state.characterY), point)
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

        // A whale surfaces only on calm days over deeper low-tide water.
        var pool = candidates
        if state.dayPhase == .day,
           state.tideLevel < 0.45,
           state.wind < 0.45,
           state.rain < 0.3 {
            pool.append(.whaleSpout)
        }

        state.ambientEvent = pool[Int(random.next() % UInt64(pool.count))]
        if state.ambientEvent == .coconutFalls { state.memory.coconutFallsWitnessed += 1 }
        state.nextAmbientEventIn = randomDuration(4...9)
    }

    private func randomDuration(_ range: ClosedRange<Double>) -> Double { randomRange(range) }

    private func randomRange(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + random.unitInterval() * (range.upperBound - range.lowerBound)
    }
}
