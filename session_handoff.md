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

### Uncommitted changes in working tree

All of these were tested in previous sessions (2026-04-13/14) plus today's fix.
Ready to commit:

```
CLAUDE.md           — project notes updates
auto_step.lua       — overshoot/timing fixes
main.lua            — grace period, title screen, dialogue filtering
map_reader.lua      — row-16 directional blocks + passthrough cells
map_survey.lua      — park_npcs cache fix + today's abort fix
route_manager.lua   — minor adjustment
test_map_reader.lua — new tests for row-16 model
```

### Open issues

1. **(12,16) east approach — MONITOR ONLY**: keep `MAP_DIRECTIONAL_BLOCKS[0x04]["12,16"].east = true`. EDGE_PROBE_MODEL_MISMATCH fired once (moved through block) but 5/6 probes blocked. Do not remove.

2. **stair_1_1 route still long**: A* takes 63 steps from ~(10,14) to (1,1). May have improved after row-16 fixes — untested.

3. **Gated west region on map 0x04**: chest_0/1/2/3 and Guard 4 at (1-3, 13-15) consistently `gated_or_isolated_region`. Unclear if true game gating (treasure room key) or model gap.

## Best Resume Points

**First action next session:**
1. Commit the working tree (see handoff doc for suggested message)
2. Reload Lua script in FCEUX
3. Teleport to an open floor tile on map 0x04 (e.g., `teleport_to:10,14`)
4. Run `echo report_viability > dw_commands.txt` — confirm open_exit_count >= 3
5. Run `echo survey_objects:park_npcs > dw_commands.txt`
6. Watch for Guard 1 (npc_1) and stair_1_1 route lengths — check if row-16 fixes helped

**Do not:**
- Survey from the staircase tile (7,7) — now aborts cleanly, but pointless
- Remove the (12,16) east=true block
- Add directional blocks to (8,7) or (7,8) — engine blocks from staircase only, not model bugs
