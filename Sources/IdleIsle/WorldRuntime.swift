import Foundation

/// Owns the single authoritative simulation state for the island.
///
/// Rendering scenes should never create their own `SimulationEngine`. One scene
/// advances this runtime; every other scene reads the same `state` snapshot.
final class WorldRuntime {
    private let persistence: WorldPersistence
    private let engine: SimulationEngine

    private(set) var state: WorldState

    init(
        persistence: WorldPersistence = WorldPersistence(),
        initialState: WorldState? = nil
    ) {
        self.persistence = persistence

        let restoredState = initialState ?? persistence.load() ?? WorldState()
        engine = SimulationEngine(initialState: restoredState)
        state = restoredState
    }

    @discardableResult
    func advance(by deltaTime: TimeInterval) -> WorldState {
        state = engine.advance(by: deltaTime)
        return state
    }

    func save() throws {
        try persistence.save(state)
    }
}
