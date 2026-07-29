#!/usr/bin/env python3
"""Migrate all SpriteKit scenes to one injected WorldRuntime.

This script is intentionally guarded: every replacement must match exactly once
before any file is written. That makes the multi-file migration atomic from the
working tree's point of view and prevents a partially rewritten build.
"""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, *, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def migrate_content_view(text: str) -> str:
    old = '''struct ContentView: View {
    @State private var scene = IslandScene(size: CGSize(width: 1280, height: 720))
    @State private var tideScene = TideScene(size: CGSize(width: 1280, height: 720))
    @State private var presenceScene = PresenceScene(size: CGSize(width: 1280, height: 720))
    @State private var characterLifeScene = CharacterLifeScene(size: CGSize(width: 1280, height: 720))

    var body: some View {'''
    new = '''struct ContentView: View {
    @State private var scene: IslandScene
    @State private var tideScene: TideScene
    @State private var presenceScene: PresenceScene
    @State private var characterLifeScene: CharacterLifeScene

    init() {
        let size = CGSize(width: 1280, height: 720)
        let runtime = WorldRuntime()
        _scene = State(initialValue: IslandScene(size: size, runtime: runtime))
        _tideScene = State(initialValue: TideScene(size: size, runtime: runtime))
        _presenceScene = State(initialValue: PresenceScene(size: size, runtime: runtime))
        _characterLifeScene = State(initialValue: CharacterLifeScene(size: size, runtime: runtime))
    }

    var body: some View {'''
    return replace_once(text, old, new, label="ContentView scene construction")


def migrate_island_scene(text: str) -> str:
    text = replace_once(
        text,
        '''    private let persistence: WorldPersistence
    private let engine: SimulationEngine''',
        '''    private let runtime: WorldRuntime''',
        label="IslandScene stored runtime",
    )
    text = replace_once(
        text,
        '''    override init(size: CGSize) {
        let persistence = WorldPersistence()
        self.persistence = persistence
        self.engine = SimulationEngine(initialState: persistence.load() ?? WorldState())
        super.init(size: size)''',
        '''    init(size: CGSize, runtime: WorldRuntime) {
        self.runtime = runtime
        super.init(size: size)''',
        label="IslandScene initializer",
    )
    text = replace_once(
        text,
        '''    override func willMove(from view: SKView) {
        try? persistence.save(engine.state)
    }''',
        '''    override func willMove(from view: SKView) {
        try? runtime.save()
    }''',
        label="IslandScene final save",
    )
    text = replace_once(
        text,
        '''        let state = engine.advance(by: delta)''',
        '''        let state = runtime.advance(by: delta)''',
        label="IslandScene advance",
    )
    text = replace_once(
        text,
        '''            try? persistence.save(state)''',
        '''            try? runtime.save()''',
        label="IslandScene periodic save",
    )
    return text


def migrate_tide_scene(text: str) -> str:
    text = replace_once(
        text,
        '''    private let worldEngine = SimulationEngine(seed: 0x54494445)
    private var lastUpdateTime: TimeInterval = 0''',
        '''    private let runtime: WorldRuntime''',
        label="TideScene stored runtime",
    )
    text = replace_once(
        text,
        '''    override init(size: CGSize) {
        super.init(size: size)''',
        '''    init(size: CGSize, runtime: WorldRuntime) {
        self.runtime = runtime
        super.init(size: size)''',
        label="TideScene initializer",
    )
    text = replace_once(
        text,
        '''    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        render(worldEngine.advance(by: delta))
    }''',
        '''    override func update(_ currentTime: TimeInterval) {
        render(runtime.state)
    }''',
        label="TideScene observer update",
    )
    return text


def migrate_presence_scene(text: str) -> str:
    text = replace_once(
        text,
        '''    private let worldEngine = SimulationEngine(seed: 0x50524553)
    private let presenceEngine = PresenceEngine()''',
        '''    private let runtime: WorldRuntime
    private let presenceEngine = PresenceEngine()''',
        label="PresenceScene stored runtime",
    )
    text = replace_once(
        text,
        '''    override init(size: CGSize) {
        super.init(size: size)''',
        '''    init(size: CGSize, runtime: WorldRuntime) {
        self.runtime = runtime
        super.init(size: size)''',
        label="PresenceScene initializer",
    )
    text = replace_once(
        text,
        '''        let world = worldEngine.advance(by: delta)
        let presence = presenceEngine.advance(by: delta, world: world)''',
        '''        let world = runtime.state
        let presence = presenceEngine.advance(by: delta, world: world)''',
        label="PresenceScene observer update",
    )
    return text


def migrate_character_scene(text: str) -> str:
    text = replace_once(
        text,
        '''    private let worldEngine: SimulationEngine
    private let crabEngine = CrabEngine()''',
        '''    private let runtime: WorldRuntime
    private let crabEngine = CrabEngine()''',
        label="CharacterLifeScene stored runtime",
    )
    text = replace_once(
        text,
        '''    override init(size: CGSize) {
        let persistence = WorldPersistence()
        worldEngine = SimulationEngine(initialState: persistence.load() ?? WorldState())
        super.init(size: size)''',
        '''    init(size: CGSize, runtime: WorldRuntime) {
        self.runtime = runtime
        super.init(size: size)''',
        label="CharacterLifeScene initializer",
    )
    text = replace_once(
        text,
        '''        let world = worldEngine.advance(by: delta)
        let crabState = crabEngine.advance(by: delta, world: world)''',
        '''        let world = runtime.state
        let crabState = crabEngine.advance(by: delta, world: world)''',
        label="CharacterLifeScene observer update",
    )
    return text


def migrate_simulation_engine(text: str) -> str:
    text = replace_once(
        text,
        '''    private static let defaultWorldSeed: UInt64 = 0x1D1E15E
    nonisolated(unsafe) private static weak var defaultWorldAuthority: SimulationEngine?

''',
        '''''',
        label="SimulationEngine temporary authority declarations",
    )
    text = replace_once(
        text,
        '''    private let participatesInDefaultWorld: Bool

''',
        '''''',
        label="SimulationEngine participation flag",
    )
    text = replace_once(
        text,
        '''        random = SeededGenerator(seed: seed)
        participatesInDefaultWorld = seed == Self.defaultWorldSeed

        if participatesInDefaultWorld, Self.defaultWorldAuthority == nil {
            Self.defaultWorldAuthority = self
        }''',
        '''        random = SeededGenerator(seed: seed)''',
        label="SimulationEngine authority registration",
    )
    text = replace_once(
        text,
        '''        if participatesInDefaultWorld,
           let authority = Self.defaultWorldAuthority,
           authority !== self {
            state = authority.state
            return state
        }

''',
        '''''',
        label="SimulationEngine authority mirroring",
    )
    return text


TRANSFORMS = {
    Path("Sources/IdleIsle/ContentView.swift"): migrate_content_view,
    Path("Sources/IdleIsle/IslandScene.swift"): migrate_island_scene,
    Path("Sources/IdleIsle/TideScene.swift"): migrate_tide_scene,
    Path("Sources/IdleIsle/PresenceScene.swift"): migrate_presence_scene,
    Path("Sources/IdleIsle/CharacterLifeScene.swift"): migrate_character_scene,
    Path("Sources/IdleIsle/SimulationEngine.swift"): migrate_simulation_engine,
}


def main() -> int:
    originals: dict[Path, str] = {}
    migrated: dict[Path, str] = {}

    try:
        for relative_path, transform in TRANSFORMS.items():
            path = ROOT / relative_path
            original = path.read_text(encoding="utf-8")
            originals[path] = original
            migrated[path] = transform(original)
    except (OSError, RuntimeError) as error:
        print(f"Migration aborted before writing files: {error}", file=sys.stderr)
        return 1

    for path, content in migrated.items():
        path.write_text(content, encoding="utf-8")
        print(f"updated {path.relative_to(ROOT)}")

    print("Shared WorldRuntime migration applied successfully.")
    print("Run: swift test")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
