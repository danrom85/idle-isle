import AppKit
import SpriteKit

final class CharacterLifeScene: SKScene {
    private let runtime: WorldRuntime
    private let crabEngine = CrabEngine()
    private var lastUpdateTime: TimeInterval = 0

    private let activityLayer = SKNode()
    private let crab = SKNode()
    private let fishingRod = SKShapeNode()
    private let fishingLine = SKShapeNode()
    private let float = SKShapeNode(circleOfRadius: 4)
    private let caughtFish = SKShapeNode()
    private let oceanWatchingMat = SKShapeNode(ellipseOf: CGSize(width: 58, height: 16))
    private let watchingFootprints = SKNode()
    private let restingMat = SKShapeNode(ellipseOf: CGSize(width: 66, height: 18))
    private let restingZ = SKLabelNode(text: "z")

    init(size: CGSize, runtime: WorldRuntime) {
        self.runtime = runtime
        super.init(size: size)

        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .clear
        buildActivityProps()
        buildCrab()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 30
        view.allowsTransparency = true
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        let world = runtime.state
        let crabState = crabEngine.advance(by: delta, world: world)
        renderWorldActivity(world)
        renderCrab(crabState, world: world)
    }

    private func buildActivityProps() {
        activityLayer.zPosition = 42
        addChild(activityLayer)

        fishingRod.strokeColor = NSColor(calibratedRed: 0.34, green: 0.20, blue: 0.08, alpha: 1)
        fishingRod.lineWidth = 4
        fishingRod.lineCap = .round
        activityLayer.addChild(fishingRod)

        fishingLine.strokeColor = NSColor.white.withAlphaComponent(0.72)
        fishingLine.lineWidth = 1
        activityLayer.addChild(fishingLine)

        float.fillColor = NSColor(calibratedRed: 0.95, green: 0.22, blue: 0.16, alpha: 1)
        float.strokeColor = .clear
        activityLayer.addChild(float)

        let fishPath = CGMutablePath()
        fishPath.move(to: CGPoint(x: -10, y: 0))
        fishPath.addQuadCurve(to: CGPoint(x: 8, y: 0), control: CGPoint(x: 0, y: 8))
        fishPath.addQuadCurve(to: CGPoint(x: -10, y: 0), control: CGPoint(x: 0, y: -8))
        fishPath.move(to: CGPoint(x: 8, y: 0))
        fishPath.addLine(to: CGPoint(x: 15, y: 7))
        fishPath.addLine(to: CGPoint(x: 15, y: -7))
        fishPath.closeSubpath()
        caughtFish.path = fishPath
        caughtFish.fillColor = NSColor(calibratedRed: 0.34, green: 0.69, blue: 0.74, alpha: 1)
        caughtFish.strokeColor = NSColor.white.withAlphaComponent(0.38)
        caughtFish.lineWidth = 1
        caughtFish.isHidden = true
        activityLayer.addChild(caughtFish)

        oceanWatchingMat.fillColor = NSColor(calibratedRed: 0.54, green: 0.34, blue: 0.16, alpha: 0.42)
        oceanWatchingMat.strokeColor = NSColor.white.withAlphaComponent(0.08)
        oceanWatchingMat.lineWidth = 1
        activityLayer.addChild(oceanWatchingMat)

        for offset in [-1.0, 1.0] {
            let footprint = SKShapeNode(ellipseOf: CGSize(width: 7, height: 14))
            footprint.fillColor = NSColor(calibratedRed: 0.48, green: 0.31, blue: 0.16, alpha: 0.22)
            footprint.strokeColor = .clear
            footprint.position = CGPoint(x: offset * 7, y: 0)
            footprint.zRotation = CGFloat(offset * 0.11)
            watchingFootprints.addChild(footprint)
        }
        activityLayer.addChild(watchingFootprints)

        restingMat.fillColor = NSColor(calibratedRed: 0.40, green: 0.25, blue: 0.12, alpha: 0.28)
        restingMat.strokeColor = .clear
        activityLayer.addChild(restingMat)

        restingZ.fontSize = 19
        restingZ.fontColor = NSColor.white.withAlphaComponent(0.72)
        activityLayer.addChild(restingZ)
    }

    private func buildCrab() {
        crab.zPosition = 46
        addChild(crab)

        let body = SKShapeNode(ellipseOf: CGSize(width: 31, height: 20))
        body.fillColor = NSColor(calibratedRed: 0.82, green: 0.20, blue: 0.13, alpha: 1)
        body.strokeColor = NSColor.white.withAlphaComponent(0.12)
        body.lineWidth = 1
        crab.addChild(body)

        for side in [-1.0, 1.0] {
            let claw = SKShapeNode(circleOfRadius: 7)
            claw.fillColor = body.fillColor
            claw.strokeColor = .clear
            claw.position = CGPoint(x: side * 21, y: 5)
            crab.addChild(claw)

            for legIndex in 0..<3 {
                let leg = SKShapeNode(rectOf: CGSize(width: 15, height: 3), cornerRadius: 1.5)
                leg.fillColor = body.fillColor
                leg.strokeColor = .clear
                leg.position = CGPoint(x: side * 17, y: CGFloat(legIndex * 6 - 7))
                leg.zRotation = side * CGFloat(0.24 + Double(legIndex) * 0.10)
                crab.addChild(leg)
            }
        }

        for x in [-6.0, 6.0] {
            let eye = SKShapeNode(circleOfRadius: 2.4)
            eye.fillColor = NSColor(calibratedWhite: 0.08, alpha: 1)
            eye.strokeColor = .clear
            eye.position = CGPoint(x: x, y: 8)
            crab.addChild(eye)
        }
    }

    private func renderWorldActivity(_ world: WorldState) {
        let castawayX = -size.width * 0.29 + CGFloat(world.characterX) * size.width * 0.58
        let sandY = -size.height * 0.10
        let fishing = world.activity == .fishing
        let watching = world.activity == .watchingOcean
        let resting = world.activity == .resting

        fishingRod.isHidden = !fishing
        fishingLine.isHidden = !fishing
        float.isHidden = !fishing
        caughtFish.isHidden = true
        oceanWatchingMat.isHidden = !watching
        watchingFootprints.isHidden = !watching
        restingMat.isHidden = !resting
        restingZ.isHidden = !resting

        switch world.activity {
        case .fishing:
            renderFishing(at: CGPoint(x: castawayX, y: sandY), world: world)

        case .watchingOcean:
            oceanWatchingMat.position = CGPoint(x: castawayX - 2, y: sandY - 5)
            oceanWatchingMat.zRotation = -0.04
            watchingFootprints.position = CGPoint(x: castawayX + 5, y: sandY + 2)
            watchingFootprints.alpha = 0.55

        case .resting:
            restingMat.position = CGPoint(x: castawayX + 4, y: sandY - 5)
            restingMat.zRotation = 0.06
            restingZ.position = CGPoint(x: castawayX + 25, y: sandY + 73)
            if restingZ.action(forKey: "restingZ") == nil {
                restingZ.run(.repeatForever(.sequence([
                    .group([.moveBy(x: 8, y: 12, duration: 1.1), .fadeOut(withDuration: 1.1)]),
                    .run { [weak self] in
                        self?.restingZ.position = CGPoint(x: castawayX + 25, y: sandY + 73)
                        self?.restingZ.alpha = 1
                    }
                ])), withKey: "restingZ")
            }

        default:
            float.removeAction(forKey: "bob")
            restingZ.removeAction(forKey: "restingZ")
            restingZ.alpha = 1
        }
    }

    private func renderFishing(at castaway: CGPoint, world: WorldState) {
        let cycle = world.elapsedTime.truncatingRemainder(dividingBy: 12)
        let isCasting = cycle < 1.2
        let hasCatch = cycle > 10.6
        let rodTip: CGPoint
        let floatPosition: CGPoint

        if isCasting {
            let progress = CGFloat(cycle / 1.2)
            rodTip = CGPoint(x: castaway.x - 18 - 25 * progress, y: castaway.y + 72 + 8 * sin(progress * .pi))
            floatPosition = CGPoint(x: castaway.x - 28 - 66 * progress, y: castaway.y + 12 - 70 * progress)
        } else if hasCatch {
            let lift = CGFloat((cycle - 10.6) / 1.4)
            rodTip = CGPoint(x: castaway.x - 34, y: castaway.y + 82)
            floatPosition = CGPoint(x: castaway.x - 76 + 42 * lift, y: castaway.y - 52 + 88 * lift)
            caughtFish.isHidden = false
            caughtFish.position = CGPoint(x: floatPosition.x, y: floatPosition.y - 12)
            caughtFish.zRotation = sin(CGFloat(world.elapsedTime) * 9) * 0.22
        } else {
            rodTip = CGPoint(x: castaway.x - 42, y: castaway.y + 78)
            floatPosition = CGPoint(x: castaway.x - 94, y: castaway.y - 58)
        }

        let rodPath = CGMutablePath()
        rodPath.move(to: CGPoint(x: castaway.x + 8, y: castaway.y + 42))
        rodPath.addLine(to: rodTip)
        fishingRod.path = rodPath

        let linePath = CGMutablePath()
        linePath.move(to: rodTip)
        linePath.addQuadCurve(
            to: floatPosition,
            control: CGPoint(x: min(rodTip.x, floatPosition.x) - 12, y: (rodTip.y + floatPosition.y) * 0.5)
        )
        fishingLine.path = linePath
        float.position = floatPosition

        if !isCasting && !hasCatch {
            if float.action(forKey: "bob") == nil {
                float.run(.repeatForever(.sequence([
                    .moveBy(x: 0, y: 3, duration: 0.55),
                    .moveBy(x: 0, y: -3, duration: 0.55)
                ])), withKey: "bob")
            }
        } else {
            float.removeAction(forKey: "bob")
        }
    }

    private func renderCrab(_ state: CrabState, world: WorldState) {
        crab.isHidden = !state.isVisible
        guard state.isVisible else { return }

        let shoreX = -size.width * 0.29 + CGFloat(state.positionX) * size.width * 0.58
        let tideOffset = CGFloat((0.5 - world.tideLevel) * 16)
        crab.position = CGPoint(x: shoreX, y: -size.height * 0.155 + tideOffset)

        switch state.activity {
        case .hidden:
            break
        case .emerging, .returningHome:
            crab.alpha = 0.82
            crab.xScale = state.destinationX >= state.positionX ? 1 : -1
            if crab.action(forKey: "scuttle") == nil {
                crab.run(.repeatForever(.sequence([
                    .moveBy(x: 0, y: 3, duration: 0.13),
                    .moveBy(x: 0, y: -3, duration: 0.13)
                ])), withKey: "scuttle")
            }
        case .foraging:
            crab.alpha = 1
            crab.removeAction(forKey: "scuttle")
            crab.zRotation = sin(CGFloat(state.activityTimeRemaining) * 3) * 0.06
        case .watchingCastaway:
            crab.alpha = 1
            crab.removeAction(forKey: "scuttle")
            let castawayX = -size.width * 0.29 + CGFloat(world.characterX) * size.width * 0.58
            crab.xScale = castawayX >= crab.position.x ? 1 : -1
            crab.zRotation = 0
        case .resting:
            crab.alpha = 0.88
            crab.removeAction(forKey: "scuttle")
            crab.zRotation = -0.04
        }
    }
}
