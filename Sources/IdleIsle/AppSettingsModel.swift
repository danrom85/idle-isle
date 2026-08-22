import Foundation

import IdleEngine

/// Observable wrapper so SwiftUI surfaces can share and persist the app's
/// settings. Saving on every change keeps the JSON file as the single
/// source of truth.
@MainActor
final class AppSettingsModel: ObservableObject {
    static let shared = AppSettingsModel()

    @Published var settings: AppSettings {
        didSet {
            try? SettingsPersistence().save(settings)
        }
    }

    private init() {
        settings = SettingsPersistence().load() ?? AppSettings()
    }
}
