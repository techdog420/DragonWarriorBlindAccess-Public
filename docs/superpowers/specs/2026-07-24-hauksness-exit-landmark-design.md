# Hauksness Exit Landmark Design

Date: 2026-07-24
Status: Approved

## Goal

Give blind players a reliable navigation target for leaving Hauksness without
allowing autowalk to cross the map transition automatically.

Use the exit as the destination for the next live map-decoding pass from the
Axe Knight area toward the western entrance, while keeping timing failures,
combat interruptions, and unverified movement anomalies out of permanent map
data.

## Verified Baseline

Live FCEUX testing on Hauksness map `0x03` established:

- entering the ruins from the world map places the player at `(0,10)`;
- the player can stand on `(0,10)`;
- moving west from `(0,10)` exits Hauksness;
- the transition places the player on world map `0x01` at `(25,89)`;
- the current interior landmark route can safely stop at the Axe Knight
  approach `(17,12)`, facing east.

The exit therefore differs from an adjacent-interaction landmark: its
transition tile is itself a safe standing tile, and only the final west input
changes maps.

## Approaches Considered

### Chosen: static entry in the existing exit table

Add Hauksness `(0,10)` to the existing map-scoped exit data in `objects.lua`.
Use `(0,10)` as both the exit's subject coordinate and its interaction
coordinate, with west as the interaction-facing direction.

This reuses the generic exit object, Travel filter, selected-object routing,
and interaction-facing behavior already proven by the Rimuldar west-edge
exit. It requires no Hauksness-specific route code.

### Rejected: custom Hauksness landmark

Create a separate static Travel landmark with a Hauksness-specific name and
interaction behavior.

This could produce the same player experience, but it would duplicate the
existing exit abstraction and make ordinary exit behavior look
map-specific.

### Rejected: runtime-only waypoint

Inject a temporary waypoint solely for the live return-route investigation.

This would help the current decoding pass but would not give players a
durable exit target. It would also leave the same exit to be implemented and
tested later.

## Design

### 1. Static exit data

Add one entry to the existing `EXITS` table in `objects.lua`:

- map: `0x03`;
- subject coordinate: `(0,10)`;
- destination: World Map;
- interaction coordinate: `(0,10)`;
- interaction facing: west;
- interaction label: `exit`.

The existing exit-object conversion should provide:

- player-facing name: `Exit to World Map`;
- stable ID derived from the exit coordinate;
- existing exit object type;
- availability under `All` and `Travel`.

It must not appear under `NPCs`, `Services`, `Treasure`, or `Doors`.

### 2. Safe route behavior

Selected-object routing must:

1. Plan and autowalk to `(0,10)`.
2. Finish facing west.
3. Release movement and stop on map `0x03`.
4. Announce normal route completion for `Exit to World Map`.
5. Require one deliberate manual west step to enter the world map.

Autowalk must not issue the final west input or otherwise trigger the map
transition. No Hauksness-specific logic should be added to `route_manager.lua`
or `auto_step.lua`; the generic interaction-point contract remains
authoritative.

### 3. Live return-route decoding

After the landmark is implemented and the Lua script is manually reloaded,
select `Exit to World Map` from the current Axe Knight area and work west
toward it in short, observable cycles.

For each interruption:

- pause for the user to clear combat;
- re-establish the player's exact map and coordinate before continuing;
- distinguish planner failure, execution timing, NPC interference, and an
  actual engine-blocked edge;
- use a same-origin movement probe when a suspected edge can be reproduced;
- record uncertain findings in `work_notes/current_investigation.md`;
- promote only repeatable, map-scoped evidence into `map_reader.lua`;
- add focused map regressions for every promoted directional block.

The exit landmark and its automated tests do not depend on completing the
entire return-route decode in the same session.

## Test Strategy

Implementation follows red-green-refactor.

Add focused object tests proving that on map `0x03`:

- the exit object exists at `(0,10)`;
- its interaction coordinate is `(0,10)`;
- its interaction facing is west;
- its interaction label is `exit`;
- its player-facing name is `Exit to World Map`;
- it appears under `All` and `Travel`;
- it does not appear under unrelated filters.

Use the existing route-manager interaction tests unless a focused regression
reveals that edge-tile exits need additional coverage. Any new route test
must prove that the final planned destination is `(0,10)` and that no
movement step attempts to leave map `0x03`.

Run the focused object suite, any changed routing suite, the full Lua suite,
Lua syntax checks for changed Lua files, and `git diff --check`.

## Live Acceptance

After a manual FCEUX Lua reload:

1. Confirm the player remains on Hauksness map `0x03`.
2. Select `Exit to World Map` under Travel.
3. Start selected-object guidance or blocker-hunt autowalk.
4. Confirm the route works westward from the Axe Knight area as far as
   current passability data allows.
5. Resolve and verify encountered blockers using the live-debug rules above.
6. Confirm the player ultimately stops at `(0,10)`, faces west, and remains
   inside Hauksness.
7. Press west manually and confirm the player reaches world map `(25,89)`.

Combat interruptions and movement-timing failures are investigation events,
not automatic acceptance failures and not permanent blocker evidence.

## Scope Boundaries

Included:

- one static Hauksness exit object;
- safe stopping and west-facing behavior;
- focused object regressions;
- live route investigation from the Axe Knight area toward the exit;
- permanent map-data changes only when supported by repeatable live evidence.

Excluded:

- automatic map transition;
- a Hauksness-specific routing branch;
- changes to global exit semantics;
- speculative promotion of the current runtime-only blocker list;
- battle-dialogue or general overworld timing fixes;
- unrelated Hauksness landmarks or hidden-item guidance.

## Acceptance Criteria

1. `Exit to World Map` is available under All and Travel on map `0x03`.
2. Selected-object navigation targets `(0,10)` and finishes facing west.
3. Navigation stops inside Hauksness and requires one manual west step to
   leave.
4. No Hauksness-specific route or autowalk logic is introduced.
5. Focused and full automated verification pass.
6. The live return-route investigation records or promotes blocker evidence
   according to the project's same-origin verification rules.
