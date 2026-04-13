# Handoff: Tantegel Castle (0x04) Survey Progress
Date: 2026-04-09 evening session

## What Was Accomplished

Multiple survey passes on map 0x04, iteratively fixing engine-blocked tiles. Started with ~6/30 survey successes and massive runtime_block cascades. Ended with 0 suspected_engine_blocked per pass (no more cascades), with 8/30 successes and 22 clean gated_or_isolated failures.

**All 6 test scenarios still pass** (spawn_to_stairs_up, spawn_to_south_hall, east_wing_to_guard, north_to_south, east_wing_to_south, stairs_to_exit).

## Blocks Added This Session (map_reader.lua)

### MAP_BLOCKED_CELLS[0x04] — new full blocks
- `["12,17"] = true` — engine blocks, confirmed by survey; forced A* to route via x=17-20 corridor
- `["12,18"] = true` — same as above

### MAP_DIRECTIONAL_BLOCKS[0x04] — new/updated entries

**x=12 column (y=19):**
- `["12,19"]` updated from `{south=true}` to `{south=true, east=true}` — survey run4 confirmed east approach also blocked

**x=4 east wall — west wing interior boundary (y=10-14):**
- `["4,10"] = {east=true}` — survey run5, count=5 high
- `["4,11"] = {east=true}` — survey run5, count=5 high
- `["4,12"] = {east=true}` — survey run5, count=5 high
- `["4,13"] = {east=true}` — survey run5, count=6 high, retry_successes=1
- `["4,14"] = {east=true}` — survey run5, count=5 high

**x=6 east wall — now fully bidirectional (y=11-16):**
- `["6,11"]` updated to `{east=true, west=true}` — west approach was causing oscillation
- `["6,13"]` updated to `{east=true, west=true}` — same
- `["6,14"]` updated to `{east=true, west=true}` — survey run7, count=2, retry_successes=2
- `["6,15"]` updated to `{east=true, west=true}` — survey run7, count=2, retry_successes=2
- `["6,16"]` updated to `{east=true, west=true, south=true}` — survey run7, added west

## Current Map 0x04 State

### x=6 Wall Architecture (IMPORTANT)
The x=6 column is now a full bidirectional wall from y=6 to y=16 EXCEPT for y=9:
- y=6, 7, 8, 10: full MAP_BLOCKED_CELLS (impassable from all directions)
- y=9: **valid crossing point** — NOT blocked in either direction; only route into west wing
- y=11: east=true, west=true
- y=12: east=true (medium confidence, only one direction confirmed so far)
- y=13, 14, 15: east=true, west=true
- y=16: east=true, west=true, south=true

### x=4 Wall Architecture
x=4 east wall blocks the west wing interior from y=9 to y=16:
- y=9: east=true, north=true
- y=10-14: east=true (new this session)
- y=15: east=true
- y=16: east=true, south=true

## Pending — First Task Next Session

**The last edit was applied and the script reloaded, but survey pass 8 was NOT run yet.**

1. Run `test_path` to confirm 6/6 still pass
2. Run `freeze_npcs` + `survey_map` for pass 8
3. Analyze results — expect the gated_or_isolated cascade from (5,21) to break now that x=6 y=14-16 is bidirectional

## Known Remaining Failures (from last survey)

22 gated_or_isolated, 0 suspected_engine_blocked. Failure starts:
- **(5,21)**: 19 failures — all gated_or_isolated, no suspected tiles. Player was in west wing south area; couldn't reach main hall, east wing, south exit, or NE wing targets.
- **(5,12)**: 3 failures — chests at (1,13), (2,14), (3,15). These are deep west wing chest room; likely need a separate start position or the chests are behind additional blocks not yet discovered.

## Survey Oscillation Bug (Important Pattern to Watch)

If survey hangs on a target and you see `blocked_tiles` log alternating between 2 cells many times:
- This is the oscillation bug: two routes each blocked from one direction, runtime_blocks partially clearing between reroutes
- `stop_survey` to abort, then check `export_directional_candidates`
- The fix: add the missing approach direction to the oscillating cells
- Example from this session: (6,11) and (6,13) had east=true but not west=true; adding west=true stopped the infinite loop

## Next Maps After 0x04

Once survey converges on map 0x04, move to:
1. Map 0x05 (Throne Room) — 5 test scenarios already pass; may need survey to find remaining blocks
2. Map 0x08 (Brecconary) — 4 test scenarios pass; 10 gated_or_isolated failures from last survey (likely building-interior access issues)
3. Dungeon maps — expected to be simpler than towns
