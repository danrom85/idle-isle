import Foundation

public struct WorldPersistence: Sendable {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        self.fileURL = applicationSupport
            .appendingPathComponent("IdleIsle", isDirectory: true)
            .appendingPathComponent("world-state.json", isDirectory: false)
    }

    /// Loads the world, or `nil` when no save exists yet.
    ///
    /// A save that exists but cannot be decoded is moved aside to a
    /// `world-state.corrupt.json` backup next to it so the fresh world that
    /// replaces it starts clean and the damaged file stays inspectable.
    public func load() -> WorldState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        do {
            var state = try JSONDecoder().decode(WorldState.self, from: data)
            if state.schemaVersion == nil {
                // Pre-versioning save: stamp it so future migrations can
                // reason about what they are upgrading from.
                state.schemaVersion = WorldState.currentSchemaVersion
            }
            return state
        } catch {
            backupCorruptFile()
            return nil
        }
    }

    public func save(_ state: WorldState) throws {
        var stateToWrite = state
        stateToWrite.schemaVersion = WorldState.currentSchemaVersion

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(stateToWrite)
        try data.write(to: fileURL, options: .atomic)
    }

    public func reset() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private var corruptBackupURL: URL {
        fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent + ".corrupt.json")
    }

    private func backupCorruptFile() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: corruptBackupURL)
        try? fileManager.moveItem(at: fileURL, to: corruptBackupURL)
    }
}
