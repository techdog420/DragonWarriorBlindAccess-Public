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
- Tantegel Castle map `0x04` is gameplay-usable and parked for now.
- Move to the next normal gameplay/playtesting pass unless a live route fails
  again.
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

## Watch Items

- Remaining map `0x04` route noise has appeared around cells such as `(23,9)`,
  `(24,9)`, `(18,14)`, `(18,15)`, `(24,10)`, `(25,6)`, `(17,6)`, and `(15,5)`.
  Do not promote those to permanent map data without clean post-reload verifier
  evidence.
- The shrine and key-merchant routes may still bounce or drift-recover. Treat
  successful completion with no persisted runtime blockers as good enough.
- If FCEUX controls wedge, try `clear_input` or `./recover_fceux_input.sh`.
  After the bridge-release patch is loaded, active-to-clear input transitions
  should send their own neutral release frame.
- `dw_crawl_04.txt` is still an untracked crawler/export artifact. Leave it
  alone unless the user asks to review or archive crawler output.

## Verification Already Run

- `luac5.1 -p debug_tools.lua test_debug_tools.lua map_reader.lua test_map_reader.lua route_manager.lua test_route_manager.lua objects.lua test_objects.lua`
- `lua5.1 test_debug_tools.lua` passed 8 tests
- `lua5.1 test_map_reader.lua` passed 37 tests
- `lua5.1 test_route_manager.lua` passed 90 tests
- `lua5.1 test_objects.lua` passed 68 tests
- `git diff --check` passed, with the existing `dw_access.ini` CRLF warning

## Suggested Next Step

Start the next gameplay pass from the current save state. Only return to map
`0x04` if a route fails to finish, exits the map unexpectedly, leaves runtime
blocks behind, or blocks on a cell the player can manually verify.
