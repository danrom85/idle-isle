import IdleEngine
import AppKit
import SpriteKit

public final class IslandScene: SKScene {
    private let runtime: WorldRuntime
    private var lastUpdateTime: TimeInterval = 0
    private var lastWallTime: TimeInterval = 0
    private var lastAmbientEvent: WorldState.AmbientEvent = .none
    private var whaleVisitCount = 0
    private var currentWind: Double = 0.22

    private let sky = SKSpriteNode(texture: nil, size: .zero)
    private var skyTextures: [WorldState.DayPhase: SKTexture] = [:]
    private let celestial = SKNode()
    private let sun = SKNode()
    private let moon = SKNode()
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
    private let fireflyLayer = SKNode()

    private let palm = SKNode()
    private let palmCrown = SKNode()
    private let campfire = SKNode()
    // Flame and smoke draw above the castaway so standing at the fire
    // reads as being behind it, not on top of it.
    private let fireFront = SKNode()
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

        buildCelestials()

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

        buildBeachDetail()

        memoryLayer.zPosition = 1
        addChild(memoryLayer)
        buildMemoryTraces()

        buildPalm()
        palm.zPosition = 6
        addChild(palm)

        buildCampfire()
        campfire.zPosition = 8
        addChild(campfire)

        buildFireFront()

        smokeLayer.zPosition = 1
        fireFront.addChild(smokeLayer)

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

        fireflyLayer.zPosition = 100
        addChild(fireflyLayer)

        buildVignette()

        // Layer order mirrors the previous overlay stack: shore effects,
        // then visitors, then the articulated castaway on top.
        tideLayer.zPosition = 110
        presenceLayer.zPosition = 120
        characterLifeLayer.zPosition = 130
        addChild(tideLayer)
        addChild(presenceLayer)
        addChild(characterLifeLayer)
    }

    /// Small touches that make the island feel lived-on rather than drawn-on.
    private func buildBeachDetail() {
        let detail = SKNode()
        detail.zPosition = 0.5
        addChild(detail)

        // A lighter sweep of dry sand along the top of the island.
        let sandHighlight = SKShapeNode(ellipseOf: CGSize(width: size.width * 0.50, height: size.height * 0.15))
        sandHighlight.fillColor = NSColor(calibratedRed: 0.97, green: 0.81, blue: 0.52, alpha: 0.55)
        sandHighlight.strokeColor = .clear
        sandHighlight.position = CGPoint(x: -size.width * 0.03, y: -size.height * 0.155)
        detail.addChild(sandHighlight)

        // A few weathered rocks along the shore.
        let rocks: [(CGPoint, CGSize)] = [
            (CGPoint(x: -size.width * 0.26, y: -size.height * 0.16), CGSize(width: 26, height: 16)),
            (CGPoint(x: size.width * 0.24, y: -size.height * 0.19), CGSize(width: 34, height: 20)),
            (CGPoint(x: size.width * 0.27, y: -size.height * 0.14), CGSize(width: 18, height: 12))
        ]
        for (position, rockSize) in rocks {
            let rock = SKShapeNode(ellipseOf: rockSize)
            rock.fillColor = NSColor(calibratedRed: 0.52, green: 0.51, blue: 0.49, alpha: 1)
            rock.strokeColor = NSColor.black.withAlphaComponent(0.15)
            rock.lineWidth = 1
            rock.position = position
            rock.zRotation = .pi / (3 + CGFloat.random(in: 0...2))
            detail.addChild(rock)
        }

        // Tufts of dune grass scattered near the palm.
        let grassXs: [CGFloat] = [-0.05, 0.02, 0.10, 0.14]
        for (index, fraction) in grassXs.enumerated() {
            let tuft = SKNode()
            tuft.position = CGPoint(
                x: size.width * fraction,
                y: -size.height * (0.115 + CGFloat(index % 2) * 0.015)
            )
            for bladeIndex in 0..<5 {
                let blade = SKShapeNode(rectOf: CGSize(width: 2.5, height: CGFloat(14 + (bladeIndex + index) % 4 * 5)), cornerRadius: 1)
                blade.fillColor = NSColor(calibratedRed: 0.24, green: 0.52, blue: 0.26, alpha: 0.9)
                blade.strokeColor = .clear
                blade.position.y = 7
                blade.zRotation = CGFloat(bladeIndex - 2) * 0.16
                tuft.addChild(blade)
            }
            detail.addChild(tuft)
        }
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
        buildFireflies()
    }

    /// Fireflies drift through warm nights; the layer fades with the
    /// day phase, wind, and rain in render(_:).
    private func buildFireflies() {
        fireflyLayer.alpha = 0

        for index in 0..<10 {
            let fly = SKShapeNode(circleOfRadius: 1.8)
            fly.fillColor = NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.55, alpha: 1)
            fly.strokeColor = .clear
            fly.glowWidth = 2.5
            fly.position = CGPoint(
                x: size.width * (CGFloat(index % 5) / 5 - 0.5) + CGFloat((index % 3) * 17),
                y: -size.height * 0.02 + CGFloat((index % 4) * 14)
            )

            let wanderX = CGFloat(18 + (index % 3) * 9) * (index % 2 == 0 ? 1 : -1)
            let wanderY = CGFloat(10 + (index % 4) * 5)
            fly.run(.repeatForever(.sequence([
                .moveBy(x: wanderX, y: wanderY, duration: 2.6 + Double(index % 3) * 0.7),
                .moveBy(x: -wanderX, y: -wanderY, duration: 2.6 + Double(index % 3) * 0.7)
            ])))
            fly.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.15, duration: 0.7 + Double(index % 4) * 0.3),
                .fadeAlpha(to: 0.95, duration: 0.7 + Double(index % 3) * 0.25)
            ])))

            fireflyLayer.addChild(fly)
        }
    }

    /// A subtle radial darkening at the frame edges focuses the eye on the
    /// island without reading as an effect.
    private func buildVignette() {
        let width = 64, height = 36
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let colors = [
            NSColor.black.withAlphaComponent(0).cgColor,
            NSColor.black.withAlphaComponent(0).cgColor,
            NSColor.black.withAlphaComponent(0.34).cgColor
        ] as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 0.62, 1]
        )!
        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: width / 2, y: height / 2), startRadius: 0,
            endCenter: CGPoint(x: width / 2, y: height / 2), endRadius: CGFloat(width) * 0.72,
            options: []
        )

        let vignette = SKSpriteNode(texture: SKTexture(cgImage: context.makeImage()!))
        vignette.size = size
        vignette.zPosition = 150
        addChild(vignette)
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
        celestial.position = CGPoint(x: 0, y: 0)

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
        fireFront.position = campfire.position
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

        // A soft gray-blue belly gives the puffs volume.
        let belly = SKShapeNode(ellipseOf: CGSize(width: 150, height: 34))
        belly.fillColor = NSColor(calibratedRed: 0.55, green: 0.62, blue: 0.74, alpha: 0.55)
        belly.strokeColor = .clear
        belly.position = CGPoint(x: 2, y: -10)
        cloud.addChild(belly)

        for (position, cloudSize) in pieces {
            let puff = SKShapeNode(ellipseOf: cloudSize)
            puff.fillColor = NSColor.white.withAlphaComponent(0.88)
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
        // Trunk: stacked segments leaning into a gentle curve.
        let trunkLight = NSColor(calibratedRed: 0.49, green: 0.31, blue: 0.15, alpha: 1)
        let trunkDark = NSColor(calibratedRed: 0.38, green: 0.23, blue: 0.11, alpha: 1)

        for index in 0..<6 {
            let segment = SKShapeNode(rectOf: CGSize(width: 17 - CGFloat(index), height: 30), cornerRadius: 7)
            segment.fillColor = index % 2 == 0 ? trunkDark : trunkLight
            segment.strokeColor = NSColor.black.withAlphaComponent(0.12)
            segment.lineWidth = 1
            segment.position.y = 12 + CGFloat(index) * 26
            // Lean increases toward the crown.
            segment.position.x = -CGFloat(index) * CGFloat(index) * 1.6
            segment.zRotation = -0.05 - CGFloat(index) * 0.02
            palm.addChild(segment)
        }

        palmCrown.position = CGPoint(x: -40, y: 152)
        palm.addChild(palmCrown)

        // Coconuts tucked under the crown.
        for offset in [CGPoint(x: -10, y: -8), CGPoint(x: 4, y: -12), CGPoint(x: -2, y: -18)] {
            let coconut = SKShapeNode(circleOfRadius: 7)
            coconut.fillColor = NSColor(calibratedRed: 0.33, green: 0.20, blue: 0.10, alpha: 1)
            coconut.strokeColor = .clear
            coconut.position = offset
            palmCrown.addChild(coconut)
        }

        // Fronds: elongated leaves that droop outward, each with a center rib.
        let angles: [Double] = [15, 55, 100, 145, 195, 250, 300, 345]
        for (index, angleDegrees) in angles.enumerated() {
            let angle = angleDegrees * .pi / 180
            let drooping = sin(angle) < 0

            let frond = SKNode()
            frond.zRotation = angle

            let length = CGFloat(95 + index % 3 * 14)
            let blade = SKShapeNode(ellipseOf: CGSize(width: length, height: 20))
            blade.fillColor = NSColor(
                calibratedRed: 0.10 + CGFloat(index % 3) * 0.03,
                green: 0.44 + CGFloat(index % 2) * 0.06,
                blue: 0.19,
                alpha: 1
            )
            blade.strokeColor = .clear
            // Shift the blade so it grows outward from the crown.
            blade.position.x = length / 2 + 14
            if drooping { blade.position.y -= 6 }
            frond.addChild(blade)

            let rib = SKShapeNode(rectOf: CGSize(width: length * 0.85, height: 2.5), cornerRadius: 1)
            rib.fillColor = NSColor(calibratedRed: 0.07, green: 0.30, blue: 0.13, alpha: 1)
            rib.strokeColor = .clear
            rib.position.x = length / 2 + 14
            frond.addChild(rib)

            palmCrown.addChild(frond)
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

    }

    /// The animated flame lives in its own overlay node so it can render in
    /// front of the castaway while the log base stays behind him.
    private func buildFireFront() {
        fireFront.zPosition = 132
        addChild(fireFront)

        // Warm light pooling on the sand beneath the flames.
        let glow = SKShapeNode(ellipseOf: CGSize(width: 92, height: 26))
        glow.name = "fireGlow"
        glow.fillColor = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.18, alpha: 0.22)
        glow.strokeColor = .clear
        glow.position.y = 4
        fireFront.addChild(glow)

        let outerFlame = SKShapeNode(ellipseOf: CGSize(width: 30, height: 52))
        outerFlame.name = "flame"
        outerFlame.fillColor = NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.10, alpha: 0.96)
        outerFlame.strokeColor = .clear
        outerFlame.position.y = 30
        fireFront.addChild(outerFlame)

        let innerFlame = SKShapeNode(ellipseOf: CGSize(width: 16, height: 32))
        innerFlame.name = "flameInner"
        innerFlame.fillColor = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.32, alpha: 0.95)
        innerFlame.strokeColor = .clear
        innerFlame.position.y = 24
        fireFront.addChild(innerFlame)
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
        guard let flame = fireFront.childNode(withName: "flame") else { return }
        flame.run(.repeatForever(.sequence([
            .scaleY(to: 0.78, duration: 0.22),
            .scaleY(to: 1.08, duration: 0.27),
            .scaleY(to: 0.92, duration: 0.18)
        ])))

        if let inner = fireFront.childNode(withName: "flameInner") {
            inner.run(.repeatForever(.sequence([
                .scaleY(to: 1.14, duration: 0.19),
                .scaleY(to: 0.82, duration: 0.24),
                .scaleY(to: 1.05, duration: 0.16)
            ])))
        }

        fireFront.childNode(withName: "fireGlow")?.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 0.9),
            .fadeAlpha(to: 1.0, duration: 1.1)
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
        sky.texture = skyTexture(for: state.dayPhase)
        ocean.fillColor = oceanColor(for: state.dayPhase)
        positionCelestials(hour: state.simulatedHour)
        stars.run(.fadeAlpha(to: state.dayPhase == .night ? 1 : 0, duration: 1.4))

        let daytimeCloudAlpha = 0.35 + state.cloudCover * 0.55
        clouds.alpha = state.dayPhase == .night ? daytimeCloudAlpha * 0.42 : daytimeCloudAlpha
        clouds.speed = CGFloat(0.55 + state.wind * 1.6)
        farWaves.speed = CGFloat(0.72 + state.wind * 1.1)
        nearWaves.speed = CGFloat(0.78 + state.wind * 1.4)
        palmCrown.speed = CGFloat(0.65 + state.wind * 1.7)

        campfire.alpha = state.dayPhase == .day ? 0.72 : 1
        fireFront.alpha = state.dayPhase == .day ? 0.85 : 1
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

        let fireflyTarget: Double = (state.dayPhase == .night && state.wind < 0.55 && state.rain < 0.3) ? 0.9 : 0
        let current = Double(fireflyLayer.alpha)
        fireflyLayer.alpha = CGFloat(current + (fireflyTarget - current) * 0.012)
        fireflyLayer.isHidden = fireflyLayer.alpha < 0.02
        fireflyLayer.speed = CGFloat(0.6 + state.wind * 0.5)

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

        case .whaleSpout:
            whaleVisitCount += 1
            let lane = Double(whaleVisitCount % 3) - 1
            let spoutX = size.width * CGFloat(0.05 + lane * 0.06)

            // A dark back glides past first.
            let back = SKShapeNode(ellipseOf: CGSize(width: 90, height: 16))
            back.fillColor = NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.22, alpha: 0.85)
            back.strokeColor = .clear
            back.position = CGPoint(x: spoutX, y: -size.height * 0.155)
            back.zPosition = 18
            addChild(back)

            // Then the spout rises twice.
            for burst in 0..<2 {
                let puff = SKShapeNode(ellipseOf: CGSize(width: 14, height: 20))
                puff.fillColor = NSColor.white.withAlphaComponent(0.75)
                puff.strokeColor = .clear
                puff.position = CGPoint(x: spoutX, y: -size.height * 0.148)
                puff.zPosition = 19
                puff.alpha = 0
                addChild(puff)

                let delay = SKAction.wait(forDuration: 0.7 + Double(burst) * 1.3)
                puff.run(.sequence([
                    delay,
                    .group([
                        .moveBy(x: -6, y: 34, duration: 0.5),
                        .fadeAlpha(to: 0.8, duration: 0.18),
                        .scaleY(to: 2.2, duration: 0.5)
                    ]),
                    .group([
                        .moveBy(x: 4, y: 10, duration: 0.6),
                        .fadeOut(withDuration: 0.6)
                    ]),
                    .removeFromParent()
                ]))
            }

            back.run(.sequence([
                .wait(forDuration: 2.6),
                .group([
                    .moveBy(x: -70, y: -4, duration: 1.6),
                    .fadeOut(withDuration: 1.6)
                ]),
                .removeFromParent()
            ]))

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

    // MARK: - Sky light

    /// Vertical gradient per phase, rendered once into a small texture and
    /// stretched across the sky.
    private func skyTexture(for phase: WorldState.DayPhase) -> SKTexture {
        if let cached = skyTextures[phase] { return cached }

        let palette: (NSColor, NSColor)
        switch phase {
        case .dawn: palette = (NSColor(calibratedRed: 0.72, green: 0.44, blue: 0.48, alpha: 1), NSColor(calibratedRed: 0.99, green: 0.72, blue: 0.52, alpha: 1))
        case .day: palette = (NSColor(calibratedRed: 0.22, green: 0.55, blue: 0.88, alpha: 1), NSColor(calibratedRed: 0.62, green: 0.84, blue: 0.96, alpha: 1))
        case .sunset: palette = (NSColor(calibratedRed: 0.28, green: 0.24, blue: 0.46, alpha: 1), NSColor(calibratedRed: 0.96, green: 0.52, blue: 0.36, alpha: 1))
        case .night: palette = (NSColor(calibratedRed: 0.015, green: 0.045, blue: 0.12, alpha: 1), NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.30, alpha: 1))
        }

        let width = 4
        let height = 256
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let colors = [palette.0.cgColor, palette.1.cgColor] as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors, locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: CGFloat(height)),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
        let texture = SKTexture(cgImage: context.makeImage()!)
        skyTextures[phase] = texture
        return texture
    }

    private func buildCelestials() {
        celestial.zPosition = -38
        addChild(celestial)

        // Sun: warm disc with a soft halo.
        let sunHalo = SKShapeNode(circleOfRadius: 44)
        sunHalo.fillColor = NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.55, alpha: 0.16)
        sunHalo.strokeColor = .clear
        sun.addChild(sunHalo)

        let sunDisc = SKShapeNode(circleOfRadius: 24)
        sunDisc.fillColor = NSColor(calibratedRed: 1.0, green: 0.93, blue: 0.62, alpha: 1)
        sunDisc.strokeColor = NSColor.white.withAlphaComponent(0.35)
        sunDisc.lineWidth = 2
        sun.addChild(sunDisc)

        // Moon: pale disc with a few craters.
        let moonDisc = SKShapeNode(circleOfRadius: 19)
        moonDisc.fillColor = NSColor(calibratedRed: 0.86, green: 0.89, blue: 0.95, alpha: 1)
        moonDisc.strokeColor = NSColor.white.withAlphaComponent(0.25)
        moonDisc.lineWidth = 1.5
        moon.addChild(moonDisc)

        for (offset, radius) in [(CGPoint(x: -6, y: 4), 3.4), (CGPoint(x: 5, y: -3), 2.6), (CGPoint(x: 1, y: 8), 1.8)] {
            let crater = SKShapeNode(circleOfRadius: radius)
            crater.fillColor = NSColor(calibratedRed: 0.72, green: 0.76, blue: 0.84, alpha: 1)
            crater.strokeColor = .clear
            crater.position = offset
            moon.addChild(crater)
        }

        celestial.addChild(sun)
        celestial.addChild(moon)
    }

    /// The sun rides a shallow arc from dawn to dusk; the moon owns the night.
    private func positionCelestials(hour: Double) {
        func arcPosition(_ progress: Double) -> CGPoint {
            let clamped = max(0, min(1, progress))
            let x = size.width * (CGFloat(clamped) * 0.9 - 0.45)
            let height = sin(clamped * .pi)
            let y = size.height * (0.08 + CGFloat(height) * 0.34) - size.height * 0.02
            return CGPoint(x: x, y: y)
        }

        let sunProgress = (hour - 5) / 14
        let sunVisible = hour >= 5 && hour <= 19
        sun.position = arcPosition(sunProgress)
        sun.alpha = sunVisible ? CGFloat(min(1, sin(max(0, min(1, sunProgress)) * .pi) * 2)) : 0

        let nightHour = hour >= 19 ? hour - 19 : hour + 5
        let moonProgress = nightHour / 10
        let moonVisible = hour >= 19 || hour < 5
        moon.position = arcPosition(moonProgress)
        moon.alpha = moonVisible ? 1 : 0
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