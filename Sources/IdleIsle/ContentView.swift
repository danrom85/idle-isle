import SpriteKit
import SwiftUI

import IdleEngine
import IdleWorld

extension Notification.Name {
    static let idleIsleToggleDebugOverlay = Notification.Name("IdleIsleToggleDebugOverlay")
    static let idleIsleToggleSound = Notification.Name("IdleIsleToggleSound")
}

struct ContentView: View {
    @State private var scene: IslandScene
    @State private var settings: AppSettings

    init() {
        let size = CGSize(width: 1280, height: 720)
        let runtime = WorldRuntime()
        _scene = State(initialValue: IslandScene(size: size, runtime: runtime))
        _settings = State(initialValue: SettingsPersistence().load() ?? AppSettings())
    }

    var body: some View {
        SpriteView(scene: scene)
            .background(Color.black)
            .ignoresSafeArea()
            .onAppear {
                scene.scaleMode = .aspectFill
                scene.setSoundEnabled(settings.soundEnabled)
            }
            .onReceive(NotificationCenter.default.publisher(for: .idleIsleToggleDebugOverlay)) { _ in
                let labels = scene.children.compactMap { $0 as? SKLabelNode }
                labels.first?.isHidden.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .idleIsleToggleSound)) { _ in
                settings.soundEnabled.toggle()
                scene.setSoundEnabled(settings.soundEnabled)
                try? SettingsPersistence().save(settings)
            }
    }
}
