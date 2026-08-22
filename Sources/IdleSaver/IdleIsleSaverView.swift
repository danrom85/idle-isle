import AppKit
import ScreenSaver
import SpriteKit

import IdleEngine
import IdleWorld

/// The island as a macOS screen saver.
///
/// Hosts the same `IslandScene` the app uses. In preview mode (System
/// Settings thumbnails) the runtime skips autosaving so hovering over the
/// preview pane never touches the real world save, and audio always stays
/// off. In a real run, ambience plays only if enabled in the configure
/// sheet; savers should stay quiet unless asked otherwise.
final class IdleIsleSaverView: ScreenSaverView {
    private let spriteView: SKView
    private let runtime: WorldRuntime
    private let settingsPersistence = SettingsPersistence()
    private var settings: AppSettings

    override init!(frame: NSRect, isPreview: Bool) {
        settings = settingsPersistence.load() ?? AppSettings()
        runtime = WorldRuntime(autosaveInterval: isPreview ? nil : 5)
        spriteView = SKView(frame: NSRect(origin: .zero, size: frame.size))
        super.init(frame: frame, isPreview: isPreview)

        spriteView.autoresizingMask = [.width, .height]
        spriteView.preferredFramesPerSecond = 30
        addSubview(spriteView)

        let scene = IslandScene(size: CGSize(width: 1280, height: 720), runtime: runtime)
        scene.scaleMode = .aspectFill
        let allowSound = !isPreview && settings.soundEnabled && settings.screensaverSoundEnabled
        scene.setSoundEnabled(allowSound)
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

    // MARK: - Configuration

    override var configureSheet: NSWindow? {
        configureWindow
    }

    private lazy var configureWindow: NSWindow = {
        let checkbox = NSButton(
            checkboxWithTitle: "Play ambient sounds while the screen saver runs",
            target: self,
            action: #selector(screensaverSoundChanged(_:))
        )
        checkbox.state = settings.screensaverSoundEnabled ? .on : .off

        let stack = NSStackView(views: [checkbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let window = NSWindow(contentView: stack)
        window.title = "Idle Isle Settings"
        return window
    }()

    @objc private func screensaverSoundChanged(_ sender: NSButton) {
        settings.screensaverSoundEnabled = sender.state == .on
        try? settingsPersistence.save(settings)
    }
}
