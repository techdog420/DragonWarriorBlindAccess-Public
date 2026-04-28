# Handoff: Brecconary `(3,5)` Route-Context Repro - 2026-04-27

## Supersedes

This supersedes `HANDOFF_2026-04-27_brecconary_35_false_blocker.md`.

The earlier split direct probe from `(2,5)->RIGHT` appeared to move through the
static `(3,5) west` blocker, but the post-reload fresh survey produced stronger
route-context and manual-confirm evidence that the seam is actually blocked.
Treat the earlier moved probe as noisy/subtile state contamination.

## Trigger

Reloading Lua cleared the failed-target cache, so a fresh parked object survey
was started from `(6,8)`:

```text
SURVEY_START run=1 map=0x08 start=(6,8) targets=21 mode=objects
npc_mode=park_npcs runtime_blocks=0
SURVEY_START_CONTEXT ... open_exit_count=3 open_exits=south|west|east
blocked_exits=north:tile
```

The first target, `Woman 3`, succeeded, leaving the player at `(4,8)`. The next
target, `Merchant 2` at `(5,4)`, planned a route through the NW building west
wall seam and then blocked at `(2,5)->RIGHT` into `(3,5)`.

## Evidence

Initial route block:

```text
NEW BLOCK: map=0x08 from=(2,5) dir=right dest=(3,5)
auto_step blocked dir=right from=(2,5) ... queued_route=true
SEAM_OBSERVATION map=0x08 cell=(3,5) approach=west result=blocked
blocked=1 moved=0 classification=blocked_only source=queued_route_block
```

Brute-force/manual confirm then repeated the same block twice:

```text
SEAM_BRUTE_FORCE ... attempt=1/2
SEAM_BRUTE_FORCE ... attempt=2/2
runtime block: map=0x08 cell=(3,5) approach=west
source=seam_confirm:manual_block blocked=3 moved=0
SEAM_CLASS_CHANGE ... from=blocked_only to=confirmed_blocked
```

`Merchant 2` failed for a real suspected engine-blocked seam:

```text
SURVEY_RESULT ... target_name="Merchant 2" ... movement_succeeded=false
final=(2,5) failure_class=suspected_engine_blocked_tile blocked_events=3
suspected_tiles=3,5 blocked_tiles=3,5|3,5|3,5 reason=reroute_no_path
```

Later in the same survey, `Guard 3` and `Merchant 1` also hit `(2,5)->RIGHT`,
then succeeded after rerouting with the runtime block in place. That gave the
candidate enough route-context support without turning the rest of the survey
into a false-negative cascade.

Partial survey was manually stopped during `Guard 1`:

```text
SURVEY_COMPLETE run=1 map=0x08 targets=10 successes=6 failures=4
no_route=0 gated_or_isolated=2 movement_failed=0 suspected_engine_blocked=1
state_issues=1 adjacency_issues=0
SURVEY_STRONG_CANDIDATE map=0x08 x=3 y=5 key=3,5 count=5 targets=3
retry_successes=2 state_issues=0 approaches=west confidence=high
```

The `Guard 1` state issue was caused by `stop_survey`/`manual_stop` and should
not be treated as a pathfinding defect.

## Conclusion

`MAP_DIRECTIONAL_BLOCKS[0x08]["3,5"].west=true` is correct. The route-context
survey and brute-force/manual confirmations outweigh the earlier moved direct
probe.

The current model should keep both NW building west-wall entries:

```lua
["3,4"] = {west = true}
["3,5"] = {west = true}
```

## Patch

Updated `map_reader.lua`:

- Restored/kept `MAP_DIRECTIONAL_BLOCKS[0x08]["3,5"] = {west = true}`.
- Added a note that the 2026-04-27 post-reload survey confirmed the seam and
  that the earlier moved probe is treated as noisy/subtile state.

Updated `test_map_reader.lua`:

- Restored the Brecconary assertion that `dirs["3,5"].west == true`.

## Validation

Passed:

```text
luac -p map_reader.lua test_map_reader.lua
git diff --check -- map_reader.lua test_map_reader.lua session_handoff.md HANDOFF_2026-04-27_brecconary_35_context_repro.md HANDOFF_2026-04-27_brecconary_35_false_blocker.md
```

`lua test_map_reader.lua` still fails only the two known unrelated Tantegel
assertions:

```text
(12,19) south expected nil, got true
(16,16) east expected true, got nil
```

The Brecconary `(3,5)` assertion passes.

## Live State

After `stop_survey report_position report_runtime_blocks report_survey_findings`:

```text
POSITION: map=0x08(Brecconary) x=20 y=15
RUNTIME_BLOCKS map=0x08 none
```

NPC freeze was released by `stop_survey`.

## Next Step

Reload Lua so the restored `(3,5) west` model is active, then run another
parked Brecconary survey from the desired current location. Merchant 2 should
no longer route through `(2,5)->RIGHT`; if it still fails, inspect the next
failure point instead of revisiting `(3,5)` unless there is a new clean repro.
