# Handoff: Teleport Command + Priority 1 Closed + Open Issues
Date: 2026-04-11

## What Was Accomplished

### 1. `teleport_to` debug command shipped (commit 6b0d528)
Same-map teleport with three modes, registered in `main.lua` near other debug
commands. Files touched:
- `main.lua` — new `teleport_to` command (~150 lines, near `unfreeze_npcs`)
- `dw_commands.sh` — added Teleport section to help header
- `debug_hooks.txt` — added TELEPORT (DEBUG) section

Usage:
```
teleport_to:X,Y             # exact — refused if target not walkable
teleport_to:X,Y,near        # exact, or first walkable cardinal/diagonal neighbor
teleport_to:X,Y,force       # skip walkability check (unstick/debug)
```

Search order for `near` mode: N, E, S, W, NE, SE, SW, NW (first walkable wins).

**Safety guards** (all modes refuse on any of):
- not STATE_FIELD
- active sweep (`debug_tools.is_sweep_active`)
- step mode (`path_debug.is_step_mode`)
- command menu open (`menu.is_open`)
- any submenu / merchant screen
- dialogue active (`prev_dialogue` or `upper_dialogue_active`)
- active auto-walk route (`auto_step.is_route_active`)
- active edge probe (`edge_probe_state ~= nil`)
- active map survey (`map_survey.is_active`)
- out of map bounds (from `map_reader.get_map_dimensions`)

**RAM writes:**
- `0x003A` (PLAYER_X), `0x003B` (PLAYER_Y) for all maps
- Also `0x0042` (OVERWORLD_X), `0x003E` (OVERWORLD_Y) when `map_id == 0x00`

**Also calls** `auto_step.cancel_active_step(true)` before the write so no
pending step/repress injects motion from the old position.

**Verified in-session on Map 0x04:**
- `teleport_to:7,7` → exact teleport to staircase succeeded
- `teleport_to:14,19` → refused with `(14,19) not walkable (tile=0x06); use near or force`
- `teleport_to:14,19,near` → landed at (14,18) "north of (14,19)"
- `teleport_to:99,99` → refused with `(99,99) out of bounds (map 30x30)`
- `teleport_to:14,19,force` → successfully stranded player on wall cell

### 2. Priority 1 (south corridor false positives) — CLOSED
Probed with `probe_edge` from east side:

| Cell | Tile | East-approach result | Retries |
|---|---|---|---|
| (14,19) | 6  | blocked | 3/3 failed |
| (14,20) | 4  | blocked | 3/3 failed |
| (12,17) | 4  | blocked | 3/3 failed |
| (12,18) | 6  | blocked | 3/3 failed |

**All four are genuine engine walls, NOT false positives** from the tainted
2026-03-23 sweep. The hypothesis that removing them would open east-west
crossing in the south corridor is disproven. No code changes needed.

Notable: (14,20) and (12,17) are tile=4 (floor) but engine-blocked — this
contradicts the usual "floor tile blocked = sweep false positive" heuristic,
so that rule has exceptions on Map 0x04. Do not auto-remove tile-4 blocks.

### 3. Priority 2 (west wing exit path) — PARTIALLY INVESTIGATED
From (13,17) the pathfinder:
- ✅ reaches (17,19) via "1 south, 4 east, 1 south"
- ❌ does NOT reach antechamber (7,9), west wing, (13,12), (17,12), (21,20), (15,20)

There is a **second isolation boundary at the y=13-17 band** cutting the
middle castle from the staircase area. Root cause unknown. See open issue #2
below for the leading hypothesis.

---

## Open Issues (all captured in memory/project_open_issues.md)

### Issue 1: Auto-step hop-over bug (MOVEMENT)
Pressing a single direction key sometimes moves the player 2 tiles instead of 1.
Confirmed live: pressed DOWN once at (13,18) and landed at (13,20), skipping
(13,19). Had to press UP to come back.

**Trace signature** (dw_debug.log):
```
begin_step dir=down from=(13,18) timeout_retries=0 turn_represses=0 inject_limit=12
schedule turn repress dir=down from=(13,18) frame=18
begin_step dir=down from=(13,18) turn_represses=1 inject_limit=4
... (player is now at 13,20)
begin_step dir=up from=(13,20) ...
```

**Suspected cause:** In `auto_step.lua`, after a first step completes, the held
button is not released fast enough before the `turn_repress` re-arm path. The
engine consumes the still-held button for a second 16-frame walk window before
the repress logic gets a chance to cancel/replace it.

**Entry points to inspect:**
- `auto_step.begin_step` — especially the `inject_limit=12` path
- `auto_step.update` — the turn_repress handler
- Field `tracked_dir` / `press_start_x` / `press_start_y` and how `update()`
  decides to continue vs stop

**Repro plan** (once teleport is available, trivial to reproduce):
```
freeze_npcs
teleport_to:13,18
simulate_input:DOWN
report_position      # expected (13,19); bug = (13,20)
```
Need multiple runs because it's intermittent. Might correlate with frame offset
between tap and frame advance.

### Issue 2: (13,16) tile reader discrepancy on Map 0x04
Player successfully walked to (13,16) via `simulate_input:UP`, but
`inspect_tile:13,16` reports **tile=11 (solid wall), base_walkable=false,
walkable=false**.

**Why it matters:** this may be the root cause of the y=13-17 isolation band.
If the tile grid has a decoding error here (or similarly for other cells in
the band), the pathfinder sees walls where the engine allows passage, and the
survey reports 24 `gated_or_isolated` failures.

**Hypothesis A — tile grid decode error:**
`map_reader.get_tile_grid(0x04)` uses RLE decompression starting from the ROM
metadata pointer. Off-by-one in row-start offsets, an RLE run miscount, or a
nibble-swap at a specific tile index could put wrong tile types in the grid
starting at some cell. Worth dumping the grid for y=13-17 and checking for
patterns (e.g., alternating rows shifted by 1).

**Hypothesis B — tile 11 context-dependent walkability:**
The walkability table marks tile 11 as wall globally, but there may be
per-map exceptions (like how Brecconary tile 1 is walkable but Tantegel tile 1
may not be). Less likely because tile 11 is described in MEMORY as "solid
wall" with no exceptions recorded — but not impossible.

**Repro plan with teleport:**
```
teleport_to:13,16,force       # stand ON the questionable cell
probe_edge:up                 # can we leave north?
teleport_to:13,16,force
probe_edge:down
teleport_to:13,16,force
probe_edge:left
teleport_to:13,16,force
probe_edge:right
```
If ANY direction succeeds, the cell is engine-walkable and the tile reader is
wrong. Then expand the probe to (12,16), (14,16), (13,13)..(13,17) to map the
true walkable extent of the y=13-17 band.

**Secondary check:** `dump_grid` for Map 0x04 and look for tile 11 clusters at
y=13-17 where the game actually allows movement.

### Issue 3: Map 0x04 dimensions discrepancy
`map_reader.get_map_dimensions(0x04)` returns **30x30** (visible in the
teleport out-of-bounds error), but MEMORY.md says Tantegel Castle is **29×29
empirically confirmed**.

Low impact — bounds checks with 30x30 are looser (allows one extra row/col of
queries). But suggests either the ROM metadata decoder or the empirical
measurement is wrong. 

**Resolution:**
- Read ROM metadata at `0x002A + (5 * 0x04)` = `0x003E` (5 bytes per map entry).
- Bytes 3 and 4 of the entry are width and height.
- If ROM says 30x30, MEMORY is wrong → update MEMORY line for 0x04.
- If ROM says 29x29, the decoder is wrong → fix `map_reader.get_metadata`.

### Issue 4 (informational, not a bug): Confirmed genuine castle walls
Record — do not re-probe unless evidence suggests they changed:
- (14,19): east approach blocked, tile=6, in MAP_BLOCKED_CELLS
- (14,20): east approach blocked, tile=4, in MAP_BLOCKED_CELLS
- (12,17): east approach blocked, tile=4, in MAP_BLOCKED_CELLS
- (12,18): east approach blocked, tile=6, in MAP_BLOCKED_CELLS

---

## Prior Session Carry-over (NOT yet committed)

These files had uncommitted modifications from the 2026-04-10 session that
I intentionally left in place when committing the teleport change:
- `map_reader.lua` — (6,9) west block + (6,12) east+west from 2026-04-10
- `map_survey.lua` — diagnostic `build_path_blocking` calls with `skip_npcs=true`
- `route_manager.lua` — `build_path_blocking` accepts `{skip_npcs=true}` option
- `path_debug.lua` — minor (unverified this session)

These are already covered in HANDOFF_2026-04-10_survey_npc_skip.md and
`feedback_npc_pathfinding.md`. They work and tests pass; decision pending on
when to commit them. Next session should decide whether to commit them
separately or bundle with other Map 0x04 work.

---

## Recommended Next Session Flow

1. **Quick sanity check** — reload script, run `test_path` on Map 0x04, verify
   6/6 scenarios still pass.

2. **Issue 2 first** (highest value): use teleport_to to directly probe
   (13,16) and nearby cells in the y=13-17 band. If the tile reader is wrong,
   fixing it could collapse the y=13-17 isolation and turn 24 survey failures
   into successes.

3. **Issue 1 second** (easy repro, scoped fix): use teleport to stand on (13,18)
   and simulate DOWN multiple times to reproduce the hop-over bug reliably.
   Fix in `auto_step.lua`.

4. **Issue 3** (cheap): verify ROM metadata for Map 0x04 dimensions and
   update MEMORY or the decoder.

5. **Run full Map 0x04 survey** after fixes to measure improvement.

---

## Key Commands Cheat Sheet

```bash
# Position / state
./dw_commands.sh report_position
./dw_commands.sh log_state
./dw_commands.sh inspect_tile:X,Y

# Teleport (new this session)
./dw_commands.sh teleport_to:X,Y             # exact
./dw_commands.sh teleport_to:X,Y,near        # fallback to neighbor
./dw_commands.sh teleport_to:X,Y,force       # bypass walkability check

# Edge probing (reliable engine test)
./dw_commands.sh probe_edge:DIR               # DIR = UP|DOWN|LEFT|RIGHT
./dw_commands.sh probe_edge:X,Y,DIR           # must be standing there
./dw_commands.sh stop_probe_edge

# Pathfinding tests
./dw_commands.sh test_path                    # all scenarios for current map
./dw_commands.sh pathfind_to:X,Y
./dw_commands.sh debug_pathfind_to:X,Y        # verbose

# Survey
./dw_commands.sh freeze_npcs                  # always before survey/sweep
./dw_commands.sh survey_map
./dw_commands.sh report_survey_findings
./dw_commands.sh unfreeze_npcs

# Logs
tail -f dw_debug.log
```

Reload Lua: FCEUX → Script → Reload (no remote equivalent).

---

## Files Modified This Session
- `main.lua` — added `teleport_to` command (committed)
- `dw_commands.sh` — Teleport section in help (committed)
- `debug_hooks.txt` — TELEPORT (DEBUG) section (committed)
- memory/MEMORY.md — compressed older entries, added teleport reference, updated Map 0x04 status
- memory/project_open_issues.md — NEW, captures 4 open issues with repro/cause

## Git
- Working on branch `master`
- Last commit: `6b0d528 Add teleport_to debug command with exact/near/force modes`
- Uncommitted prior-session work still present (see "Prior Session Carry-over" above)
