# Handoff - 2026-04-28 playability pivot and map 0x05 follow-up

## Summary

Brecconary/map `0x08` is now clean enough to stop treating it as the primary
blocker-hunting focus.

Latest reliable Brecconary result:

`SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=12 failures=9 no_route=0 gated_or_isolated=9 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0`

Follow-up confirmed:
- `RUNTIME_BLOCKS map=0x08 none`
- `SURVEY_STRONG_CANDIDATES map=0x08 none`
- remaining failed objects are NPCs in clean gated/isolated regions, not doors,
  stairs, chests, or blocker candidates
- the live final position `(10,25)` is an isolated southwest pocket; do not run
  broad surveys or `retry_failed` from there

Conclusion:
- no Brecconary `map_reader.lua` patch is justified
- if revisiting Brecconary, start from a deliberate open/central position and
  focus on object classification rather than hidden-block discovery

## New Direction

The project now has enough map data decoded to begin actual playtesting and
quality-of-life work. Prefer fun, player-facing accessibility improvements when
the user asks for them, rather than continuing broad speculative map surveys.

Map `0x05` remains a good target for further blocked-cell learning. The user
expects to let a faster model investigate the remaining engine-blocked cells
there and plans to move to the first map / castle area and start a fresh survey.

Note:
- The repo has historically referred to map `0x04` as the live Tantegel Castle
  map and map `0x05` as the Tantegel Throne Room/interior. If the user says
  "first castle map, 05", confirm the live `POSITION`/map id from logs before
  patching permanent data.

## Best Resume Point

- Treat `session_handoff.md` as canonical.
- Wait for the user's fresh survey/log output before analyzing map `0x05`.
- For map `0x05`, continue to require direct probe or repeated route-context
  evidence before changing permanent blocked-cell data.
- For gameplay/QoL work, inspect the existing command, speech, object, and
  route-manager paths first and keep changes tightly scoped.
