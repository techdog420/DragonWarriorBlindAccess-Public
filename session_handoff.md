# Session Handoff — 2026-03-21

## What Was Accomplished This Session

### Bug 1: runtime_blocked infinite rerouting loop (FIXED & VERIFIED)
When `auto_step` timed out on an engine-blocked cell, `on_blocked` would
replan a path that still went through the blocked cell, causing a permanent
loop. Two root causes were fixed:

**pathfinder.lua**: `pathfind_to_adjacent()` and `pathfind_to()` built the
internal `blocked` table using only `ipairs` (array portion of npc_positions),
silently dropping string-keyed runtime_blocked entries. Added `for k,v in
pairs(npc_positions)` loop to copy string-keyed entries so A* actually sees
runtime-discovered engine blocks.

**main.lua**: `on_blocked` recorded destination cells as engine-blocked before
checking NPC positions. Added `objects.update_npcs()` before the record step
and an NPC presence check — if an NPC is standing at the destination, the
block is temporary (not an engine wall) and is skipped. Also added "no path
found" early-exit to cancel pathfinding when rerouting genuinely fails.

Verified end-to-end: first block records cell and reroutes avoiding it; second
block deduplicates (no re-record) and reroutes correctly; no infinite loop.

### Bug 2: Movement blocked + false menu detection at (14,2) (FIXED)
Player at (14,2) on map 0x04 was unable to move. TEMP DIAG logging revealed
`menu=true` continuously even with no menu open. Root cause: COMMAND_MATCH_LEN
was 6 ("COMMAN"). The 64-column NT0+NT1 scan (added for x>=13 fix) picks up
castle tile CHR data in NT1 that accidentally matches "COMMAN" ->
`is_command_menu_open()` returns true as a false positive -> `menu.is_open()=true`
-> `can_walk=false` -> no movement.

**Fix (menu.lua)**: Changed COMMAND_MATCH_LEN from 6 to 7 ("COMMAND"). The
full NT0+NT1 virtual scan always sees all 7 bytes of a real menu header; castle
tile CHR data never accidentally forms all 7.

### Bug 3: Command menu silent at y<=1 (FIXED)
When the player presses A to open the command menu while at player_y<=1, the
`CMD_OPEN_Y1` branch fired (correctly suppressing the announcement to avoid
map-tile false-positive COMMAN noise), but also suppressed it for genuine
physical A presses.

**Fix (main.lua)**: Added `tolk.output("Command.")` to `CMD_OPEN_Y1`. The
`a_just` guard (requires physical A press via joypad.read()) already prevents
this from firing on tile-noise false positives.

## Known Remaining Issues

### NPC movement / "There is no one there"
When pathfinding to an NPC, the player arrives at the planned adjacent cell,
but the NPC may have walked away during the journey. The player uses TALK and
gets "There is no one there." This is a structural limitation: NPC positions
are sampled at pathfind time, not continuously tracked during the walk.

Possible approaches:
- Verify that NPC freeze (`npc_freeze_active`) is correctly applied on initial
  pathfind to an NPC target (not only on reroute). Check `do_pathfind_to_current`
  in main.lua around lines 929+.
- After arriving at adjacent cell, check current NPC position and re-route if
  the NPC moved significantly.
- Accept as known limitation — user re-presses pathfind to re-acquire.

### Map 0x04 y=1 corridor (untested)
At y=1, x=10-14 are void (0-). Player can only be at x=1-9 or x=15-19. The
`CMD_OPEN_Y1` fix for "Command." announcement has not been physically tested
yet. Next session: navigate there and press A to verify.

### Woman NPC at (27,5) reachability
Pathfinder correctly chooses adj=(27,6) as approach cell. Issue is NPC movement,
not approach direction. Fixing NPC freeze on initial pathfind would resolve.

## File State at Commit

| File | Key Changes |
|------|-------------|
| main.lua | runtime_blocked table; on_blocked NPC exclusion + no-path cancel; CMD_OPEN_Y1 now speaks "Command."; runtime_blocked cleared on map change |
| menu.lua | COMMAND_MATCH_LEN 6->7 |
| pathfinder.lua | pairs() loop in pathfind_to_adjacent + pathfind_to to copy string-keyed blocked entries |
| auto_step.lua | on_blocked signature: now passes from_x, from_y, blocked_dir |
| map_reader.lua | MAP_BLOCKED_CELLS[0x04] with clean sweep data (64 entries) |
| debug_tools.lua | sweep NPC exclusion, abort persistence, various sweep fixes |
| config.lua | auto_step_timeout setting |
| dw_access.ini | debug_mode=true and updated settings |

## Next Session Priorities

1. **Test command menu at y=1** — navigate to y=1 corridor (x=1-9 or x=15-19)
   and physically press A. Verify "Command." is spoken.

2. **Investigate NPC freeze on initial pathfind** — check `do_pathfind_to_current`
   to confirm freeze is applied when target is NPC. If not, add it so NPCs stay
   put during the approach walk.

3. **Stress test east corridor** — navigate from (14,2) east toward woman NPC.
   With COMMAND_MATCH_LEN=7, movement should work without false menu blocking.

4. **Re-sweep map 0x04** — dw_blocks.log has 634 entries from tainted sweeps
   (pre-NPC-exclusion). A clean sweep gives definitive MAP_BLOCKED_CELLS data.
   Sequence: freeze_npcs -> sweep_map -> stop_sweep -> export_blocks.

## Debug Commands Quick Reference

```bash
./dw_commands.sh log_state             # full state snapshot
./dw_commands.sh report_position       # current x,y
./dw_commands.sh pathfind              # pathfind to current object
./dw_commands.sh next_object           # cycle NPC/exit/chest
./dw_commands.sh simulate_input:RIGHT  # inject east step (via inject_step)
./dw_commands.sh dump_grid             # walkability grid for current map
./dw_commands.sh freeze_npcs           # freeze NPCs in place
./dw_commands.sh unfreeze_npcs         # release freeze
```
