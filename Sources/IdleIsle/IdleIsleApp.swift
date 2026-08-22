import SwiftUI

@main
struct IdleIsleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("View") {
                Button("Toggle Debug Overlay") {
                    NotificationCenter.default.post(
                        name: .idleIsleToggleDebugOverlay,
                        object: nil
                    )
                }
                .keyboardShortcut("d", modifiers: [.command])
            }
        }
    }
}
