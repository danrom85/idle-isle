import AppKit
import SpriteKit

import IdleEngine

/// Tide presentation as a layer node inside the single world scene.
///
/// The scene runs at a fixed design size (aspect-fill scaling keeps it
/// constant), so shoreline layout happens once at construction.
final class TideLayer: SKNode {
    private let size: CGSize

    private let wetSand = SKSpriteNode(texture: nil, size: .zero)
    private let shallowWater = SKSpriteNode(texture: nil, size: .zero)
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
        applyDayTint(state.dayPhase)

        wetSand.alpha = 0.45 + (1 - tide) * 0.40
        wetSand.yScale = 0.72 + (1 - tide) * 0.54
        wetSand.position.y = rise * 0.18

        shallowWater.alpha = 0.35 + tide * 0.45
        shallowWater.yScale = 0.66 + tide * 0.62
        shallowWater.position.y = rise * 0.52

        foam.alpha = 0.28 + tide * 0.52
        foam.position.y = rise
        foamGlints.alpha = 0.18 + tide * 0.48
        foamGlints.position.y = -size.height * 0.19 + rise
        foamGlints.speed = 0.65 + tide * 0.75
    }

    /// Water and foam shift with the same light that colors the sky.
    private func applyDayTint(_ phase: WorldState.DayPhase) {
        // Per-channel multipliers relative to full daylight.
        let tint: (r: CGFloat, g: CGFloat, b: CGFloat)
        switch phase {
        case .day:
            tint = (1.00, 1.00, 1.00)
        case .dawn:
            tint = (1.10, 0.88, 0.80)
        case .sunset:
            tint = (1.08, 0.72, 0.62)
        case .night:
            tint = (0.30, 0.42, 0.68)
        }

        shallowWater.color = NSColor(
            calibratedRed: min(1, tint.r),
            green: min(1, tint.g),
            blue: min(1, tint.b),
            alpha: 1
        )
        shallowWater.colorBlendFactor = phase == .night ? 0.55 : 0.18
        wetSand.color = NSColor(
            calibratedRed: min(1, 0.52 * tint.r),
            green: min(1, 0.38 * tint.g),
            blue: min(1, 0.22 * tint.b),
            alpha: 1
        )
        wetSand.colorBlendFactor = phase == .night ? 0.5 : 0.15

        let nightDim: CGFloat = phase == .night ? 0.55 : 1
        foam.strokeColor = NSColor.white.withAlphaComponent(0.58 * nightDim)
        for glint in foamGlints.children where glint is SKShapeNode {
            (glint as! SKShapeNode).fillColor = NSColor.white.withAlphaComponent(0.48 * nightDim)
        }
    }

    private func buildShoreline() {
        // Radial falloff instead of hard ellipse edges: the water melts into
        // the sand and the sand into the dry beach.
        wetSand.texture = Self.radialTexture(
            center: NSColor(calibratedRed: 0.52, green: 0.38, blue: 0.22, alpha: 0.85),
            edge: NSColor(calibratedRed: 0.52, green: 0.38, blue: 0.22, alpha: 0)
        )
        wetSand.zPosition = 1
        addChild(wetSand)

        shallowWater.texture = Self.radialTexture(
            center: NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.70, alpha: 0.55),
            edge: NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.70, alpha: 0)
        )
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

    /// A soft elliptical blob: full color at the center, transparent at the
    /// rim. Used so shore effects never show a hard edge.
    static func radialTexture(center: NSColor, edge: NSColor) -> SKTexture {
        let dimension = 256
        let context = CGContext(
            data: nil, width: dimension, height: dimension,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let colors = [center.cgColor, edge.cgColor] as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors, locations: [0, 1]
        )!
        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: CGFloat(dimension) / 2, y: CGFloat(dimension) / 2),
            startRadius: 0,
            endCenter: CGPoint(x: CGFloat(dimension) / 2, y: CGFloat(dimension) / 2),
            endRadius: CGFloat(dimension) / 2,
            options: []
        )
        return SKTexture(cgImage: context.makeImage()!)
    }

    private func layoutShoreline() {
        // Sprites are oversized relative to the visible pool so the radial
        // fade completes before the edge arrives.
        wetSand.size = CGSize(width: size.width * 0.62, height: size.height * 0.17)
        wetSand.position = CGPoint(x: 0, y: -size.height * 0.168)

        shallowWater.size = CGSize(width: size.width * 0.60, height: size.height * 0.155)
        shallowWater.position = CGPoint(x: 0, y: -size.height * 0.192)

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
