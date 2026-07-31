import SpriteKit
import SwiftUI

extension Notification.Name {
    static let idleIsleToggleDebugOverlay = Notification.Name("IdleIsleToggleDebugOverlay")
}

struct ContentView: View {
    @State private var scene: IslandScene
    @State private var tideScene: TideScene
    @State private var presenceScene: PresenceScene
    @State private var characterLifeScene: CharacterLifeScene

    init() {
        let size = CGSize(width: 1280, height: 720)
        let runtime = WorldRuntime()
        _scene = State(initialValue: IslandScene(size: size, runtime: runtime))
        _tideScene = State(initialValue: TideScene(size: size, runtime: runtime))
        _presenceScene = State(initialValue: PresenceScene(size: size, runtime: runtime))
        _characterLifeScene = State(initialValue: CharacterLifeScene(size: size, runtime: runtime))
    }

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
