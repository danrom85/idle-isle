import SpriteKit
import SwiftUI

import IdleEngine
import IdleWorld

extension Notification.Name {
    static let idleIsleToggleDebugOverlay = Notification.Name("IdleIsleToggleDebugOverlay")
}

struct ContentView: View {
    @State private var scene: IslandScene

    init() {
        let size = CGSize(width: 1280, height: 720)
        let runtime = WorldRuntime()
        _scene = State(initialValue: IslandScene(size: size, runtime: runtime))
    }

    var body: some View {
        SpriteView(scene: scene)
            .background(Color.black)
            .ignoresSafeArea()
            .onAppear {
                scene.scaleMode = .aspectFill
            }
            .onReceive(NotificationCenter.default.publisher(for: .idleIsleToggleDebugOverlay)) { _ in
                let labels = scene.children.compactMap { $0 as? SKLabelNode }
                labels.first?.isHidden.toggle()
            }
    }
}
