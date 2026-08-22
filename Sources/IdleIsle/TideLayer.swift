import AppKit
import SpriteKit

import IdleEngine

/// Tide presentation as a layer node inside the single world scene.
///
/// The scene runs at a fixed design size (aspect-fill scaling keeps it
/// constant), so shoreline layout happens once at construction.
final class TideLayer: SKNode {
    private let size: CGSize

    private let wetSand = SKShapeNode()
    private let shallowWater = SKShapeNode()
    private let foam = SKShapeNode()
    private let foamGlints = SKNode()

    init(size: CGSize) {
        self.size = size
        super.init()

        buildShoreline()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(world state: WorldState) {
        let tide = CGFloat(state.tideLevel)
        let rise = (tide - 0.5) * size.height * 0.052

        wetSand.alpha = 0.30 + (1 - tide) * 0.34
        wetSand.yScale = 0.72 + (1 - tide) * 0.54
        wetSand.position.y = rise * 0.18

        shallowWater.alpha = 0.10 + tide * 0.34
        shallowWater.yScale = 0.66 + tide * 0.62
        shallowWater.position.y = rise * 0.52

        foam.alpha = 0.28 + tide * 0.52
        foam.position.y = rise
        foamGlints.alpha = 0.18 + tide * 0.48
        foamGlints.position.y = -size.height * 0.19 + rise
        foamGlints.speed = 0.65 + tide * 0.75
    }

    private func buildShoreline() {
        wetSand.fillColor = NSColor(calibratedRed: 0.52, green: 0.38, blue: 0.22, alpha: 1)
        wetSand.strokeColor = .clear
        wetSand.zPosition = 1
        addChild(wetSand)

        shallowWater.fillColor = NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.70, alpha: 1)
        shallowWater.strokeColor = .clear
        shallowWater.zPosition = 2
        addChild(shallowWater)

        foam.fillColor = .clear
        foam.strokeColor = NSColor.white.withAlphaComponent(0.58)
        foam.lineWidth = 4
        foam.lineCap = .round
        foam.zPosition = 3
        addChild(foam)

        foamGlints.zPosition = 4
        addChild(foamGlints)
        for index in 0..<11 {
            let glint = SKShapeNode(ellipseOf: CGSize(width: 22 + CGFloat(index % 3) * 9, height: 3))
            glint.fillColor = NSColor.white.withAlphaComponent(0.48)
            glint.strokeColor = .clear
            glint.position.x = CGFloat(index - 5) * 62
            glint.position.y = CGFloat(index % 2) * 5
            foamGlints.addChild(glint)
        }

        foamGlints.run(.repeatForever(.sequence([
            .moveBy(x: 18, y: 0, duration: 2.8),
            .moveBy(x: -18, y: 0, duration: 2.8)
        ])))

        layoutShoreline()
    }

    private func layoutShoreline() {
        let wetRect = CGRect(
            x: -size.width * 0.285,
            y: -size.height * 0.225,
            width: size.width * 0.57,
            height: size.height * 0.112
        )
        wetSand.path = CGPath(ellipseIn: wetRect, transform: nil)

        let waterRect = CGRect(
            x: -size.width * 0.29,
            y: -size.height * 0.245,
            width: size.width * 0.58,
            height: size.height * 0.105
        )
        shallowWater.path = CGPath(ellipseIn: waterRect, transform: nil)

        let foamPath = CGMutablePath()
        foamPath.move(to: CGPoint(x: -size.width * 0.275, y: -size.height * 0.175))
        foamPath.addCurve(
            to: CGPoint(x: size.width * 0.275, y: -size.height * 0.175),
            control1: CGPoint(x: -size.width * 0.12, y: -size.height * 0.215),
            control2: CGPoint(x: size.width * 0.12, y: -size.height * 0.215)
        )
        foam.path = foamPath
        foamGlints.position = CGPoint(x: 0, y: -size.height * 0.19)
    }
}
