# Travel warning scope

The Announcements Travel warnings toggle uses `travel_warnings=true` by
default. Only the literal saved value `true` enables travel warning speech.

## Controlled messages

- Manual tile stepping: "Dangerous tile ahead" and hazard-specific
  "ahead. Press [direction] again to enter" prompts.
- Pathfinding and auto-walk: unsafe-route and no-safe-route warnings,
  hazard summaries, and instructions to cross hazards manually.
- Recovery auto-walk: hazard-bearing start messages and detailed refusal previews.
- Hazard boundaries reached during routes, rerouting, and seam recovery.
- Dangerous-tile auto-walk cancellation messages.
- Light changes, the darkness description appended on dungeon entry, and
  auto-walk stops when the remaining route is outside the current light.
- Warning-bearing route events delivered by the main gameplay loop.

These use `tolk.output_travel_warning` in `auto_step.lua`, `route_manager.lua`,
and `main.lua`. Route events retain arrival, handoff, and ordinary waypoint
feedback separately from optional warning text, so muting a hint cannot
silence destination arrival.
Dungeon-entry map names remain spoken even when the darkness suffix is muted.

## Unchanged behavior

Required swamp-crossing confirmation prompts remain audible even when Travel
warnings is Off. They still wait for input release, tell the player auto-walk
stopped, and explain that pressing auto-walk again confirms the crossing.
Recovery refusal feedback also remains audible. With warnings Off it gives a
short explanation and manual-rejoining instruction instead of the detailed
hazard preview. Low-health warnings retain their separate setting. Ordinary route status,
arrival, progress, player-requested cancellation feedback, non-hazard route
failures, and explicit debug/preview reports remain available. Muting does not
change planning, hazard confirmation, collision checks, or darkness stops.

Travel records retain deferred delivery after input release. Turning the
setting Off removes pending travel records while preserving other warnings
and their order. Turning it On permits new warnings without replaying old ones.

## Validation

The full Windows gate passes 39 Lua suites and 68 Python tests. Queue tests
cover cancellation of multiple travel records, preservation of health speech,
muted submission, and re-enabling without replay. Live menu saving passed;
live runtime mute passed from Kol to Swamp Cave. Hazard stops and confirmation
remained active with no warning queued/delivered events. Live re-enable testing
passed with Radiant expansion and dimming. The retained speech wrapper now
reads the current config instance after Lua reloads.

## Poison-swamp recovery

Off-network recovery can now approach poison swamp and use the existing
second-press confirmation at its boundary. Confirm within ten seconds, from
the same tile and direction, for the same route and destination. Authorization
covers the contiguous swamp crossing and clears on safe terrain, map changes,
manual cancellation, or expiry. Other hazard types still refuse recovery.
Recovery stops at its checkpoint or network entry before guided travel resumes.
Required confirmation and refusal feedback remains audible with alerts Off.

Source tests cover recovery with alerts On and Off, first-press protection,
second-press authorization, and rejection of other hazardous terrain. Live
recovery acceptance passed from `(85,112)` to `(85,113)`, then arrival at the
search area, with Travel warnings Off. The restored keyboard helper allowed
first-press and confirmation speech after the normal 12 neutral frames.
