#!/usr/bin/env python3
"""Finalize Idle Isle's migration to one injected WorldRuntime.

WorldRuntime and its tests already exist on the branch. This guarded migration
only rewires the four SpriteKit scene layers and ContentView. Every replacement
must match exactly once before any file is written, preventing a partial edit.
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
    return replace_once(
        text,
        '''struct ContentView: View {
    @State private var scene = IslandScene(size: CGSize(width: 1280, height: 720))
    @State private var tideScene = TideScene(size: CGSize(width: 1280, height: 720))
    @State private var presenceScene = PresenceScene(size: CGSize(width: 1280, height: 720))
    @State private var characterLifeScene = CharacterLifeScene(size: CGSize(width: 1280, height: 720))

    var body: some View {''',
        '''struct ContentView: View {
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

    var body: some View {''',
        label="ContentView scene construction",
    )


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


TRANSFORMS = {
    Path("Sources/IdleIsle/ContentView.swift"): migrate_content_view,
    Path("Sources/IdleIsle/IslandScene.swift"): migrate_island_scene,
    Path("Sources/IdleIsle/TideScene.swift"): migrate_tide_scene,
    Path("Sources/IdleIsle/PresenceScene.swift"): migrate_presence_scene,
    Path("Sources/IdleIsle/CharacterLifeScene.swift"): migrate_character_scene,
}


def main() -> int:
    migrated: dict[Path, str] = {}

    try:
        for relative_path, transform in TRANSFORMS.items():
            path = ROOT / relative_path
            migrated[path] = transform(path.read_text(encoding="utf-8"))
    except (OSError, RuntimeError) as error:
        print(f"Migration aborted before writing files: {error}", file=sys.stderr)
        return 1

    for path, content in migrated.items():
        path.write_text(content, encoding="utf-8")
        print(f"updated {path.relative_to(ROOT)}")

    print("Shared WorldRuntime scene migration applied successfully.")
    print("Run: swift test")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
