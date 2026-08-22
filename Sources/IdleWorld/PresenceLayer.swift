import AppKit
import SpriteKit

import IdleEngine

/// Visiting-wildlife presentation as a layer node inside the single world scene.
final class PresenceLayer: SKNode {
    private let size: CGSize
    private let presenceEngine = PresenceEngine()
    private var renderedVisitor: PresenceState.Visitor = .none
    private let visitorLayer = SKNode()

    init(size: CGSize) {
        self.size = size
        super.init()

        visitorLayer.zPosition = 50
        addChild(visitorLayer)
        render(presenceEngine.state)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(by delta: TimeInterval, world: WorldState) {
        let presence = presenceEngine.advance(by: delta, world: world)
        render(presence)
    }

    private func render(_ presence: PresenceState) {
        if presence.visitor != renderedVisitor {
            renderedVisitor = presence.visitor
            rebuildVisitor(for: presence.visitor)
        }

        visitorLayer.isHidden = !presence.isPresent
        visitorLayer.alpha = CGFloat(min(1, presence.progress * 1.25))

        switch presence.visitor {
        case .none:
            break

        case .gull:
            let startX = -size.width * 0.18
            let endX = size.width * 0.18
            visitorLayer.position = CGPoint(
                x: startX + (endX - startX) * CGFloat(presence.progress),
                y: -size.height * 0.055
            )
            visitorLayer.zRotation = sin(CGFloat(presence.progress) * .pi * 3) * 0.03

        case .butterflies:
            visitorLayer.position = CGPoint(
                x: size.width * 0.08 + sin(CGFloat(presence.progress) * .pi * 5) * size.width * 0.06,
                y: size.height * 0.02 + cos(CGFloat(presence.progress) * .pi * 4) * 16
            )

        case .fishSchool:
            visitorLayer.position = CGPoint(
                x: -size.width * 0.32 + CGFloat(presence.progress) * size.width * 0.64,
                y: -size.height * 0.31
            )

        case .seaTurtle:
            visitorLayer.position = CGPoint(
                x: size.width * 0.20 - CGFloat(presence.progress) * size.width * 0.14,
                y: -size.height * 0.285
            )
            visitorLayer.yScale = 0.92 + sin(CGFloat(presence.progress) * .pi * 2) * 0.08
        }
    }

    private func rebuildVisitor(for visitor: PresenceState.Visitor) {
        visitorLayer.removeAllChildren()
        visitorLayer.removeAllActions()
        visitorLayer.setScale(1)
        visitorLayer.zRotation = 0

        switch visitor {
        case .none:
            break
        case .gull:
            buildGull()
        case .butterflies:
            buildButterflies()
        case .fishSchool:
            buildFishSchool()
        case .seaTurtle:
            buildSeaTurtle()
        }
    }

    private func buildGull() {
        let body = SKShapeNode(ellipseOf: CGSize(width: 30, height: 14))
        body.fillColor = .white
        body.strokeColor = .clear
        visitorLayer.addChild(body)

        for side in [-1.0, 1.0] {
            let wing = SKShapeNode(ellipseOf: CGSize(width: 31, height: 8))
            wing.fillColor = NSColor.white.withAlphaComponent(0.94)
            wing.strokeColor = .clear
            wing.position = CGPoint(x: side * 20, y: 4)
            wing.zRotation = side * 0.18
            visitorLayer.addChild(wing)
        }

        visitorLayer.run(.repeatForever(.sequence([
            .scaleY(to: 0.88, duration: 0.34),
            .scaleY(to: 1.08, duration: 0.34)
        ])))
    }

    private func buildButterflies() {
        for index in 0..<4 {
            let butterfly = SKNode()
            butterfly.position = CGPoint(x: CGFloat(index * 24 - 36), y: CGFloat((index % 2) * 18))

            for side in [-1.0, 1.0] {
                let wing = SKShapeNode(ellipseOf: CGSize(width: 11, height: 15))
                wing.fillColor = NSColor(calibratedRed: 0.96, green: 0.66, blue: 0.22, alpha: 0.9)
                wing.strokeColor = .clear
                wing.position.x = side * 5
                butterfly.addChild(wing)
            }

            butterfly.run(.repeatForever(.sequence([
                .scaleX(to: 0.28, duration: 0.16 + Double(index) * 0.02),
                .scaleX(to: 1, duration: 0.16 + Double(index) * 0.02)
            ])))
            visitorLayer.addChild(butterfly)
        }
    }

    private func buildFishSchool() {
        for index in 0..<6 {
            let fish = SKLabelNode(text: "◁")
            fish.fontSize = 15 + CGFloat(index % 3) * 2
            fish.fontColor = NSColor.white.withAlphaComponent(0.70)
            fish.position = CGPoint(x: CGFloat(index * 25 - 62), y: CGFloat((index % 3) * 11 - 11))
            visitorLayer.addChild(fish)
        }

        visitorLayer.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 5, duration: 0.8),
            .moveBy(x: 0, y: -5, duration: 0.8)
        ])))
    }

    private func buildSeaTurtle() {
        let shell = SKShapeNode(ellipseOf: CGSize(width: 54, height: 28))
        shell.fillColor = NSColor(calibratedRed: 0.18, green: 0.43, blue: 0.30, alpha: 0.95)
        shell.strokeColor = NSColor.white.withAlphaComponent(0.16)
        shell.lineWidth = 2
        visitorLayer.addChild(shell)

        let head = SKShapeNode(circleOfRadius: 9)
        head.fillColor = NSColor(calibratedRed: 0.25, green: 0.52, blue: 0.36, alpha: 1)
        head.strokeColor = .clear
        head.position.x = -34
        visitorLayer.addChild(head)

        for side in [-1.0, 1.0] {
            let flipper = SKShapeNode(ellipseOf: CGSize(width: 31, height: 9))
            flipper.fillColor = head.fillColor
            flipper.strokeColor = .clear
            flipper.position = CGPoint(x: 3, y: side * 19)
            flipper.zRotation = side * 0.28
            visitorLayer.addChild(flipper)
        }

        visitorLayer.run(.repeatForever(.sequence([
            .rotate(toAngle: -0.04, duration: 1.4, shortestUnitArc: true),
            .rotate(toAngle: 0.04, duration: 1.4, shortestUnitArc: true)
        ])))
    }
}
