# Handoff: Tantegel Castle Timing/Seam Follow-up
Date: 2026-04-11

## What Changed This Session

### 1. Timing-noise hardening landed
The earlier survey noise around orphaned routes and queued multi-step autowalk
was tightened up:
- `auto_step.lua`
  - queued routes now support a configurable settle gap between successful
    steps
  - blocked-step retry budget increased from `2` to `3`
- `route_manager.lua`
  - survey-safe autowalk routes now carry settle-gap config through reroutes
  - route settle state is cleared on completion/cancel/map change
- `map_survey.lua`
  - one retry for clean orphaned queued routes
  - multi-block reroute-no-path outcomes classify as
    `command_timing_or_state_issue` instead of engine-block evidence

### 2. Stale route-context leak was fixed
Live seam probing exposed a contamination bug:
- manual `probe_edge` failures were still able to trigger reroutes if an old
  `last_pathfind_obj` survived from survey/autowalk state

Fix:
- `auto_step.lua` now tags blocked events with `queued_route=true/false`
- `route_manager.lua` ignores non-queued blocked steps for reroute purposes
- `map_survey.lua` explicitly clears route-manager context when an orphaned
  survey route is detected or when a survey is manually stopped

This was important because it turned later seam probes into clean one-off edge
tests instead of mixed probe+routed behavior.

### 3. Tantegel south-pocket stale permanent blockers were removed
Direct live probes had already shown these were open:
- `(12,24) -> RIGHT` into `(13,24)`
- `(13,20) -> RIGHT` into `(14,20)` in an earlier session

The stale permanent blockers were removed from `map_reader.lua`:
- `["13,24"]`
- `["14,20"]`

That change collapsed the old `(10,29)` mega-pocket, but also exposed that the
remaining seam issues were not all just permanent-blocker mistakes.

### 4. Tantegel seam directional model was updated again
Fresh post-fix live probes from this session:
- `(13,20) -> RIGHT` into `(14,20)` failed twice in a row, cleanly
- `(12,20) -> UP` into `(12,19)` succeeded twice in a row
- `(12,24) -> RIGHT` into `(13,24)` succeeded twice in a row

Based on that:
- removed stale `south` blocker from `["12,19"]`
- kept `["12,19"].east = true` for now
- added `["14,20"].west = true`
- kept `13,24` open

## Key Live Results

### Survey progression before the seam update

1. After timing-noise fixes:
- full `survey_map` on Map `0x04` finished `13 successes / 16 failures`
- most failures were `gated_or_isolated_region`
- no `route_inactive_without_completion`
- no `timing_orphaned_route`

2. Guard 1 timing noise was checked separately:
- survey-failed edges around `(3,7)` / `(4,8)` reprobed as passable
- raising blocked-step retries to `3` was enough to treat that as timing noise

3. Removing stale permanent blockers at `(13,24)` and `(14,20)` changed the
failure mix:
- fresh full survey became `12 successes / 17 failures`
- old giant isolation pocket mostly collapsed
- failures shifted heavily into seam-side `command_timing_or_state_issue`
  routes instead of clean gated/isolated failures

### Focused seam probe results from this session

Clean post-reload probes:
- `(13,20) -> RIGHT`:
  - failed twice
  - `EDGE_PROBE_RESULT ... status=blocked`
  - runtime block recorded at `(14,20)` approach=`west`
  - no reroute contamination after the route-context fix
- `(12,20) -> UP`:
  - succeeded twice
  - model still logged `directional_blocked=true blocked_approach=south`
  - this is why `12,19 south` was removed from directional blocks
- `(12,24) -> RIGHT`:
  - succeeded twice
  - `13,24` remains open

### Focused nearby-NPC survey sample

Single-target nearby NPC surveys:
- `Guard 11`: success
- `Guard 10`: success
- `Guard 3`: failure, but importantly the route crossed the updated seam area
  first and only failed later

`Guard 3` details:
- start `(10,27)`, target `(6,26)`, adjacent mode
- initial route length `30`
- route successfully traversed the seam via the `12,20/13,20` corridor
- later blocked at:
  - `(5,24) -> RIGHT` into `(6,24)` — strong new blocker evidence
  - `(5,26) -> RIGHT` into `(6,26)` — destination occupied by the NPC, so not
    useful as permanent blocker evidence
- survey finished:
  - `failure_class=suspected_engine_blocked_tile`
  - `reason=route_inactive_without_completion`
  - `suspected_tiles=12,19|12,16`
  - `blocked_tiles=12,19|12,16|6,24|6,26`

Interpretation:
- seam behavior is improved enough that long nearby-NPC routes are getting
  deeper into the map before failing
- the strongest fresh next blocker candidate is `6,24`
- `12,16` also needs direct repro
- `12,19` should **not** be re-promoted from the south side without new direct
  evidence because that approach just succeeded twice
- `6,26` is probably noise from the NPC occupying the destination

## Files Changed

- `auto_step.lua`
- `route_manager.lua`
- `map_survey.lua`
- `map_reader.lua`
- `test_auto_step.lua`
- `test_map_reader.lua`
- `test_map_survey.lua`
- `test_route_manager.lua`

## Verification Run This Session

Passed:
- `lua test_auto_step.lua`
- `lua test_map_reader.lua`
- `lua test_map_survey.lua`
- `lua test_route_manager.lua`
- `lua test_path_debug.lua`

Earlier in-session broader verification also passed aside from the known speech
dependency issue when using `/usr/bin/python` without `accessible_output2`.

## Current State At Wrap-up

- Latest live map: `0x04` (`Tantegel Castle`)
- Latest live player position at wrap-up was deep in the `Guard 3` route
  failure path, ending around `(5,26)`
- The Lua script was **not** reloaded after the final `map_reader.lua`
  directional-block update, so tomorrow should start with a script reload
  before more live routing tests

## Recommended First Steps Next Session

1. Reload the Lua script so the latest `map_reader.lua` seam updates are live.

2. Re-establish a clean test baseline:
```bash
./dw_commands.sh --replace report_position
./dw_commands.sh --replace freeze_npcs
./dw_commands.sh --replace clear_runtime_blocks
```

3. Directly repro the two most useful next candidates:
```bash
./dw_commands.sh --replace teleport_to:5,24
./dw_commands.sh --replace probe_edge:RIGHT      # test 6,24 from west

./dw_commands.sh --replace clear_runtime_blocks
./dw_commands.sh --replace teleport_to:13,16
./dw_commands.sh --replace probe_edge:LEFT       # test 12,16 from east
```

4. If those repro cleanly, decide whether to:
- promote `6,24 west`
- promote `12,16 east`
- or keep them as runtime-only suspects pending one more confirmation

5. Then re-run focused nearby targets that used to stress the seam:
- `Guard 3`
- `Woman 1`
- `Guard 8`
- `Merchant 3`

6. If those improve, run a fresh full:
```bash
./dw_commands.sh --replace freeze_npcs survey_map
```

## Commands That Were Especially Useful

```bash
./dw_commands.sh --replace report_position
./dw_commands.sh --replace freeze_npcs
./dw_commands.sh --replace clear_runtime_blocks
./dw_commands.sh --replace teleport_to:X,Y
./dw_commands.sh --replace probe_edge:DIR
./dw_commands.sh --replace current_object
./dw_commands.sh --replace next_filter
./dw_commands.sh --replace next_object
./dw_commands.sh --replace survey_target
```
