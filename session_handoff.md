# Session Handoff - Active Resume

Updated: 2026-05-25

This file is the short current resume point. Detailed Tantegel Castle map 0x04
evidence from the shrine/key-merchant dig is archived at:

- `handoff_archive/HANDOFF_2026-05-25_tantegel_map04_wrapup_session_handoff_full.md`
- `handoff_archive/HANDOFF_2026-05-25_tantegel_investigation_scratchpad.md`
- `handoff_archive/HANDOFF_2026-05-22_pre_cleanup_session_handoff_full.md`

## Current Direction

- Player-facing gameplay is FCEUX-first.
- BizHawk remains the explicit automation/debug/reload-heavy runtime.
- Active gameplay location is Sun Shrine map `0x0C`, currently parked on the
  opened chest tile `(4,5)` after collecting the Stones of Sunlight.
- Tantegel Castle map `0x04` is gameplay-usable and parked for now.
- Return through `Stairs to Tantegel Castle`, then continue normal
  gameplay/playtesting.
- Do not reopen broad map `0x04` blocker hunting just because a route is noisy.
  Promote more map data only after clean post-reload verifier or manual
  movement evidence.
- Codex is the primary implementation/debugging agent. Claude is mainly a
  limited-bandwidth second-eyes reviewer; keep active state in repo docs.

## Tantegel Route Status

- `Sun Shrine Stairs and Southeast Exit` at `(29,29)` works. The route is still
  a bit noisy around the complicated shrine approach, but the user manually
  validated routes between the throne-room stairs, castle entrance, and shrine
  stairs. The shrine is a rare/one-time destination, so this is acceptable for
  now.
- `Magic Key Merchant` at `(24,3)` works again from the entrance/exit side.
  Latest route readback completed at `(11,29)` with
  `PATH_STATE target=nil` and `RUNTIME_BLOCKS map=0x04 none`.
- The map `0x05` king is now a service target for save-game visits.
- Map `0x04` exposes a single combined travel object for the shared southeast
  tile: `Sun Shrine Stairs and Southeast Exit`, id `stair_29_29`.

## Sun Shrine Status

- Map `0x0C` is the Stones of Sunlight chamber.
- User confirmed the west-edge return stairs go back to Tantegel interior, not
  the world map. `objects.lua` now labels the object at `(0,4)` as
  `Stairs to Tantegel Castle`.
- `MAP_PASSTHROUGH_CELLS[0x0C]` keeps `(0,2)`, `(0,4)`, and manually proven
  `(0,7)` open despite the generic x=0 interior boundary rule.
- Objects: `Stairs to Tantegel Castle` `(0,4)`, `Chest` `(4,5)`, stationary
  `Old Man` `(4,6)`.
- Survey from `(1,7)` reached the old man and chest. The old man blocks the
  chest's south side only; chest routing itself succeeds by standing on
  `(4,5)`.
- A quick entrance/west-edge validation route to the old man drifted heavily
  around row 7, including repeated reroutes through `(3,7)`/`(4,7)`/`(5,7)`,
  but eventually reached TALK position `(4,7)`, faced north, and opened old-man
  dialogue. Treat this as noisy route execution, not map blockage.
- The chest was opened and logged `Fortune smiles upon thee, Bill. Thou hast
  found the Stones of Sunlight.` Current live state: `map=0x0C x=4 y=5`,
  `OBJECT: Chest (opened): here`, `PATH_STATE target=nil`, and
  `RUNTIME_BLOCKS map=0x0C none`.
- The only survey failure was the return-stairs target, classified as
  command-timing/route-drift noise rather than no-route or engine blockage.

## Durable Fixes From This Wrap

- `route_manager.lua` keeps autowalk NPC parking mode consistent across initial
  plans, drift reroutes, blocked-step reroutes, and follow-up route planning.
- Pending NPC restore slots are merged into fresh autowalk parking so a new
  route does not reintroduce mobile NPC blockers.
- Shrine final-approach guard logs `AUTO_WALK_FINAL_APPROACH_AVOID` and avoids
  the risky long x=29 south descent into `(29,29)` without changing permanent
  map data.
- `MAP_PASSTHROUGH_CELLS[0x04]["11,29"]` keeps the south-gate false wall
  standable so key-merchant routes reconnect to the lower entrance lane.
- `MAP_DIRECTIONAL_BLOCKS[0x04]` now closes only the confirmed north approaches
  into `(16,16)` and `(17,16)`, while leaving those cells standable.
- `debug_tools.lua` emits a raw neutral joypad frame when the internal or
  external keyboard bridge transitions from active to clear. This prevents
  sticky scripted D-pad state after FCEUX focus/menu weirdness.
- `recover_fceux_input.ps1` restarts the `keyboard_bridge.ps1` sidecar if it is
  missing, and `input_status` reports bridge-file state after Lua reload.
- `reload_navigation_modules` now refreshes `objects`, `path_debug`,
  `map_survey`, and `map_crawler` in addition to `map_reader` and `pathfinder`.
  A running Lua session needs one full script reload before this broader hook is
  available.

## Watch Items

- Remaining map `0x04` route noise has appeared around cells such as `(23,9)`,
  `(24,9)`, `(18,14)`, `(18,15)`, `(24,10)`, `(25,6)`, `(17,6)`, and `(15,5)`.
  Do not promote those to permanent map data without clean post-reload verifier
  evidence.
- The shrine and key-merchant routes may still bounce or drift-recover. Treat
  successful completion with no persisted runtime blockers as good enough.
- Sun Shrine row-7 routing can drift a lot, especially around `(3,7)` through
  `(5,7)`, but current evidence shows eventual completion and no runtime
  blocks. Do not promote noisy row-7 drift into map blockers.
- If FCEUX controls wedge, try `clear_input` or `./recover_fceux_input.sh`.
  After the bridge-release patch is loaded, active-to-clear input transitions
  should send their own neutral release frame.
- `dw_crawl_04.txt` is still an untracked crawler/export artifact. Leave it
  alone unless the user asks to review or archive crawler output.

## Verification Already Run

- `luac5.1 -p main.lua map_reader.lua test_map_reader.lua objects.lua test_objects.lua map_survey.lua`
- `lua5.1 test_map_reader.lua` passed 38 tests
- `lua5.1 test_objects.lua` passed 68 tests
- `luac5.1 -p debug_tools.lua test_debug_tools.lua map_reader.lua test_map_reader.lua route_manager.lua test_route_manager.lua objects.lua test_objects.lua`
- `lua5.1 test_debug_tools.lua` passed 8 tests
- `lua5.1 test_map_reader.lua` passed 37 tests
- `lua5.1 test_route_manager.lua` passed 90 tests
- `lua5.1 test_objects.lua` passed 68 tests
- `git diff --check` passed, with the existing `dw_access.ini` CRLF warning

## Suggested Next Step

From the current Sun Shrine state, route back to `Stairs to Tantegel Castle`.
Only return to map `0x04` blocker hunting if a route fails to finish, exits the
map unexpectedly, leaves runtime blocks behind, or blocks on a cell the player
can manually verify.
