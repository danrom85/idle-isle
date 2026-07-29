import SpriteKit
import SwiftUI

extension Notification.Name {
    static let idleIsleToggleDebugOverlay = Notification.Name("IdleIsleToggleDebugOverlay")
}

struct ContentView: View {
    @State private var scene = IslandScene(size: CGSize(width: 1280, height: 720))

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
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
