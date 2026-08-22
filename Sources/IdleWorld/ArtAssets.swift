import AppKit
import SpriteKit

/// Loads hand-authored artwork bundled with the world target.
///
/// Every lookup falls back to `nil` so hosts without bundled resources
/// (or a failed load) render the hand-built vector stand-ins instead.
enum ArtAssets {
    static func texture(_ name: String) -> SKTexture? {
        let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Art")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        guard let url, let image = NSImage(contentsOf: url) else { return nil }
        let texture = SKTexture(image: image)
        return texture
    }
}
