import AppKit
import SpriteKit

final class IslandScene: SKScene {
    private let engine = SimulationEngine()
    private var lastUpdateTime: TimeInterval = 0
    private var lastAmbientEvent: WorldState.AmbientEvent = .none

    private let sky = SKSpriteNode(color: .systemBlue, size: .zero)
    private let ocean = SKShapeNode()
    private let island = SKShapeNode()
    private let palm = SKNode()
    private let castaway = SKNode()
    private let campfire = SKNode()
    private let debugLabel = SKLabelNode(fontNamed: "SFMono-Regular")

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .black
        buildWorld()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 30
        view.ignoresSiblingOrder = true
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        let state = engine.advance(by: delta)
        render(state)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutWorld()
    }

    private func buildWorld() {
        sky.zPosition = -20
        addChild(sky)

        ocean.fillColor = NSColor(calibratedRed: 0.09, green: 0.48, blue: 0.67, alpha: 1)
        ocean.strokeColor = .clear
        ocean.zPosition = -10
        addChild(ocean)

        island.fillColor = NSColor(calibratedRed: 0.93, green: 0.74, blue: 0.43, alpha: 1)
        island.strokeColor = NSColor(calibratedWhite: 1, alpha: 0.25)
        island.lineWidth = 3
        island.zPosition = 0
        addChild(island)

        buildPalm()
        addChild(palm)

        buildCastaway()
        addChild(castaway)

        buildCampfire()
        addChild(campfire)

        debugLabel.fontSize = 13
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontColor = NSColor.white.withAlphaComponent(0.72)
        debugLabel.zPosition = 100
        addChild(debugLabel)

        layoutWorld()
        animateOcean()
        animatePalm()
        animateFire()
    }

    private func layoutWorld() {
        sky.size = size

        let oceanRect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height * 0.49)
        ocean.path = CGPath(rect: oceanRect, transform: nil)

        let islandRect = CGRect(x: -size.width * 0.29, y: -size.height * 0.23, width: size.width * 0.58, height: size.height * 0.24)
        island.path = CGPath(ellipseIn: islandRect, transform: nil)

        palm.position = CGPoint(x: size.width * 0.17, y: -size.height * 0.02)
        campfire.position = CGPoint(x: size.width * 0.05, y: -size.height * 0.12)
        debugLabel.position = CGPoint(x: -size.width / 2 + 18, y: size.height / 2 - 18)
    }

    private func buildPalm() {
        let trunk = SKShapeNode(rectOf: CGSize(width: 20, height: 150), cornerRadius: 9)
        trunk.fillColor = NSColor(calibratedRed: 0.43, green: 0.25, blue: 0.11, alpha: 1)
        trunk.strokeColor = .clear
        trunk.position.y = 72
        trunk.zRotation = -0.09
        palm.addChild(trunk)

        for angle in stride(from: 0.0, to: 360.0, by: 60.0) {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 115, height: 28))
            leaf.fillColor = NSColor(calibratedRed: 0.14, green: 0.52, blue: 0.24, alpha: 1)
            leaf.strokeColor = .clear
            leaf.position.y = 150
            leaf.zRotation = angle * .pi / 180
            leaf.position.x = cos(leaf.zRotation) * 35
            leaf.position.y += sin(leaf.zRotation) * 16
            palm.addChild(leaf)
        }
    }

    private func buildCastaway() {
        let body = SKShapeNode(rectOf: CGSize(width: 23, height: 44), cornerRadius: 8)
        body.fillColor = NSColor(calibratedRed: 0.82, green: 0.28, blue: 0.18, alpha: 1)
        body.strokeColor = .clear
        body.position.y = 22
        castaway.addChild(body)

        let head = SKShapeNode(circleOfRadius: 14)
        head.fillColor = NSColor(calibratedRed: 0.76, green: 0.52, blue: 0.32, alpha: 1)
        head.strokeColor = .clear
        head.position.y = 57
        castaway.addChild(head)

        let hat = SKShapeNode(ellipseOf: CGSize(width: 38, height: 11))
        hat.fillColor = NSColor(calibratedRed: 0.88, green: 0.70, blue: 0.30, alpha: 1)
        hat.strokeColor = .clear
        hat.position.y = 69
        castaway.addChild(hat)
    }

    private func buildCampfire() {
        for offset in [-10.0, 10.0] {
            let log = SKShapeNode(rectOf: CGSize(width: 45, height: 9), cornerRadius: 4)
            log.fillColor = NSColor(calibratedRed: 0.30, green: 0.16, blue: 0.07, alpha: 1)
            log.strokeColor = .clear
            log.zRotation = offset < 0 ? 0.35 : -0.35
            campfire.addChild(log)
        }

        let flame = SKShapeNode(ellipseOf: CGSize(width: 28, height: 46))
        flame.name = "flame"
        flame.fillColor = NSColor(calibratedRed: 1, green: 0.45, blue: 0.08, alpha: 0.95)
        flame.strokeColor = .clear
        flame.position.y = 28
        campfire.addChild(flame)
    }

    private func animateOcean() {
        let brighten = SKAction.run { [weak ocean] in ocean?.alpha = 0.90 }
        let dim = SKAction.run { [weak ocean] in ocean?.alpha = 1.0 }
        ocean.run(.repeatForever(.sequence([brighten, .wait(forDuration: 1.8), dim, .wait(forDuration: 1.8)])))
    }

    private func animatePalm() {
        palm.run(.repeatForever(.sequence([
            .rotate(toAngle: -0.018, duration: 2.6, shortestUnitArc: true),
            .rotate(toAngle: 0.018, duration: 2.6, shortestUnitArc: true)
        ])))
    }

    private func animateFire() {
        guard let flame = campfire.childNode(withName: "flame") else { return }
        flame.run(.repeatForever(.sequence([
            .scaleY(to: 0.78, duration: 0.22),
            .scaleY(to: 1.08, duration: 0.27),
            .scaleY(to: 0.92, duration: 0.18)
        ])))
    }

    private func render(_ state: WorldState) {
        sky.color = skyColor(for: state.dayPhase)
        ocean.fillColor = oceanColor(for: state.dayPhase)
        campfire.alpha = state.dayPhase == .day ? 0.72 : 1

        castaway.position = CGPoint(
            x: -size.width * 0.29 + CGFloat(state.characterX) * size.width * 0.58,
            y: -size.height * 0.10
        )

        let facingScale: CGFloat = state.destinationX >= state.characterX ? 1 : -1
        castaway.xScale = facingScale
        castaway.setScale(state.activity == .sleeping ? 0.82 : 1)
        castaway.zRotation = state.activity == .sleeping ? -.pi / 2 : 0
        castaway.alpha = state.activity == .sleeping ? 0.88 : 1

        if state.activity == .walking && castaway.action(forKey: "walkBounce") == nil {
            castaway.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 4, duration: 0.18),
                .moveBy(x: 0, y: -4, duration: 0.18)
            ])), withKey: "walkBounce")
        } else if state.activity != .walking {
            castaway.removeAction(forKey: "walkBounce")
        }

        debugLabel.text = "Idle Isle • \(state.debugSummary)"

        if state.ambientEvent != lastAmbientEvent {
            lastAmbientEvent = state.ambientEvent
            playAmbientEvent(state.ambientEvent)
        }
    }

    private func playAmbientEvent(_ event: WorldState.AmbientEvent) {
        switch event {
        case .none:
            break
        case .gullPasses:
            let gull = SKLabelNode(text: "⌁")
            gull.fontSize = 34
            gull.fontColor = .white
            gull.position = CGPoint(x: -size.width / 2 - 30, y: size.height * 0.24)
            gull.zPosition = 30
            addChild(gull)
            gull.run(.sequence([.moveTo(x: size.width / 2 + 30, duration: 4), .removeFromParent()]))
        case .fishJumps:
            let fish = SKLabelNode(text: "◁")
            fish.fontSize = 26
            fish.fontColor = NSColor.white.withAlphaComponent(0.85)
            fish.position = CGPoint(x: -size.width * 0.22, y: -size.height * 0.27)
            fish.zPosition = 20
            addChild(fish)
            fish.run(.sequence([
                .group([.moveBy(x: 55, y: 70, duration: 0.55), .rotate(byAngle: .pi, duration: 0.55)]),
                .group([.moveBy(x: 55, y: -70, duration: 0.55), .rotate(byAngle: .pi, duration: 0.55)]),
                .removeFromParent()
            ]))
        case .coconutFalls:
            let coconut = SKShapeNode(circleOfRadius: 9)
            coconut.fillColor = NSColor(calibratedRed: 0.30, green: 0.16, blue: 0.07, alpha: 1)
            coconut.strokeColor = .clear
            coconut.position = CGPoint(x: palm.position.x, y: palm.position.y + 145)
            coconut.zPosition = 15
            addChild(coconut)
            coconut.run(.sequence([.moveBy(x: -18, y: -148, duration: 0.8), .wait(forDuration: 1.2), .fadeOut(withDuration: 0.5), .removeFromParent()]))
        case .crabVisits:
            let crab = SKLabelNode(text: "⌘")
            crab.fontSize = 24
            crab.fontColor = NSColor(calibratedRed: 0.85, green: 0.22, blue: 0.15, alpha: 1)
            crab.position = CGPoint(x: size.width * 0.30, y: -size.height * 0.16)
            crab.zPosition = 20
            addChild(crab)
            crab.run(.sequence([.moveBy(x: -170, y: 0, duration: 4.5), .removeFromParent()]))
        case .shootingStar:
            let star = SKShapeNode(rectOf: CGSize(width: 70, height: 3), cornerRadius: 2)
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(x: size.width * 0.25, y: size.height * 0.34)
            star.zRotation = -0.55
            star.zPosition = 25
            addChild(star)
            star.run(.sequence([.group([.moveBy(x: -180, y: -110, duration: 0.65), .fadeOut(withDuration: 0.65)]), .removeFromParent()]))
        }
    }

    private func skyColor(for phase: WorldState.DayPhase) -> NSColor {
        switch phase {
        case .dawn: return NSColor(calibratedRed: 0.96, green: 0.58, blue: 0.48, alpha: 1)
        case .day: return NSColor(calibratedRed: 0.31, green: 0.70, blue: 0.91, alpha: 1)
        case .sunset: return NSColor(calibratedRed: 0.93, green: 0.38, blue: 0.31, alpha: 1)
        case .night: return NSColor(calibratedRed: 0.035, green: 0.08, blue: 0.18, alpha: 1)
        }
    }

    private func oceanColor(for phase: WorldState.DayPhase) -> NSColor {
        switch phase {
        case .dawn: return NSColor(calibratedRed: 0.18, green: 0.50, blue: 0.64, alpha: 1)
        case .day: return NSColor(calibratedRed: 0.07, green: 0.49, blue: 0.69, alpha: 1)
        case .sunset: return NSColor(calibratedRed: 0.23, green: 0.33, blue: 0.55, alpha: 1)
        case .night: return NSColor(calibratedRed: 0.025, green: 0.12, blue: 0.25, alpha: 1)
        }
    }
}
