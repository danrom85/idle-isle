# First Breath

The first Idle Isle milestone proves one thing: the island can feel alive before final artwork exists.

## Included in this vertical slice

- A native SwiftUI macOS application.
- A SpriteKit scene drawn entirely with placeholder vector shapes.
- A deterministic simulation clock.
- Dawn, daytime, sunset, and night palettes.
- Autonomous idle, walking, fishing, resting, ocean-watching, and sleeping behaviors.
- Energy-driven decisions.
- Ambient gull, fish, coconut, crab, and shooting-star events.
- A lightweight development overlay showing the current simulation state.
- Deterministic engine tests.

## Run it

Requires macOS 14 or newer and Xcode 16 or newer.

```bash
swift run IdleIsle
```

Or open `Package.swift` in Xcode and run the `IdleIsle` scheme.

## Current limitations

- All visual elements are temporary programmer art.
- The simulation runs faster than real time so day/night behavior is visible during development.
- No sound, persistence, settings, weather, or screensaver extension yet.
- The debug overlay is always visible in this milestone.

## Guiding principle

> Every feature must make the island feel more alive—not merely more complicated.
