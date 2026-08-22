import AVFoundation

import IdleEngine

/// Procedural ambience for the island.
///
/// Two looping buffers are synthesized at startup, so the project ships no
/// audio assets: filtered noise surf whose level breathes with the tide and
/// wind, and campfire crackle that fades with the castaway's distance from
/// the fire.
final class SoundSystem {
    private let engine = AVAudioEngine()
    private let surfPlayer = AVAudioPlayerNode()
    private let firePlayer = AVAudioPlayerNode()
    private let rainPlayer = AVAudioPlayerNode()
    private let surfMixer = AVAudioMixerNode()
    private let fireMixer = AVAudioMixerNode()
    private let rainMixer = AVAudioMixerNode()

    private let sampleRate: Double = 44_100
    private var started = false

    func start() {
        guard !started else { return }

        engine.attach(surfPlayer)
        engine.attach(firePlayer)
        engine.attach(rainPlayer)
        engine.attach(surfMixer)
        engine.attach(fireMixer)
        engine.attach(rainMixer)

        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else { return }

        engine.connect(surfPlayer, to: surfMixer, format: format)
        engine.connect(firePlayer, to: fireMixer, format: format)
        engine.connect(rainPlayer, to: rainMixer, format: format)
        engine.connect(surfMixer, to: engine.mainMixerNode, format: format)
        engine.connect(fireMixer, to: engine.mainMixerNode, format: format)
        engine.connect(rainMixer, to: engine.mainMixerNode, format: format)

        surfPlayer.volume = 0
        firePlayer.volume = 0
        rainPlayer.volume = 0

        do {
            engine.prepare()
            try engine.start()
        } catch {
            return
        }

        surfPlayer.scheduleBuffer(makeSurfBuffer(), at: nil, options: [.loops])
        firePlayer.scheduleBuffer(makeFireBuffer(), at: nil, options: [.loops])
        rainPlayer.scheduleBuffer(makeRainBuffer(), at: nil, options: [.loops])
        surfPlayer.play()
        firePlayer.play()
        rainPlayer.play()
        started = true
    }

    func stop() {
        guard started else { return }
        engine.stop()
        started = false
    }

    /// Nudges ambience toward the current world conditions. Per-frame
    /// smoothing keeps the changes gentle rather than stepped.
    func update(world: WorldState) {
        guard started else { return }

        let surfTarget = Float(min(0.32, 0.08 + 0.10 * world.tideLevel + 0.08 * world.wind))
        surfPlayer.volume += (surfTarget - surfPlayer.volume) * 0.02

        let distance = abs(world.characterX - SimulationEngine.campfireX)
        let fireTarget = Float(max(0, 0.16 * (1 - distance / 0.20)))
        firePlayer.volume += (fireTarget - firePlayer.volume) * 0.02

        let rainTarget = Float(world.rain * 0.13)
        rainPlayer.volume += (rainTarget - rainPlayer.volume) * 0.02
    }

    // MARK: - Buffer synthesis

    /// Low-passed noise with a baked-in swell whose period divides the loop
    /// length exactly, so the surf breathes seamlessly.
    private func makeSurfBuffer() -> AVAudioPCMBuffer {
        let duration = 6.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        let samples = buffer.floatChannelData![0]

        var last: Float = 0
        var generator = SeededGenerator(seed: 0x53555246)
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let white = Float(generator.unitInterval()) * 2 - 1
            last += 0.055 * (white - last)
            let swell = 0.55 + 0.45 * sin(t * 2 * .pi / 3.0)
            samples[i] = last * Float(swell)
        }

        crossfadeLoopHead(samples, frameCount: Int(frameCount))
        buffer.frameLength = frameCount
        return buffer
    }

    /// Mostly-silent bed with short noise pops: the sound of burning wood.
    private func makeFireBuffer() -> AVAudioPCMBuffer {
        let duration = 5.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        let samples = buffer.floatChannelData![0]

        var generator = SeededGenerator(seed: 0x46495245)
        for i in 0..<Int(frameCount) {
            let white = Float(generator.unitInterval()) * 2 - 1
            samples[i] = white * 0.012
        }

        for _ in 0..<16 {
            let popLength = Int(sampleRate * (0.004 + generator.unitInterval() * 0.018))
            let start = Int(generator.unitInterval() * Double(Int(frameCount) - popLength))
            let amplitude = Float(0.18 + generator.unitInterval() * 0.55)

            for j in 0..<popLength {
                let envelope = exp(-Float(j) / (Float(popLength) / 3))
                let white = Float(generator.unitInterval()) * 2 - 1
                samples[start + j] += white * envelope * amplitude
            }
        }

        crossfadeLoopHead(samples, frameCount: Int(frameCount))
        buffer.frameLength = frameCount
        return buffer
    }

    /// Steady, brighter hiss than the surf: rain on water and sand.
    private func makeRainBuffer() -> AVAudioPCMBuffer {
        let duration = 4.0
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        let samples = buffer.floatChannelData![0]

        var last: Float = 0
        var generator = SeededGenerator(seed: 0x5241494E)
        for i in 0..<Int(frameCount) {
            let white = Float(generator.unitInterval()) * 2 - 1
            last += 0.30 * (white - last)
            samples[i] = last
        }

        crossfadeLoopHead(samples, frameCount: Int(frameCount))
        buffer.frameLength = frameCount
        return buffer
    }

    /// Blends the loop tail into the head so neither buffer clicks on repeat.
    private func crossfadeLoopHead(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        let fadeLength = min(2_000, frameCount / 4)
        for i in 0..<fadeLength {
            let blend = Float(i) / Float(fadeLength)
            samples[i] = samples[i] * blend + samples[frameCount - fadeLength + i] * (1 - blend)
        }
    }
}
