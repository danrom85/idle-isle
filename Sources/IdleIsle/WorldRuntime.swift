import Foundation

/// Owns the single authoritative simulation state for the island.
///
/// Exactly one runtime should be created as a `.driver`. Rendering layers that
/// do not own time receive the same runtime instance and only read `state`.
final class WorldRuntime {
    enum Role {
        case driver
        case observer
    }

    private let persistence: WorldPersistence
    private let engine: SimulationEngine
    private let role: Role

    private(set) var state: WorldState

    init(
        role: Role = .driver,
        persistence: WorldPersistence = WorldPersistence(),
        initialState: WorldState? = nil
    ) {
        self.role = role
        self.persistence = persistence

        let restoredState = initialState ?? persistence.load() ?? WorldState()
        engine = SimulationEngine(initialState: restoredState)
        state = restoredState
    }

    var canAdvanceTime: Bool {
        role == .driver
    }

    /// Advances the island only when this runtime is the designated driver.
    /// Observers return the current snapshot unchanged.
    @discardableResult
    func advance(by deltaTime: TimeInterval) -> WorldState {
        guard canAdvanceTime else { return state }
        state = engine.advance(by: deltaTime)
        return state
    }

    func save() throws {
        try persistence.save(state)
    }
}
