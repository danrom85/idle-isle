import Foundation

/// User preferences for presentation hosts. These describe the machine's
/// owner, not the world, so they live beside the world save rather than
/// inside it.
public struct AppSettings: Codable, Equatable, Sendable {
    /// Ambient audio in the windowed app.
    public var soundEnabled: Bool = true

    /// Ambient audio while the screen saver runs. Off by default: a screen
    /// saver that makes noise should be a deliberate choice.
    public var screensaverSoundEnabled: Bool = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case soundEnabled
        case screensaverSoundEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        screensaverSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .screensaverSoundEnabled) ?? false
    }
}

/// Loads and stores `AppSettings` as JSON beside the world save.
public struct SettingsPersistence: Sendable {
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
            .appendingPathComponent("settings.json", isDirectory: false)
    }

    public func load() -> AppSettings? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    public func save(_ settings: AppSettings) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
