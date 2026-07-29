import SpriteKit
import SwiftUI

extension Notification.Name {
    static let idleIsleToggleDebugOverlay = Notification.Name("IdleIsleToggleDebugOverlay")
}

struct ContentView: View {
    @State private var scene = IslandScene(size: CGSize(width: 1280, height: 720))
    @State private var tideScene = TideScene(size: CGSize(width: 1280, height: 720))
    @State private var presenceScene = PresenceScene(size: CGSize(width: 1280, height: 720))
    @State private var characterLifeScene = CharacterLifeScene(size: CGSize(width: 1280, height: 720))

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .background(Color.black)

            SpriteView(scene: tideScene, options: [.allowsTransparency])
                .allowsHitTesting(false)

            SpriteView(scene: presenceScene, options: [.allowsTransparency])
                .allowsHitTesting(false)

            SpriteView(scene: characterLifeScene, options: [.allowsTransparency])
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            scene.scaleMode = .aspectFill
            tideScene.scaleMode = .aspectFill
            presenceScene.scaleMode = .aspectFill
            characterLifeScene.scaleMode = .aspectFill
        }
        .onReceive(NotificationCenter.default.publisher(for: .idleIsleToggleDebugOverlay)) { _ in
            let labels = scene.children.compactMap { $0 as? SKLabelNode }
            labels.first?.isHidden.toggle()
        }
    }
}
