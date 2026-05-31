# Session Handoff - Active Resume

Updated: 2026-05-30

This file is the short current resume point. Detailed Tantegel Castle and Sun
Shrine evidence from the prior wrap is archived at:

- `handoff_archive/HANDOFF_2026-05-25_tantegel_map04_wrapup_session_handoff_full.md`
- `handoff_archive/HANDOFF_2026-05-25_tantegel_investigation_scratchpad.md`
- `handoff_archive/HANDOFF_2026-05-22_pre_cleanup_session_handoff_full.md`

## End-Of-Night Resume

- Overnight live check on `2026-05-30` confirmed the current FCEUX Lua loop is
  still polling commands.
- Clean resume tile is still Garin's Grave B1 entrance `(6,11)`:
  `POSITION: map=0x18(Garin's Grave B1) x=6 y=11`.
- `report_runtime_blocks` returned `RUNTIME_BLOCKS map=0x18 none`, so there
  were no stored runtime blockers left to merge into source in this wrap-up
  pass.
- Clean-state route reads still match the current permanent model:
  `debug_route_frontier:1,18,60` reported
  `reachable=243 target_reachable=false target_side=83 candidates=159 bridge_candidates=57 hidden_bridge_candidates=0`,
  and `debug_pathfind_to:1,18` still returned
  `No path found [no_path] (visited=291 path=0)`.
- That old no-path result is now understood as "door closed" behavior. With
  the B1 southeast door opened (`DOOR_STATE ... 1=(17,17)`), the route is live
  again: `debug_pathfind_to:1,18` from `(6,11)` now returns
  `3 east, 4 north, 10 east, 9 south, 2 west, 1 south, 8 west, 1 south, 8 west`,
  and the user completed the entrance-to-stairs run in FCEUX.
- Best next live resume: the southwest B2 stair branch is now proven through
  B4. User live checks on `2026-05-30` confirmed:
  - B2 southwest stair `(1,10)` -> B3 `(2,17)`
  - B3 lower stair `(10,9)` -> B4 `(5,4)`
  - B4 upper return stair `(0,4)` -> B3 `(9,5)`
  This is the correct Silver Harp route. If resuming from the older B2 anchor,
  use STAIRS to B3 `(2,17)`, route to the lower B4 stair `(10,9)`, cross B4,
  then continue from B3 `(9,5)`.
  Current B3 route cleanup on `2026-05-30` also promoted two more permanent
  north-lip seams near the lower-stair pocket: `(8,12).south` and
  `(9,12).south`. The next best live targets are the repeated west-facing
  blockers on `(10,13)`, `(10,14)`, and `(10,15)`, which are still route-
  shaped but not yet verifier-clean.

## Current Direction

- Player-facing gameplay is FCEUX-first.
- BizHawk remains the explicit automation/debug/reload-heavy runtime.
- Battle debuff speech now covers the spell-list-suppression case seen after
  the Garin's Grave B2 Wolf fight. Sleep and Stopspell on the hero are read
  from `snapshot.combat_flags` / RAM `0x00DF`; battle-time transitions still
  speak `Asleep` / `Awake` and `Spells blocked` / `Spells restored`. Field and
  battle SPELL attempts now prioritize `Spells blocked.` over misleading
  `Spells. Empty.` wording when either Stopspell is active or the spell list is
  empty even though the hero's level/MP says spells should exist. `log_state`
  now prints raw spell/status bytes (`CE`, `CF`, combat flags, quest flags) for
  diagnosis.
- Garin's Grave B2 stair objects are now corrected to the ROM-backed floor
  coordinates. The old placeholders `(19,0)` and `(12,12)` were impossible on
  the live 13x11 B2 map. `objects.lua` now exposes six B2 stair cells:
  up to B1 at `(11,2)`, and down stairs at `(1,1)`, `(12,1)`, `(5,6)`,
  `(1,10)`, and `(12,10)`.
- User live validation on `2026-05-30` confirmed the corrected B2 return stair
  at `(11,2)`, and confirmed the southwest B2 stair `(1,10)` deposits on
  Garin's Grave B3 `(2,17)`. `objects.lua` now also replaces the old B3/B4
  placeholders with the full ROM-backed stair sets for maps `0x1A` and `0x1B`.
- The B3/B4 stair chain is now live-confirmed too: B3 lower stair `(10,9)`
  goes down to B4 `(5,4)`, and B4 upper return stair `(0,4)` comes back up on
  the Silver Harp side at B3 `(9,5)`. Treat that route as the validated
  progress branch from the southwest B2 entry.
- Garin's Grave B3 lower-stair branch now has a substantial confirmed
  directional-seam model. In addition to the validated B3/B4 stair chain,
  permanent blockers now cover the west lip `(1,8).east`, `(1,9).east`,
  `(1,12).east`, `(1,13).east`, `(1,16).east`; the upper-left return edge
  `(2,7).south`; the west-return strip `(3,8..11).west`; the north lip
  `(6,12).south`, `(7,12).south`, `(8,12).south`, `(9,12).south`; the east
  wall `(10,13..17).west`; plus `(5,13).east`, `(2,15).south/east`, and
  `(5,18).north`. This came from repeated direct `probe_edge_verify` passes,
  not just route noise, and materially improved the B3 run toward the lower B4
  stair at `(10,9)`.
- B2 route cleanup now has nine confirmed permanent `MAP_DIRECTIONAL_BLOCKS`
  for Garin's Grave B2 (`0x19`): `(2,3).west`, `(2,4).west`, `(2,5).west`,
  `(2,6).west`, `(2,7).west`, `(4,9).south`, `(9,9).south`,
  `(10,9).south`, and `(12,9).south`. Mixed neighbors such as
  `(1,2).south`, `(1,9).north`, `(7,9).south`, `(8,9).south`, and
  `(11,10).east` should remain unmodeled for now.
- Current live FCEUX position after the save-state restore is Garin's Grave B2
  map `0x19` at `(1,11)`, clean level-12 stats: `HP 52/63`, `MP 30/52`,
  `STR=0x30`, `AGI=0x24`, `ATK=0x44`, `DEF=0x30`, `spells CE=0x3F`,
  `CF=0x10`, and
  `stat_ram BA-CF=21 11 D3 0D B5 03 02 45 C3 00 00 34 1E 0C 30 24 3F 34 44 30 3F 10`.
  The restore cleared the live runtime overlay, so the nine confirmed B2
  runtime edges above were re-applied; readback confirmed
  `RUNTIME_BLOCKS map=0x19 count=9`.
- Earlier active Wolf failure left Bill with low HP and field SPELL attempts
  returning `Bill cannot yet use the spell.`
- Pre-heal town capture later refined that: at Garinham `(19,1)`, `log_state`
  showed `HP 5`, `MP 48`, `spells CE=0x00`, `CF=0x10`, `combat=0x08`, and
  lower text still `Bill cannot yet use the spell.` Because `combat=0x08` does
  not include the `0x10` Stopspell bit, the speech fix also treats zero known
  spells with level/MP evidence as blocked/suppressed rather than genuinely
  empty.
- Post-inn/reload validation proved this is broader player-stat RAM corruption,
  not a normal debuff. At that point after the FCEUX script reload, state was
  Brecconary `(24,13)`, level 12, `HP 15/15`, `MP 0/0`, and
  `stat_ram BA-CF=73 10 0B 0C B5 03 01 45 C3 00 00 0F 00 0C 04 03 0F 00 18 1F 00 10`.
  The corrupted range starts at current HP `0x00C5` and runs through spells
  `0x00CE`; EXP, gold, equipment, keys, and item bytes still look coherent.
  Do not save at the king in this state. FCEUX quick-state slot 0 and its
  `-bak.fc0` companion, timestamped `2026-05-30 15:30`, both contain a clean
  level-12 B2 snapshot at map `0x19` `(11,2)` with `HP 63/63`, `MP 52/52`,
  `STR=0x30`, `AGI=0x24`, `ATK=0x44`, `DEF=0x30`, and `spells CE=0x3F`.
- `debug_tools.check_player_stat_integrity()` is now the log-only tripwire for
  this class of corruption. It runs from `log_state`/snapshots, map changes,
  and the battle-to-field transition. It intentionally ignores level-1 no-spell
  states, but logs `PLAYER_STAT_INTEGRITY_WARNING` with raw `BA-CF` RAM when a
  higher-level hero has impossible spell/MP/stat combinations.
- Warlock live repro on `2026-05-30` tightened the timing further. During a
  B2 fight at `(13,10)`, the first warning fired on the exact frame as
  `EVENT: battle started`, before the stable `A Warlock draws near!` dialogue
  and before entering SPELL. The battle-start snapshot already showed
  `HP 56/15`, `MP 42/0`, `STR=0x04`, `AGI=0x03`, `ATK=0x18`, `DEF=0x1F`,
  `spells CE=0x00`, and
  `stat_ram BA-CF=C9 10 F1 0C B5 03 02 45 C3 00 00 38 2A 0C 04 03 0F 00 18 1F 00 10`.
  That means the corruption is present by battle initialization, not caused by
  opening the spell menu later in the fight.
- Wolf live repro on `2026-05-30` repeated the same broader stat collapse. At
  frame `51905`, battle-start forensics already showed every retained field
  trace sample from `51894..51905` corrupt: `HP 52/15`, `MP 30/0`,
  `STR=0x04`, `AGI=0x03`, `ATK=0x18`, `DEF=0x1F`, `spells CE=0x00`, and
  `stat_ram BA-CF=2F 11 F9 0D B5 03 02 45 C3 00 00 34 1E 0C 04 03 0F 00 18 1F 00 10`.
  The `A Wolf draws near!` line did not appear until frame `51965`, and the
  ambush text did not appear until frame `52032`, so the Wolf attacking first
  is probably a symptom, not the root cause.
- Heavier stat-corruption forensics are now patched on disk in
  `debug_tools.lua`. In addition to battle-start
  `PLAYER_STAT_TRACE_BEGIN/PLAYER_STAT_TRACE/PLAYER_STAT_TRACE_END` dumps, the
  per-frame tick monitor now logs the first
  `PLAYER_STAT_INTEGRITY_TRANSITION from=clean to=bad` and dumps
  `context=stat_transition` before battle-start duplication. If battle starts
  immediately after the transition dump, the logger emits
  `PLAYER_STAT_TRACE_SKIPPED context=battle_start reason=recent_transition_dump`.
  FCEUX needs a manual Lua reload before this newest transition detector is
  live.
- Metal Scorpion live repro on `2026-05-30` proved the transition detector is
  live and narrowed the corruption to one frame boundary. At frame `51249`,
  retained field samples on B2 `(11,1)` were still clean (`HP 54/63`,
  `MP 14/52`, `STR=0x30`, `AGI=0x24`, `ATK=0x44`, `DEF=0x30`,
  `spells CE=0x3F`). At frame `51250`, still before battle start, only
  `C8..CE` flipped to the level-1-like profile (`STR=0x04`, `AGI=0x03`,
  `MAX_HP=0x0F`, `MAX_MP=0x00`, `ATK=0x18`, `DEF=0x1F`, `spells CE=0x00`)
  while current HP/MP and level stayed `54`, `14`, and `12`. Battle start did
  not fire until frame `51300`, enemy-name text until `51369`, and first-strike
  text until `51466`, so the enemy dialogue/ambush are again too late to be the
  cause. A live `log_state` during the fight at frame `60840` still showed the
  corrupt profile (`HP 28/15`, `MP 14/0`) and Metal Scorpion HP `14`.
- Follow-up source patch adds an even tighter frame-boundary sentinel:
  `debug_tools.before_frameadvance()` / `after_frameadvance()` now wrap
  `FCEU.frameadvance()` and log
  `PLAYER_STAT_FRAMEADVANCE_TRANSITION` only when the stat-integrity state
  changes across that exact emulator frame boundary. The log line includes
  `pre_frame`, `post_frame`, changed RAM bytes, issues, and both before/after
  `BA-CF` stat blocks. FCEUX needs a manual Lua reload before this newest
  boundary sentinel is live.
- Skeleton live repro on `2026-05-30` confirmed the boundary sentinel in FCEUX.
  It logged `PLAYER_STAT_FRAMEADVANCE_TRANSITION from=clean to=bad` at frame
  `13342`, with `pre_frame=13342`, `post_frame=13343`, map `0x19`, pos
  `(11,2)`, and `changed=C8,C9,CA,CB,CC,CD,CE`. Before the frame advance,
  Bill was level 12 with `HP 43/63`, `MP 42/52`, and clean stats/spells; after
  the same frame advance, level/current HP/current MP stayed `12`/`43`/`42`,
  but max/stat/spell bytes collapsed to `HP 43/15`, `MP 42/0`,
  `STR=0x04`, `AGI=0x03`, `ATK=0x18`, `DEF=0x1F`, `spells CE=0x00`.
  Battle start did not fire until frame `13393`, Skeleton text until `13457`,
  and first-strike text until `13532`, so this is now confirmed as a NES-side
  frame-execution write before Lua's next tick, not an enemy-dialogue/menu
  symptom.
- Winning that Skeleton fight then restored the same stat range. Victory text
  logged at frame `27895`, then
  `PLAYER_STAT_FRAMEADVANCE_TRANSITION from=bad to=clean` fired at frame
  `27899` across `pre_frame=27899` / `post_frame=27900`, changing `C8..CE`
  back to the clean level-12 profile. A current field `log_state` at frame
  `35220` confirmed map `0x19` `(11,2)`, `HP 31/63`, `MP 42/52`,
  `STR=0x30`, `AGI=0x24`, `ATK=0x44`, `DEF=0x30`, `spells CE=0x3F`, and
  clean `BA-CF` stat RAM. Treat this as a battle-time engine stat swap/recompute
  that can restore on victory, not necessarily persistent save/RAM damage.
- Current strongest mod-side suspect is the movement-state normalization used
  to clean up autowalk route settles. The Skeleton repro logged
  `AUTO_STEP_MOVEMENT_STATE_RESET reason=queued_route_final_complete` at frame
  `13334`, followed by the bad stat write at frame `13342`. This correlation
  is not proof, but the next best A/B test is to set
  `auto_step_reset_movement_on_route_turn_settle=false`, reload config, keep
  the frame-boundary sentinel active, and repeat the B2 route/combat test.
- Follow-up after the user set
  `auto_step_reset_movement_on_route_turn_settle=false`, ran
  `reload_config`, manually reloaded the FCEUX Lua script, and made another B2
  pass: the fresh log showed no new
  `PLAYER_STAT_FRAMEADVANCE_TRANSITION`/`PLAYER_STAT_INTEGRITY_TRANSITION`
  warnings across the latest Wolf/Metal Scorpion battles, but it still logged
  `AUTO_STEP_MOVEMENT_STATE_RESET` on `queued_route_final_complete`. Root cause
  was code, not reload hygiene: `auto_step.lua` already honored the toggle for
  turn-settle resets, but final-settle activation and the final queued-route
  completion reset still bypassed it. Both final-settle paths are now patched
  to honor the config toggle, with regression coverage in
  `test_auto_step.lua` (`queued_route_final_settle_skips_movement_reset_when_disabled`).
  Verification passed with `lua5.1 test_auto_step.lua`,
  `luac5.1 -p auto_step.lua test_auto_step.lua`, and
  `git diff --check -- auto_step.lua test_auto_step.lua`. FCEUX needs a manual
  Lua reload before the next live A/B pass uses this fix.
- Live A/B after that manual FCEUX reload is clean so far. The route/combat log
  includes five post-reload battles (Skeleton, Metal Scorpion, Metal Scorpion,
  Skeleton, Wolf) with no `PLAYER_STAT_*` warnings/transitions and no
  `AUTO_STEP_MOVEMENT_STATE_RESET reason=queued_route...` lines. The only
  remaining movement-state reset logs are `reason=seam_retry_complete`, which
  is the separate retry path left intentionally enabled. A read-only state probe
  after the Wolf fight showed clean level-12 stats on B2 `(1,11)`:
  `HP 40/63`, `MP 26/52`, `STR=0x30`, `AGI=0x24`, `ATK=0x44`, `DEF=0x30`,
  `spells CE=0x3F`, and `stat_ram BA-CF=C5 12 EB 11 B5 03 02 45 C3 00 00 28 1A 0C 30 24 3F 34 44 30 3F 10`.
  `PATH_STATE` still targets the southwest B2 stair at `(1,10)`, one tile north
  of the hero, because the Wolf interrupted the final approach; that is a route
  interruption, not stat corruption.
- The same Skeleton repro showed the B2 live runtime overlay had been cleared
  again: `report_runtime_blocks` returned `RUNTIME_BLOCKS map=0x19 none`.
  Re-applied the nine confirmed B2 edges in-battle, and readback at frame
  `17880` confirmed `RUNTIME_BLOCKS map=0x19 count=9`.
- The provisional west-entry reopening experiment on B1 is now disproved.
  In a clean no-runtime-block state, `debug_pathfind_to:1,18` from `(6,11)`
  briefly reopened a 22-step route through `(4,14)->(5,14)->(5,15)`, but live
  `validate_path` aborted at step 14 on `(4,14)->RIGHT`. Direct clean-state
  verifiers then reconfirmed both seams blocked `5/5`:
  `(5,14).west` from `(4,14)->RIGHT` and `(5,15).west` from `(4,15)->RIGHT`.
- `map_reader.lua` and `test_map_reader.lua` now re-close those two B1 seams
  in code, focused checks passed again
  (`luac5.1 -p map_reader.lua test_map_reader.lua`,
  `lua5.1 test_map_reader.lua`,
  `git diff --check -- map_reader.lua test_map_reader.lua`), and the same two
  blockers were mirrored into the live runtime overlay so the current FCEUX
  session matches the corrected source without waiting for a reload.
- Latest clean-state overnight check from entrance `(6,11)` confirms the
  running script is still alive, `report_runtime_blocks` is now
  `map=0x18 none`, `debug_route_frontier:1,18,60` still reports
  `reachable=243 target_reachable=false target_side=83 candidates=159 bridge_candidates=57`,
  and `debug_pathfind_to:1,18` still returns
  `No path found [no_path] (visited=291 path=0)`.
- New route status after the B1 door confirmation:
  - with door RAM holding `(17,17)` open, the planner now sees a full
    entrance-to-B2-stairs route from `(6,11)` to `(1,18)` and the user has
    completed it live
  - the remaining route chatter in the successful runs was mostly seam-retry
    timing on cells that later moved, not fresh durable blocker evidence
  - follow-up return-route cleanup promoted only one new durable southeast
    shelf wall: `(16,17).east`, confirmed `5/5` by
    `probe_edge_verify:17,17,LEFT,5`
  - the sibling route suspect `(17,19).north` did look blocked during the
    successful door-open run, but a later direct recheck from `(17,18)->DOWN`
    stayed mixed `moved=1 blocked=4`, so keep it unmodeled for now
  - strongest examples of "noisy but ultimately passable" on the same run were
    `(19,16).north`, `(17,16).east`, `(14,19).east`, `(12,18).east`, and
    `(1,19).east`; each first looked blocked under queued movement, then moved
    on seam retry and should stay unmodeled for now
- New live clarification: the reverse pocket that reaches entrance from
  `(1,18)` is not a usable forward bridge. Direct inverse checks proved the lip
  is one-way:
  - `(6,11)->LEFT` into `(5,11)` blocked `10/10`
  - `(5,11)->RIGHT` into `(6,11)` moved `6/6` with stability recheck
  Treat that `(5,11)->...->(1,18)` pocket as reverse-only for now.
- Another long-standing noisy low-west seam is now settled open:
  `(2,10)->UP` into `(2,9)` moved `11/11` with stability recheck, so keep
  `(2,9).south` unmodeled.
- The deeper `debug_route_frontier:X,Y[,LIMIT]` commands are now live in the
  running FCEUX script after the manual reload. With the current 38-cell
  runtime overlay, the broad entrance-side frontier mainly re-ranks already
  injected runtime seams rather than exposing fresh untreated bridges.
- New left-center frontier clarification:
  - `(2,13)->RIGHT` into `(3,13)` is now settled as another one-way gate:
    forward blocked `10/10`, reverse open `11/11` with stability recheck.
  - `(3,12)` is now confirmed to be on the both-sides component:
    from teleported `(3,12)`, `debug_pathfind_to:1,18` gives
    `1 south, 2 east, 3 south, 4 west, 2 south`, and
    `debug_pathfind_to:6,11` gives `1 south, 3 east, 2 north`.
  - But the entrance-side entries into that `(3,12)` pocket mostly collapsed:
    `(3,11)->DOWN` blocked `10/10`, `(2,12)->RIGHT` blocked `10/10`, and
    `(4,12)->LEFT` stayed only weakly mixed at `moved=1 blocked=9`.
  - The nearby sibling seam `(3,14)->UP` into `(3,13)` also stayed noisy:
    `moved=4 blocked=6`, while reverse `(3,13)->DOWN` moved `10/10` before a
    battle interrupted only the stability recheck.
  - Another untreated west entry into the known `(5,11)` both-sides pocket is
    now closed too: `(4,11)->RIGHT` blocked `10/10`.
  - Practical consequence: this whole left-center branch is now mostly reduced
    to two noisy survivors, `(3,14)->UP` and `(4,12)->LEFT`, rather than a
    clean new reopening.
  - Follow-up on those two survivors materially changed the picture:
    - reverse sides are now both cleanly passable:
      `(3,13)->DOWN` moved `6/6` with stability recheck, and
      `(3,12)->RIGHT` moved `6/6` with stability recheck
    - the first survivor is a real forward bridge under seeded natural
      approach:
      starting from `(3,15)`, `probe_edge_after_raw_to:UP,40,3,14,20,UP`
      reached `(3,14)` naturally and then moved into `(3,13)`
    - but that bridge does **not** reopen B2 by itself. From that natural
      `(3,13)` landing, `auto_walk:1,18` failed on the very first move, and
      direct follow-up proved the next seam cleanly blocked:
      `(3,13)->RIGHT` into `(4,13)` blocked `5/5`
    - after runtime-injecting `add_blocked_edge:3,13,RIGHT`,
      `debug_pathfind_to:1,18` from `(3,13)` fell to
      `No path found [no_path] (visited=303)`
    - the second survivor did not hold up under the same treatment:
      starting from `(5,12)`, `probe_edge_after_raw_to:LEFT,40,4,12,20,LEFT`
      reached `(4,12)` naturally but the follow-up left probe blocked
  - Practical consequence now: `(3,14)->UP` is a real forward lip into the
    deeper pocket, but that pocket is still dead-ended by `(3,13)->RIGHT`;
    `(4,12)->LEFT` is demoted again behind it.
- Updated `5,10` pocket classification after the west-entry repeat:
  - A seeded natural-arrival probe from `(4,9)` proved the west entry is real:
    `probe_edge_after_raw_to:DOWN,40,4,10,20,RIGHT` cleanly moved from
    entrance-side `(4,10)` into `(5,10)`.
  - But that does **not** reopen the route to B2. Live `auto_walk:1,18` from
    the resulting natural `(5,10)` landing failed immediately on the first
    south step into `(5,11)`, and direct verification settled that seam
    cleanly blocked:
    `probe_edge_verify:5,10,DOWN,10` => blocked `10/10`.
  - After injecting that blocker at runtime with `add_blocked_edge:5,10,DOWN`,
    `(5,10)` no longer pathfinds to stairs:
    `debug_pathfind_to:1,18` from `(5,10)` fell to
    `No path found [no_path] (visited=294)`.
  - `(5,11)` is still on the stairs-side/reverse component:
    from teleported `(5,11)`, `debug_pathfind_to:1,18` gives
    `5 south, 4 west, 2 south`, and `debug_pathfind_to:6,11` gives `1 east`.
    The reverse seam `(5,11)->UP` stayed mixed at `moved=3 blocked=7`, so keep
    it unmodeled for now.
  - Practical consequence: the whole `5,9/5,10/5,11` cluster is now
    de-prioritized as a forward bridge lead. The west entry exists, but the
    next continuation seam is a real forward blocker.
- Best next live resume:
  - keep the new runtime blocker `(5,10)->DOWN` live
  - pivot away from the `5,9/5,10/5,11` cluster and back to the remaining
    unresolved mixed/non-runtime candidates outside that pocket
  - the old left-center survivors are no longer top-priority bridge leads:
    `(3,14)->UP` really does cross forward, but the next seam behind it,
    `(3,13)->RIGHT`, is now runtime-confirmed blocked `5/5`;
    `(4,12)->LEFT` failed its seeded natural recheck
  - the next frontier seam after that, `(7,12)->DOWN`, is now also classified
    as a one-way gate:
    forward blocked `5/5`, reverse `(7,13)->UP` passable with stability
  - the next frontier seam after that, `(9,14)->DOWN`, is now also classified
    as a one-way gate:
    forward blocked `5/5`, reverse `(9,15)->UP` passable with stability
  - follow-up on that same band:
    - `(9,13)->LEFT` into `(8,13)` is now settled blocked `5/5`
    - `(8,14)->UP` into `(8,13)` is a real forward lip under at least one
      natural entrance-side arrival:
      `probe_edge_after_raw_to:RIGHT,40,8,14,20,UP` from `(7,14)` reached
      `(8,14)` naturally and then moved into `(8,13)`
    - but the same seam stayed state-sensitive: a seeded natural arrival from
      the east `(9,14)` into `(8,14)` then UP blocked, even though a direct
      verifier also moved through it `6/6`
    - the pocket behind that lip still dead-ends immediately:
      from natural `(8,13)`, `auto_walk:1,18` failed on the very first move,
      and direct follow-up proved `(8,13)->LEFT` into `(7,13)` blocked `5/5`
  - that blocker is now mirrored live too:
    `add_blocked_edge:8,13,LEFT` merged into `RUNTIME_BLOCK map=0x18 x=7 y=13 dirs=east`
    but the broad entrance rerun still stays closed:
    `debug_pathfind_to:1,18` remains `No path found [no_path] (visited=291)`,
    while `debug_route_frontier:1,18,70` now reports
    `target_side=83 bridge_candidates=57`
  - follow-up on the nearby `4,14/4,13` band clarified another false lead:
    - `(4,13)` reaches both entrance and stairs, and reverse
      `(4,13)->DOWN` is now cleanly passable (`probe_edge_verify:4,13,DOWN,3`
      finished `moved=4 blocked=0` with stability after two earlier
      battle-interrupted `5/5` repeats)
    - `(4,14)` remains entrance-side under the current model
    - natural west arrival into `(4,14)` is real:
      `probe_edge_verify:3,14,RIGHT,5` moved `6/6`, and a raw-field
      `probe_edge:RIGHT` from `(3,14)` also landed on `(4,14)`
    - but the actual natural follow-up lip still blocks:
      from that real `(4,14)` landing, `probe_edge:UP` blocked on
      `(4,14)->(4,13)`
    - practical consequence: treat this as another reverse-biased gate, not a
      reliable forward reopening, and downgrade the earlier mixed teleported
      `(4,14)->UP` verifier to state noise
  - a farther-east frontier cleanup also settled cleanly:
    `probe_edge_verify:8,16,UP,5` blocked `5/5`, and
    `add_blocked_edge:8,16,UP` merged into
    `RUNTIME_BLOCK map=0x18 x=8 y=15 dirs=north,south`
  - follow-up on the next east pair split them cleanly:
    - `probe_edge_verify:10,16,UP,5` blocked `5/5`, and
      `add_blocked_edge:10,16,UP` merged into
      `RUNTIME_BLOCK map=0x18 x=10 y=15 dirs=north,south`
    - `(11,15)->LEFT` is a true cross-component seam candidate, but still not
      clean enough to model:
      - teleported `(10,15)` reaches both entrance and stairs
      - teleported `(11,15)` reaches entrance only
      - reverse `probe_edge_verify:10,15,RIGHT,5` moved `6/6` with stability
      - forward `probe_edge_verify:11,15,LEFT,5` stayed mixed at
      `moved=4 blocked=1`
      - a real entrance-side `auto_walk:11,15` from `(6,11)` completed and
        landed on field `(11,15)`, but two immediate raw `probe_edge:LEFT`
        attempts from that natural landing both blocked
      - practical consequence: leave `(11,15)->LEFT` unmodeled for now and
        treat it as downgraded rather than promoted
    - clean restarted follow-up on that same local pocket changed the read
      again:
      - from a fresh source-backed state with `RUNTIME_BLOCKS map=0x18 none`,
        `debug_pathfind_to:1,18` from `(6,11)` still stayed
        `No path found [no_path] (visited=291 path=0)`
      - after re-clearing menu/input contamination, a fresh natural rerun again
        reached the lip and confirmed `(11,14)->DOWN` cleanly opens into
        `(11,15)`
      - from that true natural `(11,15)` landing, `(11,15)->LEFT` blocked
        twice again, and both `debug_pathfind_to:1,18` / `:6,11` showed that
        `(11,15)` is still entrance-side only
      - the new important discovery is the east edge:
        `probe_edge:RIGHT` from natural `(11,15)` blocked twice even though
        the preview said `(12,15)` was open, and
        `probe_edge_verify:11,15,RIGHT,5` then settled it cleanly at
        `moved=0 blocked=5 classification=confirmed_blocked` with repeated
        `blocked_despite_open_preview` mismatches
      - that seam is now mirrored live as `(12,15).west` via
        `add_blocked_edge:11,15,RIGHT`; with just that blocker live, the
        entrance route still stays closed at `visited=292`
      - the same pocket also extends south cleanly:
        `probe_edge_verify:11,15,DOWN,5` finished
        `moved=6 blocked=0 classification=confirmed_passable`, and live
        `probe_edge:RIGHT` from `(11,16)` then moved into `(12,16)`
      - but even from live `(12,16)`, `debug_pathfind_to:1,18` still stayed
        `No path found [no_path] (visited=332 path=0)`
      - practical consequence: the old mixed `(11,15)->LEFT` lead is now
        de-prioritized further; the active local branch is a small
        entrance-side pocket around `(11,15)`, `(11,16)`, and `(12,16)`,
        with a fresh hidden blocker now confirmed at `(12,15).west`
    - that natural arrival also exposed a new nearby noisy seam:
      `(10,14)->RIGHT` into `(11,14)` blocked once during autowalk, then moved
      on seam retry; after landing at `(11,14)`, reroute to `(11,15)` was only
      `1 south` and the walk completed normally
  - with those clarified, the broad entrance rerun is still unchanged:
    `debug_pathfind_to:1,18` remains `No path found [no_path] (visited=291)`,
    `debug_route_frontier:1,18,60` stays at `target_side=83 bridge_candidates=57`,
    and `report_runtime_blocks` stays `count=39`
  - direct follow-up on that local `10,14/11,14` seam then retired it:
    - `probe_edge_verify:10,14,RIGHT,5` moved `6/6` with stability
    - teleported `(11,14)` still reaches entrance only and not the stairs
    - practical consequence: `(10,14)->RIGHT` is just open entrance-side
      terrain, not a reopening lead
  - the east pocket is therefore narrowed back down again: keep
    `(11,15)->LEFT` downgraded/unmodeled, treat `10,14/11,14` as resolved
    ordinary terrain, and look for the next untreated seam outside this pocket
  - the old central x=10 oddities are now largely de-prioritized too:
    `(10,11)`, `(10,12)`, and `(11,12)` all still pathfind to the entrance but
    not to the stairs, `(11,11)->LEFT` is now confirmed blocked `10/10`, and
    the leftover `(10,12)` weirdness remains only a local mixed seam
  - treat that x=10 family as local movement noise unless a fresh
    goal-specific frontier exposes a new cross-component seam elsewhere
  - deeper reverse-side follow-up from clean stairs anchor `(1,18)` tightened
    that same middle pocket without reopening it:
    - `debug_route_frontier:6,11,90` still reports
      `reachable=315 target_side=364 bridge_candidates=97`
    - clean new runtime blockers from that pass:
      `(11,12)->LEFT`, `(11,14)->UP`, `(12,14)->UP`, `(13,14)->UP`, and
      `(12,11)->UP`
    - mixed, still-unmodeled siblings:
      `(10,14)->UP` stayed `moved=1 blocked=4`, and
      `(12,9)->DOWN` stayed `moved=2 blocked=3`
    - practical read: a new reverse-side false-front is emerging across the
      row-14 north lip into `(11,13)`, `(12,13)`, and `(13,13)`, while the
      nearby x=12 pocket still behaves one-way or state-sensitive rather than
      like a clean bridge
    - broad entrance rerun after mirroring that batch is still closed:
      `debug_pathfind_to:1,18` from `(6,11)` remains
      `No path found [no_path] (visited=291 path=0)`, and
      `report_runtime_blocks` is now `count=45`
    - best next reverse-side seams after this batch are
      `(13,9)->DOWN`, `(13,11)->UP`, and `(14,12)->UP`; if those dry up, the
      two mixed survivors worth natural/reverse rechecks are `(10,14)->UP` and
      `(12,9)->DOWN`
  - that next reverse-side batch mostly cleaned up too:
    - clean new runtime blockers:
      `(13,9)->DOWN`, `(13,11)->UP`, and `(14,12)->UP`
    - practical consequence:
      `(13,10)` is now fully closed north/south at runtime, and the
      row-14/center pocket widened one step east to include `(14,11).south`
    - the nearby sibling seams into `(14,11)` and `(14,10)` did **not**
      cleanly promote:
      `(13,11)->RIGHT` stayed `moved=1 blocked=4`,
      `(15,11)->LEFT` stayed `moved=2 blocked=3`,
      `(14,9)->DOWN` stayed `moved=2 blocked=3`, and
      `(15,10)->LEFT` stayed `moved=3 blocked=2`
    - direct cell classification demoted that whole mixed pocket:
      teleported `(14,10)` and `(14,11)` both pathfind back to entrance
      `(6,11)` but not to stairs `(1,18)`, so treat those mixed seams as
      entrance-side noise or one-way/state-sensitive behavior, not as the
      missing bridge
    - entrance-side reruns still do not reopen the route:
      `debug_route_frontier:1,18,80` remains
      `reachable=243 target_side=83 bridge_candidates=57`, and
      `debug_pathfind_to:1,18` from `(6,11)` still returns
      `No path found [no_path] (visited=291 path=0)`
    - `report_runtime_blocks` is now `count=47`
    - practical next work:
      deprioritize the `(14,10)/(14,11)` pocket and go back to the remaining
      stronger mixed reverse-side survivors, especially `(12,9)->DOWN` and
      `(10,14)->UP`; after those, the next fresh farther-north contour is the
      `(13,8)/(14,8)` band from `(13,7)->DOWN` and `(14,9)->UP`
  - follow-up on those remaining strongest mixed seams further narrowed them:
    - `(12,10)` is now clearly entrance-side only:
      teleported `(12,10)` pathfinds to entrance with
      `3 west, 1 south, 3 west`, but `debug_pathfind_to:1,18` is still
      `No path found [no_path] (visited=362)`
    - reverse lip repeat on that pocket settled fully open:
      `probe_edge_verify:12,10,UP,5` moved `6/6` with stability recheck
    - practical read: the old mixed `(12,9)->DOWN` seam is now best treated as
      another one-way trap or state-sensitive lip, not a bridge lead
    - the farther-north contour split:
      - clean new runtime blocker:
        `(13,7)->DOWN` blocked `5/5`, mirrored into
        `RUNTIME_BLOCK map=0x18 x=13 y=8 dirs=north`
      - but the sibling `(14,9)->UP` stayed mixed at `moved=2 blocked=3`
    - direct cell classification then demoted that contour too:
      teleported `(14,8)` and `(13,8)` both pathfind back to entrance but not
      to stairs, so treat the `(13,8)/(14,8)` pocket as entrance-side noise
      or one-way/state-sensitive behavior rather than a fresh bridge
    - recheck on the older long-running lead `(11,15)->LEFT` still did not
      cleanly promote:
      teleported `(11,15)` still reaches entrance only
      (`1 north, 2 west, 3 north, 3 west`) and not stairs, while a stronger
      direct verifier stayed mixed at `moved=3 blocked=7`
    - broad entrance rerun remains unchanged:
      `debug_pathfind_to:1,18` from `(6,11)` is still
      `No path found [no_path] (visited=291 path=0)`, and
      `report_runtime_blocks` is now `count=48`
    - practical next work:
      the remaining highest-value unresolved seam is still `(11,15)->LEFT`;
      after that, the strongest leftover mixed cleanup is `(10,14)->UP`
  - source sync status after that pass:
    - direct source-vs-live comparison against the latest
      `RUNTIME_BLOCKS map=0x18 count=48` snapshot found only four B1
      directions still missing from `map_reader.lua`:
      `(4,13).west`, `(5,11).north`, `(7,13).east`, and `(14,17).north`
    - those four are now patched into `map_reader.lua`, with matching
      assertions added in `test_map_reader.lua`
    - focused checks all passed:
      `luac5.1 -p map_reader.lua test_map_reader.lua`,
      `lua5.1 test_map_reader.lua`, and
      `git diff --check -- map_reader.lua test_map_reader.lua`
    - a fresh source-vs-live comparison now returns
      `all_runtime_dirs_present`
    - practical consequence:
      the current running FCEUX session is carrying a 48-direction runtime
      overlay that the source now fully models; restart or manual script reload
      should let B1 come back up with little or no runtime blocker residue
    - best next step:
      restart or reload the running emulator/script, then rerun
      `debug_pathfind_to:1,18` and `report_runtime_blocks` from `(6,11)` in
      the clean post-reload state before probing any more mixed seams
- Three B2-stairs cleanup batches are now live in code. Clean 8/8 direct
  verifiers promoted:
  - `(16,15).east/south`, `(17,14).south`, `(18,15).south/west`
  - `(17,11).east`, `(17,12).east`, `(18,14).east`, `(18,15).east`, `(19,12).south`
  - `(10,9).east`, `(11,10).north`, `(14,10).east`, `(16,11).north`, `(16,12).south`
- A fourth B2-stairs cleanup batch is now also live in code:
  `(11,8).south`, `(12,8).south`, `(12,10).north`, `(13,10).north`, and
  `(14,10).north`.
  `luac5.1 -p map_reader.lua test_map_reader.lua`,
  `lua5.1 test_map_reader.lua`, and `git diff --check -- map_reader.lua test_map_reader.lua`
  all passed after the patch.
- After `reload_navigation_modules` plus `clear_blocked_tiles`, the previously
  noisy west-approach revisits both settled open: `(17,16).west` is passable
  9/9 from `(16,16)->RIGHT`, and `(18,16).west` is passable 9/9 from
  `(17,16)->RIGHT`. Do not promote either edge.
- The next B2-stairs batch has already restarted. After the fourth permanent
  batch, reloading and clearing runtime blocks rerouted the live path from
  `(12,9)` through the upper lane, but `validate_path` then failed on
  `(13,9)->UP`. Direct `probe_edge_verify:13,9,UP,8` confirmed
  `(13,8).south` blocked 8/8; it is runtime-injected only so far.
- Latest live B1 state is `map=0x18(Garin's Grave B1) x=13 y=9` with one
  runtime-only next-batch seed: `(13,8).south`. The current down-stairs
  preview from `(13,9)` is
  `(13,9)->(14,9)->(14,8)->(13,8)->(12,8)->(11,8)->(10,8)->(10,9)->(10,10)->(10,11)->(10,12)->(10,13)->(11,13)->(12,13)->(13,13)->(14,13)->(14,14)->(14,15)->(14,16)->(14,17)->(14,18)->(13,18)->(12,18)->(11,18)->(10,18)->(9,18)->(8,18)->(7,18)->(6,18)->(5,18)->(4,18)->(3,18)->(2,18)->(1,18)`.
- `INPUT_STATUS` may still show the benign FCEUX `LeftAlt` latch with no bridge
  direction; do not treat that as movement evidence.
- The Garin's Grave entrance is now confirmed: STAIRS from Garinham `(19,0)`
  changes to map `0x18` / Garin's Grave B1. User manual follow-up confirmed
  B1 arrival/return at `(6,11)` and return stairs back to Garinham `(19,0)`.
- The map-data changes can be picked up by `reload_navigation_modules`, but
  the queued-route executor fix in `auto_step.lua` needs a full Lua script
  reload or relaunch before live autowalk testing can exercise it.
- Live verification now shows both-grave-route ends are reachable: from
  `(17,9)` to `(19,0)` and from `(19,0)` back to `(17,9)` with route
  completion and no runtime blockers added.
- Autowalk drift tuning pass: a config-only trial of
  `auto_step_route_turn_settle_frames=8` still drifted, and `0` reached
  `(19,0)` but continued into the world map. `dw_access.ini` is restored to
  `auto_step_route_turn_settle_frames=16`. After manual FCEUX reload, the
  `auto_step.lua` queued-route early-twitch hold cap looked better: the first
  route to grave stairs still overshot from `(19,14)` out to world map, but the
  next attempt completed at `(19,0)` with only one route-drift reroute and no
  temporary block/brute-force retries on the final north lane.
- Follow-up pre-turn tuning is live-tested and looks good:
  `auto_step_route_pre_turn_inject_limit=10` shortens the last same-direction
  queued step before a turn, and early-twitch turn repress now only re-presses
  the old direction when the next queued step is also that direction. After
  manual FCEUX reload, repeated grave-route runs had no observed drift on the
  grave legs. One remaining route-manager glitch happened after a timing retry
  at `(2,13)->down`: the seam follow-up reached `(2,14)` but reported
  `No path found`, while a fresh `auto_walk` immediately planned `1 west` to
  the exit. Treat this as a follow-up planner/replan bug, not map evidence.
  `route_manager.lua` now gives that exact no-temp-blocks seam-followup
  false negative one refreshed replanning attempt
  (`seam_retry_followup_refreshed`) before cancelling; this needs a full Lua
  reload in FCEUX. Follow-up live routes did not hit this exact refreshed
  fallback branch: one exit route from `(15,15)` cancelled early with
  `can_walk_false`, the next recovered a one-tile overshoot from `(0,14)` back
  to `(1,14)`, and the route from the west exit to `(19,0)` completed cleanly.
  Treat that as no new map-block evidence. A focused regression test now covers
  the cleared-temp-block seam-followup false negative.
  `luac5.1 -p auto_step.lua test_auto_step.lua config.lua`,
  `lua5.1 test_auto_step.lua`,
  `luac5.1 -p route_manager.lua test_route_manager.lua`, and
  `lua5.1 test_route_manager.lua` pass.

## Garinham Status

- Public Garinham services are usable: west-side `Exit to World Map`,
  `Tool Merchant`, `Inn`, and `Weapons Merchant`.
- Garinham `Merchant 1` is a dialogue-only hint NPC. Live TALK from adjacent
  stand `(9,5)` facing south produced the darkness/map hint, so Services now
  excludes him while NPC browsing still exposes him.
- The old public east-door guess at `(19,16)` is disproved. OPEN from
  `(19,17)` facing north reported `There is no door here.`
  `objects.lua` no longer exposes `door_19_16`, and `map_reader.lua` no longer
  lists `(19,16)` in `MAP_DOOR_CELLS[0x09]`.
- The grey-building grave-route door is now modeled as door cell `(17,10)`,
  exposed as `Grave Route Door` / `door_17_10`, with route interaction stand
  `(17,9)` facing south. Evidence came from the user's Magic Key/manual OPEN
  pass plus fresh `DOOR_STATE keys=5 slots=0=(17,10)` after opening from
  `(17,9)` facing south. The earlier `(18,9)` estimate is not a door override.
- Door-RAM seed tests did not open route-shaped candidates `(13,4)`,
  `(19,7)`, or `(19,9)`. Keep those as wall/route geometry until exact OPEN
  or door-RAM proof says otherwise.
- Old Man 3 at `(14,1)` appears in the object list but is not an NPC blocker.
  Trail-blazing later proved the west approach into that cell is still an
  engine seam: `probe_edge_verify:RIGHT,5` from `(13,1)` blocked 5/5 with no
  NPC at `(14,1)`. The reverse grave-stairs-to-door run also confirmed
  `(15,1)->LEFT` into `(14,1)` blocks 5/5, so both east and west approaches
  are now modeled.

## Grave-Route Evidence

- Guide/image orientation points to the grey-building back-wall / "wall of
  darkness" path, but guide data is only orientation; live map transitions are
  the source of truth.
- `MAP_PASSTHROUGH_CELLS[0x09]["3,3"]` is confirmed: live
  `probe_edge_verify` from `(3,4)->UP` moved into this ROM-wall tile 6/6 after
  a stability recheck.
- `MAP_PASSTHROUGH_CELLS[0x09]["19,10"]` is confirmed: after the top lane at
  `(13,1)->RIGHT` proved blocked, route frontier found the lower bridge, and
  `probe_edge_verify:19,11,UP,5` moved into `(19,10)` 6/6 including stability
  recheck.
- After the map patch, `debug_pathfind_to:19,0` found a live route from
  `(13,1)`: `2 west, 10 south, 8 east, 11 north`. A pre-reload autowalk using
  the old loaded `auto_step.lua` reached `(19,11)` but timed out on the turn
  upward into `(19,10)` with stale movement bytes (`move=0x40 sub=0x90`).
  `auto_step.lua` now clears movement state during queued route turn/final
  settle frames; retest after a full Lua reload.
- A post-reload route reached `(18,1)`.
- Direct probing then proved `(18,1)->UP` moves into standable `(18,0)`.
- Direct probing from `(18,0)->UP` changed the map to `0x01` / World Map and
  landed near Garinham on the overworld. This is not Garin's Grave B1.
- ROM stair-down table entry `09 13 00` at file offset `0xF411` points to
  Garinham `(19,0)`.
- Live STAIRS from `(19,0)` while the command menu was on STAIRS produced
  `EVENT: map change -> 0x18 (Garin's Grave B1)`.
- User manual follow-up confirmed the B1 arrival tile is `(6,11)` and the return
  stairs come back to Garinham `(19,0)`.
- Live B1 follow-up confirmed that `objects.lua` had a stale
  `Exit to World Map` at `(0,0)` on map `0x18`; this has been removed. Map
  `0x18` now exposes `Stairs to Garinham` / `stair_6_11` at the live
  entry/exit tile. User manual check disproved the older `Stairs Down`
  placeholder at `(19,0)`; local ROM data points the B1 stair-down entry to
  `(1,18)`, and live `inspect_tile` says `(1,18)` is walkable.
- Garin's Grave B1 chest decoding: the ROM chest table has map `0x18` entries
  at `(11,0)`, `(12,0)`, and `(13,0)`. A follow-up disproved the row-1
  normalization idea: TAKE at `(13,1)` and `(13,2)` found nothing, while SEARCH
  at `(11,0)` and `(12,0)` reported a treasure box and forced teleport to
  `(13,0)` held stable. `map_reader.lua` now marks only those three B1 top-row
  treasure cells as passthroughs so object navigation can target the raw ROM
  coordinates. Guide contents are Herb plus two gold chests, but live
  TAKE/content-code confirmation is still pending.
- User then validated all three B1 chest locations by teleporting/walking to
  each and opening them. A live text diagnostic caught the reward readout bug:
  raw lower text was `Of GOLD thou hast gained 12`, but the low-row cleanup
  announced `Ofthou hast gained 12`. `text.clean_low_row_dialogue()` now strips
  known command labels while preserving meaningful uppercase tokens like GOLD.
  User follow-up validated this chest dialogue fix in FCEUX.
- Chest-row route cutting from the northeast treasure area back toward
  `Stairs to Garinham` promoted repeated blocked-only B1 seams into
  `MAP_DIRECTIONAL_BLOCKS[0x18]`: `(10,1).east`, `(10,2).east`,
  `(10,3).east`, `(11,4).north`, `(12,3).north/west`, `(13,3).north`, and
  `(14,2).west`. The noisy `(11,1).south` seam moved on retry, and the later
  `(14,1).west` candidate was interrupted after only one block before battle,
  so both remain unpromoted.
- Follow-up user route from the chest area reached the Garinham return stairs
  at `(6,11)`, but bumped through another batch of hidden B1 seams. The
  repeated blocked-only additions now modeled are `(14,2).north/east`,
  `(15,3).north`, `(16,3).north`, `(17,8).north`, `(5,10).north`,
  `(6,8).north`, and `(7,8).north`. Suspicious/noisy seams that blocked once
  and then moved remain unpromoted: `(14,1).west`, `(15,1).west`,
  `(17,2).west`, `(14,7).east`, `(6,7).east`, and `(5,7).east`.
- Follow-up route from the entrance side back toward the chests found the
  opposite side of the x=14..16 wall band. Direct `probe_edge_verify`
  promoted `(15,3).south`, `(16,4).west`, `(14,4).east`, `(16,5).west`,
  `(14,5).east`, `(16,6).west`, and `(14,6).east` after each blocked 5/5 with
  no drift or interruptions. The route-suspicious `(17,1).south` edge stayed
  unpromoted because direct verification from `(17,2)->UP` was mixed
  (`moved=2 blocked=3`).
- Later chest/entrance repeat routes, apparently after combat/NPC parking
  altered the route shape, exposed a lower middle B1 detour cluster. Direct
  probes promoted `(10,3).west`, `(10,4).west`, `(11,4).south`,
  `(12,5).west`, and `(12,6).west`, all confirmed blocked 5/5. Related
  suspicious edges were deliberately left unpromoted at that point:
  `(10,1).west`, `(10,4).south`, `(12,5).east`, and `(12,6).south` were
  mixed; `(10,2).west` was interrupted by an upper dialogue window;
  `(12,6).east` was interrupted after battle started.
- A later near-chest repeat/probe pass superseded the mixed/interrupted status
  for the row-4/5/6 side entries. Direct probes promoted `(12,4).east`,
  `(14,4).west`, `(12,5).east`, `(14,5).west`, `(12,6).east`,
  `(14,6).west`, and `(14,6).south`, all blocked 5/5. Still unpromoted:
  `(13,3).south` (`moved=1 blocked=4`) and `(12,6).south`
  (`moved=2 blocked=3`).
- After the next battle cleared, resumed probes promoted another three
  south-approach blockers: `(12,6).south`, `(10,6).south`, and
  `(16,6).south`, each blocked 5/5. The same pass confirmed `(10,1).west`
  and `(17,3).south` passable 6/6.
- Follow-up cleanup of the interrupted/mixed B1 candidates promoted
  `(13,3).south`, `(10,4).south`, and `(10,2).west`; each direct verifier
  blocked 5/5 with no drift, map change, or battle interruption. The same
  cleanup confirmed `(14,1).west` passable 6/6 with stability recheck, so keep
  it unmodeled.
- Continued chest/entrance route cleanup promoted another four B1 seams after
  direct 5/5 verifiers: `(8,8).north`, `(6,8).south`, `(17,1).south`, and
  `(16,6).east`. Recent route-only noisy seams that moved afterward remain
  unmodeled, including row-7 east/west bumps, `(9,11).north`, `(9,1).south`,
  `(15,2).east`, `(15,1).west`, `(17,2).west`, and top-row chest-adjacent
  noise.
- Later near-finish cleanup promoted `(16,5).east` after a clean direct 5/5
  verifier. Direct verifiers left `(16,1).west` mixed (`moved=2 blocked=3`)
  and `(11,8).north` mixed (`moved=2 blocked=3`). A follow-up detour pass
  superseded the earlier `(16,3).east` passable result: after an interrupted
  retry with `moved=2 blocked=0`, two clean direct verifiers from
  `(17,3)->LEFT` blocked 5/5 and then 6/6, so `(16,3).east` is now modeled.
- Same follow-up pass left these B1 candidates unpromoted: `(7,10).south`
  moved twice before an upper-dialogue interruption, `(12,8).north` mixed
  (`moved=1 blocked=4`), `(16,1).west` rechecked passable 6/6 with stability
  after earlier mixed evidence, and `(10,1).west` remained mixed
  (`moved=1 blocked=4`).
- Mixed-edge cleanup rechecked the remaining candidates with stronger probes:
  `(12,8).north` stayed mixed (`moved=4 blocked=4`) and `(10,1).west` stayed
  mixed (`moved=5 blocked=3`), so both remain unmodeled. `(7,10).south`
  initially moved once before another upper-dialogue interruption, then
  rechecked cleanly blocked 8/8 and is now modeled.
- Latest manual-route audit superseded that older `(10,1).west` mixed/open
  evidence. The current bad route was `(9,1)->RIGHT` into `(10,1)`, not
  `(19,1)->RIGHT`; `probe_edge_verify:9,1,RIGHT,8` blocked 8/8 cleanly with
  no drift, map change, refusal, or interruption, so `(10,1).west` is now
  modeled.
- Post-patch live check reloaded navigation modules, showed
  `inspect_move:9,1,RIGHT` as `approach_blocked=true` /
  `effective_passable=false`, replanned to chest `(11,0)` via a 27-step detour,
  and `validate_path` completed all 27 steps with 0 mismatches.
- Follow-up run-result audit promoted one more B1 return-route seam:
  `(15,1)->RIGHT` into `(16,1)` blocked 8/8 cleanly with no drift, map change,
  refusal, or interruption, superseding older mixed/passable `(16,1).west`
  notes. The entrance-to-chest hotspot `(9,11)->RIGHT` into `(10,11)` stayed
  mixed (`moved=2 blocked=6`), so keep it unmodeled for polishing.
- Post-patch live check reloaded navigation modules and confirmed
  `(15,1)->RIGHT` now reports `approach_blocked=true` /
  `effective_passable=false`. The chest-to-stairs preview from `(11,0)` avoids
  `(16,1)` by routing `(15,1)->(15,2)->(16,2)->(17,2)`. A validation walk
  followed that preview through 23 steps before a random Warlock battle
  interrupted it at `(9,9)`; no new map blocker evidence came from the abort.
- User follow-up passes completed the chest-to-stairs run cleanly. A focused
  audit found two remaining route-only hotspots with clean direct evidence:
  `(9,10)->LEFT` into `(8,10)` blocked 8/8, so `(8,10).east` is modeled, and
  `(9,9)->RIGHT` into `(10,9)` blocked 8/8, so `(10,9).west` is modeled.
  Live `reload_navigation_modules` made both inspect as
  `directional_blocked=true` / `effective_passable=false`, with no runtime
  blocks left.
- Down-stairs preview from the restored B1 entrance/return tile is available:
  `debug_pathfind_to:1,18` planned `7 south, 5 west` from `(6,11)` to the
  ROM-derived B2 stairs coordinate `(1,18)` with no runtime blocks and without
  moving the hero.
- First B2-stairs autowalk found the lower B1 maze wall band before a Warlock
  battle. Direct clean 5/5 verifiers promoted `(5,12).east`,
  `(6,13).north/south`, `(6,15).north`, `(7,13).north/south`,
  `(7,15).north`, `(8,13).north/south`, `(8,15).north`, and `(9,15).north`.
  `(5,14).east` initially stayed unmodeled after a mixed direct verifier
  (`moved=3 blocked=2`), but later cleanly blocked 5/5 and is now modeled.
- Follow-up B2-stairs autowalk/validator pass promoted the lower B1 maze
  closures exposed by route validation plus stronger direct verifiers:
  `(4,17).east`, `(5,11).east`, `(5,14).east`, `(5,16).east/south`,
  `(5,18).north`, `(6,15).south`, `(6,18).north`, `(7,15).south`,
  `(7,17).east/north/west`, `(8,13).east`, `(8,15).south`,
  `(8,18).north`, `(9,15).south`, `(9,17).north/west`,
  `(10,15).east/north/south`, `(10,17).north`, `(11,13).south`,
  `(11,17).north`, and `(12,17).north`. Several of these started as mixed or
  even passable-looking probe results, then acted out during route validation
  and rechecked cleanly blocked 8/8.
- Left unmodeled from the same pass: route/noisy edges that eventually moved
  on retry, including `(10,14).east` and `(8,16).south`. Treat these as
  timing/noise unless a future direct verifier cleanly blocks them.
- Follow-up autowalk after the user resumed toward B2 exposed the low-west
  pocket. Direct verification promoted `(4,7).west` after 8/8 blocked. The
  sibling `(3,8).north` first looked mixed (`moved=4 blocked=4`), then acted
  out during route validation and rechecked cleanly blocked 15/15, so it is
  also modeled. `(2,10).north` remains unmodeled: direct verification moved
  once before battle interrupted the check. Post-patch reload makes
  `(3,7)->DOWN` and `(3,7)->RIGHT` inspect as approach-blocked, and the new
  preview from `(3,7)` to `(1,18)` is `2 west, 11 south`.
- The first direct verifier was contaminated by stale `PREV.upper_active=true`
  even though the upper text later reported as status baseline only. `main.lua`
  now refreshes stale status/baseline/noise-only upper state inside the
  autowalk and edge-probe guards before refusing movement. This needs a full
  FCEUX Lua reload; the B1 map-data patch alone can still be picked up by
  `reload_navigation_modules`.
- After clearing stale route-temp context with `stop_auto_walk`, a post-patch
  preview from `(8,14)` to `(1,18)` was `7 west, 4 south` with runtime blocks
  none. Validation moved `(8,14)->(7,14)->(6,14)` cleanly before a random
  Poltergeist battle interrupted step 3 toward `(5,14)`, so the abort is not
  map evidence. A later post-patch preview from `(6,11)` is now
  `1 north, 5 west, 8 south`, with runtime blocks none.
- Therefore `(18,0)` stays a passthrough/world-exit edge cell, while `(19,0)`
  is the exposed `Stairs to Garin's Grave` object.
- Reloaded reverse autowalk from `(19,0)` toward `Grave Route Door` did not
  find a new door. It drifted through a town/world exit after moving right into
  `(19,1)`: `EVENT: map change -> 0x01 (World Map)` at frame `08396`, followed
  by route drift at world-map `(2,2)`.
- Clean reverse-route verifiers promoted `(18,2).north`, `(17,2).north`,
  `(16,2).north`, `(15,2).north`, and `(14,1).east`. The suspicious
  `(19,1)->DOWN` into `(19,2)` verifier was mixed (`moved=2 blocked=3`), so
  keep `(19,2).north` unmodeled for now.
- With those clean blockers runtime-injected, `debug_pathfind_to:17,9` from
  `(19,0)` can now resolve in this state and execution follows with route
  drift or timing retries, but no newly promoted persistent blockers.

## New Map Data In This Working Tree

- `MAP_PASSTHROUGH_CELLS[0x09]`: adds `(3,3)`, `(18,0)`, and `(19,0)` for the
  hidden back-wall/top-edge route and true grave stairs, plus `(19,10)` for
  the live-confirmed lower grave-route bridge.
- `objects.lua`: exposes Garinham `stair_19_0` as `Stairs to Garin's Grave`.
- `MAP_DOOR_CELLS[0x09]` / `objects.lua`: adds `(17,10)` as the
  grey-building `Grave Route Door`, closed until opened-door RAM includes
  `(17,10)`, and routes interaction to `(17,9)` facing south.
- `MAP_DIRECTIONAL_BLOCKS[0x09]`: adds verified approach-specific blockers for
  the grave-route survey, including row-9 south approaches, the `(13,3)` to
  `(13,6)` west wall, row-6 south approaches, `(19,7..9).west`,
  `(18,14).east`, `(14,1).east/west`, the latest clean `(15,10).south` /
  `(16,10).south`, and reverse top-row blockers `(15..18,2).north`.
- `MAP_DIRECTIONAL_BLOCKS[0x18]`: adds the current Garin's Grave B1 hidden
  maze seam model for chest-return and B2-stairs routing. Latest additions are
  `(4,7).west` and `(3,8).north` from the low-west B2-stairs pocket.
- Explicit open assertions keep `(15,10).west` and `(4,12).south` open after
  clean live movement proof.
- `NONBLOCKING_NPC_CELLS[0x09]["14,1"]` keeps the browseable false Old Man
  from blocking the hidden route.
- `auto_step.lua`: queued autowalk turn/final settle frames now clear stale
  movement state/subpixel bytes, controlled by
  `auto_step_reset_movement_on_route_turn_settle` in `config.lua`.

## Suggested Next Step

Recover the hero before pushing into B3:

- Current live position after healing and script reload:
  `POSITION: map=0x08(Brecconary) x=24 y=13`. The player-stat block is still
  corrupted: `HP 15/15`, `MP 0/0`, `spells CE=0x00`, `combat=0x08`, and
  `stat_ram BA-CF=73 10 0B 0C B5 03 01 45 C3 00 00 0F 00 0C 04 03 0F 00 18 1F 00 10`.
- Avoid saving at the king until the hero is recovered. Best non-destructive
  recovery candidate is FCEUX slot 0 (`Dragon Warrior (USA) (Rev 1).fc0`),
  which decodes as a clean level-12 Garin's Grave B2 state at map `0x19`
  `(11,2)` with `HP 63/63`, `MP 52/52`, and `spells CE=0x3F`.
- The reloaded Lua script now has the new `log_state` raw-stat diagnostics
  active. If SPELL is selected while this corrupted state remains live, the
  expected accessibility fallback is `Spells blocked.` rather than
  `Spells. Empty.`
- Once the hero is safe and spell access is understood/restored, route back to
  the B2 southwest stair `(1,10)`. The prior healthy checks still stand:
  from `(1,10)` to B2 return stair `(11,2)` is `7 north, 10 east, 1 north`, and
  from B3 `(2,17)` to `(9,5)` is `12 north, 7 east`.
- If B3 route execution struggles, use the normal blocker-harvest loop:
  `stop_auto_walk`, `report_position`, inspect repeated seam observations, and
  promote only clean `probe_edge_verify:X,Y,DIR,5` results.

## Verification To Run Before Commit

- `luac5.1 -p auto_step.lua test_auto_step.lua config.lua debug_tools.lua map_reader.lua test_map_reader.lua objects.lua test_objects.lua battle.lua main.lua test_battle.lua`
- `luac5.1 -p route_manager.lua test_route_manager.lua`
- `lua5.1 test_route_manager.lua`
- `lua5.1 test_auto_step.lua`
- `lua5.1 test_battle.lua`
- `lua5.1 test_map_reader.lua`
- `lua5.1 test_objects.lua`
- `lua5.1 test_debug_tools.lua`
- `git diff --check`
