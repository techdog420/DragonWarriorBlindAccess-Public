# Handoff: Survey Park-NPCs Mode
Date: 2026-04-12

## What Changed

Added an explicit survey-only parked-NPC mode for reducing NPC movement noise
without changing normal `auto_walk` behavior.

New command forms:

```bash
./dw_commands.sh survey_map:park_npcs
./dw_commands.sh survey_objects:park_npcs
./dw_commands.sh survey_objects:retry_failed,park_npcs
./dw_commands.sh survey_target:npc_6,park_npcs
./dw_commands.sh report_survey_start:park_npcs
```

## Behavior

- Parked mode is survey-only. Normal `survey_map`, `survey_target`, and
  `auto_walk` remain unchanged.
- At survey start, eligible non-target NPCs are moved to `(31,31)` so they
  disappear from the active blocker map for the run.
- When the current survey target is an NPC:
  - that target slot is restored before its attempt starts
  - all other eligible NPCs remain parked
- NPCs are restored to their original survey-start bytes when the survey
  finishes or is manually stopped.
- On map change, the parked state is cleared without writing the old map's NPC
  bytes back into the new map's RAM.

## Important Assumption

The mode currently parks all active non-target NPC slots, not just
"definitely mobile" NPCs.

Why:
- the movement-behavior byte exists in RAM
- but the repo still does not decode those behavior values confidently enough
  to distinguish "mobile" from "stationary" without risk

This is acceptable because:
- the feature is explicit and survey-only
- its purpose is map/path validation, not faithful live gameplay

If we later decode movement behavior cleanly, the parked-set can be narrowed to
true movers only.

## Implementation Notes

- `map_survey.lua`
  - parses `park_npcs` survey arguments
  - owns parked-NPC capture/apply/restore state
  - logs:
    - `SURVEY_NPC_PARK_START`
    - `SURVEY_NPC_PARK_TARGET`
    - `SURVEY_NPC_PARK_RESTORE`
- `main.lua`
  - now calls `map_survey.apply_npc_parking()` after
    `route_mgr.apply_npc_freeze()` each frame
- `dw_commands.sh` and `debug_hooks.txt`
  - document the new explicit survey command forms

## Verification

Passed locally:

- `lua test_map_survey.lua`
- `lua test_route_manager.lua`
- `lua test_map_reader.lua`
- `lua test_objects.lua`
- `lua -e 'assert(loadfile("map_survey.lua")); assert(loadfile("main.lua"))'`

New focused regression coverage:

- parked mode parks non-target NPCs and restores them on completion
- parked mode re-targets the exempt live NPC as the survey queue advances

## Best Live Verification

Reload the Lua script in FCEUX first, then compare:

```bash
./dw_commands.sh --replace freeze_npcs report_survey_start
./dw_commands.sh --replace freeze_npcs survey_map
```

against:

```bash
./dw_commands.sh --replace report_survey_start:park_npcs
./dw_commands.sh --replace survey_map:park_npcs
```

Most useful things to compare in `dw_debug.log`:

- `SURVEY_START_STATUS`
- `SURVEY_COMPLETE`
- count of `SURVEY_NPC_BLOCKED_ROUTE`
- whether previously NPC-clogged targets now complete cleanly
- whether new runtime blocks still look conservative and retry-backed
