# 🌴 Idle Isle

> A tiny world that lives while you work.

Idle Isle is an open-source macOS living-world screensaver inspired by the magic of classic desktop companions.

Watch an original castaway explore, fish, build, rest, and react to a peaceful island that slowly changes over time.

No goals.

No scores.

No gameplay.

Just a tiny world that never stops living.

## Building

Requires macOS 14+ and Swift 6 (Xcode 15.4 or newer).

```sh
git clone https://github.com/danrom85/idle-isle.git
cd idle-isle
swift build
swift run
```

Or open `Package.swift` in Xcode and press Cmd+R.

## Testing

```sh
swift test
```

## Screen saver

Build and install the island as a macOS screen saver:

```sh
./Tools/build_saver.sh
open "build/Idle Isle.saver"
```

The saver shares the same world save as the app, so your castaway's memories carry over.

## Documentation

- [Vision](Documentation/VISION.md) — what Idle Isle is and is not.
- [Architecture](Documentation/ARCHITECTURE.md) — engine/presentation boundary and package layout.
- [Memory](Documentation/MEMORY.md) — how the island remembers.
- [First Breath](Documentation/FIRST_BREATH.md) — the first playable milestone.

## License

[Apache 2.0](LICENSE)
