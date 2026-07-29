import Foundation

struct PresenceState: Equatable, Sendable {
    enum Visitor: String, CaseIterable, Sendable {
        case none
        case gull
        case butterflies
        case fishSchool
        case seaTurtle
    }

    enum Phase: String, Sendable {
        case absent
        case arriving
        case lingering
        case departing
    }

    var visitor: Visitor = .none
    var phase: Phase = .absent
    var progress: Double = 0
    var phaseTimeRemaining: TimeInterval = 0
    var nextArrivalIn: TimeInterval = 7
    var visitCount: Int = 0

    var isPresent: Bool {
        visitor != .none && phase != .absent
    }
}

final class PresenceEngine {
    private(set) var state: PresenceState
    private var random: SeededGenerator

    init(seed: UInt64 = 0x50524553454E4345, initialState: PresenceState = PresenceState()) {
        state = initialState
        random = SeededGenerator(seed: seed)
    }

    func advance(by deltaTime: TimeInterval, world: WorldState) -> PresenceState {
        let delta = min(max(deltaTime, 0), 0.1)

        switch state.phase {
        case .absent:
            state.nextArrivalIn -= delta
            if state.nextArrivalIn <= 0 {
                beginVisit(selectVisitor(for: world))
            }
        case .arriving:
            state.progress = min(1, state.progress + delta / 2.4)
            state.phaseTimeRemaining -= delta
            if state.phaseTimeRemaining <= 0 {
                state.phase = .lingering
                state.phaseTimeRemaining = lingerDuration(for: state.visitor)
            }
        case .lingering:
            state.phaseTimeRemaining -= delta
            if state.phaseTimeRemaining <= 0 {
                state.phase = .departing
                state.phaseTimeRemaining = 2.6
            }
        case .departing:
            state.progress = max(0, state.progress - delta / 2.6)
            state.phaseTimeRemaining -= delta
            if state.phaseTimeRemaining <= 0 {
                state.visitor = .none
                state.phase = .absent
                state.progress = 0
                state.nextArrivalIn = randomRange(8...18)
            }
        }

        return state
    }

    private func beginVisit(_ visitor: PresenceState.Visitor) {
        state.visitor = visitor
        state.phase = .arriving
        state.progress = 0
        state.phaseTimeRemaining = 2.4
        state.visitCount += 1
    }

    private func selectVisitor(for world: WorldState) -> PresenceState.Visitor {
        let roll = random.unitInterval()

        // Tide now acts as an ecological filter before time-of-day preferences.
        // High water brings ocean life closer; low water shifts activity ashore.
        if world.tideLevel > 0.72 {
            if world.wind < 0.48 && roll < 0.44 { return .seaTurtle }
            return roll < 0.82 ? .fishSchool : .gull
        }

        if world.tideLevel < 0.28 {
            if world.dayPhase == .day && world.wind < 0.42 && roll < 0.38 { return .butterflies }
            return roll < 0.76 ? .gull : .fishSchool
        }

        switch world.dayPhase {
        case .night:
            return roll < 0.72 ? .seaTurtle : .fishSchool
        case .dawn, .sunset:
            if world.wind < 0.45 && roll < 0.34 { return .butterflies }
            if roll < 0.67 { return .gull }
            return .seaTurtle
        case .day:
            if world.wind > 0.64 { return roll < 0.72 ? .gull : .fishSchool }
            if world.cloudCover < 0.42 && roll < 0.34 { return .butterflies }
            if roll < 0.68 { return .fishSchool }
            return .seaTurtle
        }
    }

    private func lingerDuration(for visitor: PresenceState.Visitor) -> TimeInterval {
        switch visitor {
        case .none: return 0
        case .gull: return randomRange(7...13)
        case .butterflies: return randomRange(8...15)
        case .fishSchool: return randomRange(5...10)
        case .seaTurtle: return randomRange(7...12)
        }
    }

    private func randomRange(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + random.unitInterval() * (range.upperBound - range.lowerBound)
    }
}