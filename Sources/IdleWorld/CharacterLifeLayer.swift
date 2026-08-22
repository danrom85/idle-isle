import IdleEngine
import AppKit
import SpriteKit

final class CharacterLifeLayer: SKNode {
    private let size: CGSize
    private let crabEngine = CrabEngine()
    private var lastAmbientEvent: WorldState.AmbientEvent = .none
    private var duckOffset: CGFloat = 0

    private let activityLayer = SKNode()
    private let castawayRig = SKNode()
    private let castawayShadow = SKShapeNode(ellipseOf: CGSize(width: 44, height: 11))
    private let torso = SKShapeNode(rectOf: CGSize(width: 25, height: 43), cornerRadius: 8)
    private let headGroup = SKNode()
    private let head = SKShapeNode(circleOfRadius: 14)
    private let hat = SKShapeNode(ellipseOf: CGSize(width: 38, height: 11))
    private let leftArm = SKNode()
    private let rightArm = SKNode()
    private let leftLeg = SKNode()
    private let rightLeg = SKNode()

    private let crab = SKNode()
    private let fishingRod = SKShapeNode()
    private let fishingLine = SKShapeNode()
    private let float = SKShapeNode(circleOfRadius: 4)
    private let caughtFish = SKShapeNode()
    private let cookingSmoke = SKShapeNode(circleOfRadius: 5)
    private let oceanWatchingMat = SKShapeNode(ellipseOf: CGSize(width: 58, height: 16))
    private let watchingFootprints = SKNode()
    private let restingMat = SKShapeNode(ellipseOf: CGSize(width: 66, height: 18))
    private let restingZ = SKLabelNode(text: "z")

    init(size: CGSize) {
        self.size = size
        super.init()

        buildActivityProps()
        buildCastawayRig()
        buildCrab()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(by delta: TimeInterval, world: WorldState) {
        let crabState = crabEngine.advance(by: delta, world: world)
        renderCastaway(world)
        renderWorldActivity(world)
        renderCrab(crabState, world: world)
        reactToAmbientEvent(world)

        // Applied after posing so the duck survives resetPose().
        if duckOffset != 0 {
            headGroup.position.y += duckOffset
            let decay = exp(-delta * 7)
            duckOffset *= decay
            if abs(duckOffset) < 0.05 { duckOffset = 0 }
        }
    }

    /// Familiar castaways barely react to falling coconuts; newcomers flinch.
    private func reactToAmbientEvent(_ world: WorldState) {
        guard world.ambientEvent != lastAmbientEvent else { return }
        let previousEvent = lastAmbientEvent
        lastAmbientEvent = world.ambientEvent

        guard world.ambientEvent == .coconutFalls,
              previousEvent != .coconutFalls,
              world.memory.coconutFamiliarity < 0.75 else { return }

        duckOffset = -2.5

        let reaction = 0.35 * (1 - world.memory.coconutFamiliarity)
        hat.removeAction(forKey: "coconutFlinch")
        hat.run(.sequence([
            .rotate(byAngle: reaction, duration: 0.09),
            .rotate(byAngle: -reaction * 2, duration: 0.12),
            .rotate(toAngle: 0, duration: 0.14)
        ]), withKey: "coconutFlinch")
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

        cookingSmoke.fillColor = NSColor.white.withAlphaComponent(0.24)
        cookingSmoke.strokeColor = .clear
        cookingSmoke.isHidden = true
        activityLayer.addChild(cookingSmoke)

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

    private func buildCastawayRig() {
        castawayRig.zPosition = 45
        addChild(castawayRig)

        castawayShadow.name = "rig-shadow"
        castawayShadow.fillColor = NSColor.black.withAlphaComponent(0.20)
        castawayShadow.strokeColor = .clear
        castawayShadow.position = CGPoint(x: 0, y: -2)
        castawayShadow.zPosition = -2
        castawayRig.addChild(castawayShadow)

        let skin = NSColor(calibratedRed: 0.76, green: 0.52, blue: 0.32, alpha: 1)
        let shirt = NSColor(calibratedRed: 0.82, green: 0.28, blue: 0.18, alpha: 1)
        let shorts = NSColor(calibratedRed: 0.24, green: 0.35, blue: 0.45, alpha: 1)

        torso.name = "torso"
        torso.fillColor = shirt
        torso.strokeColor = .clear
        torso.position = CGPoint(x: 0, y: 24)
        castawayRig.addChild(torso)

        head.fillColor = skin
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 0)
        headGroup.position = CGPoint(x: 0, y: 58)
        headGroup.addChild(head)

        hat.fillColor = NSColor(calibratedRed: 0.88, green: 0.70, blue: 0.30, alpha: 1)
        hat.strokeColor = .clear
        hat.position = CGPoint(x: 0, y: 12)
        headGroup.addChild(hat)
        castawayRig.addChild(headGroup)

        buildLimb(leftArm, length: 31, width: 8, color: skin)
        buildLimb(rightArm, length: 31, width: 8, color: skin)
        leftArm.position = CGPoint(x: -13, y: 42)
        rightArm.position = CGPoint(x: 13, y: 42)
        castawayRig.addChild(leftArm)
        castawayRig.addChild(rightArm)

        buildLimb(leftLeg, length: 31, width: 10, color: shorts)
        buildLimb(rightLeg, length: 31, width: 10, color: shorts)
        leftLeg.position = CGPoint(x: -7, y: 10)
        rightLeg.position = CGPoint(x: 7, y: 10)
        leftLeg.zPosition = -1
        rightLeg.zPosition = -1
        castawayRig.addChild(leftLeg)
        castawayRig.addChild(rightLeg)
    }

    private func buildLimb(_ limb: SKNode, length: CGFloat, width: CGFloat, color: NSColor) {
        let segment = SKShapeNode(rectOf: CGSize(width: width, height: length), cornerRadius: width / 2)
        segment.fillColor = color
        segment.strokeColor = .clear
        segment.position = CGPoint(x: 0, y: -length / 2)
        limb.addChild(segment)
    }

    private func resetPose() {
        castawayRig.zRotation = 0
        castawayRig.yScale = 1
        torso.position = CGPoint(x: 0, y: 24)
        torso.zRotation = 0
        headGroup.position = CGPoint(x: 0, y: 58)
        headGroup.zRotation = 0
        leftArm.position = CGPoint(x: -13, y: 42)
        rightArm.position = CGPoint(x: 13, y: 42)
        leftArm.zRotation = 0.12
        rightArm.zRotation = -0.12
        leftLeg.position = CGPoint(x: -7, y: 10)
        rightLeg.position = CGPoint(x: 7, y: 10)
        leftLeg.zRotation = 0.04
        rightLeg.zRotation = -0.04
        castawayShadow.position = CGPoint(x: 0, y: -2)
        castawayShadow.xScale = 1
        castawayShadow.alpha = 1
    }

    private func renderCastaway(_ world: WorldState) {
        let sandY = -size.height * 0.10
        let castawayX = worldX(world.characterX)
        let facing: CGFloat = world.destinationX >= world.characterX ? 1 : -1
        let time = CGFloat(world.elapsedTime)
        resetPose()

        castawayRig.position = CGPoint(x: castawayX, y: sandY)
        castawayRig.xScale = facing
        castawayRig.alpha = 1

        switch world.activity {
        case .walking, .carryingFish:
            let stride = sin(time * 12)
            castawayRig.position.y += abs(stride) * 3
            leftArm.zRotation = 0.35 * stride
            rightArm.zRotation = -0.35 * stride
            leftLeg.zRotation = -0.42 * stride
            rightLeg.zRotation = 0.42 * stride
            if world.activity == .carryingFish {
                leftArm.zRotation = -0.92
                rightArm.zRotation = 0.72
                headGroup.zRotation = -0.08
            }

        case .fishing:
            let finalLift = world.activityTimeRemaining < 1.1
            torso.zRotation = finalLift ? 0.16 : -0.08
            leftLeg.zRotation = 0.24
            rightLeg.zRotation = -0.22
            leftArm.zRotation = finalLift ? -1.18 : -0.78
            rightArm.zRotation = finalLift ? -0.82 : -1.10
            headGroup.zRotation = finalLift ? 0.15 : -0.10

        case .watchingOcean:
            castawayRig.position.y -= 9
            torso.position = CGPoint(x: 0, y: 18)
            torso.zRotation = -0.16
            headGroup.position = CGPoint(x: -2, y: 49)
            headGroup.zRotation = -0.12 + sin(time * 0.7) * 0.025
            leftLeg.position = CGPoint(x: -8, y: 5)
            rightLeg.position = CGPoint(x: 8, y: 5)
            leftLeg.zRotation = 1.12
            rightLeg.zRotation = -1.02
            leftArm.position = CGPoint(x: -13, y: 34)
            rightArm.position = CGPoint(x: 13, y: 34)
            leftArm.zRotation = 0.88
            rightArm.zRotation = -0.88
            castawayShadow.xScale = 1.25

        case .resting:
            castawayRig.position.y -= 10
            torso.position = CGPoint(x: 0, y: 17)
            torso.zRotation = 0.24
            headGroup.position = CGPoint(x: 5, y: 47)
            headGroup.zRotation = 0.22
            leftLeg.position = CGPoint(x: -7, y: 4)
            rightLeg.position = CGPoint(x: 7, y: 4)
            leftLeg.zRotation = 1.28
            rightLeg.zRotation = -0.28
            leftArm.zRotation = 0.42
            rightArm.zRotation = -0.12
            castawayShadow.xScale = 1.35

        case .sleeping:
            castawayRig.position.y -= 10
            castawayRig.zRotation = -.pi / 2
            castawayRig.yScale = 0.92
            leftArm.zRotation = 0.66
            rightArm.zRotation = -0.48
            leftLeg.zRotation = 0.44
            rightLeg.zRotation = -0.38
            headGroup.zRotation = 0.18
            castawayShadow.position = CGPoint(x: 22, y: -1)
            castawayShadow.xScale = 1.55
            castawayRig.alpha = 0.92

        case .cookingFish:
            castawayRig.position.y -= 8
            torso.position = CGPoint(x: 0, y: 18)
            torso.zRotation = -0.28
            headGroup.position = CGPoint(x: -5, y: 48)
            headGroup.zRotation = -0.22
            leftLeg.position = CGPoint(x: -8, y: 6)
            rightLeg.position = CGPoint(x: 7, y: 5)
            leftLeg.zRotation = 0.92
            rightLeg.zRotation = -1.24
            let tending = sin(time * 2.4) * 0.10
            leftArm.zRotation = -1.08 + tending
            rightArm.zRotation = -0.72 - tending
            castawayShadow.xScale = 1.25

        case .eatingFish:
            castawayRig.position.y -= 4
            torso.zRotation = -0.06
            let bite = sin(time * 8)
            leftArm.zRotation = -1.40 + bite * 0.08
            rightArm.zRotation = -1.12 - bite * 0.08
            headGroup.zRotation = 0.08 + max(0, bite) * 0.05
            leftLeg.zRotation = 0.18
            rightLeg.zRotation = -0.18

        case .reactingToCrab:
            torso.zRotation = -0.05
            leftArm.zRotation = 2.15
            rightArm.zRotation = -2.15
            leftLeg.zRotation = 0.16
            rightLeg.zRotation = -0.16
            headGroup.zRotation = sin(time * 8) * 0.12
            castawayRig.position.y += abs(sin(time * 9)) * 2

        case .idle:
            let gestureCycle = world.elapsedTime.truncatingRemainder(dividingBy: 18)
            torso.zRotation = sin(time * 0.7) * 0.018
            headGroup.zRotation = sin(time * 0.45) * 0.035
            if gestureCycle > 13 && gestureCycle < 16 {
                let progress = CGFloat((gestureCycle - 13) / 3)
                rightArm.zRotation = -0.25 - sin(progress * .pi) * 1.55
                headGroup.zRotation += sin(progress * .pi) * 0.10
            } else if gestureCycle > 8 && gestureCycle < 10.5 {
                leftArm.zRotation = 0.12 + sin(CGFloat((gestureCycle - 8) / 2.5) * .pi) * 0.55
                rightArm.zRotation = -0.12 - sin(CGFloat((gestureCycle - 8) / 2.5) * .pi) * 0.55
            }
        }
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
        let castawayX = worldX(world.characterX)
        let sandY = -size.height * 0.10
        let fishing = world.activity == .fishing
        let watching = world.activity == .watchingOcean
        let resting = world.activity == .resting

        fishingRod.isHidden = !fishing
        fishingLine.isHidden = !fishing
        float.isHidden = !fishing
        caughtFish.isHidden = true
        cookingSmoke.isHidden = true
        oceanWatchingMat.isHidden = !watching
        watchingFootprints.isHidden = !watching
        restingMat.isHidden = !resting
        restingZ.isHidden = !resting

        switch world.activity {
        case .fishing:
            renderFishing(at: CGPoint(x: castawayX, y: sandY), world: world)

        case .carryingFish:
            renderSharedFish(world, at: CGPoint(x: castawayX - 18, y: sandY + 42), rotation: -0.18)

        case .cookingFish:
            let fire = CGPoint(x: worldX(SimulationEngine.campfireX), y: sandY + 11)
            renderSharedFish(world, at: fire, rotation: 0.04)
            renderCookingSmoke(at: fire, world: world)

        case .eatingFish:
            let bite = sin(CGFloat(world.elapsedTime) * 8) * 4
            renderSharedFish(world, at: CGPoint(x: castawayX - 12 + bite, y: sandY + 59), rotation: -0.25)

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
        let finalLift = world.activityTimeRemaining < 1.1
        let cycle = world.elapsedTime.truncatingRemainder(dividingBy: 8)
        let isCasting = cycle < 1.0 && !finalLift
        let rodTip: CGPoint
        let floatPosition: CGPoint

        if isCasting {
            let progress = CGFloat(cycle)
            rodTip = CGPoint(x: castaway.x - 18 - 25 * progress, y: castaway.y + 72 + 8 * sin(progress * .pi))
            floatPosition = CGPoint(x: castaway.x - 28 - 66 * progress, y: castaway.y + 12 - 70 * progress)
        } else if finalLift {
            let lift = CGFloat(max(0, min(1, (1.1 - world.activityTimeRemaining) / 1.1)))
            rodTip = CGPoint(x: castaway.x - 34, y: castaway.y + 82)
            floatPosition = CGPoint(x: castaway.x - 76 + 42 * lift, y: castaway.y - 52 + 88 * lift)
            caughtFish.isHidden = false
            caughtFish.position = CGPoint(x: floatPosition.x, y: floatPosition.y - 12)
            caughtFish.zRotation = sin(CGFloat(world.elapsedTime) * 9) * 0.22
        } else {
            let tension = world.activityTimeRemaining < 2.4 ? CGFloat((2.4 - world.activityTimeRemaining) / 2.4) : 0
            rodTip = CGPoint(x: castaway.x - 42 + tension * 5, y: castaway.y + 78 - tension * 8)
            floatPosition = CGPoint(x: castaway.x - 94, y: castaway.y - 58 + tension * 5)
        }

        let rodPath = CGMutablePath()
        rodPath.move(to: CGPoint(x: castaway.x + 8, y: castaway.y + 42))
        rodPath.addQuadCurve(
            to: rodTip,
            control: CGPoint(x: (castaway.x + rodTip.x) * 0.5 - 5, y: max(castaway.y + 55, rodTip.y - 4))
        )
        fishingRod.path = rodPath

        let linePath = CGMutablePath()
        linePath.move(to: rodTip)
        linePath.addQuadCurve(
            to: floatPosition,
            control: CGPoint(x: min(rodTip.x, floatPosition.x) - 12, y: (rodTip.y + floatPosition.y) * 0.5)
        )
        fishingLine.path = linePath
        float.position = floatPosition

        if !isCasting && !finalLift {
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

    private func renderSharedFish(_ world: WorldState, at position: CGPoint, rotation: CGFloat) {
        guard let fish = world.fish else { return }
        caughtFish.isHidden = fish.state == .eaten || fish.state == .stolen
        caughtFish.position = position
        caughtFish.zRotation = rotation + sin(CGFloat(world.elapsedTime) * 7) * 0.05

        let progress = CGFloat(max(0, min(1, fish.cookingProgress)))
        caughtFish.fillColor = NSColor(
            calibratedRed: 0.34 + 0.36 * progress,
            green: 0.69 - 0.35 * progress,
            blue: 0.74 - 0.55 * progress,
            alpha: 1
        )
    }

    private func renderCookingSmoke(at fire: CGPoint, world: WorldState) {
        cookingSmoke.isHidden = false
        let rise = CGFloat(world.elapsedTime.truncatingRemainder(dividingBy: 1.6) / 1.6)
        cookingSmoke.position = CGPoint(x: fire.x + 4 * sin(rise * .pi * 2), y: fire.y + 18 + 34 * rise)
        cookingSmoke.alpha = 0.32 * (1 - rise)
        cookingSmoke.setScale(0.7 + rise * 0.8)
    }

    private func worldX(_ normalizedX: Double) -> CGFloat {
        -size.width * 0.29 + CGFloat(normalizedX) * size.width * 0.58
    }

    private func renderCrab(_ state: CrabState, world: WorldState) {
        crab.isHidden = !state.isVisible
        guard state.isVisible else { return }

        let shoreX = worldX(state.positionX)
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
            let castawayX = worldX(world.characterX)
            crab.xScale = castawayX >= crab.position.x ? 1 : -1
            crab.zRotation = 0
        case .resting:
            crab.alpha = 0.88
            crab.removeAction(forKey: "scuttle")
            crab.zRotation = -0.04
        }
    }
}
