import SwiftUI

import IdleEngine

struct SettingsView: View {
    @ObservedObject private var model = AppSettingsModel.shared

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Ambient sound in the app", isOn: $model.settings.soundEnabled)
                Toggle(
                    "Ambient sound while the screen saver runs",
                    isOn: $model.settings.screensaverSoundEnabled
                )
            } footer: {
                Text(
                    "The screen saver stays silent in its preview thumbnail. "
                        + "Changes are saved automatically."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 160)
    }
}
