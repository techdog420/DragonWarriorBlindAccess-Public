# Handoff: Survey Staircase Trap and Auto-Step Recovery
Date: 2026-04-17

## Summary

Two separate issues were resolved on map `0x04` (Tantegel Castle):

1. Survey runs launched from the staircase tile at `(7,7)` were pointless and
   got trapped immediately because the DW1 engine blocks outward movement from
   staircase tiles even though the surrounding floor/carpet tiles look walkable
   to the map model.
2. A broader `auto_step` regression caused open-floor probes and surveys to fail
   from normal starting squares like `(10,14)` and `(11,11)`, falsely promoting
   passable edges into runtime blocked evidence.

Both are now addressed on disk, and the movement fix is live-verified in FCEUX.

## What Changed

### 1. Survey abort for low-exit starts

`map_survey.lua` now aborts a survey before `survey_state` initialization when
the tile model sees only `1-2` open exits from the start square.

Speech:

```text
Survey aborted: start (X,Y) has only N open exits. Move to a more open position and try again.
```

Log tag:

```text
SURVEY_START_ABORT reason=low_exit_count
```

This specifically prevents wasting a full survey run from staircase/trap-like
starts such as map `0x04` `(7,7)`.

### 2. Auto-step turn-repress recovery fix

The current `auto_step` patch now does all of the following:

- restores `TURN_REPRESS_DELAY = 18`
- makes the 2-frame turn-repress gap actively send neutral input
- allows live D-pad input to cancel active queued route steps again
- upgrades `TURN_REPRESS_INJECT_LIMIT` from the old short 4-frame follow-up
  hold to the full `INJECT_LIMIT` window after a turn-only attempt

Supporting changes:

- `route_manager.lua`
  - stops forwarding autonomous-route suppression into `auto_step`
- `map_survey.lua`
  - stops requesting autonomous route suppression for surveys
- `test_auto_step.lua`
  - covers neutral-gap behavior, manual interrupt behavior, and the full
    follow-up repress window after a turn-only attempt
- `debug_tools.lua`
  - supports multi-frame `simulate_input:BTN,N` and
    `simulate_raw_input:BTN,N` for live isolation
- `debug_hooks.txt`
  - documents the new debug command syntax

## Why the Last Auto-Step Change Worked

Live isolation showed:

- `inspect_move:LEFT` from `(11,11)` reported `(10,11)` as passable
- `simulate_raw_input:LEFT,12` moved cleanly from `(11,11)` to `(10,11)`
- but `probe_edge:LEFT` still failed through `auto_step.inject_step`

That narrowed the remaining bug to the queued/injected `auto_step` path rather
than map data or general controller suppression.

Best current interpretation:

- the 4-frame follow-up repress after a turn-only attempt was too weak on live
  hardware to reliably start movement
- restoring a full follow-up inject window after the turn fixed that path

## Live Verification

After reloading the latest patch in FCEUX, all three previously failing open
floor probes now succeed:

1. `clear_runtime_blocks` + `teleport_to:11,11` + `probe_edge:LEFT`
   - `status=moved final=(10,11)`
2. `clear_runtime_blocks` + `teleport_to:10,14` + `probe_edge:UP`
   - `status=moved final=(10,13)`
3. `clear_runtime_blocks` + `teleport_to:13,14` + `probe_edge:LEFT`
   - `status=moved final=(12,14)`

User-observed side effect after the patch:

- field controller input also feels more reliable again

## Fresh Survey Status

From `(10,14)`:

- `report_survey_start:park_npcs`
  - `reachable_area=128`
  - `open_exit_count=4`
  - `status=viable`
- `survey_objects:park_npcs`
  - left the start square normally
  - produced real movement and early successes instead of immediate
    `command_timing_or_state_issue`

Confirmed successes seen in log:

- `Person 1` (`npc_2`)
  - `movement_succeeded=true`
  - `final=(12,14)`
- `Woman 1` (`npc_0`)
  - `movement_succeeded=true`
  - `final=(13,16)`
- `Guard 7` (`npc_14`)
  - `movement_succeeded=true`
  - `final=(9,9)`

At the last log read, the survey was still active and had reached:

- `Old Man 1` (`npc_3`)
- attempt index `7/29`

Interpretation:

- the broad auto-step regression appears fixed
- new survey failures should now be treated as fresh map/path evidence rather
  than fallout from the earlier broken movement state

## 2026-04-18 Follow-Up: Suspected Targets from Start `(10,29)`

Fresh live rechecks on 2026-04-18 show the late survey failure cluster from
`(10,29)` is best explained by a stranded lower-pocket start, not by a new
regression in the previously suspected targets.

### What was confirmed

- `report_survey_start:park_npcs` from `(10,29)` still reports
  `reachable_area=128` with only `north|west` open
- direct probe from `(10,29)`:
  - `UP` to `(10,28)` moves
  - `LEFT` to `(9,29)` moves
- path debug from `(10,29)` shows the lower pocket still has a narrow route
  northward through the middle:
  - reachable:
    - `(11,27)`
    - `(11,24)`
    - `(11,20)`
    - `(13,20)`
    - `(13,19)`
    - `(13,18)`
    - `(13,17)`
    - `(13,16)`
    - `(14,16)`
    - `(20,17)`
  - unreachable:
    - `(10,18)`
    - `(12,19)`
    - `(20,16)`
    - `(21,17)`
    - `(21,16)`
    - `(22,17)`
    - `(24,17)`
- direct probes confirmed the decisive chokepoints are real:
  - `(20,17) -> (20,16)` blocks
  - `(20,17) -> (21,17)` blocks
  - `(13,20) -> (14,20)` blocks

### Interpretation

- The survey can walk itself into the lower exit pocket and then become
  legitimately cut off from many remaining targets.
- That means the late `(10,29)` failures should not be treated as fresh
  evidence against:
  - `Merchant 3`
  - `Guard 5`
  - `Old Man 2`
  - `Guard 2`
  - `Old Man`
  - `Guard`
  - the throne-room / treasure-room stair targets
- No new `map_reader.lua` edit is justified from this failure cluster alone.

## Known Good Repro Set

Use these commands if movement sanity needs re-checking:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks report_upper_dialogue_state
./dw_commands.sh --replace teleport_to:11,11 report_position
./dw_commands.sh --replace probe_edge:LEFT
./dw_commands.sh --replace clear_runtime_blocks teleport_to:10,14 report_position
./dw_commands.sh --replace probe_edge:UP
./dw_commands.sh --replace clear_runtime_blocks teleport_to:13,14 report_position
./dw_commands.sh --replace probe_edge:LEFT
```

Expected:

- all three probes end with `status=moved`

If the first edge ever regresses again, use the raw-input isolation sequence:

```bash
./dw_commands.sh --replace clear_runtime_blocks teleport_to:11,11 report_position
./dw_commands.sh --replace simulate_raw_input:LEFT,12
./dw_commands.sh --replace report_position report_blockers
```

Expected:

- player ends at `(10,11)`
- `runtime_count=0`

## Open Issues

### 1. Tomorrow focus: improve survey logic, not just map data

Map decoding will stay slow if the survey can walk into a stranded pocket late
in the run and then burn many attempts on expected no-path targets. Use the
map `0x04` `(10,29)` pocket as the concrete repro when reviewing
`map_survey.lua`.

High-value directions to explore:

- stop counting a clustered same-start no-path run as many independent target
  failures
- re-anchor or restart from a more open square when the survey becomes stranded
- order / group remaining targets so one isolated branch does not poison the
  rest of the run

### 2. `(12,16)` east approach — monitor only

Keep `MAP_DIRECTIONAL_BLOCKS[0x04]["12,16"].east = true`.

Do not remove it. Evidence remains mixed, but the block still fires often
enough to be useful and it is not part of the movement regression that was just
fixed.

### 3. West-side/gated region on map `0x04`

These targets still need interpretation once the survey completes:

- `chest_0` at `(1,13)`
- `chest_2` at `(2,14)`
- `chest_3` at `(3,15)`
- `chest_1` at `(1,15)`
- `Guard 4` (`npc_7`) at `(3,15)`

These may be genuinely gated by castle layout / key progression, or they may
still expose a model gap. Re-evaluate them only with the now-fixed movement
state.

### 4. Survey-order / stranded-start follow-up

The survey can still end up at `(10,29)` and then record many expected no-path
results for later targets because that pocket does not reconnect to the upper /
east target clusters. If future work touches survey workflow, consider whether
that late-run state should trigger reordering, restart-from-anchor, or a more
explicit "stranded start" interpretation instead of counting each remaining
target as an independent failure.

## Resume Plan

1. Read the latest `dw_debug.log` tail.
2. Start by reviewing `map_survey.lua` with the `(10,29)` pocket findings in
   mind before launching another long live survey.
3. If you need to re-ground the behavior live, use the short repro loop:

```powershell
./dw_commands.ps1 --replace freeze_npcs clear_runtime_blocks report_position report_survey_start:park_npcs
./dw_commands.ps1 --replace clear_runtime_blocks "teleport_to:10,29" report_position
./dw_commands.ps1 --replace "probe_edge:UP"
./dw_commands.ps1 --replace clear_runtime_blocks "teleport_to:10,29" report_position
./dw_commands.ps1 --replace "probe_edge:LEFT"
```

4. Treat the late `(10,29)` target failures as expected from that pocket unless
   a direct probe or non-pocket path debug contradicts it.
5. Focus on remaining west-side / gated targets as fresh evidence.

## Do Not

- Do not survey from staircase tile `(7,7)`.
- Do not remove the `(12,16).east` directional block.
- Do not convert the previously failing open-floor edges near `(11,11)`,
  `(10,14)`, or `(13,14)` into permanent map blockers; they are now verified
  passable.

## Update 2026-04-19

- The survey-logic follow-up from the `(10,29)` pocket repro is now implemented.
- `map_survey.lua` now defers continuation-trap landings when they would strand
  most or all remaining targets, using structural preview planning
  (`skip_npcs=true`) plus run-local preview/diagnostic caches.
- Confirmed isolated same-start no-path clusters now trigger a stranded-start
  cleanup pass: reachable pocket-local targets remain queued, but structurally
  unreachable remainder targets are recorded immediately as
  `gated_or_isolated_region` instead of consuming full live attempts.
- Successful survey attempts now skip the expensive alternate-mode / skip-NPC
  re-analysis path, which removes a chunk of decode-time overhead from clean
  survey runs.
- `route_manager.plan_path_to_object(obj, opts)` now accepts preview overrides
  for origin/blocking so survey previews stay aligned with the real planner.
- Focused regression coverage was added in `test_map_survey.lua` and
  `test_route_manager.lua`, and the relevant Lua test suites passed on
  2026-04-19.
- Additional west-side live follow-up on 2026-04-19:
  - direct seam probe reconfirmed `(7,13) -> (6,13)` blocks, while
    `(5,13) -> (6,13)` and `(6,13) -> (7,13)` move
  - the pre-reload direct probes had `(5,13) -> (4,13)` and `(4,13) -> (5,13)`
    both moving, so `(4,13)` initially stayed off disk
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["6,13"].east = true` has now been restored on
    disk as the stable one-way west-entry seam
  - east-side single-target surveys still strand both `Guard 4` and `chest_0`
    at `(5,13)` after west-entry reroutes
  - inside-west `chest_0` from `(4,13)` succeeds, but inside-west `Guard 4`
    still fails on a different internal west-pocket cluster around
    `(3,16)` / `(4,15)`
  - after the Lua reload, east-side `Guard 4` retest from `(8,7)` now uses the
    restored `(6,13).east` seam live and no longer attempts `(7,13) -> (6,13)`
  - that post-reload `Guard 4` retest then collapses to a direct failure on
    `(5,13) -> (4,13)`, and a fresh direct probe now confirms:
    - `(5,13) -> (4,13)` blocks
    - `(4,13) -> (5,13)` moves
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["4,13"].east = true` is now also restored on
    disk
  - follow-up direct four-side probe on `(3,16)` now shows:
    - `(4,16) -> (3,16)` blocks
    - `(3,15) -> (3,16)` moves
    - `(2,16) -> (3,16)` moves
    - `(3,17) -> (3,16)` moves through the previously modeled south block
  - a later repeat on the next reload did not hold that up:
    - repeated `(4,16) -> (3,16)` moved through the temporary east block
    - repeated `(3,17) -> (3,16)` also moved
  - `3,16` is therefore back to monitor-only status and has been removed from
    disk again rather than modeled permanently
  - direct probes on `(4,15)` after the next reload showed:
    - `(5,15) -> (4,15)` still blocks cleanly
    - `(4,16) -> (4,15)` moves
    - `(3,15) -> (4,15)` blocked once, then moved on immediate retest
    - `(4,14) -> (4,15)` blocked once, then moved on immediate retest
  - keep the existing `MAP_DIRECTIONAL_BLOCKS[0x04]["4,15"].east = true`, but
    do not add north/west yet; those faces are still too noisy
  - direct probes on `(4,16)` after the same reload then showed:
    - `(5,16) -> (4,16)` blocks cleanly
    - `(4,17) -> (4,16)` moves through the old `south=true` model twice
    - `(4,15) -> (4,16)` moves
    - `(3,16) -> (4,16)` blocks twice on immediate retest
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["4,16"]` has therefore been updated from
    `{east = true, south = true}` to `{east = true, west = true}`
  - on the next reload, `survey_target:npc_7,park_npcs` for `Guard 4` passed
    cleanly from `(4,15)`, confirming that the west-pocket route is currently
    good enough for that target even though a few seam cells are still noisy
  - the same reload made the seam-cell picture more nuanced:
    - `(4,14) -> (4,15)` blocked twice in a row, so `4,15.north` is more
      suspicious again
    - `(3,15) -> (4,15)` still moved, so `4,15.west` does not support a new
      permanent block
    - `3,16` blocked from south, north, and west, and east blocked twice after
      one earlier move on the same reload
  - best current interpretation:
    - keep `MAP_DIRECTIONAL_BLOCKS[0x04]["4,15"] = {east = true}` only
    - do not add `4,15.north` yet because it has flipped across reloads
    - keep `3,16` out of permanent data; it still looks reload-sensitive and
      too unstable for a clean directional rule
  - on the next reload-separated retest:
    - `(4,14) -> (4,15)` moved twice in a row, reinforcing that
      `4,15.north` is still not stable enough to model
    - `(4,16) -> (3,16)` moved once and then blocked on immediate retest,
      reinforcing that `3,16.east` is still reload-sensitive/noisy rather than
      a clean permanent seam rule
  - raw-input control checks on the following reload sharpened that further:
    - `probe_edge:LEFT` from `(4,16)` still blocked on `(3,16)`
    - a 30-frame raw Left hold from `(4,16)` also failed to enter `(3,16)`,
      so this is not just a `probe_edge` artifact
    - a 30-frame raw Down hold from `(4,14)` did move south, confirming the
      input path itself still works on nearby open floor
    - caveat: raw holds are not a perfect one-step validator here because the
      held direction's release can fall through into `auto_step` and chain an
      extra tile after the raw movement
  - best handling remains conservative:
    - do not promote `3,16` or `4,15.north` into `map_reader.lua`
    - keep using runtime block/reroute behavior for live route recovery
    - if we want stronger automation later, add a separate noisy-seam
      confidence/quarantine layer instead of hardcoding these cells
  - that follow-up layer is now on disk:
    - `route_manager.lua` keeps per-approach seam observations separate from
      confirmed runtime blocks
    - a blocked edge only becomes a hard runtime block after 3 blocked-only
      observations with no successful traversal
    - a later successful traversal clears the matching runtime block and marks
      the seam noisy instead
    - queued-route failures first try an alternate reroute with a temporary
      block on just the failed approach; if no alternate path exists yet, the
      manager tries a limited brute-force single-step seam push before giving up
    - after a successful brute-force seam step, the manager replans the rest of
      the route automatically
    - new debug commands exist to inspect/reset seam memory:
      `report_seam_cells`, `list_seam_cells`, `clear_seam_cells`
  - focused verification after the change:
    - `luajit.exe test_route_manager.lua`
    - `luajit.exe test_auto_step.lua`
    - `luajit.exe test_map_survey.lua`
