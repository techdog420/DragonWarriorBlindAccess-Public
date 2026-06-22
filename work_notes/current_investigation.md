# Current Investigation Scratchpad

Updated: 2026-06-21

No active investigation is in progress.

The 2026-06-19 through 2026-06-21 `sweep_walk` break-in and hostile-area
validation has wrapped. Detailed live evidence was archived here:

- `handoff_archive/HANDOFF_2026-06-21_sweep_walk_break_in_scratchpad.md`
- `handoff_archive/HANDOFF_2026-06-19_sweep_walk_break_in_handoff.md`

Use `session_handoff.md`, `PLAYTESTING.md`, and `PROJECT_MEMORY.md` for
durable current state.

## Sweep Walk Break-In Summary

- `sweep_walk` is now the preferred normal-movement sweep command. It writes
  `sweep_status.txt` while active and final `sweep_walk_MM_runNNN.json`,
  `sweep_walk_MM_runNNN_summary.txt`, and `dw_crawl_MM.txt` review output on
  finish. The generated status/JSON/summary files are ignored.
- Garinham and Tantegel live runs covered larger safe areas without trusted
  teleport-backed blocker exports. Remaining noisy observations were kept in
  review-only timing-suspect, unstable-origin, door-frontier, boundary, or
  dynamic buckets unless same-origin walked verification supported a map patch.
- Swamp Cave hostile validation proved the battle-interruption exit path:
  random encounters stop the active sweep with `reason=battle_interrupted` and
  `source_classification=battle_interrupted`. For now, resume manually by
  starting a new sweep after combat returns to field control.
- Resume-from-JSON support is intentionally deferred. Field use should prove a
  real need before adding pause/resume complexity.
- User-observed `stop_sweep` behavior is good enough for this cleanup pass; the
  final live check was not repeated.

## Durable Bugs Fixed During Break-In

- Debug teleports now synchronize logical player coordinates with screen and
  sprite-position RAM through `teleport_state.lua`, reducing split-state
  failures after `teleport_to`.
- `speech_bridge.py` dispatches speech on a worker so a blocking screen reader
  call cannot stop command-file polling.
- Field/menu/dialogue scanning now suppresses scrolling status/name artifacts
  without relying on hard-coded hero names such as Bill or Ivy.
- `auto_step.lua` force-releases script-owned D-pad state on live-direction
  cancellation and map-crawl step cleanup paths, reducing sticky-input hangs.
- `map_crawler.lua` no longer resets movement RAM during sweep step completion
  or settle cleanup. Hostile Swamp Cave reruns after this change kept player
  stats clean across encounter interruptions.

## Next Work

- Local verification and CodeRabbit review passed on the cleaned diff.
- Resume normal gameplay/playtesting from the current save.
- Treat future sweep JSON as review evidence only. Promote map data only after
  walked same-origin confirmation or similarly strong live evidence.

For the next live map task, start a new dated section here with:

- current map id, floor, and player position
- exact target/object being investigated
- runtime blockers injected during the session
- evidence that is still uncertain or should not be promoted
- evidence that has been promoted to permanent map data
