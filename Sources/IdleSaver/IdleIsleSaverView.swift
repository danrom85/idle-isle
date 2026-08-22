import AppKit
import ScreenSaver
import SpriteKit

import IdleEngine
import IdleWorld

/// The island as a macOS screen saver.
///
/// Hosts the same `IslandScene` the app uses. In preview mode (System
/// Settings thumbnails) the runtime skips autosaving so hovering over the
/// preview pane never touches the real world save.
final class IdleIsleSaverView: ScreenSaverView {
    private let spriteView: SKView
    private let runtime: WorldRuntime

    override init!(frame: NSRect, isPreview: Bool) {
        runtime = WorldRuntime(autosaveInterval: isPreview ? nil : 5)
        spriteView = SKView(frame: NSRect(origin: .zero, size: frame.size))
        super.init(frame: frame, isPreview: isPreview)

        spriteView.autoresizingMask = [.width, .height]
        spriteView.preferredFramesPerSecond = 30
        addSubview(spriteView)

        let scene = IslandScene(size: CGSize(width: 1280, height: 720), runtime: runtime)
        scene.scaleMode = .aspectFill
        spriteView.presentScene(scene)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func stopAnimation() {
        super.stopAnimation()
        runtime.save()
    }
}
