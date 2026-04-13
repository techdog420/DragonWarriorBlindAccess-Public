# Session Handoff — 2026-04-12

## Active Handoff Set

Start here:
- `HANDOFF_2026-04-12_survey_park_npcs_mode.md`

Also keep handy:
- `HANDOFF_2026-04-12_route_cleanup_and_west_bisection.md`
- `HANDOFF_2026-04-12_map04_command_timing_and_bisection.md`

Historical notes older than the current active set were moved to:
- `handoff_archive/`

## Current State

- survey-only parked-NPC mode is implemented and live:
  - `survey_map:park_npcs`
  - `survey_objects:park_npcs`
  - `survey_objects:retry_failed,park_npcs`
  - `survey_target:NAME,park_npcs`
  - `report_survey_start:park_npcs`
- parked mode currently parks all active non-target NPC slots rather than only
  decoded movers; this is intentional until the movement-behavior byte is
  understood confidently
- `survey_target` now resolves by:
  - exact id
  - numeric index
  - case-insensitive exact display name
  - unique case-insensitive partial id/name
- ambiguous partial matches now fail explicitly instead of guessing

## Recent Verified Results

- `survey_target:Guard 3,park_npcs` resolves live to `target_id=npc_6`
- `survey_target:Guard,park_npcs` fails cleanly with an ambiguous-target error
- parked-NPC restore was verified on both manual stop and normal completion
- stale permanent blocker `20,17` on map `0x04` was removed earlier in the day
- current west-wall picture still keeps `19,16` blocked and treats `20,17` as
  open

## Best Resume Points

For survey work:
- compare `survey_map` versus `survey_map:park_npcs`
- if parked mode surfaces a new blocker candidate, repro it directly before
  promoting map data

For Tantegel Castle `0x04` boundary follow-up:
- use the split-command teleport/probe pattern from
  `HANDOFF_2026-04-12_map04_command_timing_and_bisection.md`
- compare against the older chamber notes in
  `handoff_archive/HANDOFF_2026-03-24_castle_chamber_probe.md`
