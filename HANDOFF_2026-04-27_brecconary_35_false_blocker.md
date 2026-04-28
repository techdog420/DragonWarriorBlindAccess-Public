# Handoff: Brecconary `(3,5)` False Directional Block - 2026-04-27

## Superseded

Superseded by `HANDOFF_2026-04-27_brecconary_35_context_repro.md`.

The later post-reload fresh survey produced stronger route-context plus
brute-force/manual evidence that `(2,5)->RIGHT` into `(3,5)` is blocked. Treat
the direct moved probe described below as noisy/subtile state contamination, not
as current map truth.

## Trigger

After moving to another part of Brecconary and checking the focused
`retry_failed` target set, the preflight still reported every remaining target
unreachable:

```text
SURVEY_START_STATUS map=0x08 mode=retry_failed start=(6,8) targets=8
reachable_area=128 open_exit_count=3 open_exits=south|west|east
blocked_exits=north:tile status=isolated_start reachable_targets=0
unreachable_targets=8 isolation_reason=low_target_coverage npc_mode=park_npcs
```

Live sanity check from `(6,8)`:

```text
POSITION: map=0x08(Brecconary) x=6 y=8
RUNTIME_BLOCKS map=0x08 none
SURVEY_STRONG_CANDIDATES map=0x08 none
```

So this was not a stale runtime blocker.

## Evidence

Debug pathfinding from `(6,8)` to Merchant 2 at `(5,4)` failed even though the
adjacent goal cells were walkable:

```text
Debug pathfind adjacent to (5,4): No path found [no_path] (visited=402 path=0)
pathfind adj (5,5) walkable=true blocker=nil
pathfind adj (4,4) walkable=true blocker=nil
pathfind adj (6,4) walkable=true blocker=nil
```

The search log showed the pathfinder treating the NW building west wall as
closed, including `(3,5)` from the west.

A split live probe disproved that specific model entry:

```text
freeze_npcs
teleport_to:2,5
probe_edge:RIGHT
```

Result:

```text
MOVE map=0x08 from=(2,5) dir=right dest=(3,5) ... directional_blocked=true blocked_approach=west approach_blocked=true effective_passable=false
EDGE_PROBE_RESULT map=0x08 from=(2,5) dir=right dest=(3,5) status=moved final=(3,5)
EDGE_PROBE_MODEL_MISMATCH map=0x08 from=(2,5) dir=right dest=(3,5) kind=moved_through_modeled_block ... static_directional_blocked=true runtime_directional_blocked=false
```

Once physically inside at `(3,5)`, pathfinding to Merchant 2 succeeded:

```text
Debug pathfind adjacent to (5,4): Approach: 1 north, 1 east (visited=7 path=2). Face east
```

Conclusion: the remaining failures are not all blocked by design. At least one
false static blocker was still in play.

## Patch

Updated `map_reader.lua`:

- Removed `MAP_DIRECTIONAL_BLOCKS[0x08]["3,5"] = {west = true}`.
- Kept `MAP_DIRECTIONAL_BLOCKS[0x08]["3,4"] = {west = true}` intact.

Updated `test_map_reader.lua`:

- Added a regression assertion that `dirs["3,5"]` remains `nil`, because the
  direct probe moved through `(2,5)->RIGHT` into `(3,5)`.

## Validation

Passed:

```text
luac -p map_reader.lua test_map_reader.lua
git diff --check -- map_reader.lua test_map_reader.lua
```

`lua test_map_reader.lua` still fails only the two known unrelated Tantegel
assertions:

```text
(12,19) south expected nil, got true
(16,16) east expected true, got nil
```

The Brecconary directional-wall test passed with the new `(3,5)` assertion.

## Live State

After probing, live state was restored:

```text
POSITION: map=0x08(Brecconary) x=6 y=8
NPCs unfrozen
RUNTIME_BLOCKS map=0x08 none
```

## Next Step

Reload Lua before testing; the running emulator still has the old static table.

Then run:

```sh
./dw_commands.sh --replace report_survey_start:retry_failed,park_npcs
```

If the focused preflight shows nonzero reachable targets, run the focused
survey. Merchant 2 should be the first expected improvement, and the opened
west entry may allow the route to reach additional top-side components.
