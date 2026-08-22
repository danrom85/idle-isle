# Idle Isle Architecture

Idle Isle is a living-world engine with multiple possible presentation surfaces. The macOS app is the first host, not the definition of the system.

## Core boundary

The simulation must not depend on SpriteKit, SwiftUI, AppKit, screen size, frame rate, or final art assets. The Swift package enforces this: `Sources/IdleEngine` compiles against Foundation only, and any scene import that leaks in fails the build.

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

## Package layout

Two targets keep the boundary honest:

**IdleEngine** (`Sources/IdleEngine`) — Foundation only.

- `WorldState.swift` — serializable facts about the world.
- `SimulationEngine.swift` — deterministic state transitions and decisions.
- `CrabSystem.swift` — the shore crab's own small behavior loop.
- `PresenceSystem.swift` — visiting wildlife (gulls, butterflies, fish schools, sea turtles).
- `WorldRuntime.swift` — owns the authoritative state; exactly one `.driver` advances time while observers only read snapshots. Also owns autosave cadence.
- `WorldPersistence.swift` — atomic JSON saves with a schema version and corrupt-file backup.

**IdleIsle** (`Sources/IdleIsle`) — SwiftUI host.

- `ContentView.swift` — one `SpriteView` hosting the composite scene.
- `IdleIsleApp.swift` — macOS application entry point.

**IdleSaver** (`Sources/IdleSaver`) — the macOS screen saver host, compiled by `Tools/build_saver.sh` into `build/Idle Isle.saver` (SwiftPM has no `.saver` product type). `IdleIsleSaverView` embeds the same `IslandScene` in an `SKView`; preview mode skips autosaving so thumbnail rendering never touches the real save.

Everything renders through one scene and one view; layers are plain `SKNode`s ordered by z-position. All presentation lives in the reusable **IdleWorld** library (`Sources/IdleWorld`) so every host shares it:

- `IslandScene.swift` — the single SKScene. Hosts sky, ocean, memory traces, rod rack, palm, campfire, ambient events, and the overlay layers below.
- `TideLayer.swift` — wet sand, shallow water, and foam that breathe with the tide and shift with the day's light.
- `PresenceLayer.swift` — visiting wildlife driven by `PresenceEngine`.
- `CharacterLifeLayer.swift` — the articulated castaway rig, activity props, coconut reactions, and the crab.
- `SoundSystem.swift` — procedural surf and campfire ambience synthesized at startup; no audio assets ship with the project.

## Simulation contract

- Time enters only through `advance(by:)`, clamped to 100 ms steps.
- All randomness is seeded, so a given seed and delta sequence produces an identical world.
- Rendering never mutates world state; it only reads snapshots.

## Persistence

The world state is encoded as JSON and saved atomically to:

`~/Library/Application Support/IdleIsle/world-state.json`

`WorldRuntime` autosaves every few seconds of simulated time, catches up on missed time after pauses or occlusion (capped), and performs a final save when the scene leaves its view. Saves carry a `schemaVersion`; a save that cannot be decoded is moved aside to `world-state.corrupt.json` so a fresh world starts clean without destroying evidence.

## Hosts

- **App**: `swift run` opens a resizable window into the island.
- **Screen saver**: `Tools/build_saver.sh` compiles `Idle Isle.saver`. Note that if both the app and the saver run simultaneously they each drive their own simulation and the last writer wins the save file.
