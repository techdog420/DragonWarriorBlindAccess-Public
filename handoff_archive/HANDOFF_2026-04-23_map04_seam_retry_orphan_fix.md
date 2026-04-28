# Handoff 2026-04-23 — Map 0x04 seam-retry orphan fix

## What happened

Follow-up live debugging on map `0x04` focused on the remaining post-patch
east-side suspect seam `(17,5) -> (17,6)`.

Direct probe observations in the live emulator:
- `(17,6) -> (17,5)` moved cleanly
- `(17,5) -> (17,6)` blocked once
- later, the same direct `(17,5) -> (17,6)` probe also moved

That means `(17,6)` north-approach is **not** a clean permanent wall. It is a
mixed-result seam and should stay unmodeled in `map_reader.lua`.

## Clean single-target repro

To isolate the survey logic from accumulated state:
- cleared runtime blocks
- cleared seam memory
- teleported to `(10,10)`
- ran `survey_target:Merchant 3,park_npcs`

The route reached `(17,5)` and then reproduced the failure deterministically:

1. queued route step `(17,5) -> (17,6)` blocked
2. reroute found no alternate path
3. route manager started `SEAM_BRUTE_FORCE ... attempt=1/2`
4. manual seam-bruteforce step `(17,5) -> (17,6)` also blocked
5. route then became inactive without emitting a clean route-cancel event
6. survey finalized the attempt as:
   - `reason=route_inactive_without_completion`
   - `failure_class=suspected_engine_blocked_tile`
   - `suspected_tiles=17,6`

Key log lines from `dw_debug.log`:
- queued seam block and first brute-force start:
  - `SEAM_OBSERVATION map=0x04 cell=(17,6) approach=north result=blocked ... source=queued_route_block`
  - `SEAM_BRUTE_FORCE map=0x04 from=(17,5) dir=down dest=(17,6) attempt=1/2`
- failed brute-force and orphaned survey result:
  - `SEAM_OBSERVATION map=0x04 cell=(17,6) approach=north result=blocked ... source=manual_block`
  - `SURVEY_RESULT run=3 ... target_name="Merchant 3" ... final=(17,5) failure_class=suspected_engine_blocked_tile ... reason=route_inactive_without_completion`

## Root cause

This was a **route-manager bug**, not a new permanent map block.

In `route_manager.lua`, `auto_step.on_blocked` was classifying seam-bruteforce
retry failures as `queued_route = false` manual blocks and immediately ignoring
them with:

- `route_manager: ignoring blocked step outside queued route`

That branch is correct for ad-hoc manual probes, but wrong for seam retries that
were launched by the reroute system. When the brute-force retry blocked, the
route manager dropped the event instead of:
- attempting the next seam retry, or
- cancelling the route cleanly after retry exhaustion

This left surveys to detect an orphaned inactive route one frame later.

## Code fix applied

Updated `route_manager.lua` so that:
- true out-of-route manual blocked steps are still ignored
- but blocked steps that match the active `same_seam_retry(...)` state are
  treated as part of the route-manager reroute flow

Effect:
- failed seam-bruteforce retries now continue through the normal reroute logic
- a second retry is attempted when allowed
- after retry exhaustion, the route is cancelled cleanly instead of being
  orphaned

Added regression coverage in `test_route_manager.lua`:
- `failed_seam_bruteforce_retries_again_then_cancels_cleanly`

Validation completed:
- `luac -p route_manager.lua`
- `luac -p test_route_manager.lua`
- `lua test_route_manager.lua`

All route-manager Lua tests passed.

## Live verification after script reload

The emulator later restarted/reloaded the Lua script, which allowed a fresh
live verification of the same focused repro.

Re-run:

```bash
./dw_commands.sh --replace clear_runtime_blocks clear_seam_cells "teleport_to:10,10" report_position
./dw_commands.sh --replace "survey_target:Merchant 3,park_npcs"
```

Verified live behavior in `dw_debug.log`:
- first seam retry still launched:
  - `SEAM_BRUTE_FORCE ... attempt=1/2` at `dw_debug.log:373`
- failed brute-force retry now launched the second retry instead of orphaning:
  - `SEAM_BRUTE_FORCE ... attempt=2/2` at `dw_debug.log:390`
- after the second retry also failed, the route cancelled cleanly:
  - `runtime block: map=0x04 cell=(17,6) approach=north ... blocked=3 moved=0`
    at `dw_debug.log:399`
  - `SEAM_OBSERVATION ... classification=confirmed_blocked source=manual_block`
    at `dw_debug.log:400`
  - `SURVEY_RESULT ... reason=reroute_no_path` at `dw_debug.log:409`

Most important regression check:
- the old bad result `reason=route_inactive_without_completion` did **not**
  occur after the patch
- the survey now ends through the normal reroute-cancel path

## Important map-data conclusion

Do **not** add `["17,6"] = {north = true}` to `MAP_DIRECTIONAL_BLOCKS[0x04]`
based on this investigation alone.

Current evidence says:
- `(17,6)` north approach is noisy / mixed
- seam-retry orphaning has now been fixed
- the correct next step is to reload the Lua script in FCEUX and rerun the
  broader parked-NPC survey to see how many map04 failures remain

## Next step

With the route-manager fix now verified live, the next meaningful check is a
fresh broad survey:

```bash
./dw_commands.sh --replace clear_runtime_blocks clear_seam_cells "teleport_to:10,10" report_position
./dw_commands.sh --replace "survey_objects:park_npcs"
```

Primary question for that rerun:
- how many of the old east-side `17,6` failures disappear now that the seam
  retry path no longer dies as an orphaned route
