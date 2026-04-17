# Session Handoff — 2026-04-17

## Active Handoff Set

Start here:
- `HANDOFF_2026-04-17_survey_abort_staircase_fix.md`

Historical notes:
- `handoff_archive/`

## Current State

### Change made this session

**Survey abort on low exit count** (`map_survey.lua`):

When the tile model sees only 1–2 open exits from the survey start position, the
survey now aborts immediately (before `survey_state` initialization, before NPC
parking) instead of running and getting trapped. Speech says:

> "Survey aborted: start (X,Y) has only N open exits. Move to a more open position
> and try again."

Log tag: `SURVEY_START_ABORT reason=low_exit_count`

Root cause that motivated the fix: user teleported to staircase tile (7,7) on map
0x04 and launched a survey. Engine blocks movement off staircase tiles (they are
one-way entry triggers). Both tile-model exits from (7,7) were engine-blocked within
2 attempts, trapping the player for 28 failed attempts.

**Auto-step movement/control follow-up** (`auto_step.lua`, `route_manager.lua`, `map_survey.lua`, `test_auto_step.lua`, `debug_tools.lua`, `debug_hooks.txt`):

After the staircase abort fix, the user ran a fresh map 0x04 survey from open floor
at `(10,14)`. `SURVEY_START_CONTEXT` reported `open_exit_count=4`, but the run still
failed `0 successes / 29 failures`. Direct clean probes reproduced the problem
outside survey logic:

- `freeze_npcs` + `report_upper_dialogue_state` showed no active menu/dialogue lock
- `probe_edge:UP` from `(10,14)` failed on a tile the model previewed as open
- `teleport_to:13,14` + `probe_edge:LEFT` failed on another open floor edge

This points away from map data and toward a broad `auto_step` regression.

Fresh live evidence from the current session made that clearer:

- `report_position` + `report_upper_dialogue_state` + `log_state` confirmed clean
  field state at `map=0x04`, `(11,11)`, with no menu/dialogue lock
- `inspect_move` from `(11,11)` reported `up`, `left`, and `right` as passable
- a clean `freeze_npcs` + `probe_edge:LEFT` from `(11,11)` still failed:
  `EDGE_PROBE_RESULT ... status=blocked`
  `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`
  `runtime block: map=0x04 cell=(10,11) approach=east source=auto_step:left from (11,11)`

The follow-up patch on disk now does two things:

- restores the turn re-press timing to `TURN_REPRESS_DELAY=18`
- makes the 2-frame turn re-press gap actively send neutral input (`joypad.set({}, ...)`)
  instead of passively waiting

This is paired with a manual-control fix:

- removed the newer survey/autowalk route suppression that ignored live D-pad input
  during active route steps

Unit coverage in `test_auto_step.lua` now checks:

- sequence-based re-press behavior
- explicit neutral frames during the release gap
- live manual input interrupting an active queued step even if the caller asked for
  autonomous routing

That patch was reloaded and then fully live-verified. The additional
`TURN_REPRESS_INJECT_LIMIT = INJECT_LIMIT` change fixed the previously failing
open-floor probe path:

- `freeze_npcs` + `clear_runtime_blocks` + `teleport_to:11,11`
- `probe_edge:LEFT` now moves successfully:
  `EDGE_PROBE_RESULT ... status=moved final=(10,11) reason=position_changed`
- `clear_runtime_blocks` + `teleport_to:10,14`
- `probe_edge:UP` now moves successfully:
  `EDGE_PROBE_RESULT ... status=moved final=(10,13) reason=position_changed`
- `clear_runtime_blocks` + `teleport_to:13,14`
- `probe_edge:LEFT` now moves successfully:
  `EDGE_PROBE_RESULT ... status=moved final=(12,14) reason=position_changed`

Fresh survey verification also looks healthy again:

- `report_survey_start:park_npcs` from `(10,14)` reported:
  `reachable_area=128 open_exit_count=4 status=viable`
- `survey_objects:park_npcs` now leaves the start square and records real
  early successes instead of immediate `command_timing_or_state_issue`
- confirmed successes so far:
  - `Person 1` (`npc_2`): `movement_succeeded=true final=(12,14)`
  - `Woman 1` (`npc_0`): `movement_succeeded=true final=(13,16)`
- `Merchant 1` (`npc_4`) was in progress at the last log read and was making
  real coordinate progress step by step

### Uncommitted changes in working tree

Current project changes from this session:

```
auto_step.lua       — restore 18-frame re-press timing; make release gap explicitly neutral; manual input can cancel routes again; use full inject window after turn-only repress
route_manager.lua   — stop forwarding autonomous route suppression to auto_step
map_survey.lua      — stop requesting autonomous route suppression for survey routes
test_auto_step.lua  — add neutral-gap + manual-override coverage; expect a full follow-up repress window after turn-only attempts
debug_tools.lua     — allow multi-frame simulate_input/simulate_raw_input holds (e.g. BTN,12) for live movement isolation
debug_hooks.txt     — document multi-frame simulate_input/simulate_raw_input syntax
```

### Open issues

1. **Fresh survey run may still be active**: read the latest `dw_debug.log`
   tail before sending more commands. At the last checkpoint read, the survey
   had confirmed successes for `Person 1`, `Woman 1`, and `Guard 7`, and was
   still progressing through `Old Man 1`.

2. **(12,16) east approach — MONITOR ONLY**: keep
   `MAP_DIRECTIONAL_BLOCKS[0x04]["12,16"].east = true`. Do not remove it as
   part of the movement-fix checkpoint.

3. **Gated west region on map 0x04**: `chest_0/1/2/3` and `Guard 4` at
   `(1-3, 13-15)` still need fresh interpretation now that movement is fixed.

## Best Resume Points

**First action next session:**
1. Reload Lua script in FCEUX
2. Read the latest `dw_debug.log` tail first; the fresh
   `survey_objects:park_npcs` run may still be active
3. If the survey is still running, let it continue and watch additional
   `SURVEY_RESULT` lines
4. If it stopped or needs a rerun, use:
   `./dw_commands.sh --replace clear_runtime_blocks teleport_to:10,14 report_position`
5. Then:
   `./dw_commands.sh --replace report_survey_start:park_npcs`
6. Then:
   `./dw_commands.sh --replace survey_objects:park_npcs`
7. Keep monitoring map `0x04` west-side targets (`Merchant 1`, Guard 4, chests)
   to distinguish genuine gating from remaining model gaps

**Do not:**
- Survey from the staircase tile (7,7) — now aborts cleanly, but pointless
- Remove the (12,16) east=true block
- Add directional blocks to (8,7) or (7,8) — engine blocks from staircase only, not model bugs
