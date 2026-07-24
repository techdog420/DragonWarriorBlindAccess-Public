# Hauksness Axe Knight Approach Landmark Design

Date: 2026-07-24
Status: Approved

## Goal

Give blind players a reliable navigation target for Hauksness's fixed Axe
Knight encounter without starting the battle automatically and without
revealing the buried Erdrick's Armor or the SEARCH action that uncovers it.

The landmark should also provide an intentional preparation point where the
player can stop, heal, and make any other preparations before choosing to
enter the encounter.

## Verified Baseline

Live FCEUX testing on Hauksness map `0x03` established:

- the player can stand safely at `(17,12)`;
- stepping east from `(17,12)` onto `(18,12)` starts the fixed Axe Knight
  battle;
- the Axe Knight is a scripted encounter rather than an NPC represented in
  NPC RAM;
- the encounter tile is ordinary-looking ruined-town terrain, with no visible
  Axe Knight sprite;
- after winning, SEARCH on the encounter tile finds and automatically equips
  Erdrick's Armor;
- the terrain does not visibly change after the battle or search.

The fixed encounter is therefore a useful maze landmark, but the buried
reward remains an intentional secret.

## Approaches Considered

### Chosen: static encounter landmark under Travel

Add a map-scoped static landmark that reuses the existing Travel object
category. Store the fixed encounter tile as the landmark's subject and
provide `(17,12)`, facing east, as its interaction point.

This uses the generic selected-object route behavior already shared by doors,
services, and other objects with separate interaction stands. It is the
smallest implementation and avoids inventing a fake NPC.

### Rejected: synthetic NPC

Represent the Axe Knight as a stationary NPC at `(18,12)`.

This would place the landmark under NPC filters and make it participate in
NPC movement, blocking, visited, and stale-RAM logic even though no NPC exists
there. That would misrepresent the game state and risk reviving the same
phantom-NPC problems already found on Hauksness.

### Rejected: new Encounters object type and filter

Introduce a new object type and player-facing filter specifically for fixed
encounters.

This is a cleaner taxonomy if many fixed encounters are later exposed, but it
would expand filter cycling, speech, tests, and command semantics for one
current landmark. A dedicated type can be reconsidered if more fixed
encounters prove useful.

## Design

### 1. Static landmark data

Add a dedicated map-scoped static-landmark table in `objects.lua`, separate
from `EXTRA_TREASURES` and NPC data. The Hauksness entry will contain:

- map: `0x03`;
- player-facing name: `Axe Knight Approach`;
- stable ID: `landmark_hauksness_axe_knight`;
- subject coordinate: `(18,12)`;
- safe interaction coordinate: `(17,12)`;
- interaction facing: east;
- interaction label: `safe approach`;
- existing Travel-compatible object type.

The landmark table will be gathered with other static objects. Reusing the
Travel-compatible type makes it available under `All` and `Travel`, but not
under `NPCs`, `Services`, `Treasure`, or `Doors`.

The landmark remains available after the battle and after the armor is
collected. Its purpose is stable navigation through the ruined-town maze, not
tracking enemy or treasure state.

### 2. Safe route behavior

Selected-object routing must use the interaction coordinate rather than the
subject coordinate:

1. Plan and autowalk to `(17,12)`.
2. Finish facing east.
3. Stop with movement released.
4. Announce normal route completion for the selected landmark.
5. Require the player to press east manually to enter `(18,12)` and start the
   battle.

The mod must not take the final east step, trigger combat, heal the player, or
perform any other field action automatically. Stopping one tile away gives
the player an explicit opportunity to restore HP or otherwise prepare.

No special route-manager or autowalk behavior should be necessary. The
existing generic interaction-point contract should remain authoritative.

### 3. Hidden-reward boundary

The implementation may retain the encounter coordinate internally because it
is required to describe and route to the Axe Knight landmark. It must not add
the buried armor as an object or treasure target.

Ordinary player-facing browsing, descriptions, route guidance, and completion
speech must not:

- name Erdrick's Armor;
- describe buried treasure at the encounter tile;
- instruct or suggest that the player use SEARCH;
- automatically issue SEARCH;
- expose the encounter tile under the Treasure filter.

Developer-only evidence in map notes and tests may record the relationship so
future work does not accidentally convert it into a player-facing treasure
hint.

### 4. Speech behavior

Use existing object-description and route-completion speech. Do not add a
bespoke explanatory message that could leak the reward.

At the preparation tile, an object description should communicate the
equivalent of:

`Axe Knight Approach: 1 east, safe approach here`

This tells the player where the encounter is and that the current tile is the
safe stopping point. It does not mention what happens after the battle.

## Test Strategy

Implementation follows red-green-refactor.

Add focused object tests proving that on map `0x03`:

- `landmark_hauksness_axe_knight` exists;
- its subject coordinate is `(18,12)`;
- its interaction coordinate is `(17,12)`;
- its interaction facing is east;
- its interaction label is `safe approach`;
- it appears under `All` and `Travel`;
- it does not appear under `NPCs`, `Services`, `Treasure`, or `Doors`;
- stale or parked NPC RAM does not affect its presence;
- no Hauksness treasure object is introduced for the hidden armor;
- its player-facing name and description contain no armor or SEARCH hint.

Add or extend a route-manager regression proving that a selected object with
this interaction geometry plans to `(17,12)`, preserves east-facing arrival,
and does not include `(18,12)` as a movement step.

Run the focused object and route-manager suites, then the full Lua suite,
`git diff --check`, and Lua syntax checks for changed Lua files.

## Live Acceptance

After a manual FCEUX Lua reload:

1. Enter Hauksness on a clean map state.
2. Select `Axe Knight Approach` under Travel.
3. Start selected-object guidance/autowalk.
4. Confirm the player stops at `(17,12)`, faces east, and remains out of
   combat.
5. Confirm the player can pause there and use ordinary preparation actions.
6. Press east manually and confirm the Axe Knight encounter starts.
7. Recheck the object filters and spoken descriptions for any armor or SEARCH
   disclosure.

The hidden armor itself does not need to be searched again to accept this
feature; its existing live proof is developer evidence, not player guidance.

## Scope Boundaries

Included:

- one static Hauksness encounter landmark;
- safe interaction geometry and normal route completion;
- filter, speech-boundary, and routing regressions;
- concise developer documentation of the hidden-reward boundary.

Excluded:

- exposing the buried armor as treasure;
- automatic SEARCH or post-battle instructions;
- automatic battle initiation;
- HP restoration or inventory management;
- a new Encounters filter;
- generic fixed-encounter discovery;
- unrelated Hauksness passability or combat-dialogue fixes.

## Acceptance Criteria

1. `Axe Knight Approach` is available under All and Travel on map `0x03`.
2. Selected-object autowalk stops at `(17,12)`, faces east, releases movement,
   and does not enter combat.
3. Entering the encounter requires one deliberate manual east step.
4. No ordinary object or route speech names the armor, suggests SEARCH, or
   exposes the encounter cell as treasure.
5. The landmark is independent of NPC RAM and remains useful after the fight.
6. Focused and full automated verification pass.
