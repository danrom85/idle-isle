import SwiftUI

import IdleEngine

struct SettingsView: View {
    @ObservedObject private var model = AppSettingsModel.shared

    var body: some View {
        Form {
            Section {
                Toggle("Ambient sound in the app", isOn: $model.settings.soundEnabled)
                Toggle(
                    "Ambient sound while the screen saver runs",
                    isOn: $model.settings.screensaverSoundEnabled
                )
            } header: {
                Text("Sound")
            } footer: {
                Text(
                    "The screen saver stays silent in its preview thumbnail. "
                        + "Changes are saved automatically."
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 160)
    }
}
