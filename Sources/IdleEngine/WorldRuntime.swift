import Foundation

import OSLog

/// Owns the single authoritative simulation state for the island.
///
/// Exactly one runtime should be created as a `.driver`. Rendering layers that
/// do not own time receive the same runtime instance and only read `state`.
public final class WorldRuntime {
    public enum Role {
        case driver
        case observer
    }

    private static let logger = Logger(
        subsystem: "org.idle-isle.engine",
        category: "persistence"
    )

    private let persistence: WorldPersistence
    private let engine: SimulationEngine
    private let role: Role

    /// How often an advancing driver persists the world, or `nil` to opt out.
    private let autosaveInterval: TimeInterval?

    public private(set) var state: WorldState
    private var timeSinceLastSave: TimeInterval = 0

    public init(
        role: Role = .driver,
        persistence: WorldPersistence = WorldPersistence(),
        initialState: WorldState? = nil,
        autosaveInterval: TimeInterval? = 5
    ) {
        self.role = role
        self.persistence = persistence
        self.autosaveInterval = autosaveInterval

        var restoredState = initialState ?? persistence.load() ?? WorldState()
        if restoredState.schemaVersion == nil {
            restoredState.schemaVersion = WorldState.currentSchemaVersion
        }
        engine = SimulationEngine(initialState: restoredState)
        state = restoredState
    }

    public var canAdvanceTime: Bool {
        role == .driver
    }

    /// Advances the island only when this runtime is the designated driver.
    /// Observers return the current snapshot unchanged.
    @discardableResult
    public func advance(by deltaTime: TimeInterval) -> WorldState {
        guard canAdvanceTime else { return state }

        state = engine.advance(by: deltaTime)

        if let autosaveInterval {
            timeSinceLastSave += max(0, deltaTime)
            if timeSinceLastSave >= autosaveInterval {
                save()
            }
        }

        return state
    }

    /// Advances a longer span of wall-clock time in simulation-sized steps.
    /// Used when the host was paused or occluded and the island should have
    /// kept living. Capped so a long absence costs bounded work.
    @discardableResult
    public func advanceSpan(by span: TimeInterval) -> WorldState {
        var remaining = min(max(span, 0), 600)
        while remaining > 0 {
            let step = min(remaining, 0.1)
            _ = advance(by: step)
            remaining -= step
        }
        return state
    }

    /// Persists the world immediately, logging any failure instead of
    /// crashing or silently dropping it.
    public func save() {
        do {
            try persistence.save(state)
            timeSinceLastSave = 0
        } catch {
            Self.logger.error("Failed to save world state: \(error.localizedDescription, privacy: .public)")
        }
    }
}
