# Idle Isle Architecture

Idle Isle is a living-world engine with multiple possible presentation surfaces. The macOS app is the first host, not the definition of the system.

## Core boundary

The simulation must not depend on SpriteKit, SwiftUI, AppKit, screen size, frame rate, or final art assets.

```text
Input time
   ↓
Simulation engine
   ↓
WorldState snapshot
   ↓
Renderer
   ↓
macOS app / screen saver / future hosts
```

## Current prototype

The First Breath branch intentionally keeps the files in one executable target to minimize setup friction. The boundaries are still conceptual and should remain visible:

- `WorldState.swift` — serializable facts about the world.
- `SimulationEngine.swift` — deterministic state transitions and decisions.
- `IslandScene.swift` — SpriteKit representation of the current state.
- `ContentView.swift` — SwiftUI host for the SpriteKit scene.
- `IdleIsleApp.swift` — macOS application entry point.

## Planned package boundaries

After First Breath compiles and the visual direction is validated, extract modules incrementally:

```text
Packages/
  IdleEngine/       Pure simulation and scheduling
  IdleRenderer/     SpriteKit scene and animation adapters
  IdleContent/      Data-driven events, characters, and locations
  IdlePersistence/  Save snapshots and migrations
  IdleAudio/        Ambient soundscape and event cues

Apps/
  IdleIslePreview/      Development host
  IdleIsleScreenSaver/  ScreenSaver framework host
```

## Simulation rules

1. The engine advances from elapsed time, not rendered frames.
2. Random behavior is seedable for reproducible tests and bug reports.
3. Rendering reads state; it does not decide character behavior.
4. Events have conditions, weights, cooldowns, and outcomes.
5. Persistent consequences become part of world state.
6. Offline progression must be bounded and deterministic.

## State categories

- **Clock:** world date, time of day, season, elapsed simulation time.
- **Environment:** weather, wind, tide, wave state, light.
- **Character:** position, energy, mood, curiosity, memory, activity, goal.
- **Objects:** condition, location, ownership, repair state, age.
- **Ecology:** visitors, animals, plants, resources.
- **History:** notable events and durable consequences.

## Performance target

Idle Isle should remain lightweight enough to run continuously. The simulation can update at a lower fixed cadence than rendering, and visual effects should degrade gracefully on constrained hardware.

## First Breath exit criteria

The prototype may be refactored into packages only after it:

- compiles on the supported macOS/Xcode toolchain;
- runs continuously without crashing;
- clearly shows autonomous behavior;
- completes the accelerated day/night cycle;
- demonstrates at least three ambient events;
- passes deterministic engine tests.
