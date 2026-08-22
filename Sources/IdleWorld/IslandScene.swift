import IdleEngine
import AppKit
import SpriteKit

public final class IslandScene: SKScene {
    private let runtime: WorldRuntime
    private var lastUpdateTime: TimeInterval = 0
    private var lastWallTime: TimeInterval = 0
    private var lastAmbientEvent: WorldState.AmbientEvent = .none
    private var currentWind: Double = 0.22

    private let sky = SKSpriteNode(color: .systemBlue, size: .zero)
    private let stars = SKNode()
    private let clouds = SKNode()
    private let ocean = SKShapeNode()
    private let farWaves = SKNode()
    private let nearWaves = SKNode()
    private let island = SKShapeNode()

    private let memoryLayer = SKNode()
    private let pathWear = SKShapeNode()
    private let fishingWear = SKShapeNode()
    private let campfireWear = SKShapeNode()
    private let palmWear = SKShapeNode()
    private let rodRack = SKNode()
    private let rainLayer = SKNode()

    private let palm = SKNode()
    private let palmCrown = SKNode()
    private let campfire = SKNode()
    private let smokeLayer = SKNode()
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")

    // Overlay presentation layers. One scene hosts everything so SpriteKit
    // renders through a single view and pipeline.
    private let tideLayer: TideLayer
    private let presenceLayer: PresenceLayer
    private let characterLifeLayer: CharacterLifeLayer
    private let soundSystem = SoundSystem()
    private var soundEnabled = true

    public init(size: CGSize, runtime: WorldRuntime) {
        self.runtime = runtime
        tideLayer = TideLayer(size: size)
        presenceLayer = PresenceLayer(size: size)
        characterLifeLayer = CharacterLifeLayer(size: size)
        super.init(size: size)

        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .black
        buildWorld()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 30
        view.ignoresSiblingOrder = true
        view.allowsTransparency = false
        view.window?.makeFirstResponder(view)
        if soundEnabled { soundSystem.start() }
    }

    /// Hosts call this to reflect the user's sound preference.
    public func setSoundEnabled(_ enabled: Bool) {
        guard enabled != soundEnabled else { return }
        soundEnabled = enabled
        if enabled {
            soundSystem.start()
        } else {
            soundSystem.stop()
        }
    }

    override public func willMove(from view: SKView) {
        soundSystem.stop()
        runtime.save()
    }

    override public func keyDown(with event: NSEvent) {
        guard event.charactersIgnoringModifiers?.lowercased() == "d" else {
            super.keyDown(with: event)
            return
        }
        debugLabel.isHidden.toggle()
    }

    override public func update(_ currentTime: TimeInterval) {
        let wallTime = Date().timeIntervalSinceReferenceDate
        let wallDelta = lastWallTime == 0 ? 0 : wallTime - lastWallTime
        lastWallTime = wallTime

        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // A large gap means the view was paused or occluded; let the island
        // catch up on what it missed instead of freezing in place.
        if wallDelta > 1.5 {
            runtime.advanceSpan(by: min(wallDelta, 120))
        } else {
            _ = runtime.advance(by: delta)
        }

        let state = runtime.state
        render(state)
        tideLayer.update(world: state)
        presenceLayer.update(by: min(delta, 0.1), world: state)
        characterLifeLayer.update(by: min(delta, 0.1), world: state)
        if soundEnabled {
            soundSystem.update(world: state)
        }
    }

    override public func didChangeSize(_ oldSize: CGSize) {
        layoutWorld()
    }

    private func buildWorld() {
        sky.zPosition = -40
        addChild(sky)

        stars.zPosition = -35
        addChild(stars)
        buildStars()

        clouds.zPosition = -30
        addChild(clouds)
        buildClouds()

        ocean.fillColor = NSColor(calibratedRed: 0.09, green: 0.48, blue: 0.67, alpha: 1)
        ocean.strokeColor = .clear
        ocean.zPosition = -20
        addChild(ocean)

        farWaves.zPosition = -18
        addChild(farWaves)
        buildWaveBand(in: farWaves, count: 10, width: 92, alpha: 0.26)

        nearWaves.zPosition = -16
        addChild(nearWaves)
        buildWaveBand(in: nearWaves, count: 8, width: 125, alpha: 0.42)

        island.fillColor = NSColor(calibratedRed: 0.93, green: 0.74, blue: 0.43, alpha: 1)
        island.strokeColor = NSColor(calibratedWhite: 1, alpha: 0.25)
        island.lineWidth = 3
        island.zPosition = 0
        addChild(island)

        memoryLayer.zPosition = 1
        addChild(memoryLayer)
        buildMemoryTraces()

        buildPalm()
        palm.zPosition = 6
        addChild(palm)

        buildCampfire()
        campfire.zPosition = 8
        addChild(campfire)

        smokeLayer.zPosition = 14
        addChild(smokeLayer)

        debugLabel.fontSize = 13
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.fontColor = NSColor.white.withAlphaComponent(0.72)
        debugLabel.zPosition = 100
        debugLabel.isHidden = true
        addChild(debugLabel)

        layoutWorld()
        animateWaves()
        animatePalm()
        animateFire()
        animateClouds()
        beginSmoke()

        rodRack.zPosition = 5
        addChild(rodRack)

        rainLayer.zPosition = 135
        addChild(rainLayer)

        // Layer order mirrors the previous overlay stack: shore effects,
        // then visitors, then the articulated castaway on top.
        tideLayer.zPosition = 110
        presenceLayer.zPosition = 120
        characterLifeLayer.zPosition = 130
        addChild(tideLayer)
        addChild(presenceLayer)
        addChild(characterLifeLayer)
    }

    private func buildMemoryTraces() {
        pathWear.strokeColor = NSColor(calibratedRed: 0.60, green: 0.42, blue: 0.22, alpha: 1)
        pathWear.fillColor = .clear
        pathWear.lineCap = .round
        memoryLayer.addChild(pathWear)

        for node in [fishingWear, campfireWear, palmWear] {
            node.fillColor = NSColor(calibratedRed: 0.60, green: 0.42, blue: 0.22, alpha: 1)
            node.strokeColor = .clear
            memoryLayer.addChild(node)
        }

        buildRodRack()
        buildRain()
    }

    /// Rain streaks recycled by a loop action; intensity is driven entirely
    /// by `WorldState.rain`.
    private func buildRain() {
        rainLayer.isHidden = true

        for index in 0..<70 {
            let streak = SKShapeNode(rectOf: CGSize(width: 1.5, height: 15), cornerRadius: 0.75)
            streak.fillColor = NSColor.white.withAlphaComponent(0.32)
            streak.strokeColor = .clear
            streak.zRotation = -0.12

            let fallDistance = size.height * 0.85
            let duration = 0.55 + Double(index % 5) * 0.09
            let drift = -fallDistance * 0.18
            let startX = size.width * (CGFloat(index % 11) / 11 - 0.5)
            let startY = size.height * 0.45 + CGFloat(index % 7) * 22
            streak.position = CGPoint(x: startX, y: startY)

            streak.run(.repeatForever(.sequence([
                .moveBy(x: drift, y: -fallDistance, duration: duration),
                .run { [weak self, weak streak] in
                    guard let self, let streak else { return }
                    streak.position = CGPoint(
                        x: self.size.width * (CGFloat.random(in: 0...1) - 0.5),
                        y: self.size.height * 0.45
                    )
                }
            ])))

            rainLayer.addChild(streak)
        }
    }

    /// A rack of hand-cut fishing rods appears as fishing becomes habit.
    private func buildRodRack() {
        rodRack.isHidden = true

        let wood = NSColor(calibratedRed: 0.36, green: 0.21, blue: 0.09, alpha: 1)

        let post = SKShapeNode(rectOf: CGSize(width: 7, height: 44), cornerRadius: 3)
        post.fillColor = wood
        post.strokeColor = .clear
        post.position.y = 22
        rodRack.addChild(post)

        let bar = SKShapeNode(rectOf: CGSize(width: 46, height: 6), cornerRadius: 3)
        bar.fillColor = wood
        bar.strokeColor = .clear
        bar.position.y = 38
        rodRack.addChild(bar)

        for index in 0..<3 {
            let rod = SKShapeNode(rectOf: CGSize(width: 4, height: 52), cornerRadius: 2)
            rod.fillColor = NSColor(calibratedRed: 0.48, green: 0.30, blue: 0.13, alpha: 1)
            rod.strokeColor = .clear
            rod.position = CGPoint(x: CGFloat(index * 13 - 13), y: 30)
            rod.zRotation = CGFloat(index - 1) * 0.10 + 0.06
            rod.name = "rack-rod-\(index)"
            rod.isHidden = true
            rodRack.addChild(rod)
        }
    }

    private func layoutWorld() {
        sky.size = size

        let oceanRect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height * 0.49
        )
        ocean.path = CGPath(rect: oceanRect, transform: nil)

        let islandRect = CGRect(
            x: -size.width * 0.29,
            y: -size.height * 0.23,
            width: size.width * 0.58,
            height: size.height * 0.24
        )
        island.path = CGPath(ellipseIn: islandRect, transform: nil)

        farWaves.position = CGPoint(x: 0, y: -size.height * 0.12)
        nearWaves.position = CGPoint(x: 0, y: -size.height * 0.36)
        palm.position = CGPoint(x: size.width * 0.17, y: -size.height * 0.02)
        campfire.position = CGPoint(
            x: islandX(SimulationEngine.campfireX),
            y: -size.height * 0.12
        )
        smokeLayer.position = campfire.position
        rodRack.position = CGPoint(x: islandX(0.56), y: -size.height * 0.10)
        debugLabel.position = CGPoint(x: -size.width / 2 + 18, y: size.height / 2 - 18)

        let fishingX = islandX(SimulationEngine.fishingSpotX)
        let fireX = islandX(SimulationEngine.campfireX)
        let palmX = -size.width * 0.29 + size.width * 0.58 * 0.72
        let sandY = -size.height * 0.10

        let path = CGMutablePath()
        path.move(to: CGPoint(x: fishingX, y: sandY - 4))
        path.addCurve(
            to: CGPoint(x: palmX, y: sandY + 2),
            control1: CGPoint(x: -size.width * 0.08, y: sandY - 22),
            control2: CGPoint(x: size.width * 0.08, y: sandY + 18)
        )
        pathWear.path = path
        pathWear.lineWidth = max(8, size.height * 0.018)

        fishingWear.path = CGPath(
            ellipseIn: CGRect(x: fishingX - 38, y: sandY - 16, width: 76, height: 28),
            transform: nil
        )
        campfireWear.path = CGPath(
            ellipseIn: CGRect(x: fireX - 62, y: sandY - 22, width: 124, height: 40),
            transform: nil
        )
        palmWear.path = CGPath(
            ellipseIn: CGRect(x: palmX - 58, y: sandY - 20, width: 116, height: 36),
            transform: nil
        )
    }

    private func buildStars() {
        for index in 0..<34 {
            let radius = CGFloat(1 + (index % 3)) * 0.65
            let star = SKShapeNode(circleOfRadius: radius)
            star.fillColor = NSColor.white.withAlphaComponent(0.45 + CGFloat(index % 4) * 0.12)
            star.strokeColor = .clear
            let x = CGFloat((index * 83) % 1000) / 1000 - 0.5
            let y = CGFloat((index * 47) % 360) / 720 + 0.08
            star.position = CGPoint(x: x * size.width, y: y * size.height)
            stars.addChild(star)
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.28, duration: 1.2 + Double(index % 4) * 0.4),
                .fadeAlpha(to: 0.95, duration: 1.2 + Double(index % 3) * 0.5)
            ])))
        }
        stars.alpha = 0
    }

    private func buildClouds() {
        for index in 0..<3 {
            let cloud = makeCloud(scale: 0.72 + CGFloat(index) * 0.18)
            cloud.name = "cloud-\(index)"
            cloud.position = CGPoint(
                x: -size.width * 0.55 + CGFloat(index) * size.width * 0.4,
                y: size.height * (0.18 + CGFloat(index % 2) * 0.12)
            )
            cloud.alpha = 0.76
            clouds.addChild(cloud)
        }
    }

    private func makeCloud(scale: CGFloat) -> SKNode {
        let cloud = SKNode()
        let pieces: [(CGPoint, CGSize)] = [
            (CGPoint(x: -34, y: 0), CGSize(width: 58, height: 30)),
            (CGPoint(x: 0, y: 12), CGSize(width: 72, height: 44)),
            (CGPoint(x: 39, y: 1), CGSize(width: 62, height: 32))
        ]

        for (position, cloudSize) in pieces {
            let puff = SKShapeNode(ellipseOf: cloudSize)
            puff.fillColor = NSColor.white.withAlphaComponent(0.84)
            puff.strokeColor = .clear
            puff.position = position
            cloud.addChild(puff)
        }
        cloud.setScale(scale)
        return cloud
    }

    private func buildWaveBand(in node: SKNode, count: Int, width: CGFloat, alpha: CGFloat) {
        for index in 0..<count {
            let wave = SKShapeNode(rectOf: CGSize(width: width, height: 3), cornerRadius: 1.5)
            wave.fillColor = NSColor.white.withAlphaComponent(alpha)
            wave.strokeColor = .clear
            wave.position.x = -size.width * 0.55 + CGFloat(index) * size.width / CGFloat(max(count - 1, 1))
            wave.position.y = CGFloat((index % 3) * 11)
            node.addChild(wave)
        }
    }

    private func buildPalm() {
        let trunk = SKShapeNode(rectOf: CGSize(width: 20, height: 150), cornerRadius: 9)
        trunk.fillColor = NSColor(calibratedRed: 0.43, green: 0.25, blue: 0.11, alpha: 1)
        trunk.strokeColor = .clear
        trunk.position.y = 72
        trunk.zRotation = -0.09
        palm.addChild(trunk)

        palmCrown.position.y = 150
        palm.addChild(palmCrown)

        for angle in stride(from: 0.0, to: 360.0, by: 60.0) {
            let leaf = SKShapeNode(ellipseOf: CGSize(width: 115, height: 28))
            leaf.fillColor = NSColor(calibratedRed: 0.14, green: 0.52, blue: 0.24, alpha: 1)
            leaf.strokeColor = .clear
            leaf.zRotation = angle * .pi / 180
            leaf.position.x = cos(leaf.zRotation) * 35
            leaf.position.y = sin(leaf.zRotation) * 16
            palmCrown.addChild(leaf)
        }
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

    private func animateWaves() {
        farWaves.run(.repeatForever(.sequence([
            .moveBy(x: 24, y: 0, duration: 3.8),
            .moveBy(x: -24, y: 0, duration: 3.8)
        ])))
        nearWaves.run(.repeatForever(.sequence([
            .moveBy(x: -36, y: 0, duration: 2.7),
            .moveBy(x: 36, y: 0, duration: 2.7)
        ])))
    }

    private func animateClouds() {
        for (index, cloud) in clouds.children.enumerated() {
            let distance = size.width * (1.25 + CGFloat(index) * 0.15)
            let duration = 48.0 + Double(index) * 17.0
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: distance, y: 0, duration: duration),
                .run { [weak self, weak cloud] in
                    guard let self, let cloud else { return }
                    cloud.position.x = -self.size.width * 0.65
                }
            ])))
        }
    }

    private func animatePalm() {
        palmCrown.run(.repeatForever(.sequence([
            .rotate(toAngle: -0.035, duration: 2.6, shortestUnitArc: true),
            .rotate(toAngle: 0.035, duration: 2.6, shortestUnitArc: true)
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

    private func beginSmoke() {
        smokeLayer.run(.repeatForever(.sequence([
            .run { [weak self] in self?.spawnSmokePuff() },
            .wait(forDuration: 1.25)
        ])))
    }

    private func spawnSmokePuff() {
        let puff = SKShapeNode(circleOfRadius: 8)
        puff.fillColor = NSColor(calibratedWhite: 0.72, alpha: 0.34)
        puff.strokeColor = .clear
        puff.position = CGPoint(x: 0, y: 52)
        smokeLayer.addChild(puff)

        let drift = 8 + currentWind * 48
        puff.run(.sequence([
            .group([
                .moveBy(x: drift, y: 72, duration: 3.2),
                .scale(to: 2.1, duration: 3.2),
                .fadeOut(withDuration: 3.2)
            ]),
            .removeFromParent()
        ]))
    }

    private func render(_ state: WorldState) {
        currentWind = state.wind
        sky.color = skyColor(for: state.dayPhase)
        ocean.fillColor = oceanColor(for: state.dayPhase)
        stars.run(.fadeAlpha(to: state.dayPhase == .night ? 1 : 0, duration: 1.4))

        let daytimeCloudAlpha = 0.35 + state.cloudCover * 0.55
        clouds.alpha = state.dayPhase == .night ? daytimeCloudAlpha * 0.42 : daytimeCloudAlpha
        clouds.speed = CGFloat(0.55 + state.wind * 1.6)
        farWaves.speed = CGFloat(0.72 + state.wind * 1.1)
        nearWaves.speed = CGFloat(0.78 + state.wind * 1.4)
        palmCrown.speed = CGFloat(0.65 + state.wind * 1.7)

        campfire.alpha = state.dayPhase == .day ? 0.72 : 1
        smokeLayer.alpha = state.dayPhase == .day ? 0.55 : 0.8

        pathWear.alpha = CGFloat(state.memory.pathWear * 0.23)
        fishingWear.alpha = CGFloat(state.memory.fishingSpotWear * 0.30)
        campfireWear.alpha = CGFloat(state.memory.campfireWear * 0.24)
        palmWear.alpha = CGFloat(state.memory.palmShadeWear * 0.22)

        renderRodRack(trips: state.memory.fishingTrips)

        let rainAlpha = CGFloat(state.rain)
        rainLayer.isHidden = rainAlpha < 0.02
        rainLayer.alpha = rainAlpha
        rainLayer.speed = CGFloat(0.7 + state.rain * 0.6)
        rainLayer.zRotation = CGFloat(-state.wind) * 0.14

        debugLabel.text = "Idle Isle • \(state.debugSummary) • Fish \(state.memory.fishingTrips) • Sleeps \(state.memory.nightsSlept)"

        if state.ambientEvent != lastAmbientEvent {
            lastAmbientEvent = state.ambientEvent
            playAmbientEvent(state.ambientEvent, memory: state.memory)
        }
    }

    /// Rods accumulate slowly: one after five trips, then every seven more.
    private func renderRodRack(trips: Int) {
        guard trips >= 5 else {
            rodRack.isHidden = true
            return
        }

        rodRack.isHidden = false
        let targetAlpha: CGFloat = 0.85
        rodRack.alpha = min(targetAlpha, rodRack.alpha + 0.01)

        for (index, rod) in rodRack.children.enumerated() where rod.name?.hasPrefix("rack-rod-") == true {
            let threshold = 5 + index * 7
            if rod.isHidden && trips >= threshold {
                rod.isHidden = false
                rod.setScale(0.6)
                rod.run(.group([
                    .scale(to: 1, duration: 0.8),
                    .fadeAlpha(to: 1, duration: 0.8)
                ]))
            }
        }
    }

    private func playAmbientEvent(_ event: WorldState.AmbientEvent, memory: WorldState.Memory) {
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
            coconut.run(.sequence([
                .moveBy(x: -18, y: -148, duration: 0.8),
                .wait(forDuration: 1.2),
                .fadeOut(withDuration: 0.5),
                .removeFromParent()
            ]))

        // Retired events stay decodable for older world saves but have no
        // presentation anymore.
        case .crabVisits:
            break

        case .shootingStar:
            let star = SKShapeNode(rectOf: CGSize(width: 70, height: 3), cornerRadius: 2)
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(x: size.width * 0.25, y: size.height * 0.34)
            star.zRotation = -0.55
            star.zPosition = 25
            addChild(star)
            star.run(.sequence([
                .group([.moveBy(x: -180, y: -110, duration: 0.65), .fadeOut(withDuration: 0.65)]),
                .removeFromParent()
            ]))
        }
    }

    /// Converts a normalized island X (0...1) into scene coordinates.
    private func islandX(_ normalizedX: Double) -> CGFloat {
        -size.width * 0.29 + CGFloat(normalizedX) * size.width * 0.58
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