import SpriteKit
import SwiftUI

struct ContentView: View {
    @State private var scene = IslandScene(size: CGSize(width: 1280, height: 720))

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .background(Color.black)
            .ignoresSafeArea()
            .onAppear {
                scene.scaleMode = .aspectFill
            }
    }
}
