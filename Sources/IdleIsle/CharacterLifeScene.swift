import AppKit
import SpriteKit

final class CharacterLifeScene: SKScene {
    private let worldEngine: SimulationEngine
    private let crabEngine = CrabEngine()
    private var lastUpdateTime: TimeInterval = 0

    private let activityLayer = SKNode()
    private let crab = SKNode()
    private let fishingRod = SKShapeNode()
    private let fishingLine = SKShapeNode()
    private let float = SKShapeNode(circleOfRadius: 4)
    private let oceanWatchingMat = SKShapeNode(ellipseOf: CGSize(width: 46, height: 14))
    private let restingZ = SKLabelNode(text: "z")
    private let activityLabel = SKLabelNode(fontNamed: "Menlo")

    override init(size: CGSize) {
        let persistence = WorldPersistence()
        worldEngine = SimulationEngine(initialState: persistence.load() ?? WorldState())
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

        let world = worldEngine.advance(by: delta)
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

        oceanWatchingMat.fillColor = NSColor(calibratedRed: 0.54, green: 0.34, blue: 0.16, alpha: 0.45)
        oceanWatchingMat.strokeColor = .clear
        activityLayer.addChild(oceanWatchingMat)

        restingZ.fontSize = 19
        restingZ.fontColor = NSColor.white.withAlphaComponent(0.72)
        activityLayer.addChild(restingZ)

        activityLabel.fontSize = 11
        activityLabel.fontColor = NSColor.white.withAlphaComponent(0.48)
        activityLabel.horizontalAlignmentMode = .center
        activityLayer.addChild(activityLabel)
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

        fishingRod.isHidden = world.activity != .fishing
        fishingLine.isHidden = world.activity != .fishing
        float.isHidden = world.activity != .fishing
        oceanWatchingMat.isHidden = world.activity != .watchingOcean
        restingZ.isHidden = world.activity != .resting
        activityLabel.isHidden = ![WorldState.Activity.fishing, .watchingOcean, .resting].contains(world.activity)

        switch world.activity {
        case .fishing:
            let rodPath = CGMutablePath()
            rodPath.move(to: CGPoint(x: castawayX + 8, y: sandY + 42))
            rodPath.addLine(to: CGPoint(x: castawayX - 42, y: sandY + 78))
            fishingRod.path = rodPath

            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: castawayX - 42, y: sandY + 78))
            linePath.addQuadCurve(
                to: CGPoint(x: castawayX - 94, y: sandY - 58),
                control: CGPoint(x: castawayX - 104, y: sandY + 22)
            )
            fishingLine.path = linePath
            float.position = CGPoint(x: castawayX - 94, y: sandY - 58)
            float.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 3, duration: 0.55),
                .moveBy(x: 0, y: -3, duration: 0.55)
            ])), withKey: "bob")
            activityLabel.text = "fishing"
            activityLabel.position = CGPoint(x: castawayX, y: sandY + 88)

        case .watchingOcean:
            oceanWatchingMat.position = CGPoint(x: castawayX, y: sandY - 4)
            activityLabel.text = "watching the tide"
            activityLabel.position = CGPoint(x: castawayX, y: sandY + 72)

        case .resting:
            restingZ.position = CGPoint(x: castawayX + 24, y: sandY + 74)
            restingZ.run(.repeatForever(.sequence([
                .group([.moveBy(x: 8, y: 12, duration: 1.1), .fadeOut(withDuration: 1.1)]),
                .run { [weak self] in
                    self?.restingZ.position = CGPoint(x: castawayX + 24, y: sandY + 74)
                    self?.restingZ.alpha = 1
                }
            ])), withKey: "restingZ")
            activityLabel.text = "resting"
            activityLabel.position = CGPoint(x: castawayX, y: sandY + 76)

        default:
            float.removeAction(forKey: "bob")
            restingZ.removeAction(forKey: "restingZ")
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
