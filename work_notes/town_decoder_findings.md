# Town decoding investigation: Woman 2

Date: 2026-09-10. Branch: codex/town-audit.
Baseline commit: 6deef9272d630ac18dd9068a9a91ce25c0c14cae, independently
verified against GitHub refs/heads/codex/town-audit. Initial worktree clean.
The September 10 investigation changed documentation only. The corrections were
implemented September 11. Live route and TALK checks passed September 15;
the separate survey retry/timing defect was fixed and regression-tested the same day.

## Findings

### NPC mobility is decoded from the wrong field

objects.lua parse_npcs and read_live_npc copy byte2 into movement, then
npc_movement_status labels zero stationary and nonzero roaming. route_manager
uses the same assumption for blocker descriptions, mobile parking/reactive
parking, and stationary-path handling. map_crawler also uses byte2 to choose
mobile parking and identify stationary blockers.

The actual third byte is NPCMidPos, the offset within the current tile.
Zero means the NPC is between movement steps; it does not establish immobility.
The game allocates the first ten slots (0..9) to mobile NPCs and slots10..19
to static NPCs. Woman 2 is slot7.

Same-session live evidence, no savestate or teleport between these observations:
- Audit frame20062: Woman2 at(11,16), movement0.
- report_npcs frame22620: slot7 at(9,11), raw C9,AB,00.
- report_npcs frame25260: slot7 at(13,9), raw CD,A9,00.
- Audit frame42382: slot7 at(20,7), movement0, modeled reachable.
This confirms actual roaming while the current model reports stationary.

Primary source:
- [Bank00.asm](https://github.com/nmikstas/dragon-warrior-disassembly/blob/master/source_files/Bank00.asm),
  UpdateNPCs1 at $B76F: updates pairs across NPCUpdateCntr0..4 (ten slots).
- [Bank03.asm](https://github.com/nmikstas/dragon-warrior-disassembly/blob/master/source_files/Bank03.asm),
  ValidateNPC at $D0DC: compares three-byte slot offset against $1E to select
  mobile versus static NPC processing.
- [Dragon_Warrior_Defines.asm](https://github.com/nmikstas/dragon-warrior-disassembly/blob/master/source_files/Dragon_Warrior_Defines.asm),
  NPCMidPos at $53: within-tile X/Y offset, not movement behavior.

### The base town tile table contains incorrect meanings

map_reader.lua WALKABLE_TOWN is explicitly a best-guess table. Its tile0 is
blocked as void/boundary and tile4 allowed as floor. The game's town conversion
table at Bank00 $9A00 instead maps raw0 to grass and raw4 to stone. The table
also identifies raw7 as stairs down, raw8 trees, raw9 swamp, rawA force field,
rawB door, rawC weapon-shop sign, rawD inn sign, rawE bridge, and rawF large tile.
Do not infer all collision rules just from graphics; preserve door state,
hazard policy, boundaries, special interactions, and known map-specific evidence.

Normal-movement evidence from this investigation:
- (9,18)->DOWN into raw4 (9,19): queued retries failed, then raw probe frame8819
  blocked with NPC false. Temporary north-approach blocker was used for diagnosis.
- (15,22)->LEFT across raw0 (14,22) to(13,22): frame13655; reverse right crossing
  frame14906; repeated left crossing frame15145; second reverse frame27997.
- Normal auto-walk followed the tree column (13,22)..(13,27), frame15468.
- (13,27)->DOWN into raw0 (13,28) succeeded frame16233. A left input also walked
  onto raw0 (12,28); TALK found nobody because Woman2 had roamed elsewhere.
- Returned normally from(13,28) north through(13,27) to(13,26), frame25166;
  walked back to(13,22) and crossed east to(15,22). No teleport/reset proof used.

The original snapshot's Woman2 position (12,28) is a real reachable grass area
in the game, but not a permanent NPC location. A coordinate-only NPC fix would
miss the mobility bug and leave her other grass positions vulnerable.

## Recommended correction order

1. Correct NPC mobility consistently across parsing/live reads, descriptions,
   blockers, route parking, and crawler parking. Preserve raw byte2 for diagnostics
   and byte restoration; introduce an explicit mobility field/helper based on the
   actual slot range instead of repurposing the raw offset as a boolean.
   Test idle slot7 as mobile, active/static slot boundaries9/10, slot10+ as static,
   target exemptions, parking restoration, and ordinary NPC route/TALK behavior.
   Update fixture NPC slots where old tests encoded the incorrect assumption.
2. Pilot the source-backed town tile classification in Brecconary. Compare the
   captured raw grid/model and service round trips before broadening to other
   town/castle maps. Confirm special tile/door/hazard handling separately.
   Keep existing overrides until reviewed; do not globally delete legacy fixes
   or alter validated dungeon behavior based only on this town.
3. Re-run audits from a common entrance after each correction. Snapshot NPC
   positions are time-specific; compare stable target IDs and source fingerprints,
   not only aggregate reachable counts. Do not label old audit locations as
   permanently stationary based on byte2.

## Current state

Hero returned normally to Brecconary (1,15), frame37248. The temporary
(9,19).north runtime blocker was cleared; frame42240 confirms runtime none
and clear menu/dialogue/guard state. No code/config/map data changed, no
NPC freeze remains active, and no teleport or purchase was used.
Newest audit: town_audit_08_20260910T165251Z_001, frame42382, at(1,15):
22 modeled reachable, zero NPC-obstructed, one model-blocked, two return
concerns. Woman2 is at(20,7) and modeled reachable. These changing counts do
not represent fixes; they reflect the current NPC layout.

## Implementation and validation (2026-09-11)

- `npc_mobility.lua` now classifies slots0..9 mobile and10..19 stationary.
  Objects retain raw `movement` for diagnostics and expose `slot`/`mobility`.
  Cached/live descriptions, path blockers, initial/reactive mobile parking,
  stationary-route hints, and crawler parking use the same slot rule.
  `report_npcs` distinguishes `pixel_offset` from `mobility`.
- Crawler parking now uses the same ROM-inactive(0,0) coordinate as route
  parking, preserving original bytes. The previous(31,31) sentinel can leave
  the ROM sprite updater active. Inactive31,31 slots are still ignored.
- Brecconary alone uses the town conversion table at Bank00 $9A00 with the
  CheckCollision $B1CC threshold: converted IDs >= BLK_LRG_TILE are blocked.
  Grass is open; stone, water, signs, counters, and closed doors are blocked.
  Town swamp/force-field tiles use the existing hazard policy. Per-cell,
  directional, boundary, and opened-door overrides remain in effect.
- Audit source fingerprints include the mobility helper. Player package lists
  include it plus previously omitted required darkness/audit/frontier modules.
  The package regression now checks required local Lua dependencies.
- Verification: 41 Lua suites and68 Python tests passed. Focused tests include
  124 objects,163 route manager,52 crawler,86 map-reader tests. The final package
  list/dependency-check change passed all5 package tests afterward.
  Coverage includes idle mobile slots7/9, static10/19, changing pixel offsets,
  selected-target exemptions, reactive parking, byte restoration, door state,
  hazards, and unchanged neighboring-town/dungeon classification.

### Controlled model comparison

Replayed raw tiles and closed-door state from snapshot
`town_audit_08_20260910T165251Z_001` through the updated map reader. Compared
outward/return movement distances with the same directional overrides and
without NPC occupancy. This is offline planning evidence, not live acceptance.

- 254 raw0 grass cells change from blocked to open.
- 149 raw4 stone cells and one rawD inn sign change from open to blocked.
- Southern grass(13,28): no previous round trip; now25 steps each way from(1,15).
- Woman2's earlier position(12,28): no previous round trip; now24 steps each way.
- Tool Merchant stand(23,25): remains32 steps each way.
- Weapons Merchant stand(5,6): remains13 steps each way.
- Curse Remover stand(24,12): remains26 steps each way.

Fresh pre-edit probe at frame153120 confirmed hero(1,15), clear field, and no
runtime blockers. The next audit command was not consumed before its timeout;
no live movement or NPC parking was attempted. Manual FCEUX main.lua reload
requested after source validation. Next: fresh probe/report_npcs/audit_town,
then ordinary routes to southern grass, Woman2, and the tool counter with return.

## Live validation (2026-09-15)

Fresh FCEUX/main.lua reload confirmed at frame24180: Brecconary(0,15), clear
field, zero runtime blockers, speech bridge ready without errors. `report_npcs`
now labels idle slot7 Woman2 mobile and slots10..19 stationary, independently
of their pixel offsets. INI and source files were unchanged during this pass.

### Audit and closed-door checks

- Initial snapshot `town_audit_08_20260915T184226Z_001`, frame24682:
  21/23 modeled reachable, no NPC-only obstructions or return concerns.
- Two model-blocked targets: Fairy Water Merchant npc_5 and Guard4 npc_9.
  Door RAM is empty (both doors closed), keys6. Read-only replay of the same
  walkability/directional snapshot finds a route to each when its respective
  door alone is hypothetically opened: (21,6) reaches the fairy-water counter
  in32 steps; (5,23) reaches the inn room guard's approach in20 steps, from(1,15).
  This supports the closed-door explanation; no door was opened and no key used.
- Final snapshot `town_audit_08_20260915T185118Z_001`, frame56602, from(1,15):
  20 modeled reachable, one NPC-obstructed target/return (Curse Remover), and
  the same two closed-door targets. The Curse Remover works in skip-NPC planning;
  changing NPC layout explains that additional flag. Audit live fields remain
  untested by design; live evidence is recorded separately below.

### Successful ordinary movement and interaction

- Southern grass: `auto_walk_blocker:13,28` walked26 steps from(0,15), arrived
  frame27228, restored all10 roaming NPCs frame27247. Return to(1,15) walked25
  steps and completed frame29138. No blocked steps/reroutes on either leg.
  Normal movement reached the newly modeled grass, not a teleport landing.
- Tool Merchant:32 steps from(1,15) to counter(23,25), frame32465; east-facing
  arrival and ten-slot restore frame32484. TALK opened Merchant Buy at34522.
  B cancelled without purchase; normal field confirmed35880. Return32 steps
  completed38299, with no blocker/reroute. Ordinary turn/timing retries recovered.
- Woman2: after the survey problem below, a stale coordinate request selected
  Tile19,11 instead of her; this was not counted as NPC acceptance. Distance
  browsing also skipped/revisited entries as NPC distances changed.
  Briefly froze NPCs solely to capture slot7 coordinates at50340, then queued
  `unfreeze_npcs auto_walk_blocker:25,10` together. The freeze was released
  before planning/movement; log50400 confirms target_id=npc_7, parked_slots9,
  exempt_slot7. Normal walk reached(25,11) at50838, restored all9 non-target
  roamers and faced north at50857. TALK produced 'No,I am not Princess Gwaelin.'
  and VISITED_AUTO for npc_7 at52412. B closed dialogue; field clear54360.
  Return28 steps to(1,15) completed55457 with ten-slot restore and no blocker.
- Final fresh probe56460: hero(1,15), PATH_STATE target=nil, runtime none,
  menus/dialogue/input guards clear, bridge ready. NPC parking/freeze released.
  No map/config/source edit, teleport, purchase, or key use during validation.
  Capture: `.test_tmp/brecconary_live_20260915.log` (local ignored artifact).

### FIXED: SURVEY-DRIFT-RETRY-01 (medium, test harness; 2026-09-15)

- Trigger: `survey_target:Woman 2` from(1,15), default survey profile, target
  npc_7 at(21,14). The survey planned20 steps to adjacent(21,15), frame40680.
- Observed: final-settle drift moved the hero to(22,15) at41023. On that same
  frame, SURVEY_REQUEUE scheduled a route_drift_retry while normal auto-walk
  also queued its own one-step drift recovery back to(21,15).
  Survey retried at41024, hit the active-route guard, and reported failure
  (`guard_blocked`, no blocked events), then finished at41025. The corrective
  route was still running and actually completed41106.
- Expected: survey retains ownership of the current attempt while route-manager
  recovery runs, or waits for it before starting a retry; no premature failure
  or context teardown while a corrective route remains active.
- Cause confirmed: auto_step publishes `route_cancelled` before calling
  route_manager's synchronous drift-recovery callback. Immediate survey retry
  finalization raced that callback.
- Fix: `map_survey.on_route_cancelled` defers the raw `route_drift_off_path`
  decision until the next survey tick. If a corrective route is active, the
  original attempt remains active and logs `SURVEY_DRIFT_RECOVERY`. Same-frame
  completion or terminal failure wins; if no recovery starts, the existing
  bounded survey retry still runs. Core route event ordering is unchanged.
- Three regressions failed against the old code and pass with the fix: active
  corrective route ownership, immediate completion, and terminal retry-limit
  failure. Existing unrecovered-drift tests pass too. `test_map_survey.lua`:56
  tests; full `python -u run_tests.py`:41 Lua suites and68 Python tests pass.
  Syntax and `git diff --check` pass. Full gate log:
  `.test_tmp/survey_retry_gate.log`.
- This is not permanent map/blocker evidence. Ordinary auto-walk and TALK to
  Woman2 passed before the fix; current live survey results are recorded below.

## Open-door survey retest (2026-09-15, fresh emulator session)

- User opened both doors: frame14340 door slots contain(5,23) and(21,6), keys4,
  hero(21,7), clear field. No agent key use, purchase, config change, or teleport.
- `audit_town` at frame15000 refreshed navigation modules, including the new
  `map_survey.lua`, while idle. This existing command reloads that module; a
  second manual main.lua reload was unnecessary for this focused module fix.
- Audit `town_audit_08_20260915T195118Z_001`, finished15022 from(21,7):23/23
  modeled reachable, zero NPC obstructions, model blockers, or return concerns.
  Reports continue to label actual arrival/TALK/return untested by design.
- Ordinary28-step walk returned to(1,15), finished16951. Woman2 survey then
  passed15 steps to(12,11), NPC7 at(12,10), result18802/complete18803.
- Fairy Water Merchant survey passed17 steps to public counter(22,4), NPC5 at
  (24,5), result20565/complete20566. It crossed open door(21,6) at20303.
  Ordinary four-step return to street(21,7) completed31366.
- Guard4 survey initially refused to start from counter(22,4):low_exit_count,
  frame29220. This is the existing safe-start guard (two exits); it is not a
  route failure. Restarted from open street(21,7), it passed33 planned steps
  to(6,25), NPC9 now at(7,25), result33958/complete33959. A temporary timing
  retry at(8,21) west cleared when normal movement crossed at33652; no permanent
  blocker evidence. Ordinary19-step return reached(1,15), complete35335.
- All three completed surveys recorded movement_succeeded=true, blocked_events=0,
  failure_class=none, and released NPC freeze. The exact drift-recovery race
  did not recur in these runs; its corrected event ordering is covered by the
  deterministic regressions, not claimed as live-triggered acceptance.
- Guard4 had wandered out after the door opened. To verify the room itself,
  ordinary21-step walking from(1,15) crossed door(5,23) west at39206 and reached
  the former guard position(3,22) at39334, with parking released39353. Fresh
  frame40740 confirms clear field/input guards and zero runtime blocks inside.
- Inn-room return crossed(5,23) east at41476 and completed21 steps to(1,15)
  at42199, all10 parked NPC slots restored. Final audit from the common entrance:
  `town_audit_08_20260915T195938Z_001`, frame45022, again23/23 modeled reachable,
  zero NPC obstructions/model blockers/return concerns.
- Final frame45420:hero(1,15), nil path, zero runtime blockers, clear field/input
  guards, bridge ready/available/error none, no pending warnings. Both doors
  remain open, keys4. Full raw capture:
  `.test_tmp/brecconary_survey_fix_live_20260915.log`.
- No permanent map, config, or route-manager changes were needed for this survey
  fix. Next recommended audit/polish map remains Kol's service routes.
