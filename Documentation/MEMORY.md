# Memory

Idle Isle should not merely play animations. It should accumulate history.

The Memory milestone establishes the first version of that principle.

## What the island remembers

The simulation records:

- Total lived time.
- Distance walked.
- Time spent fishing.
- Time spent near the campfire.
- Time spent beneath the palm.
- Time spent watching the ocean.
- Fishing trips.
- Nights slept.
- Coconut falls witnessed.

These values persist across launches in the user's Application Support directory.

## How memory becomes visible

Repeated behavior slowly creates four environmental traces:

- A route worn across the sand.
- A worn fishing spot.
- Flattened sand around the campfire.
- A familiar resting patch beneath the palm.

The marks are deliberately subtle. They should feel discovered rather than announced.

## How memory changes behavior

Memory is allowed to influence future choices.

The first examples are intentionally small:

- A familiar palm-shade location becomes more attractive when the castaway is tired.
- Repeated ocean watching creates a slight preference for returning to it.
- Repeated coconut falls reduce his visible surprise response.

## Persistence

The world state is encoded as JSON and saved atomically to:

`~/Library/Application Support/IdleIsle/world-state.json`

The renderer saves periodically and when the SpriteKit scene leaves its view.

## Design rule

Memory should create continuity, not optimization.

The castaway is not learning how to win. He is becoming familiar with his home.