# Session Handoff - Active Resume

Updated: 2026-05-10

## Active Resume

Resume from Erdrick's Cave B2 (`map=0x1D`) at the B2 stairs `(8,9)`.
Current live state after the latest cave-loop investigation: BizHawk reloaded
the patched Lua script, the player was restored to B2 stairs `(8,9)`, and the
latest two-way auto-walk route between the stairs and chest now succeeds from
there.

User decision: call the B2 maze done enough. This cave chest is the only known
required chest/interaction on this floor, and both stairs-to-chest and
chest-to-stairs are now playable. Do not keep polishing B2 bounce candidates
unless normal gameplay exposes a fresh blocker; the next preferred focus is
something else, likely combat dialogue tuning while the hero exits the dungeon.

The uncommitted B2 patch set is in `map_reader.lua`, `test_map_reader.lua`,
`session_handoff.md`, `PROJECT_MEMORY.md`, and `PLAYTESTING.md`. Static
validation passed: `luac -p map_reader.lua test_map_reader.lua`,
`lua test_map_reader.lua`, and `git diff --check`. Live validation after the
latest reload is in `dw_debug.log` from `Started: 2026-05-10 14:56:18`.

Morning route/verifier pass after the user ran stairs-to-chest first promoted
six more B2 directional seams from clean 5/5 direct verifier consensus:
`(6,5).west`, `(7,9).east`, `(7,7).north`, `(8,7).north`, `(4,7).south`, and
`(4,7).west`. Later walkthrough-guided loop testing briefly made
`(7,9).east` suspect because a same-batch raw-input/report run appeared to
cross west from the stairs. The latest route-shaped raw pass and fresh
`probe_edge_verify:8,9,LEFT,15` both stayed blocked, so `(7,9).east` is modeled
again. After the user enabled BizHawk auto-reload and reloaded for real,
validation exposed `(8,7).east`, which verified blocked 5/5, then exposed
`(2,6).east`, which verified blocked 10/10. Both are now promoted.

Reverse-route pass after the user teleported adjacent to the chest and routed
toward the stairs promoted six more clean 10/10 direct-verifier B2 seams:
`(9,5).north`, `(7,4).north`, `(6,4).north`, `(5,3).east`, `(5,2).east`, and
`(5,1).east`. Two route-observed seams remain intentionally unmodeled because
direct verification was mixed: `(8,5).north` from `(8,4)->DOWN` moved 2/10,
then 2/15 on a longer repeat, and `(7,4).east` from `(8,4)->LEFT` moved 1/10.
After the user reran chest-to-stairs, those exact exits failed naturally from
`(8,4)`. Fresh direct repeats promoted both: `(8,5).north` from
`(8,4)->DOWN` verified blocked 15/15, and `(7,4).east` from `(8,4)->LEFT`
verified blocked 15/15.

Latest left-edge investigation found the missing route shape. The generic
dungeon boundary rule was hiding the intended B2 loop along the west edge. The
current uncommitted patch now marks B2 passthrough cells `(0,1)`, `(0,2)`,
`(0,4)`, `(0,5)`, `(0,6)`, and `(0,7)`, and adds confirmed directional seams
from both the left-edge and upper-left reroute passes.

Live evidence for that patch:
- `(1,7)->LEFT` first verified passable 5/5 and a later raw hold from `(1,7)`
  ended at `(0,7)`. One later single `probe_edge` false-blocked from the same
  origin, so treat this edge as hidden-state noisy but route-shaped passable.
- From `(0,7)`, route-shaped probes moved north through `(0,6)`, `(0,5)`, and
  `(0,4)`. `(0,4)->RIGHT` moved to `(1,4)`.
- `(0,4)->UP` into `(0,3)` blocked, `(1,8)->LEFT` into `(0,8)` blocked 5/5,
  and `(1,9)->LEFT` into `(0,9)` was mixed 4 moved / 1 blocked, so those
  boundary cells intentionally remain unmodeled.
- After the left edge opened, `(1,4)->UP`, `(2,4)->UP`, and
  `(3,3)->RIGHT` each verified blocked 5/5 and are now modeled as directional
  seams. `(4,4)->UP` was mixed 1 moved / 4 blocked, and `(3,3)->UP` was mixed
  4 moved / 1 blocked, so both remain unmodeled.

Latest reroute investigation:
- The user reran stairs-to-chest after the left-edge patch. The route got deep
  into the upper-left loop, then failed from `(1,2)` after repeated blockers.
- Newly promoted directional seams: `(1,5).west`, `(4,4).west`,
  `(4,3).north`, `(5,2).west`, `(4,1).south`, `(3,1).south`,
  `(3,5).north/west`, `(2,3).east`, `(2,1).south`, and `(1,1).south`.
  Most came from queued-route blocks plus seam retries; `(1,1).south` then
  verified blocked 15/15 directly.
- A static leave-one-out graph check showed that the confirmed upper-left
  blockers require another narrow west-edge opening. Live
  `probe_edge_verify:1,2,LEFT,15` moved into `(0,2)` 15/15, and a forced-origin
  `probe_edge:UP` from `(0,2)` moved into `(0,1)`.
- The next real autowalk reached `(0,1)` and failed on `(0,1)->RIGHT` into
  `(1,1)`. Fresh `probe_edge_verify:0,1,RIGHT,15` confirmed `(1,1).west`
  blocked 15/15. Graph and live probes then found the top-edge continuation:
  `(0,1)->UP` into `(0,0)` verified passable 15/15, route-shaped probes moved
  right through `(1,0)` through `(6,0)`, downward entries into `(1,1)` through
  `(5,1)` blocked, and `(6,0)->DOWN` moved into `(6,1)`. The current patch adds
  B2 passthrough cells `(0,0)` through `(6,0)` plus the matching north-entry
  blockers for `(1,1)` through `(5,1)`.
- Static validation after the upper-left patch passed:
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`
  (22 tests), and a local ROM-backed pathfinder run. The patched model now
  finds a 42-step route from B2 stairs `(8,9)` to chest-adjacent `(8,3)`,
  facing east.
- Live validation after reload: `inspect_tile:0,0` and `inspect_tile:6,0`
  both report `base_walkable=true walkable=true reason=passthrough`.
  `debug_pathfind_adjacent:9,3` from `(8,9)` chooses `(8,3)` with the 42-step
  route and `Face east`: `1 north, 1 east, 2 north, 3 west, 3 south,
  2 west, 1 north, 1 west, 1 north, 3 west, 3 north, 3 east, 2 north,
  3 west, 2 north, 6 east, 2 south, 2 east, 1 south`.
- Actual two-way proof after the user reran the route: stairs-to-chest queued
  43 steps for `Chest`, bounced at `(6,2)->RIGHT` into `(7,2)`, rerouted
  through `(6,3)`, and reached the chest. The return queued 29 steps for
  `Stairs Up to B1`, bounced through several route-learned dead branches, and
  still reached B2 stairs `(8,9)`.
- Return-trip bounce candidates observed in the successful run, not yet
  promoted as permanent data: `(1,3).north`, `(2,3).north`, `(2,6).north`,
  `(1,5).east/north`, `(2,8).north`, `(3,9).north`, `(7,9).west`, and
  `(7,7).west`. Treat these as optional direct-verifier cleanup targets.
- Current live state is `(8,9)`, `RUNTIME_BLOCKS map=0x1D none`, and
  `PATH_STATE target=nil`.

Latest loop investigation notes:
- External guide context agrees with the user's clue: Erdrick's Cave B2 is a
  normal loop to the tablet/chest, not a special-gated puzzle; torch is for
  visibility.
- `(9,5).south` was temporarily demoted after `probe_edge_verify:9,6,UP,10`
  produced mixed 2 moved / 8 blocked, but raw held UP from `(9,6)` stayed at
  `(9,6)` and a live auto-walk failed there. Restored `(9,5).south` as blocked.
- Latest route-shaped raw walk from the stairs reconfirmed the east-side and
  west-loop blockers already modeled: `(9,6)->UP`, `(8,6)->UP`, `(6,6)->UP`,
  `(5,4)->UP/RIGHT/LEFT`, `(4,8)->UP`, `(3,6)->LEFT/UP`, `(2,7)->UP`,
  `(1,7)->UP`, and the `(7,5)` north/west/east branches all stayed blocked.
- `(7,9).east` is restored as permanent data after a settled raw `LEFT,90`
  from `(8,9)` stayed at `(8,9)` and verifier evidence returned
  15 blocked / 0 moved. Post-reload `inspect_move:8,9,LEFT` reports
  `directional_blocked=true`, and `RUNTIME_BLOCKS map=0x1D none`.
- Do not trust same-command `simulate_raw_input:* report_position`; the report
  can run before queued raw input has played out. Split raw input and later
  `report_position` with a delay.
- Raw/teleport checks around the west loop are still hidden-state sensitive.
  The chest route is now playably validated in both directions. The next useful
  B2 work would only be optional cleanup of the return-trip bounce candidates
  with direct verifiers. The user has decided to move on now that the only
  required cave chest is reachable. Keep using the external visual/decoded map
  reference as orientation on future maps, but live movement remains the source
  of truth.

## Current Focus

The BizHawk emulator swap is now good enough to call successful. The current
branch is adding player-facing quality-of-life features before the next normal
gameplay pass, while preserving FCEUX as an explicit fallback.

Reason for the decision:
- FCEUX has recurring keyboard/input weirdness, especially stale Alt/menu focus.
- FCEUX command-line/script reload behavior is awkward for automated testing.
- FCEUX menu navigation with a screen reader can inject gameplay input.
- BizHawk is more screen-reader tolerable, supports clean command-line Lua
  launch/reload workflows, and does not send the player walking while JAWS is
  used in menus.

Keep FCEUX supported as a fallback. New work should assume BizHawk is the
primary path unless the task explicitly targets FCEUX.

BizHawk 2.11.1 side-install note:
- Installed official `BizHawk-2.11.1-win-x64.zip` side by side at
  `D:\emulation\bizhawk-2.11.1` / `/mnt/d/emulation/bizhawk-2.11.1`.
- The existing `D:\emulation\bizhawk` 2.10 install was left untouched.
- Version check:
  `EmuHawk.exe` reports `FileVersion 2.11.1.0` and
  `ProductVersion 2.11.1+bdddf4a58aa1a022afb11dc73294a81a5aa7bbd5`.
- Test with:
  `./launch_dw.sh --bizhawk-path /mnt/d/emulation/bizhawk-2.11.1/EmuHawk.exe`.
- Dry-run confirmation resolved to
  `D:\emulation\bizhawk-2.11.1\EmuHawk.exe` with the normal ROM and
  `main.lua` arguments.

BizHawk 2.11.1 bulk PPU-read experiment status:
- Implemented an experimental `ppu.readbyterange(address, length)` path in
  `emulator_compat.lua`. When BizHawk exposes
  `memory.read_bytes_as_binary_string` or `memory.read_bytes_as_array`, the
  adapter reads contiguous nametable/CIRAM spans through one bulk memory call
  and populates the existing within-frame PPU cache. It falls back to the old
  byte loop when bulk APIs are unavailable.
- `text.lua`, `menu.lua`, and `merchant.lua` now request contiguous PPU row or
  row-span reads, preserving byte-loop fallback for FCEUX/older runtimes.
- `scan_profiler.lua` now includes `bulk_reads` and `bulk_bytes` in
  `PPU_STATS`, so a real live reload should make bulk use obvious in logs.
- Static validation passed:
  `luac -p emulator_compat.lua scan_profiler.lua text.lua menu.lua merchant.lua main.lua test_emulator_compat.lua`,
  `lua test_emulator_compat.lua`, `lua test_text.lua`, `lua test_menu.lua`,
  `lua test_merchant.lua`, `lua test_hotkeys.lua`, and `git diff --check`.
- Live caveat: WSL/PowerShell timestamp nudges did not actually reload the
  current BizHawk Lua script; the old `report_scan_stats` command closure kept
  logging the pre-patch `PPU_STATS` format with no `bulk_reads`. A real Lua
  Console script reload or close/relaunch of BizHawk 2.11.1 is needed before
  judging the experiment.
- Live result after enabling BizHawk auto-reload and reloading manually:
  `report_scan_stats` now shows the new `PPU_STATS` fields. A 2,280-frame
  Brecconary sample logged `bulk_reads=46482`, `bulk_bytes=1290432`, proving
  the bulk path is active. Compared with the earlier 2.11.1 idle profile,
  average costs improved: `check_yesno_prompt 3.566ms -> 1.246ms`,
  `check_merchant_screen 1.823ms -> 0.302ms`, `check_dialogue 1.119ms ->
  0.337ms`, `check_upper_dialogue 0.790ms -> 0.254ms`, and
  `check_command_menu 1.499ms -> 1.126ms`. Recording was stopped after the
  sample at frame `08340`.
- Follow-up lag attribution test: in Brecconary, `pathability_filter:refresh`
  from `(1,15)` over 21 objects took `59ms` and logged matching
  `CMD_TIMING`; scan profiling put the spike in `debug_tools.tick max_ms=60`
  while `objects.check_refresh` stayed `0ms`. Selected `Guard 2` at `(4,8)`;
  `pathfind` planned a 9-step route to `(4,9)` without hitting the 25ms route
  timing threshold, and `auto_walk` completed the 9 steps with normal 23-28
  frame moves, no timeout/retry reroute, then faced/held the guard. Current
  player position after the test is `(4,9)`.
- Object pathability refresh now builds one reachable-cell set for the current
  map/start/blocking context and classifies all objects against that set,
  instead of running one A* search per object. Static tests confirm the batch
  path no longer calls per-object pathfinding and still refreshes immediately
  when the player's position changes. Live reload proof:
  `LAUNCHER_PROBE: codex_pathability_flood` at frame 60; from Brecconary
  `(4,9)`, `pathability_filter:refresh` over 21 objects returned normally and
  emitted no `OBJECT_PATHABILITY_TIMING` or `CMD_TIMING` warning, meaning it
  stayed under the existing 25ms log threshold. This is not a perfect
  apples-to-apples comparison with the old `(1,15)` 59ms sample, but it removes
  the identified per-target A* cost center.
- Manual reroute-lag follow-up: user noticed a lag spike during reroute while
  traveling from Merchant 2 toward the Brecconary exit. Log evidence showed
  queued auto-walk timing out on `(5,13)->LEFT` into `(4,13)`, publishing
  `SEAM_OBSERVATION map=0x08 cell=(4,13) approach=east result=blocked`, then
  rerouting successfully via `(5,12)`. `map_reader.lua` now models Brecconary
  `(4,13)` with `{east=true}`. Live reload proof:
  `LAUNCHER_PROBE: codex_brec_413_block`; a path-only probe from `(5,6)` to
  adjacent `(0,15)` chose `3 south, 1 west, 3 south, 2 west, 2 south, 1 west,
  1 south`, avoiding the old `(5,13)->LEFT` timeout. Player was restored to
  Brecconary `(1,15)` afterward.
- Brecconary inn/service route follow-up: the old `Merchant 3` service entry
  targeted `(9,21)`, which TALK can use but which is directionally blocked from
  the public west approach. Live proof from `(1,15)` showed `pathfind_to:9,21`
  failed while `pathfind_to:8,21` succeeded; a controlled TALK probe from
  `(8,21)` facing east opened the inn dialogue. `objects.lua` now labels
  Merchant 2 as `Weapons Merchant`, labels Merchant 3 as `Inn`, and routes the
  inn to `(8,21)` facing east. The first retest exposed a real timeout on
  `(7,17)->RIGHT` into `(8,17)`, so `map_reader.lua` now blocks `(8,17)` from
  the west. Live reload proof: `LAUNCHER_PROBE: codex_inn_edge_reload`, then
  `auto_walk` from Brecconary `(1,15)` queued 17 steps for `Inn`, reached
  `(8,21)`, and logged `AUTO_WALK_FACE target=Inn face=east` with no new
  blocked edge. Player was restored to `(1,15)`.
- Level-3 spell menu follow-up: after learning Heal, selecting `SPELL` opened a
  list that was silent because `main.lua` only tracked `STATUS` and `ITEM`
  submenus. Live `report_menu_state` while in the spell list showed
  `raw_open=true`, speech ready, `cursor=(0,0)`, no lower/upper text, and
  `submenu=nil`, meaning this was a missing submenu mode rather than a speech
  backend failure. `items.lua` now exposes known-spell list helpers and
  `main.lua` tracks `submenu=SPELL`. The game screen only shows the spell name
  (`>HEAL`) plus the separate current-MP status panel, not per-spell costs, so
  speech adds NES MP costs from spell metadata. Entry/cursor speech now says
  entries such as `Spells. Heal. 4 MP`; later spell-list movement speaks the
  selected spell with its cost. A follow-up reload suppressed the first
  synthetic cursor jump so entry no longer double-speaks. Live proof:
  `LAUNCHER_PROBE: codex_spell_menu_dedup_reload`; after backing out and
  re-entering SPELL, `speech_bridge.log` recorded one `speak:Spells. Heal`.
  Cost follow-up proof: `LAUNCHER_PROBE: codex_spell_cost_reload`; re-entering
  SPELL recorded `speak:Spells. Heal. 4 MP`, `MENU_STATE` reported
  `submenu=SPELL`, and `speech_status` was ready with `error=none`.

## Current Baseline

2026-05-10 Erdrick's Cave B2 first chest-route investigation:
- User reached brand-new map `0x1D` / Erdrick's Cave B2 and selected the only
  visible chest at `(9,3)`. Auto-walk planned routes but repeatedly gave up
  because B2 had no permanent directional seam model yet; decoded cave floor
  tiles looked walkable while the engine blocked one-way maze approaches.
- Direct verifier-confirmed B2 seam data has been promoted to `map_reader.lua`
  as directional-only blockers: `(5,3).south`, `(6,4).west`,
  `(6,5).east/south`, `(7,4).south`, `(8,5).west/south`, `(9,5).south`,
  `(1,6).south`, `(2,6).south`, `(5,8).south/east`, and `(7,8).west`. These
  are all `probe_edge_verify` 5/5 blocked results; a first mixed `(6,6)->UP`
  result was not promoted until a later verifier pass returned clean 5/5
  blocked. A later route-observed `(4,7).west` and `(2,6).east` were checked
  directly and came back mixed, so they remain unmodeled.
- Final focused verifier pass from the stairs/chest churn added
  `(3,5).south`, `(4,4).east`, `(4,5).east`, `(4,6).east/west`,
  `(5,7).north/east`, `(5,8).west`, `(7,8).east`, and `(8,7).south`.
  Additional route-observed `(6,5).west` and `(4,7).south` came back mixed
  under direct verification and were not promoted.
- Morning follow-up after a normal stairs-to-chest route promoted six more
  clean direct-verifier seams: `(6,5).west`, `(7,9).east`, `(7,7).north`,
  `(8,7).north`, `(4,7).south`, and `(4,7).west`. After the user enabled
  BizHawk auto-reload and reloaded for real, validation exposed `(8,7).east`,
  which verified blocked 5/5, and then `(2,6).east`, which verified blocked
  10/10. Both are now modeled.
- Reverse-route follow-up from chest side toward stairs promoted six more clean
  10/10 verifier seams: `(9,5).north`, `(7,4).north`, `(6,4).north`,
  `(5,3).east`, `(5,2).east`, and `(5,1).east`. Route-observed
  `(8,5).north` and `(7,4).east` stayed mixed under direct verification and
  remain unmodeled.
- Final static validation passed after the reverse-route B2 pass:
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`,
  and `git diff --check`.
- Live reload proof after auto-reload was enabled: `LAUNCHER_PROBE:
  codex_b2_87east_reload` and `LAUNCHER_PROBE: codex_b2_26east_reload`.
  Reverse-route reload proof: `LAUNCHER_PROBE: codex_b2_reverse_edges`.
  Runtime B2 blocks were cleared afterward and `RUNTIME_BLOCKS map=0x1D none`
  reported, with the player restored to chest-side `(8,3)` and
  `PATH_STATE target=nil`.
- Caveat: this is still a partial B2 decode, not a full map solve. The current
  disk model finds no stairs-to-chest route. From chest-side `(8,3)`, it can
  plan back to stairs `(8,9)`, but the route depends on mixed seam
  `(8,5).north`; the next useful work is targeted bridge/region investigation
  rather than treating this as a normal player-facing chest route.
- Later left-edge investigation found the missing route shape: B2 needs narrow
  west-edge passthrough cells `(0,4)` through `(0,7)`, plus new directional
  blockers `(1,3).south`, `(2,3).south`, and `(4,3).west`. Static tests pass
  and a local patched-model pathfinder run reaches chest-adjacent `(8,3)` from
  stairs `(8,9)` in 30 steps. Live BizHawk still needs a real Lua reload before
  that patch can be judged in-emulator; timestamp nudges only proved the old
  script loop was still consuming commands.

2026-05-09 Brecconary autowalk stress survey:
- User returned to Brecconary and stood at the town entrance. The entrance tile
  `(0,15)` is a transition/isolated tile, and `(1,15)` still trips the survey
  `low_exit_count` guardrail, so the stress survey was launched from the open
  interior seed `(15,15)` with `survey_objects:park_npcs`.
- Survey run `2` completed on map `0x08`: `targets=21`, `successes=7`,
  `failures=14`, `gated_or_isolated=8`, `state_issues=6`,
  `suspected_engine_blocked=0`, and `strong_reroute_candidates=0`.
  Post-run checks showed `PATH_STATE target=nil map=0x08 runtime_count=0`,
  `RUNTIME_BLOCKS map=0x08 none`, `SURVEY_STRONG_CANDIDATES map=0x08 none`,
  and player position `(10,25)`.
- The six `command_timing_or_state_issue` failures were traced to survey routes
  performing normal post-arrival actions: `AUTO_WALK_FACE` and target-NPC hold
  fired after a successful route, then the next survey target started on the
  next frame and auto_step saw that synthetic facing input as
  `live_input_interrupt`. This is autowalk orchestration noise, not map data.
- `route_manager.lua` now treats `survey_safe` autowalks as silent
  post-arrival routes: no target-facing input, no target NPC hold, and no
  normal completion speech. Normal player autowalk still faces/holds/speaks
  after arrival. Regression coverage was added in `test_route_manager.lua`.
  Static checks passed: `lua test_route_manager.lua`, `lua test_auto_step.lua`,
  `lua test_map_survey.lua`, and `git diff --check` (with the existing
  `dw_access.ini` CRLF warning).
- Fresh rerun after the survey-safe patch completed with `targets=21`,
  `successes=12`, `failures=9`, `gated_or_isolated=7`,
  `suspected_engine_blocked=2`, and `state_issues=0`. The two suspects split
  cleanly under direct verifier:
  `probe_edge_verify:5,2,DOWN,5` confirmed `(5,3).north` blocked 5/5, while
  `probe_edge_verify:19,14,RIGHT,5` confirmed `(20,14).west` passable 5/5.
  `map_reader.lua` now models Brecconary `(5,3).north`; after reload
  `inspect_move:5,2,DOWN` reports `directional_blocked=true` and
  `report_runtime_blocks:0x08` reports none.
- `map_survey.lua` now downgrades orphaned-route blocker claims when the hero
  actually lands on the suspected tile before `route_inactive_without_completion`.
  That covers the false Old Man 1 `(20,14)` report without weakening real
  `reroute_no_path` blocker evidence. Regression coverage was added in
  `test_map_survey.lua`.
- Follow-up survey after reload was materially contaminated by two
  `route_drift_retry` events, not map geometry. The first was Old Man 1:
  `(7,12)->UP` completed at `(7,11)`, then stale/continued movement put the
  hero at `(7,10)` during route settle. The second was Person 4:
  `(2,12)->DOWN` completed at `(2,13)`, then drifted to `(2,14)`. Because
  route-drift retries were appended to the survey tail, seven later targets
  were attempted from the stranded `(7,10)` start and became bogus
  `gated_or_isolated` failures. Current run summary was therefore
  `successes=13 failures=8`, but the `start=(7,10)` failure cluster should not
  be interpreted as map data.
- `map_survey.lua` now inserts `route_drift_retry` and
  `timing_orphaned_route` retries immediately after the failed target instead
  of appending them after the rest of the object queue. `auto_step.lua` also
  avoids queued-route early-twitch holding after a timeout retry; this targets
  the exact overshoot pattern where a retry press lands on the next tile within
  8 frames and can commit one extra tile. Regression coverage was added in
  `test_map_survey.lua` and `test_auto_step.lua`. Live reload proof:
  `LAUNCHER_PROBE: codex_drift_retry_patch`, followed by
  `POSITION: map=0x08(Brecconary) x=10 y=25` and
  `RUNTIME_BLOCKS map=0x08 none`.
- Fresh user-run parked-NPC survey from `(15,15)` completed as run `1` on
  map `0x08`: `targets=21`, `successes=10`, `failures=11`,
  `gated_or_isolated=9`, `state_issues=2`, and
  `suspected_engine_blocked=0`. Follow-up live checks showed
  `POSITION: map=0x08(Brecconary) x=10 y=25`,
  `PATH_STATE target=nil map=0x08 runtime_count=0`, and
  `RUNTIME_BLOCKS map=0x08 none`.
- The two remaining state issues are still route timing/orchestration, not
  map data. `Guard 2` briefly marked `(15,17).west` blocked, then immediately
  brute-forced into `(15,17)`, so the harness downgraded it to
  `command_timing_or_state_issue`. `Old Man 1` drifted off the queued route
  from `(18,18)` to `(16,18)` during route settle, retried immediately, then
  hit a target-NPC adjacency problem (`NO_PATH_STATIONARY_NPC`) rather than a
  hidden wall. The one runtime reroute at `(9,15).west` was noisy and recovered;
  no runtime blocks persisted.
- Follow-up queued-route timing patch is live and validated. `auto_step.lua`
  now keeps queued-route input held through early movement-subpixel twitches,
  uses a shorter configured timeout after a turn re-press twitch, and marks
  those reports as `timing_suspect` so survey does not promote them as map
  candidates. `route_manager.lua` now publishes `route_completed` when a
  seam-bruteforce retry lands exactly at the adjacent goal. Regression coverage
  was added in `test_auto_step.lua`, `test_route_manager.lua`, and
  `test_map_survey.lua`.
- Live proof after reload `LAUNCHER_PROBE: codex_timing_ignore_reload`: from
  Brecconary `(15,15)`, `survey_target:Exit,park_npcs` hit the same early
  twitch/turn-repress path repeatedly, logged `SURVEY_TIMING_BLOCK_IGNORED`
  plus `AUTO_WALK_TIMING_RETRY`, reached `(1,15)`, and recorded
  `movement_succeeded=true`, `blocked_events=0`, `suspected_tiles=-`,
  `failure_class=none`, `reason=route_completed`. Final checks showed
  `RUNTIME_BLOCKS map=0x08 none` and `POSITION map=0x08 x=1 y=15`.
- Latest user-run parked-NPC Brecconary survey from `(15,15)` is cleaner but
  still not a map-data patch candidate. Run `1` on map `0x08` completed with
  `targets=21`, `successes=13`, `failures=8`, `no_route=0`,
  `gated_or_isolated=8`, `movement_failed=0`,
  `suspected_engine_blocked=0`, `state_issues=0`, and
  `adjacency_issues=0`. Failure starts were `(28,2)` for four targets
  (`Guard`, `Merchant`, `Person`, `Weapons Merchant`), `(17,16)` for two
  targets (`Old Man 2`, `Person 5`), `(1,2)` for `Inn`, and `(24,7)` for
  `Woman 1`. Every failed `SURVEY_RESULT` had `blocked_events=0` and
  `suspected_tiles=-`; follow-up reports showed
  `SURVEY_STRONG_CANDIDATES map=0x08 none`,
  `SURVEY_FINDINGS ... failed_targets=8 failure_starts=4
  strong_reroute_candidates=0`, and `RUNTIME_BLOCKS map=0x08 none`. The log
  did contain `118` `SURVEY_TIMING_BLOCK_IGNORED` /
  `AUTO_WALK_TIMING_RETRY` pairs, so route timing remains noisy even though the
  survey now classifies that noise without promoting false blockers.
- Follow-up tuning attempt did not leave a new timing patch. Focused live
  repro was `survey_target:Exit,park_npcs` from Brecconary `(15,15)`.
  Extending queued-route early-twitch holding removed route-level timing
  retries briefly, but chained extra tiles and caused `route_drift_off_path`
  around `(7,15)`/`(7,17)`. Moving the first timing retry inside `auto_step`
  kept queued-route state stuck long enough to become normal blocked events.
  Narrowing the early-twitch grace and widening the turn-repress timeout still
  produced the same every-other-tile `AUTO_WALK_TIMING_RETRY` pattern on the
  westbound exit route. Those experimental changes were reverted. The useful
  clue is that queued-route steps from even x-coordinates on the westbound
  path often see `0x00->0x90` subpixel twitches and time out, while the direct
  seam retry from the same tile succeeds quickly after a fresh inject. Next
  timing work should investigate why queued-route retry state behaves
  differently from `inject_step`/seam-bruteforce state, rather than only tuning
  grace/timeout thresholds.
- Survey/manual autowalk comparison found one real survey-data skew and one
  remaining timing concern. Before the fix, manual Services autowalk to the
  Brecconary `Inn` from `(15,15)` used the service counter target `(8,21)`,
  queued `13` steps, hit one `AUTO_WALK_TIMING_RETRY`, and arrived with
  `RUNTIME_BLOCKS map=0x08 none`; `survey_target:Inn` copied only
  `id/name/type/x/y`, lost `interaction_x/y/face_dir`, and therefore tried raw
  adjacent routing to the innkeeper at `(10,21)`, producing a false no-path.
  `map_survey.copy_object()` now preserves `service`, `interaction_x`,
  `interaction_y`, and `interaction_face_dir`, with regression coverage in
  `test_map_survey.lua`. Live proof after reload
  `LAUNCHER_PROBE: ab_service_copy_reload`: `survey_target:Inn` from
  `(15,15)` now logs `mode=direct path_length=13`, succeeds at final `(8,21)`,
  and reports `blocked_events=0`, `RUNTIME_BLOCKS map=0x08 none`. That fixed
  route still logged five timing retries / five
  `SURVEY_TIMING_BLOCK_IGNORED` entries and two `route_settle_catchup` lines,
  so survey data is no longer losing the service target, but survey-safe
  settle timing remains noisy and worth later tuning. A static code check also
  confirmed survey-safe exits/stairs intentionally route adjacent while manual
  `auto_walk` routes direct to walkable exits/stairs, so exit comparisons are
  not apples-to-apples unless the goal mode is specified.
- Catchup-noise follow-up kept the service-target fix and narrowed the survey
  settle behavior. An abandoned branch that delayed queued-route re-press after
  early movement twitches could finish at the wrong tile, so it was not kept.
  `auto_step.lua` now cancels a queued route as `route_drift_off_path` if a
  step lands somewhere other than the injected direction would allow, and
  survey-safe routes now skip the long settle between same-direction straight
  steps while retaining it for direction changes. Live reload
  `LAUNCHER_PROBE: catchup_straight_settle_reload`; `survey_target:Inn` from
  `(15,15)` succeeded at `(8,21)` with `blocked_events=0`,
  `RUNTIME_BLOCKS map=0x08 none`, `route_settle_catchup=0`, and four
  `AUTO_WALK_TIMING_RETRY` / `SURVEY_TIMING_BLOCK_IGNORED` pairs. That is an
  improvement over the previous fixed-Inn proof's five retry pairs plus two
  catchups, and it did not skew the route target or survey result.
- Player-facing Inn autowalk route-drift follow-up: after the catchup tuning,
  a live route from the Brecconary entrance `(0,15)` to `Inn` canceled at
  `(2,15)` as `route_drift_off_path`. The drift guard was correct; the executor
  had held through an early first-step movement twitch and then scheduled a
  same-direction turn re-press, which committed an extra right tile during the
  planned right-to-down settle. `auto_step.lua` now treats early queued-route
  movement twitches as timing-suspect short timeouts/direct retries but does
  not schedule the same-direction turn re-press while the hold-through-grace
  path is active. Live proof `LAUNCHER_PROBE: route_twitch_patch_inn_repro`:
  from `(0,15)`, player-facing `auto_walk` to `Inn` reached `(8,21)` and
  logged `AUTO_WALK_FACE target=Inn face=east`; final checks showed
  `PATH_STATE target=nil`, `RUNTIME_BLOCKS map=0x08 none`, and no route-drift
  lines. One `AUTO_WALK_TIMING_RETRY` remains on the first twitchy step, but it
  no longer skews the route.
- Follow-up player-facing drift while routing from `Merchant 1` to
  `Weapons Merchant`: log showed `AUTO_WALK` from `(2,14)` queued 11 steps,
  timed out the first `(2,14)->RIGHT` early-twitch step at frame 24, then
  seam-bruteforce retried right. The retry landed at `(3,14)` in one frame,
  but the immediate follow-up `UP` step saw residual right movement carry the
  hero to `(4,14)`, so the drift guard canceled with
  `source=auto_hold_mismatch`; later status was `(4,13)`,
  `PATH_STATE target=nil`, and `RUNTIME_BLOCKS map=0x08 none`. This is
  executor timing, not map data. Worktree patch separates early-twitch timeout
  from turn-repress timeout: `auto_step_route_turn_repress_timeout_frames`
  stays `24`, while new `auto_step_route_early_twitch_timeout_frames=32`
  lets a real in-progress tile finish before injecting a seam retry. After the
  user reloaded the Lua script, live proof `LAUNCHER_PROBE:
  weapons_drift_patch_live` from `(2,14)` reached `Weapons Merchant` and logged
  `AUTO_WALK_FACE target=Weapons Merchant face=north`; the first timing retry
  now reported `timeout=32`. A second live proof
  `LAUNCHER_PROBE: inn_entrance_patch_live` force-started from the entrance
  `(0,15)`, reached the inn stand tile `(8,21)`, and logged
  `AUTO_WALK_FACE target=Inn face=east`. The fresh post-reload log contains no
  `clear_route`, `route_drift`, or `auto_hold_mismatch` lines. Final status was
  `POSITION map=0x08 x=8 y=21`, `PATH_STATE target=nil`, and
  `RUNTIME_BLOCKS map=0x08 none`.
- Weapons-merchant item-list follow-up: after the clean route, TALK/YES reached
  the shop prompt but the item list was silent. The pre-fix report at frame
  `40020` showed speech was ready and lower text contained the merchant prompt,
  but `MERCHANT_STATE active=false` and the fixed merchant row reader dumped no
  item rows. Root cause was scroll context: at the Brecconary weapon counter the
  shop overlay is vertically scrolled (`dialogue_start_row=25`, so merchant
  visual rows need `vertical_scroll_tiles=6`), and BizHawk reported
  `base_nt=1` while the text was in the alternate base order. `merchant.lua`
  now supports ordered screen-context fallbacks, and `main.lua` passes fixed,
  live, and live-alt-base contexts to merchant scans and cursor reads. Live
  reload proof `LAUNCHER_PROBE: merchant_context_reload` reported
  `MERCHANT_STATE active=true ... context=live_alt_base context_scroll=30
  context_base=0 context_vertical=6`, recovered all six offers, and spoke
  `Merchant. Gold 44. Club. 60 gold.` A down/up cursor pulse then spoke
  `Copper Sword. 180 gold.` and `Club. 60 gold.`, leaving the cursor back on
  Club.
- Overworld route replacement/recalculation follow-up: player testing found
  that once a route was active, pressing `R` only reported the old route and
  never calculated a route to a newly selected Travel destination. The route
  decision now lives in `overworld_routes.guidance_for_object()`: selecting a
  different guided Travel destination replaces the active route, selecting the
  same destination recalculates from the current world-map position, and
  pressing `R` on an active route waypoint recalculates/statuses the current
  route so large drift can recover to the best next marker. While movement is
  unstable, `R` remains read-only status and will not replace/recalculate the
  active route until object controls are stable. Command-file helpers now
  include `route_recalculate` and `recalculate_overworld_route`;
  `stop_overworld_route` remains the explicit cancel command. Static
  validation passed: `luac -p overworld_routes.lua hotkeys.lua
  object_commands.lua test_overworld_routes.lua test_hotkeys.lua`,
  `lua test_overworld_routes.lua`, `lua test_hotkeys.lua`, and
  `lua test_objects.lua`.

2026-05-08 Erdrick's Cave B1 first-floor cleanup in the worktree:
- Dungeon/cave object browsing no longer accepts stale town NPC RAM. Live
  proof after reload `LAUNCHER_PROBE: codex_dungeon_npc_fix` showed
  `POSITION: map=0x1C(Erdrick's Cave B1) x=0 y=0`, with exactly two objects:
  `Exit to World Map` at `(0,0)` and the old hard-coded
  `Stairs Down to B2` at `(1,1)`. The NPC filter reported `No objects`.
- Live stairway probes confirmed the cave entrance strip is walkable even
  though the decoded tile type is 9 and the old generic boundary rule rejected
  it: `(0,0)->RIGHT` moved to `(1,0)`, `(1,0)->DOWN` moved to `(1,1)`,
  `(1,1)->UP` moved back to `(1,0)`, and `(1,0)->LEFT` moved back to `(0,0)`.
  `map_reader.lua` now models `(0,0)` and `(1,0)` on map `0x1C` as scoped
  passthrough cells and lets passthroughs override the generic interior
  x/y-zero boundary in both direct tile checks and walkability snapshots.
- Live validation after reload `LAUNCHER_PROBE: codex_cave_snapshot_patch`:
  `pathfind_to:1,1` from `(0,0)` now returns `Path: 1 east, 1 south`, and
  `report_survey_start` reports `targets=2`, `reachable_area=83`,
  `open_exits=east`, and `status=viable`.
- Survey battle-interruption safety is now implemented. If `battle_started`
  fires during a survey, `map_survey.lua` cancels the active auto-walk route,
  clears route context, logs `SURVEY_PAUSE reason=battle_started`, keeps the
  interrupted target queued, and resumes it when `can_walk` becomes true again.
  This prevents random encounters from becoming bogus `SURVEY_RESULT` failures
  or blocked-tile candidates. If combat ends on a different map, the survey
  aborts rather than continuing with contaminated context.
- Targeted B1 surveys are clean enough to proceed. Starting surveys directly
  from `(0,0)` hit the expected `low_exit_count` guardrail, so `(2,2)` is the
  current interior survey seed: `report_survey_start` from there reports
  `reachable_area=83` and `open_exit_count=4`. `survey_target:Exit` succeeded
  for `Exit to World Map`. The earlier `survey_target:Stairs` success only
  proved that the route could reach the old modeled coordinate, not that the
  coordinate was correct: standing at `(1,1)` and selecting STAIRS produced
  `'There are no stairs here.`
- Erdrick B1/B2 stair coordinates are corrected in `objects.lua`. The ROM
  stair-down table contains `1C 09 09`, and live proof from `(9,9)` selecting
  STAIRS changed to `map=0x1D(Erdrick's Cave B2)` with landing `(8,9)`.
  Returning from B2 `(8,9)` via STAIRS changed back to `map=0x1C` with landing
  `(9,9)`. `Stairs Down to B2` is now `(9,9)` and `Stairs Up to B1` is now
  `(8,9)`. Live reload proof `LAUNCHER_PROBE: codex_erdrick_stairs_fix` then
  `current_object` at B1 `(9,9)` reported
  `Stairs Down to B2: here (1 of 2) [player 9,9 obj 9,9]`.
- The survey route briefly marked `(2,1)` from the south and `(1,2)` from the
  east as blocked/noisy, but direct probes from `(2,2)` with `probe_edge:UP`
  and `probe_edge:LEFT` both moved successfully, so do not promote those to
  permanent map data. `RUNTIME_BLOCKS map=0x1C none`. Current live position
  after the stair confirmation is `(9,9)` on B1.
- Full B1 route passes exposed real directional maze seams, with no
  `EVENT: battle` / `battle_started` log entries. Direct `probe_edge` checks
  after clearing runtime blocks confirmed the pre-regression approaches:
  `(3,3)` from north/south, `(4,3)` from north/south, `(2,4)` from east/west,
  `(3,5)` from north, `(7,2)` from west, `(6,3)` from north, `(1,5)` from
  north, `(6,6)` from west, `(5,7)` from north, `(8,8)` from north/west, and
  `(8,9)` from west. `map_reader.lua` models them as directional-only blocks
  for map `0x1C`.
  Reload proofs: `LAUNCHER_PROBE: codex_b1_route_blocks`,
  `codex_b1_more_seams`, `codex_b1_upper_seams`, `codex_b1_top_verticals`,
  and `codex_b1_logpass_edges`.
- A later B1 pass got worse after four newer one-probe additions and produced
  many reroutes plus contaminated runtime blocks. Those newest additions are
  rolled back for now: `(4,3)` from east, `(4,1)` from south, `(6,3)` from
  west, and `(6,6)` from north. Route-only blocked observations now remain
  seam-memory evidence and no longer promote into hard `runtime_blocked` map
  facts. Use `probe_edge_verify:DIR[,N]` or
  `probe_edge_verify:X,Y,DIR[,N]` before re-promoting any suspect B1 edge.
  The verifier resets movement state between attempts and only reports
  `confirmed_blocked` / `confirmed_passable` when every attempt agrees.
  Static tests pass. The stale live Lua loop was relaunched during this check;
  the current emulator is on the title screen (`map=0x00`) after
  `LAUNCHER_PROBE: codex_relaunch_probe`, and the command-surface check from
  title refused cleanly. A live field-edge verifier run is still needed after
  restoring gameplay state.
- Follow-up after manual reload: both B1 entrance/stairs routes can eventually
  succeed, but the live log still shows engine-collision sounds as soft seam
  observations. The latest clean route to stairs hit blocked-only route evidence
  at `(2,1)` from west, `(2,3)` from west/north, `(6,3)` from west,
  `(6,4)` from west, and `(6,6)` from north; it then recovered and reached
  `(9,9)` with `RUNTIME_BLOCKS map=0x1C none`. Do not promote these from route
  evidence alone.
- `probe_edge_verify:X,Y,DIR,N` was adjusted so explicit-coordinate verifier
  calls relocate to the origin themselves instead of requiring a separate
  `teleport_to` command. `luac -p main.lua` and `git diff --check` pass.
  Live verification is still blocked because the Lua command loop stalled after
  `report_runtime_blocks` at frame `07620`: BizHawk remains responsive, but
  `dw_debug.log` stops advancing and a queued
  `launcher_probe:codex_probe_after_missing_cmd` remains in `dw_commands.txt`.
  After a fresh manual reload/relaunch, test with single commands such as
  `probe_edge_verify:6,5,DOWN,5`, `probe_edge_verify:5,4,RIGHT,5`, and
  `probe_edge_verify:5,3,RIGHT,5`.
- Latest B1 route validation: from entrance `(0,0)`, `pathfind_to:9,9`
  planned `Path: 1 east, 2 south, 4 east, 2 south, 3 east, 2 south, 1 east,
  3 south`; auto-walk to `Stairs Down to B2` reached `(9,9)` and ended with
  `RUNTIME_BLOCKS map=0x1C none`. The route still produced a one-off blocked
  observation at `(6,4)` from the west, but direct probe `(5,4)->RIGHT` moved
  successfully, so do not promote it. Also keep `(5,1)` from south, `(2,1)`
  from east/south/west, and `(2,3)` from north/west unpromoted; direct probes
  moved through those logged approaches.
- Latest diagnostic follow-up after manual reload: auto-walk from B1 entrance
  to `Stairs Down to B2` reached `(9,9)` again, but produced six route-only
  blocked auto-step events: `(2,1)` from west, `(2,3)` from west and north,
  `(6,3)` from west, `(6,4)` from west, and `(6,6)` from north. Current-state
  reports after a fresh `launcher_probe:codex_b1_after_reroutes` showed
  `PATH_STATE target=nil map=0x1C runtime_count=0`,
  `RUNTIME_BLOCKS map=0x1C none`, and
  `SEAM_SUMMARY map=0x1C total=26 confirmed_blocked=0 noisy=0 blocked_only=6
  passable_only=20`. This confirms the soft-seam gate is working: route-only
  collisions are not contaminating hard runtime blockers.
- The first live `probe_edge_verify:1,1,RIGHT,3` retest still wedged the Lua
  command loop before any verifier lines reached `dw_debug.log`; a later
  `report_position` remained queued in `dw_commands.txt`, and
  `dw_script_error.log` had no fresh entry. `debug_tools.lua` now flushes the
  `CMD:` marker immediately before and after command handlers, and
  `main.lua` makes `probe_edge_verify` log-only, defers the first verifier
  movement out of the command callback, and wraps `tick_edge_probe` /
  `tick_edge_verify` in `checked_call` so future verifier failures leave either
  `EDGE_VERIFY_*` evidence or a `dw_script_error.log` entry. Static validation:
  `luac -p main.lua debug_tools.lua`, `lua test_route_manager.lua`,
  `lua test_map_reader.lua`, `lua test_auto_step.lua`, and `git diff --check`
  all pass.
- Live reload note: after the verifier logging patch, `touch main.lua` plus
  `launcher_probe:codex_verifier_patch_reload` successfully reloaded the
  patched script and consumed the command at frame `00060`; `dw_commands.txt`
  is empty and `dw_script_error.log` has no fresh entry. The active state was
  `title`, so B1 edge verification still needs to wait until gameplay is back
  on Erdrick's Cave B1.
- At that point, the best next step was to run a single verifier such as
  `probe_edge_verify:1,1,RIGHT,3` and wait for either `EDGE_VERIFY_RESULT` or a
  fresh script-error entry. If that produces useful output, verify the
  remaining soft B1 route-only edges before moving on to B2; otherwise debug
  the verifier loop itself before trusting further probe data.
- Follow-up verifier crash from the first B1 retry is fixed in the worktree:
  `dw_script_error.log` reported
  `tick_edge_verify: [string "main"]:582: attempt to call a nil value (global
  'get_autowalk_unavailable_reason')`. Cause: `tick_edge_verify` is defined
  before the local guard function, so Lua resolved it as a nil global. `main.lua`
  now forward-declares `get_autowalk_unavailable_reason` before the verifier
  helpers and assigns the existing guard body later. Validation passed:
  `luac -p main.lua debug_tools.lua`, `lua test_route_manager.lua`,
  `lua test_auto_step.lua`, and `git diff --check`. A reload probe attempted
  after the patch timed out because the running script was already stopped by
  the old crash; `dw_commands.txt` has been cleared. Manually reload/relaunch
  before retrying `probe_edge_verify:1,1,RIGHT,3`.
- Live verifier follow-up after manual reload: the script no longer crashed.
  The first `probe_edge_verify:1,1,RIGHT,3` completed as `classification=mixed`
  with `moved=1 blocked=2`, so it correctly avoided runtime promotion. A later
  same-edge retry completed `confirmed_blocked` with `moved=0 blocked=3` and
  `runtime_added=true`. Additional soft-edge checks produced:
  `(1,3)->RIGHT` into `(2,3)` confirmed blocked 3/3 and added runtime,
  `(2,2)->DOWN` into `(2,3)` mixed 1/2,
  `(5,3)->RIGHT` into `(6,3)` confirmed passable 3/3,
  `(5,4)->RIGHT` into `(6,4)` mixed 1/2, and
  `(6,5)->DOWN` into `(6,6)` mixed 2/1. Current live state after summaries:
  `POSITION map=0x1C x=6 y=5`, `RUNTIME_BLOCKS count=2`, with runtime
  directional blocks only for `(2,1)` west and `(2,3)` west.
- Worktree-only verifier hardening after that live pass: `main.lua` now raises
  verifier post-teleport settle to 18 frames and adds a 30-frame inter-attempt
  settle before the next teleport/attempt. Caveat: the attempted
  `touch main.lua` reload did not actually restart the Lua script; later live
  verifier logs still showed the old `settle_frames=8` format. Manually reload
  before judging the new settle patch. A clean retest should first clear
  runtime blocks, then verify the two current confirmed edges and the three
  mixed edges again. The new `EDGE_VERIFY_START` line should include
  `settle_frames=18 between_settle_frames=30`.
- Latest B1 verifier pass after manual reload: the new settle patch is live;
  `EDGE_VERIFY_START` now reports
  `settle_frames=18 between_settle_frames=30`. Five-attempt verification
  confirmed four west-approach engine seams on map `0x1C`: `(2,1)` west,
  `(2,3)` west, `(6,4)` west, and `(8,6)` west. `map_reader.lua` now models
  those as directional blocks and `test_map_reader.lua` asserts them while
  keeping unconfirmed approaches open. Mixed/unpromoted edges remain
  `(2,3)` north, `(6,3)` west, and `(6,6)` north. Runtime simulation with all
  four confirmed blocks reached `Stairs Down to B2` at `(9,9)` and reduced the
  route to one remaining blocked auto-step: `(2,2)->DOWN` into `(2,3)` from
  the north. Fresh state marker `LAUNCHER_PROBE: codex_b1_final_state` then
  reported `PATH_STATE target=nil map=0x1C runtime_count=4` and
  `SEAM_SUMMARY map=0x1C total=27 confirmed_blocked=4 noisy=0 blocked_only=3
  passable_only=20`. Validation passed:
  `luac -p map_reader.lua test_map_reader.lua main.lua debug_tools.lua
  route_manager.lua test_route_manager.lua test_auto_step.lua`,
  `lua test_map_reader.lua`, `lua test_route_manager.lua`,
  `lua test_auto_step.lua`, and `git diff --check`. A later
  `touch main.lua` plus `launcher_probe:codex_b1_permanent_reload` was
  consumed at frame `34260` without resetting the frame counter, so it did not
  prove a source reload. Manually reload/relaunch before judging the permanent
  `map_reader.lua` version with runtime blocks cleared.
- Latest B1 route follow-up after the user reloaded the script: the permanent
  four-seam patch is live and made the entrance-to-stairs route cleaner. The
  route from `(0,0)` to `Stairs Down to B2` reached `(9,9)` with three
  remaining route-only collisions: `(2,2)->DOWN` into `(2,3)` from the north,
  `(5,3)->RIGHT` into `(6,3)` from the west, and `(7,5)->RIGHT` into `(8,5)`
  from the west. Five-attempt verifier results: `(2,3)` north confirmed
  blocked `5/5`, `(8,5)` west confirmed blocked `5/5`, `(6,6)` north confirmed
  blocked `5/5` after the runtime-simulation retest exposed it again, and
  `(6,3)` west stayed mixed with `moved=4 blocked=1`. `map_reader.lua` now
  models only the three confirmed approaches and keeps `(6,3)` west unmodeled.
  A runtime simulation with `(2,3)` north, `(8,5)` west, and `(6,6)` north
  active reached `(9,9)` and only bumped the mixed `(6,3)` west edge. Fresh
  summary at `FRAME:26700`: `PATH_STATE target=nil map=0x1C runtime_count=3`,
  runtime blocks exactly those three verified approaches, and
  `SEAM_SUMMARY map=0x1C total=22 confirmed_blocked=3 noisy=0 blocked_only=1
  passable_only=18`. Validation passed again:
  `luac -p map_reader.lua test_map_reader.lua main.lua debug_tools.lua
  route_manager.lua test_route_manager.lua test_auto_step.lua`,
  `lua test_map_reader.lua`, `lua test_route_manager.lua`,
  `lua test_auto_step.lua`, and `git diff --check`.
- Reverse-route log investigation found a real runtime-contamination bug plus a
  stale-live-code issue. `route_manager.build_path_blocking()` used to pass a
  live `runtime_blocked` direction table directly into the mutable pathfinding
  overlay when no static entry already existed. A later reroute-only temporary
  block could then mutate that verified runtime table and make one confirmed
  approach look like several hard runtime directions. `route_manager.lua` now
  copies runtime direction tables before merging them into the planner overlay,
  and `test_route_manager.lua` has a regression
  `reroute_temporary_block_does_not_mutate_verified_runtime_dirs`. Validation:
  `luac -p route_manager.lua test_route_manager.lua map_reader.lua
  test_map_reader.lua main.lua debug_tools.lua test_auto_step.lua`,
  `lua test_route_manager.lua`, `lua test_map_reader.lua`,
  `lua test_auto_step.lua`, and `git diff --check` passed.
- Live reload attempt `touch main.lua` plus
  `launcher_probe:codex_route_alias_fix` was consumed, but did not pick up the
  latest `map_reader.lua` directional table. Evidence: after clearing B1
  runtime/seam state and rerunning stairs-to-entrance from `(9,9)`, the route
  reached `(0,0)` with `PATH_STATE target=nil map=0x1C runtime_count=0` and
  `RUNTIME_BLOCKS map=0x1C none`, so the hard runtime contamination was gone.
  However `inspect_move:4,4,DOWN` still reported `approach_blocked=false` for
  `(4,5)` north, `inspect_move:5,2,UP` reported `approach_blocked=false` for
  `(5,1)` south, and `inspect_move:9,8,LEFT` saw a directional entry at
  `(8,8)` but not the newly patched east approach. That means the current
  emulator script is still using older map-reader data; manually reload/relaunch
  before judging the reverse route or promoting more B1 seams.
- Post-reload reverse-route failure investigation from B1 stairs `(9,9)` to
  entrance `(0,0)` found three more confirmed one-way engine blockers. The route
  hard-stopped at `(9,9)->LEFT` into `(8,9)` from the east; verifier
  `probe_edge_verify:9,9,LEFT,5` blocked `5/5`, so `(8,9).east` is now modeled.
  Runtime simulation with that block exposed `(6,1)->LEFT` into `(5,1)` from
  the east; `probe_edge_verify:6,1,LEFT,5` blocked `5/5`, so `(5,1).east` is
  now modeled. A second simulation exposed `(5,5)->LEFT` into `(4,5)` from the
  east; `probe_edge_verify:5,5,LEFT,5` blocked `5/5`, so `(4,5).east` is now
  modeled. `test_map_reader.lua` keeps unverified approaches open for all three
  cells. The current live session is stopped at B1 `(5,5)`, `PATH_STATE
  target=nil`, command queue empty, with runtime blocks exactly `(8,9).east`,
  `(5,1).east`, and `(4,5).east`. Because the earlier reload probe left
  `map_reader.lua` stale, manually reload/relaunch before judging whether the
  disk patch fully quiets the route; a full stairs-to-entrance run with all three
  changes loaded from disk has not yet been completed.
- 2026-05-09 route-2 follow-up after the user drove the hero back toward the
  B1 entrance: route 1 to `Stairs Down to B2` is clean enough for now, but the
  return route stopped at `(4,6)->UP` into `(4,5)` from the south. A focused
  verifier confirmed `(4,5).south` blocked `5/5`, and follow-up verifier runs
  confirmed the same south-approach wall at `(1,5)`, `(2,5)`, and `(3,5)`.
  `map_reader.lua` now models those four row-5 south approaches as directional
  B1 blockers, and `test_map_reader.lua` asserts them while preserving other
  approaches. Control check: `(4,2)->LEFT` into `(3,2)` moved `5/5`, so do not
  promote that earlier repeated route-only noise. With the four confirmed
  runtime blocks active in the stale live session, a short `auto_walk` tail
  reached the entrance `(0,0)`. It logged noisy but passable brute-force bumps
  at `(3,1).south`, `(2,1).south`, `(1,0).south`, and `(0,0).east`; do not
  promote those from route-only evidence.
- Validation for the row-5 B1 patch passed:
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`, and
  `git diff --check`. Live caveat: `touch main.lua` plus
  `launcher_probe:codex_b1_45_south_reload` proved the command loop was alive,
  but after clearing runtime blocks, `inspect_move:4,6,UP` still reported
  `approach_blocked=false`, so the running BizHawk Lua state had not picked up
  the disk `map_reader.lua` change. Current live state after the route tail:
  B1 `(0,0)`, no active path, runtime blocks exactly `(1,5).south`,
  `(2,5).south`, `(3,5).south`, and `(4,5).south`. A real Lua reload/relaunch
  is still needed before judging the permanent disk data without runtime help.
- Later 2026-05-09 rerun after the user found the BizHawk Lua Console
  auto-reload setting is not persistent across emulator exit and reran both
  route directions: the fresh log started at `2026-05-09 10:29:39`, so the
  row-5 disk patch was live. Route 1 from B1 entrance `(0,0)` to `Stairs Down
  to B2` at `(9,9)` reached the target with only one reroute, `(5,3)->RIGHT`
  into `(6,3)` from the west. Leave `(6,3).west` unmodeled because earlier
  verifier evidence was mixed and this rerun was only a single route bounce.
  The return route reached `(0,0)` but bounced heavily; post-run state was
  `POSITION map=0x1C x=0 y=0`, `PATH_STATE target=nil runtime_count=0`, and
  `RUNTIME_BLOCKS none`.
- Focused verifier follow-up on the return-route bounce cluster confirmed seven
  more B1 directional blockers with `probe_edge_verify` 5/5 blocked attempts:
  `(9,5).south`, `(8,6).east`, `(7,3).south`, `(6,4).east`, `(8,2).south`,
  `(7,3).east`, and `(4,3).east`. `map_reader.lua` now models those confirmed
  directions and `test_map_reader.lua` asserts them. The top-row check
  `probe_edge_verify:3,2,UP,5` was mixed (`moved=4 blocked=1`), so do not
  promote `(3,1).south`; similarly, route-only noisy bumps such as
  `(9,7).south`, `(9,6).south`, `(7,7).east`, `(7,6).south`, `(7,5).south`,
  `(7,4).south`, `(7,1).east`, `(6,1).east`, `(4,2).east`, `(3,2).east`,
  `(2,1).south`, `(1,0).south`, and `(0,0).east` still need verifier consensus
  before permanent modeling.
- Validation for the later return-route patch passed:
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`, and
  `git diff --check`. Current live state after the verifier pass is B1 `(3,1)`,
  no active path, and runtime blocks matching the newly confirmed directions:
  `(8,2).south`, `(4,3).east`, `(7,3).east/south`, `(6,4).east`,
  `(9,5).south`, and `(8,6).east`. A reload or relaunch will load the disk
  model; if route tests again look stale, manually re-enable BizHawk Lua
  Console auto reload before touching source files.
- Follow-up manual pass later on 2026-05-09 looked much better. Starting from
  the prior verifier position `(3,1)`, the route first returned to entrance
  `(0,0)` with small top-left noise, then route 1 from entrance to `Stairs Down
  to B2` queued 18 steps and reached `(9,9)` with only the known
  `(6,3).west` route-only bounce. The return route to entrance also completed
  and ended at `(0,0)` with no active path. It still logged noisy/passable
  brute-force corrections at several previously noisy seams plus hard route
  bounces at cells already covered by static or verifier runtime data, but no
  new edge had verifier-grade evidence. Live caveat: `report_runtime_blocks`
  after the pass still showed the six verifier runtime cells active
  (`(8,2).south`, `(4,3).east`, `(7,3).east/south`, `(6,4).east`,
  `(9,5).south`, `(8,6).east`), so this was a practical route-success check,
  not a clean disk-only validation. For disk-only proof, reload/relaunch or
  clear B1 runtime blocks before the next route pair.
- Reloaded disk-only pass and focused verifier follow-up on the recurring
  suspects clarified the remaining route bounces. After the clean route pair,
  `POSITION` was B1 `(0,0)`, `PATH_STATE target=nil runtime_count=0`, and
  `RUNTIME_BLOCKS map=0x1C none`, so the previous verifier runtime overlay was
  not carrying the pass. The route still produced some temporary route bounces,
  but focused `probe_edge_verify` split them cleanly. New confirmed blockers
  now modeled in `map_reader.lua`: `(6,7).east` from
  `probe_edge_verify:7,7,LEFT,5`, `(6,6).east` from
  `probe_edge_verify:7,6,LEFT,5`, `(8,2).east` from
  `probe_edge_verify:9,2,LEFT,5`, `(7,2).north` from
  `probe_edge_verify:7,1,DOWN,5`, and `(2,1).south` from
  `probe_edge_verify:2,2,UP,5`; all were `5/5` blocked. Do not model the mixed
  results: `(6,3).west` was `moved=1 blocked=4`, `(5,5).east` was
  `moved=4 blocked=1`, `(8,2).north` was `moved=1 blocked=4`, and
  `(3,1).south` again was `moved=4 blocked=1`. Validation for this patch passed
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`, and
  `git diff --check`. Current live state after verifier probes is B1 `(2,2)`,
  no active path, with runtime blocks matching the five new disk entries; reload
  before judging a fresh disk-only route pair.
- Later route-2 geometry pass after those five entries were loaded from disk:
  the log restarted at `2026-05-09 11:01:49`, proving a fresh script run. The
  route returned from the prior verifier position to entrance, route 1 reached
  `Stairs Down to B2` with the known `(6,3).west` mixed bounce, and route 2
  eventually reached entrance `(0,0)` but detoured farther through the lower B1
  rows. Post-route state before probes was clean: `POSITION` B1 `(0,0)`,
  `PATH_STATE target=nil runtime_count=0`, and `RUNTIME_BLOCKS none`. Focused
  verifier follow-up promoted three more real engine seams: `(5,7).south` from
  `probe_edge_verify:5,8,UP,5`, `(5,7).west` from
  `probe_edge_verify:4,7,RIGHT,5`, and `(2,1).east` from
  `probe_edge_verify:3,1,LEFT,5`; all were `5/5` blocked and are now modeled in
  `map_reader.lua`. Do not model the cleared suspects from this pass:
  `(7,6).south` verified `moved=5 blocked=0`, `(6,8).east` was mixed
  `moved=2 blocked=3`, `(6,8).south` was mixed `moved=4 blocked=1`,
  `(9,1).south` verified `moved=5 blocked=0`, and `(5,5).east` verified
  `moved=5 blocked=0`. Validation passed `luac -p map_reader.lua
  test_map_reader.lua`, `lua test_map_reader.lua`, and `git diff --check`.
  Current live state after verifier probes is B1 `(3,1)`, no active path, with
  runtime blocks matching the three new disk directions; reload before judging
  the next clean disk-only route pair.
- 2026-05-09 silent-reroute/autowalk timing investigation: the noisy return
  route was not only map geometry. Many queued-route blocks showed
  `movement_started=true` from an early `$003D` subpixel twitch, then timed out;
  the same edge either succeeded immediately through seam brute-force or should
  have been direct-tested before allowing an alternate reroute. `auto_step.lua`
  now keeps queued-route input held through early subpixel twitches
  (`auto_step_route_early_release_grace_frames=6` in `dw_access.ini`) and adds
  blocked-step metadata (`movement_started`, `movement_start_frame`,
  retry/turn counts). `route_manager.lua` treats movement-start route timeouts
  as suspect timing and tries the same seam with `AUTO_WALK_TIMING_RETRY`
  before silently rerouting around it.
  Validation passed `luac -p auto_step.lua route_manager.lua config.lua
  test_auto_step.lua test_route_manager.lua`, `lua test_auto_step.lua`,
  `lua test_route_manager.lua`, and `git diff --check` (only the known
  `dw_access.ini` CRLF warning). Live reload proof:
  `LAUNCHER_PROBE: codex_autowalk_timing_patch` at frame `00060`.
  Clean live B1 retest from `(0,0)` with no runtime/seam state reached
  `(9,9)`; early twitch holds turned the previous false blockers into normal
  10-13 frame steps. The only blocked edge was `(5,3)->RIGHT` into `(6,3)`
  from the west, which got the new `AUTO_WALK_TIMING_RETRY`, failed direct
  retry, and then detoured without hard runtime contamination. Return route
  from `(9,9)` to entrance then reached `(0,0)` cleanly with no blocked events.
  Final state: `POSITION map=0x1C x=0 y=0`, `PATH_STATE target=nil
  runtime_count=0`, `RUNTIME_BLOCKS none`, and seam memory was passable-only
  except the still-unmodeled `(6,3).west` blocked-only route/seam evidence.

2026-05-08 overworld route-guidance QoL implemented in the worktree:
- `overworld_routes.lua` adds manual route guidance for the first dungeon,
  Erdrick's Cave, plus safety returns to Brecconary and Tantegel Castle. It is
  route-table driven, accepts `erdrick`, `erdric`, `cave`, `brecconary`,
  `breconary`, `town`, `safe`, `tantegel`, and `castle`, and keeps the route
  in reload-surviving Lua state while the script remains alive.
- Route guidance deliberately does not enable overworld `auto_walk`. The
  player-facing hotkey is `R`: select a supported Travel destination such as
  `Erdrick's Cave`, `Brecconary`, or `Tantegel Castle`, then press `R` to start
  guidance or press it again for active route status/recalculation. Selecting
  another guided Travel destination and pressing `R` replaces the active route;
  selecting the same destination recalculates from the current world-map
  position. The active route injects a small Travel layer capped at the next
  two `Route next` / `Route later` markers, and advances one waypoint at a time
  as the player manually reaches markers.
- The first route includes a one-time bridge warning: `Bridge crossing.
  Monsters may become more dangerous beyond this point.` This addresses the
  early-game clue about bridge/danger boundaries without making every step
  noisy.
- Live route follow-up after the first successful trip to the dungeon: the
  `North trail marker` waypoint was consumed correctly, but the final cave
  waypoint was not cleared because the map changed to `0x1C` before the
  world-map final-tile arrival check fired. `overworld_routes.lua` now treats
  Erdrick's Cave destination maps `0x1C` and `0x1D` as route completion.
  The same log showed blocked mountain tiles around `(30,31)`, `(29,32)`,
  `(27,33)`, and `(28,32)` when the route gave a long heading from the pinch,
  so the route now guides through `East choke approach`,
  `Eastern mountain lane`, and `North ridge bend` before `North trail marker`.
- Cave-bound bridge follow-up: after the safety-route patch, a live cave-bound
  trip reached `map=0x01 x=45 y=34` with active Erdrick route status still
  pointing at `Mountain pinch turn`; pressing north from `(45,34)` blocked into
  `(45,33)`. `overworld_routes.lua` now routes Erdrick's Cave through `Bridge
  south bend` `(44,38)`, `Bridge lower west lane` `(38,36)`, `Bridge west
  bend` `(38,34)`, `Upper bridge lane` `(38,32)`, then
  `East choke approach` `(35,32)`.
  Reload proof: `launcher_probe:cave_bridge_detour_reload` plus `route_status`
  at frame `00060` reported `route=erdrick waypoint=Bridge south bend index=4`
  while the player was still at `map=0x01(World Map) x=45 y=34`.
- Latest bridge-detour log review: the `Bridge south bend` -> `Bridge west
  bend` leg was still too diagonal and produced blocked north attempts from
  `(41,35)`, `(40,35)`, and `(39,35)` before the player found the passable
  `x=38` column. The `Bridge lower west lane` marker at `(38,36)` exists to
  steer west on the lower lane before turning north. The same review found a
  safety-route backtrack where `Bridge south bend` sent the player up toward
  `(45,34)`, then the next Brecconary checkpoint sent them south again; safety
  routes now go from `Bridge south bend` directly to the destination.
  Validation: `luac -p overworld_routes.lua test_overworld_routes.lua
  objects.lua test_objects.lua hotkeys.lua main.lua`, `lua
  test_overworld_routes.lua`, `lua test_objects.lua`, `lua test_hotkeys.lua`,
  and `git diff --check` passed (only the existing `dw_access.ini` CRLF
  warning). BizHawk reload proof:
  `launcher_probe:bridge_lower_lane_reload`; fresh position reported
  `map=0x01(World Map) x=48 y=41`.
- East-choke log review: the route advanced `East choke approach` while the
  player was still at `(34,32)`, one tile west of the intended `(35,32)` lane,
  then `Eastern mountain lane` advanced from `(34,24)` before the player
  finished correcting east. These were early-consumed route markers rather
  than confirmed terrain blockers. `overworld_routes.lua` now requires exact
  arrival at `(35,32)` and `(35,24)` for the east choke / mountain lane turn
  points in both cave-bound and safety routes. Focused regression tests cover
  the one-tile-west non-advance cases.
- East-choke reversal follow-up: the exact marker fix exposed an older route
  ordering problem. Cave-bound guidance sent the player west from `(35,32)` to
  the old `Mountain pinch turn`, then immediately back east four steps to
  `East choke approach`. The route now uses `Upper bridge lane` at `(38,32)`
  between `Bridge west bend` and `East choke approach`; return routes use the
  same marker in reverse, so the player should stay on the east/west lane
  instead of doing a west-then-east reversal.
- Safety-route follow-up: `overworld_routes.lua` now has reverse routes to
  Brecconary and Tantegel Castle using the same cave-road, north-trail,
  mountain-lane, east-choke, upper-bridge, and bridge markers. A live Brecconary
  return then showed the direct `Mountain pinch turn` -> `First bridge
  crossing` leg hitting blocked moves into `(39,34)`, `(41,34)`, and `(42,34)`.
  The safety routes now insert `Upper bridge lane` at `(38,32)`, `Bridge west
  bend` at `(38,34)`, `Bridge lower west lane` at `(38,36)`, and `Bridge south
  bend` at `(44,38)`. Brecconary completes on map `0x08`; Tantegel Castle
  completes on maps `0x04` and `0x05`. Both routes warn once at the bridge
  that monsters should become safer beyond that point.
- New debug/player command hooks: `route_guidance`, `start_overworld_route`,
  `start_overworld_route:erdrick`, `start_overworld_route:erdric`,
  `start_overworld_route:cave`, `start_overworld_route:brecconary`,
  `start_overworld_route:castle`, `route_status`, `route_recalculate`,
  `recalculate_overworld_route`, and `stop_overworld_route`.
- Follow-up after the first live try: the route command was registered and the
  object list grew from 13 to 16 entries, but selection stayed on the old
  `Erdrick's Cave` landmark. `object_commands.lua` now refreshes the overworld
  list immediately, clears the pathability layer, switches to Travel, and
  selects the active `Route next` waypoint when `route_guidance` or
  `start_overworld_route:*` runs. `O` remains a plain heading/path preview for
  the selected object; `U` remains reserved for auto-walk.
- Input/speech QoL follow-up: player testing showed the generic `Object
  controls unavailable right now` message felt bad when pressing readout keys
  during step movement, and route announcements could be cut off by hotkey
  interrupts. `hotkeys.lua` now lets `R` report active route status while
  movement is settling, keeps new route starts and movement-changing object
  controls blocked until stable movement, and uses non-interrupting speech for
  read-only hotkeys (`Shift+W`, `Shift+H`, `Shift+I`, `Shift+G`, `Shift+E`,
  `Shift+R`, `Shift+T`, and `R`). `main.lua` now passes a specific block reason
  such as `Wait for movement to finish`.
- Latest input/speech QoL validation passed: `luac -p hotkeys.lua main.lua
  test_hotkeys.lua overworld_routes.lua test_overworld_routes.lua objects.lua
  object_commands.lua config.lua hotkey_filter.lua`, `lua test_hotkeys.lua`
  (24 tests), `lua test_objects.lua`, `lua test_overworld_routes.lua`,
  `lua test_hotkey_filter.lua`, and `git diff --check` (only the existing
  `dw_access.ini` CRLF warning). BizHawk source reload was nudged with
  `launcher_probe:input_qol_reload`; fresh position reported
  `map=0x01(World Map) x=45 y=34`.
- Validation passed: `luac -p overworld_routes.lua objects.lua
  object_commands.lua hotkeys.lua hotkey_filter.lua config.lua main.lua
  test_overworld_routes.lua test_objects.lua test_hotkeys.lua
  test_hotkey_filter.lua`, `lua test_overworld_routes.lua`,
  `lua test_objects.lua`, `lua test_hotkeys.lua`, `lua test_hotkey_filter.lua`,
  `lua test_route_manager.lua`, `lua test_maps.lua`, and `git diff --check`
  (only the existing `dw_access.ini` CRLF warning). Live note: the first
  timestamp nudge plus `launcher_probe:route_destination_patch` proved the old
  loop was still polling but did not immediately reload the route table. A
  later fresh script header appeared, and `start_overworld_route:cave` then
  logged `waypoint=Eastern mountain lane index=5` at frame `01440`, proving
  that version of the refined pinch-point route was live. A later hands-on pass
  still hit blockage on the first leg, then worked smoothly after reaching the
  eastern lane; `overworld_routes.lua` now adds `East choke approach` at
  `(35,32)` before `Eastern mountain lane`. The stale active route from the
  completed cave trip had also been cleared earlier with `stop_overworld_route`
  at frame `47760`. Destination-map completion then worked live at frame
  `13879`: entering map `0x1C` logged `OVERWORLD_ROUTE: event=arrived`.

2026-05-05 Codex-first tooling refresh implemented in the worktree:
- `.codex/config.toml` now uses `AGENTS.md` first, falls back to
  `PROJECT_MEMORY.md` then `CLAUDE.md`, keeps hooks enabled, leaves model and
  memory preferences to global config, and keeps the project sandboxed with
  network disabled by default.
- Repo-local hook commands now resolve from the git root and use `python3`.
  The session-start hook summarizes the real `Current Focus` instead of
  accidentally treating the first handoff bullet as the active handoff.
- `pretool_dw_command_guard.py` now parses actual shell invocations instead of
  raw substring matches. It blocks hazardous live command batches, raw writes
  to `dw_commands.txt` / `dw_debug.log`, source reload triggers without a
  follow-up probe/wait, and state-sensitive `dw_commands` calls without
  `--replace`, while allowing documentation strings that merely mention bad
  examples.
- `dw_commands.sh` and `dw_commands.ps1` now support `--require-live SECONDS`,
  `--wait-ready TAG`, and `--json` for automated harnesses. `--require-live`
  fails before queueing commands when the log is missing or stale; `--wait-ready`
  queues `launcher_probe:TAG` and waits for the fresh marker; `--json` emits a
  machine-readable status object.
- The `dw-debug-loop` skill moved from legacy `.codex/skills/` to the documented
  repo-skill location `.agents/skills/dw-debug-loop/SKILL.md` with BizHawk-first
  wording and current reload/stale-log guidance.

2026-05-04 QoL feature batch implemented in the worktree:
- `auto_walk` now speaks progress every 6 completed queued steps on longer
  routes and announces route completion. When the target is an NPC, arrival
  briefly holds that NPC slot in place and prompts the player to use TALK.
- Object navigation filters are now player-facing categories:
  All, NPCs, Services, Treasure, Travel, and Doors. `Q` cycles forward;
  `Shift+J` / `Shift+L` cycle filters backward/forward, and `Shift+K` jumps
  directly back to All without also speaking the current object.
- Object navigation also has a separate pathability layer on `Shift+O`.
  It cycles All, Reachable, and Unreachable, stacking with the category filter
  (for example `Treasure, reachable`). The debug command is
  `pathability_filter`, with `:all`, `:reachable`, `:unreachable`, and
  `:refresh` forms. Reachability is computed on demand with shared blocking,
  ignores moving NPC occupancy, and resets to All on overworld maps where
  interior A* reachability is unavailable.
- Object-browser command registration moved out of `main.lua` into
  `object_commands.lua` to keep main's local-variable pressure down while
  adding the pathability command.
- Session-only visited flags are map-scoped. `Shift+V` / `mark_visited` marks
  the current object; TALK followed by real dialogue marks an adjacent NPC
  automatically; `clear_visited` clears the current map and
  `clear_visited:all` clears all maps.
- Selected-object teleport is available through configurable hotkeys:
  `Shift+Enter` for exact target cell, and `Shift+Up/Down/Left/Right` for the
  adjacent cell on that side of the selected object. Teleport reuses the
  existing safe refusal checks, rejects NPC-occupied landings unless forced
  through the debug command, normalizes movement state, and suppresses leaked
  D-pad/Start input for a few frames. The NPC-occupied landing check now reads
  live NPC RAM directly instead of forcing a full object-list rebuild.
- Manual selected-object teleport failures now use a simpler player-facing
  refusal when the target cell is not walkable. The debug command still keeps
  the developer hint about `near` / `force`.

Manual test finding from the first QoL pass:
- The reported "keyboard/controller input stopped responding" after teleport
  did not show a script crash or lost emulator polling. A follow-up
  `report_position input_status report_path_state speech_status` command was
  consumed at frame `113460`, reporting map `0x05`, position `(4,6)`,
  `keys=-`, and speech ready.
- The log shows the player had teleported north of the door at `(4,7)` to
  `(4,6)`, then multiple manual directions were seen by `auto_step` and timed
  out as blocked. At the live snapshot, NPC blockers occupied `(3,6)` and
  `(5,6)`, the door blocked south, and the north edge was the known noisy
  `(4,6)->(4,5)` doorway seam. Treat this as a boxed-in landing/pathing
  situation, not an input bridge failure.
- `report_path_state` itself took `1476 ms` because it builds current blocker
  state; avoid using that command as a routine player-facing check during
  manual testing.

Manual test finding from the auto-walk/TALK pass:
- Auto-walk reached the King at map `0x05` by standing at `(3,4)` beside the
  target at `(3,3)`, but the final route step was left, so the hero was still
  facing west. TALK then produced `There is no one there.` even though the NPC
  was adjacent.
- `route_manager.lua` now queues a short post-arrival facing press toward
  adjacent interaction targets before prompting TALK, and the NPC hold default
  is longer (`auto_walk_npc_hold_frames=1200`) so manual menu selection has
  more time. Failed TALK text no longer marks the adjacent NPC as visited.

Latest manual playtest notes:
- 2026-05-07 refactor review / merchant regression follow-up: after the
  `main.lua` local-reduction refactor, field entry initially looked dead
  because `get_autowalk_unavailable_reason()` captured `MER` before the local
  merchant state table was declared. `main.lua` now forward-declares `MER`,
  and the per-frame `scan_profiler.call(...)` paths go through `checked_scan`
  so future scan-loop crashes are written to `dw_script_error.log` instead of
  silently stopping after the startup header. Validation:
  `luac -p main.lua merchant.lua route_manager.lua hotkeys.lua`,
  `lua test_hotkeys.lua`, `lua test_merchant.lua`, `lua test_route_manager.lua`,
  and `git diff --check`.
- Same follow-up: Brecconary Merchant 2's weapon/armor item list was visible
  but silent because `merchant.read_rows()` defaulted to live field scroll
  registers (`scroll_tiles=10`, `base_nt=1` in the failing log) and therefore
  missed the fixed shop/menu rows. `merchant.lua` now defaults merchant scans
  to screen coordinates while still accepting explicit scrolled contexts.
  Live reload evidence: `MERCHANT_STATE active=true` found Bamboo Pole, Club,
  Copper Sword, Clothes, Leather Armor, and Small Shield; a raw Down input
  then logged `MERCHANT_SELECT: Clothes. 20 gold.`
- Same follow-up: the object pathability reachability cache no longer reuses
  changed-context data inside an `os.clock()` throttle window. The signature
  cache still avoids recompute when map/start/objects/runtime blocks are
  unchanged, but a changed player position now recomputes immediately; the new
  regression is
  `object_pathability_filter_recomputes_when_position_changes`.
- 2026-05-06 Spark-change review / hotkey crash follow-up: reviewed the
  field-only object-hotkey patch and tightened it before the next live pass.
  `hotkeys.update` still receives `game_state` plus an object-hotkey allowance,
  but `main.lua` now blocks object/teleport/path/mark/freeze hotkeys when the
  existing auto-walk interaction guard reports menu/dialogue/merchant/sweep/step
  state, when lower dialogue has not fully cleared, or while an auto-walk route
  is active. The position readout now protects `nav.get_position_string()` and
  speech output with `pcall`; a failed "where am I" read logs the error and says
  `Position unavailable` instead of killing the Lua loop. Validation:
  `lua test_hotkeys.lua` (15 tests), `lua test_hotkey_filter.lua` (9 tests),
  `luac -p hotkeys.lua test_hotkeys.lua test_hotkey_filter.lua`, and
  `git diff --check`.
- Live status from the same review: `dw_debug.log` is stale at only a fresh
  header from `2026-05-06 12:42:24`; `./dw_commands.sh --require-live 60 ...`
  refused to queue, and a guarded `touch main.lua && ./dw_commands.sh --replace
  --wait "LAUNCHER_PROBE: codex_review_reload" launcher_probe:codex_review_reload`
  timed out. Windows still shows an `EmuHawk` process with window title
  `Lua Console`, so the next live test needs a manual script restart or an
  intentional close/relaunch of BizHawk before judging `Shift+W` / Ctrl+W.
  Also note an untracked zero-byte `main..lua` exists in the repo root, likely
  accidental scratch output; remove it after confirming no external tool needs
  it.
- Loader-error correction from the screenshot: the Lua console showed
  `[string "main"]:4010: too many local variables (limit is 200) in main
  function near '='`. The new object-hotkey helper pushed `main.lua` over the
  Lua 5.1/NLua local limit. The helper was removed and the same boolean is now
  passed inline at the `hotkeys.update` call site, so `luac -p main.lua` now
  passes again. After the fix, `touch main.lua && ./dw_commands.sh --replace
  --wait "LAUNCHER_PROBE: codex_local_limit_fixed" ...` still timed out, which
  means the existing failed Lua Console instance did not auto-reload; reload the
  script manually in BizHawk's Lua Console or close/relaunch BizHawk before the
  next live probe.
- Follow-up after script reload: the Lua loop is live again in Brecconary at
  `(21,7)`. `speech_status` reports `backend=bridge ready=true available=true
  error=none`, and `speech_bridge.log` received fresh utterances including
  `Codex_speech_test`, current-object speech, and `Teleport refused. Target
  cell is occupied by an NPC`. A command-file `teleport_to:5,4` refused because
  Merchant 2 occupies that tile and did not move the player. No physical
  selected-object teleport hotkey event appeared in `dw_debug.log`, so the
  likely bad experience was a silent object-hotkey guard/focus/key-filter miss,
  not a teleport or speech crash. `hotkeys.lua` now speaks `Object controls
  unavailable right now` and logs `object hotkey blocked: CONFIG_KEY` when a
  blocked object/path/teleport/freeze hotkey is pressed. Reload verification:
  `launcher_probe:object_hotkey_guard_message` landed at frame `00060` after
  `touch main.lua`, with speech ready and position still `map=0x08 x=21 y=7`.
- Blocked-teleport input leak follow-up: after the guard-message patch, physical
  blocked teleport attempts logged `object hotkey blocked: key_teleport_*`, but
  the directional component still leaked into gameplay. Evidence: immediately
  after blocked `key_teleport_west/east/south/north`, `auto_step` began manual
  steps left/up/right from `(21,7)`, hit blocked edges, and left the player
  feeling control-locked. A live `clear_input input_status:unlock_check
  report_position report_menu_state speech_status` recovered/confirmed neutral
  input (`keys=- joy1=- left_alt=false`), menu closed, speech ready, and player
  at Brecconary `(22,7)`. `hotkeys.lua` now calls
  `DW_QOL_STATE.suppress_teleport_input()` whenever an object/path/teleport/freeze
  hotkey is blocked, so the same six-frame neutralization used by successful
  teleports also prevents leaked D-pad/Start input from reaching `auto_step`.
  Validation: `luac -p main.lua hotkeys.lua test_hotkeys.lua test_hotkey_filter.lua`,
  `lua test_hotkeys.lua` (15 tests), `lua test_hotkey_filter.lua` (9 tests), and
  `git diff --check`. Reload verification:
  `launcher_probe:blocked_hotkey_suppresses_input` landed at frame `00060`,
  with speech ready, position `map=0x08 x=22 y=7`, and neutral input.
- Held-key/self-blocking correction: the first suppression patch only neutralized
  input for six frames after the rising edge, but a held `Shift+Up` outlasted
  that window and still reached `auto_step`. `hotkeys.lua` now suppresses leaked
  input every frame while a blocked object/path/teleport/freeze hotkey remains
  held, but only speaks the guard on the initial press. Also, `main.lua` no
  longer bases object-hotkey allowance on `field_dialogue_guard_active()`, because
  that function treats the teleport hotkey's own Enter/arrow component as live
  joypad input and made teleport hotkeys refuse themselves. The allowance still
  uses the menu/dialogue/merchant/autowalk guard via
  `get_autowalk_unavailable_reason()`, pending lower-dialogue state, and active
  route state. Validation: `luac -p main.lua hotkeys.lua test_hotkeys.lua
  test_hotkey_filter.lua`, `lua test_hotkeys.lua` (16 tests),
  `lua test_hotkey_filter.lua` (9 tests), and `git diff --check`.
  Reload verification: `launcher_probe:teleport_self_block_removed` landed at
  frame `00060`, speech ready, neutral input, Brecconary `(22,7)`.
- Initial 2026-05-06 hotkey robustness follow-up: object/teleport/path/mark-visited hotkeys were moved behind a field-state gate.
  `hotkeys.update` now receives `game_state`, and `main.lua` evaluates state before
  hotkey processing so battle-state actions are suppressed in that pass. `Shift+V`
  / `mark_visited` and selected-object teleport remain available in field play.
  Superseded by the interaction-aware guard, loader-error correction, and later
  validation notes above.
- Ctrl+W crash follow-up: immediately after the user used `Ctrl+W`, the script
  crashed with `2026-05-06T03:35:37Z snapshot.update: nil`. The stack pointed
  at `emulator_compat.lua:174` inside `bizhawk_console.log()` while reporting a
  `mainmemory.read_u8` fallback from `game_snapshot.update()`. `emulator_compat`
  now wraps adapter logging in `pcall`, disables the console-log path after its
  first failure, and falls back to protected `print`. The first reload then
  surfaced a second transient `BizHawk memory read_u8/readbyte API is
  unavailable` crash; the adapter now returns `0` for temporarily unavailable
  reads and drops unavailable writes after logging once, instead of killing the
  Lua loop. Validation passed:
  `luac -p emulator_compat.lua test_emulator_compat.lua` and
  `lua test_emulator_compat.lua` (14 tests). Live reload after the second fix
  succeeded: `launcher_probe:memory_api_hardened` landed at frame `00060`, and
  `speech_status` reported `backend=bridge ready=true`.
- Future overworld QoL note: the user heard an NPC clue that crossing bridges
  leads into more dangerous areas. This is a good later candidate for an
  optional/subtle alert when the player crosses into a new encounter-strength
  region or other invisible overworld danger boundary.
- Brecconary service-discovery note: the user talked to every reachable
  towns-person target and did not find the inn keeper or a true selling
  merchant. Woman 3 mentioned she was near the shop. Next pass should inspect
  whether shop/inn keepers are blocked targets, static/counter objects, or
  missing from normal NPC/service registration.
- Brecconary counter-service discovery follow-up: the missing first-town
  services were counter/large-tile interactions. `map_reader.lua` now exposes
  non-invasive raw block helpers (`get_raw_block_id`, `is_large_tile`) for the
  original two-nibbles-per-byte map data. `objects.lua` infers service counters
  from adjacent raw `0xF` large tiles, but Brecconary has live-confirmed direct
  overrides: `Weapons Merchant` at `(5,4)` uses `(5,6)` facing north for the
  weapon/armor shop; `Inn` at `(10,21)` uses the public stand `(8,21)` facing
  east because `(9,21)` is blocked from the west approach; Merchant 4 `(25,25)`
  uses raw large tile `(24,25)` facing east for the tool shop. Live evidence:
  TALK from `(8,21)` opened `Welcome to the traveler's Inn... Room and board
  is 6 GOLD per night`, and TALK from `(24,25)` opened `Welcome. We deal in
  tools.` Final reload verification showed `Services` objects with
  `Weapons Merchant ... interact 5,6`, `Inn ... interact 8,21`, and
  `Merchant 4 ... interact 24,25`.
- Brecconary Merchant 2 located: selected-object teleport placed the player west
  of `Merchant 2` at `(5,4)`, and TALK from `(4,4)` opened the real
  weapon/armor shop (`We deal in weapons and armor...`). Follow-up proved that
  `(4,4)`, `(4,5)`, `(4,6)`, `(5,5)`, `(6,4)`, and `(6,5)` are trap/service
  pocket cells for autonomous routing. A later public-side route repro
  superseded the old noisy `(8,5)->LEFT` moved evidence: `(7,5).east` is blocked
  too. The real public service approach is the doorway/counter square `(5,6)`;
  face north and TALK to Merchant 2 at `(5,4)`, two tiles away.
- Merchant item-list readout fix: the weapon/armor list can show a `COMMAND`
  header while reusing command-menu cursor RAM, so the command-menu reader was
  speaking `TALK` / `STATUS` / `SEARCH` and raw cursor values. `merchant.lua`
  now reads visible rows with horizontal scroll, vertical scroll, and active
  nametable order, and `main.lua` does a fresh merchant-layout check before
  command-menu speech. Follow-up found two stability issues: merchant scans
  were starved while the shop prompt kept `dialogue_hint` true, and stale
  command labels were visible behind item confirmation/error dialogue.
  `main.lua` now keeps merchant scanning active during dialogue hints and blocks
  command-menu speech while lower dialogue is present. Live validation completed
  a Copper Sword not-enough-gold loop and returned to the list with
  `Bamboo Pole. 10 gold.` and no fresh command-label chatter.
- Merchant 2 routing correction: `(4,4)`, `(4,5)`, `(4,6)`, `(5,5)`,
  `(6,4)`, and `(6,5)` are all pathfinder-forbidden trap/service-pocket cells.
  After reload, a trapped start at `(5,5)` reports `No path found` immediately
  with no runtime blocks, while a public start at `(8,5)` auto-walked all the
  way to the world-map exit at `(1,15)` and ended with `RUNTIME_BLOCKS none`.
  Follow-up route validation found that `(5,3)` was a false interaction target:
  the shop opens from `(5,6)` while the merchant object remains two squares
  north at `(5,4)`. `objects.lua` now exposes a Brecconary service interaction
  override for Merchant 2, and `route_manager.lua` routes to the interaction
  square directly, then faces north. Live reload verification:
  `FILTER: Services. Merchant 2: 2 north, counter here (1 of 4) [player 5,6
  obj 5,4 interact 5,6]`.
- Merchant 2 doorway passthrough correction: the first counter-interaction
  route still stopped short because the doorway throat tiles `(5,6)` and
  `(5,7)` decoded as non-walkable type-0 tiles. Live evidence showed movement
  through `(5,8)->UP->(5,7)->UP->(5,6)` and TALK from `(5,6)` opens the shop.
  `map_reader.lua` now marks `(5,6)` and `(5,7)` as narrow Brecconary
  passthrough cells. Live validation after reload: `debug_pathfind_to:5,6`
  found a 13-step path from the west exit side, `auto_walk` queued 13 steps for
  Merchant 2, arrived at `(5,6)`, faced north, and `pathability_filter:refresh`
  from `(5,6)` reported `targets=21 reachable=11 unreachable=10` with no
  runtime blocks.
- Live verification (2026-05-06): after a restart in BizHawk and reload of the
  current state, `next_filter` still reports `Services. Merchant 1/2/3/4` plus
  a `Woman 3` NPC. TALK attempts on `Merchant 1` and `Woman 3` both return
  `There is no one there.` with `VISITED_AUTO skipped`. Superseded follow-up:
  `Weapons Merchant` is the weapon/armor shop, `Inn` is reached via public
  stand `(8,21)`, and Merchant 4 is the tool shop via counter tile `(24,25)`.
- Brecconary Guard 6 follow-up: after auto-walk reached Guard 6 in the
  southwest/southeast guard pocket, the object browser recomputed pathability
  as `targets=21 reachable=1 unreachable=20`, leaving only Guard 6 in the
  reachable filter. This matches the known isolated guard-pocket behavior from
  `handoff_archive/HANDOFF_2026-04-26_brecconary_stranded_start_abort.md` and
  `HANDOFF_2026-04-27_brecconary_clean_post_35_survey.md`, not a stale object
  scanner by itself. If continued play needs broad Brecconary routing, move the
  player back to a viable central/open-town start before judging target
  reachability.
- Investigation note: a standalone Lua pathfinder probe accidentally loaded the
  real `debug_tools.lua` once and reset `dw_debug.log` at local time
  `2026-05-05 22:31:03`. Do not treat that fresh header as proof that the
  emulator consumed commands; rely on later frame-bearing log lines or
  `speech_bridge.log` for live evidence.
- Live `Shift+O` follow-up: the first manual test did not reach
  `hotkeys.lua` because the existing checked-in `dw_access.ini`
  `bizhawk_keyboard_hotkey_allowlist` was an explicit override missing
  `key_pathability_filter`. The setting itself had been auto-appended, but the
  allowlist still blocked the combo while full BizHawk hotkeys were off.
  `dw_access.ini` now includes `key_pathability_filter` in the allowlist;
  `reload_config` was consumed at frame `14580`, and command-file
  `pathability_filter` logged `All, reachable. Chest: 1 east (1 of 8)`.
  The browser was reset with `pathability_filter:all`, so the next physical
  `Shift+O` press should cycle to Reachable.
- Guard 1 follow-up from live map `0x05`: the route itself recovered and
  reached `(6,5)` adjacent to Guard 1 at `(7,5)`, but the post-arrival facing
  input walked into `(7,5)` and TALK returned `There is no one there.` Root
  cause was the target NPC hold snapshotting the guard's current live RAM
  position after he had wandered, not the object coordinates used for the
  route plan. `route_manager.lua` now pins the held NPC slot to the planned
  object `(x,y)` while preserving sprite/facing/movement bits, and restores the
  held target before applying the facing input.
- Stale command-menu follow-up: live logs showed `EVENT: command menu opened`
  after a TALK attempt and dialogue appeared, but there was no matching
  `EVENT: command menu closed`. Later `auto_walk` attempts were repeatedly
  blocked before planning. The raw `menu.is_open()` value can stay true from
  lingering `COMMAND` PPU text after the field menu is no longer interactive,
  so `main.lua` now blocks movement/auto-walk only when the confirmed live
  command-menu session still has a recent visible cursor hold. The command
  menu scanner still uses the raw header match so real open/close tracking can
  recover.
- Reload-cache follow-up: a BizHawk console reload re-ran `main.lua` but kept
  the old cached `route_manager.lua`; evidence was the old
  `NPC target hold started: target=Guard 1 slot=0 frames=1200` log without the
  new `at=(x,y)` suffix. `main.lua` now clears project modules from
  `package.loaded` before requiring them, so console/file-change reloads should
  actually pick up required-module edits. After touching `main.lua`, the log
  reset and `report_upper_dialogue_state` used the new diagnostic format.
- Reload-lag follow-up: clearing `package.loaded["emulator_compat"]` exposed a
  second reload trap. The old BizHawk shim-created `FCEU` global survived in the
  Lua state, so the fresh adapter saw `FCEU` first, misdetected the runtime as
  FCEUX, disabled `scan_profiler`, and made reloads crawl. `emulator_compat.lua`
  now prefers real BizHawk API markers (`emu` plus `mainmemory`/`client` or
  memory-domain APIs) over stale `FCEU` shim globals. Live recovery check after
  `touch main.lua`: `launcher_probe:reload_detect` landed at frame `00060` and
  `report_scan_stats` produced normal BizHawk `SCAN_PROFILE` lines instead of
  `SCAN_PROFILE unavailable`.
- Reload-input follow-up: another stale-shim layer could still leave BizHawk in
  the right mode while capturing old wrapped `joypad`/`input`/`ppu` tables as
  if they were native. Symptoms were player controls like `X`/`Z` not working
  and keys behaving like emulator/UI shortcuts after reload. `emulator_compat`
  now unwraps prior adapter closures back to the original BizHawk tables and
  replaces the `FCEU.frameadvance` wrapper on every BizHawk reload so the active
  PPU cache flushes under the current adapter. Live check after `touch main.lua`:
  `launcher_probe:frameadvance_unwrap` landed at frame `00180`,
  `cache_flushes=179`, and `input_status` reported no stuck keys.
- P-key follow-up: the project-side `Shift+P` position hotkey was configured
  and allowlisted correctly, but the local BizHawk config has global
  `"Quick Load": "P"`, making P a bad player-facing shortcut in this runtime.
  `key_position` is now `Shift+W` in both `config.lua` defaults and
  `dw_access.ini`. Live `reload_config` was consumed at frame `12780`; the
  follow-up `input_status:after_position_key_remap` showed no stuck keys.
- Pathfinding confusion follow-up: live logs showed manual blocked movement
  near the throne-room door/seam area promoted runtime blockers at `(4,7)` and
  `(5,7)` on map `0x05`, which then made later autowalks report no path.
  `route_manager.lua` now keeps `queued_route=false` manual blocks as seam
  diagnostics only; runtime blocker promotion still happens for queued-route
  and seam-retry failures. After the reload, `report_runtime_blocks` reported
  `RUNTIME_BLOCKS map=0x05 none`, and the later config-reload snapshot stayed
  clean.
- Guard/NPC overlap follow-up: a live Guard 1 route still arrived at `(4,7)`
  and then the post-arrival facing helper pressed north long enough for
  `auto_step` to treat the artificial face tap as a player step. That walked
  the hero onto Guard 1's square `(4,6)`. `auto_step.lua` now exposes
  `suppress_direction_tracking(frames)`, and `route_manager.lua` calls it when
  queuing post-arrival facing, so the face tap can turn the hero without being
  reinterpreted as tap-to-step. Live retest after reload:
  `auto_walk` while adjacent to Guard 1 logged `AUTO_WALK_FACE ... dir=up
  frames=8`, then a later `report_position` still showed `(4,7)`.
- NPC-clutter route follow-up: queued-route blocks that are currently caused by
  a live NPC are now logged as `AUTO_WALK_NPC_BLOCK`, cancel with "Route
  blocked by NPC movement", do not seam-bruteforce into the NPC, and do not
  promote runtime map blockers. Separately, a live chest route from `(4,7)` to
  the chest at `(4,4)` blocked at `(4,6)` from the south while current NPC
  blockers were `(3,6)`, `(5,6)`, `(2,6)`, and `(3,3)`. That one was not NPC
  clutter; it promoted `BLOCKER_RUNTIME map=0x05 cell=4,6(south)` as current
  live seam evidence.
- Command-menu scan follow-up: while BizHawk dialogue throttling is active,
  `main.lua` now keeps the command-menu scanner awake during current or recent
  player input. This should catch a fresh menu open after dialogue even when
  the menu was not already known open. Automated `simulate_raw_input:A` /
  `simulate_input:A` / `simulate_raw_input:B` did not open the field command
  menu in the live session, so this still needs a physical `X`/command-menu
  test from the user.
- King dialogue wrap follow-up: live play produced
  `greatly pleased 'I am thou hast that rned, Bill. retu` for the King's
  line that should read in normal screen order. The live state at map `0x05`
  `(3,4)` had `PPU_CTRL=0x03` and horizontal scroll `0xB0` (22 tiles), so the
  visible dialogue row starts in NT1 and wraps into NT0. `text.decode_row()`
  now assembles visible rows using horizontal scroll plus PPUCTRL bit 0 instead
  of reading NT0 then NT1 blindly. `report_upper_dialogue_state` now logs
  `scroll_tiles` and `base_nt`; `report_movement_state` logs `ppu_ctrl` and
  `scroll_x`. Offline tests cover NT1-first dialogue wrap. Live validation was
  attempted with `touch main.lua`, but BizHawk did not reload/poll the command
  queue, so the next physical script reload should retest the King dialogue.
- King Yes/No prompt follow-up: the fixed King row order exposed a separate
  lower-window overlap issue. Live logs showed the prompt reads as repeated
  prior tail text plus the actual question, for example
  `experience thou must gain 7 Points. 'Will thou tell me now of thy deeds so
  they won't be forgotten?'`. `text.extract_new_dialogue()` now strips both the
  normal suffix/prefix dialogue overlap and the prompt-specific "new text
  starts inside old text" overlap; `check_yesno_prompt()` speaks/logs only the
  genuinely new question while keeping the full lower-window baseline for the
  normal dialogue scanner.
- Current lag note: the local BizHawk config already matches the known safer
  baseline (`SoundBufferSizeMs=200`, `SoundThrottle=true`, `FrameSkip=0`,
  `Rewind.Enabled=false`, VSync off). A live `report_scan_stats` during the
  King follow-up showed dialogue/menu scanners staying in single-digit max
  milliseconds, while the remaining suspicious spikes were script-side:
  `objects.check_refresh max_ms=3027`, `hotkeys.update max_ms=2270`, and
  `auto_step.update max_ms=1536`. Treat future lag repros as object refresh,
  route command, or movement executor evidence first unless a clean scan window
  shows no script spike.
- Reload/menu silence follow-up: after another script reload at map `0x05`
  `(3,5)`, command-menu and dialogue speech went silent while the script still
  polled commands. Diagnostics at frame `06900` showed speech bridge ready,
  state `field`, `scroll_tiles=22`, `base_nt=1`, and active scanners, but
  `menu_raw=false lower=""`. Root cause is the same NT1-first scroll condition
  as the King dialogue row bug, but in `menu.lua`: the command-menu and Yes/No
  scanners still searched only NT0-first physical row order. `menu.lua` now
  scans both NT0->NT1 and NT1->NT0 virtual row orders for the `COMMAND` header
  and Yes/No cursor patterns. A live `touch main.lua` reload succeeded and
  `launcher_probe:menu_nt_wrap_patch` landed at frame `00180`; physical
  command-menu/TALK retest is still needed because automated simulated A input
  still did not open the field menu in this live state.
- Follow-up PPU dump note: the user-provided `ppu_dump.txt` did not capture an
  active command menu or dialogue page; it only included rows 15-29, which miss
  much of the command window. The PPU dump hotkey now records all rows 0-29 for
  both NT0 and NT1, decodes both NT0->NT1 and NT1->NT0 row orders, and marks
  explicit `COMMAND` / `YESNO` matches. `report_menu_state` is now available to
  log parser/cursor state (`raw_open`, cached open, cursor visibility, yes/no,
  scroll/base, and dialogue start row). Live reload probe
  `launcher_probe:menu_dump_diag_patch` landed at frame `00180`; current idle
  state had `MENU_STATE raw_open=false ... lower_len=0 ... base_nt=0
  dialogue_start_row=13`.
- Latest King silence capture: after a manual reload and a PPU dump taken while
  the King dialogue was believed to be open, the dump still contained no
  `COMMAND` match, no `YESNO` match, and no lower-window lowercase dialogue.
  It showed map `0x05`, player `(3,4)`, `scroll_tiles=22`, `base_nt=1`, and
  only the status/name fragments. A live `report_menu_state
  report_upper_dialogue_state speech_status` probe likewise reported
  `raw_open=false`, `lower_len=0`, and speech bridge ready. Diagnostics now
  clear the BizHawk PPU cache immediately before `Ctrl+D`,
  `report_menu_state`, and `report_upper_dialogue_state` sample the screen so
  the next capture rules out stale cached nametable bytes. The dump hotkey now
  also appends a diagnostic-only `PPU source comparison` section that compares
  native `ppu.readbyte` with available BizHawk nametable-like memory domains,
  so the next bad-state dump can show whether another source sees text that the
  normal reader misses.
- Root cause confirmed by the next dump: native BizHawk `ppu.readbyte` showed
  the blank/status-only state, while `CIRAM (nametables)` contained the real
  King text, the `COMMAND` header, and the Yes/No/menu rows. `emulator_compat.lua`
  now prefers a readable nametable memory domain for PPU reads and falls back
  to native `ppu.readbyte` only when no domain is available. Live reload proof:
  after `touch main.lua`, frame `00144` logged the full King dialogue event,
  and `speech_bridge.log` spoke both the question and `YES NO prompt. YES`.
- King final-line follow-up: the final page dump showed the farewell text in
  the nametable (`'Goodbye now, Bill. Take care and tempt not the Fates.`), but
  no matching dialogue event or speech. On that page `PPUCTRL` reported
  `base_nt=0` even though `scroll_tiles=22` still required the NT1-to-NT0
  visible order. With the reported base, the lower reader missed rows 12-17
  entirely. `text.read_dialogue_window_filtered()` now compares the reported
  base with the alternate nametable order and keeps the one with more lowercase
  dialogue. Live reload proof: frame `00156` spoke a lower-window error line
  (`'There are no stairs here.`) while `base_nt=0`, confirming the fallback is
  active in the running script. Retest the King farewell naturally on the next
  save/continue interaction.
- Command-menu opening follow-up: after the King dialogue fix, live speech logs
  still showed stale cursor RAM leaking into the first command-menu
  announcement, e.g. `Command. STAIRS` immediately before `TALK`. The snapshot
  matched this (`report_menu_state` had cursor `(0,2)` / `STAIRS` while the
  live menu was not confirmed). `main.lua` now queues the menu-open speech for
  a short six-frame debounce and either flushes it with the first real cursor
  movement or speaks the settled current item. The first live reload attempt
  was blocked by the idle emulator loop, but after the user killed/restarted the
  script, the physical retest worked as expected: opening the command menu no
  longer speaks the last-used selection before TALK.
- Death-square follow-up: manual movement found a damaging/death tile on map
  `0x04` at `(10,18)`. The relevant log evidence is a manual/tap step from
  `(10,19)` to `(10,18)`, followed by speech `Lost 15 HP. HP 0`, `Thou art
  dead.`, and the normal Death King recovery dialogue. Treat this as a hazard
  discovery, not an autowalk failure. `map_reader.lua` now models `(10,18)` as
  an engine-walkable hazard, making snapshots/pathfinding/teleport walkability
  avoid it, and `auto_step.lua` refuses tap-extension or queued-route injected
  steps into known hazards while raw held manual movement remains player-owned.
- Reachable-NPC dialogue pass: the user finished dialogue testing all
  reachable NPCs in this part of Tantegel Castle. NPC traffic was still
  annoying enough that Guard 1 was reached by teleport. The castle
  merchant-labeled NPCs only offered dialogue in this pass; verify later
  whether they ever sell before keeping them in the Services object filter.
- First-town merchant dialogue follow-up: in Brecconary, `Merchant 1` also
  offered dialogue only (`Please, save us from the minions of the Dragonlord.`)
  while still appearing in Services. The first encounter at `(15,8)` spoke the
  full line, but after the NPC moved near the top of town, the later encounters
  at `(11,4)` logged/spoke only `Please,save us from`. Root cause is likely the
  y<=3 special row reader catching only the first line and ignoring the richer
  normal lower-window candidate. `read_y1_dialogue()` now compares the fixed
  row scan against the already-filtered lower reader and uses the candidate
  with more lowercase text. Validation passed (`luac -p main.lua text.lua
  test_text.lua`, `lua test_text.lua`, `lua test_auto_step.lua`, and
  `git diff --check` with the known `dw_access.ini` CRLF warning). This patch
  has not been live-reloaded yet, to avoid interrupting active town autowalk.
- Script-crash follow-up: the user reported the script acted funky, lagged,
  then crashed. `dw_debug.log` only had a fresh header, but
  `dw_script_error.log` showed `snapshot.update: 69` from
  `emulator_compat.lua` inside `mainmemory.read_u8`. `emulator_compat.lua` now
  wraps direct BizHawk RAM reads/writes in `pcall` and falls back through the
  domain-backed `System Bus` memory API instead of letting one native memory
  read kill the Lua loop. Because the script was already dead, `touch main.lua`
  did not reload it; relaunch/reload BizHawk Lua before judging the fix.
- Map-transition lag follow-up: after the live `0x05` -> `0x04` transition,
  `report_scan_stats` showed `objects.check_refresh max_ms=1846` while dialogue
  and menu scans stayed in single-digit milliseconds. The spike was the
  map-entry path-grid prewarm. BizHawk now skips that prewarm by default via
  `bizhawk_map_entry_prewarm_path_grid=false`; FCEUX keeps the old behavior,
  and BizHawk can opt back in if first-route warmup matters more than transition
  smoothness.
- Latest scripted live state after the manual-block patch: the player was on
  map `0x05` at `(4,7)`, the selected object had reset to `Door (opened)`, and
  `report_upper_dialogue_state` showed only the status row:
  `menu_raw=false menu_active=false lower=""`. This snapshot did not reproduce
  the silent command-menu/dialogue issue; capture the next bad state while the
  menu or dialogue is visibly up before patching parser logic.
- Second-map stale object-browser follow-up: during normal fresh-game play,
  entering map `0x04` from the throne room could leave old map `0x05` NPCs in
  the current object browser until a later route/NPC-block check forced an NPC
  refresh. The user narrowed the repro: a fresh Lua load transitions cleanly,
  but after touching `main.lua` for a BizHawk reload, the old behavior returns.
  The `ppu_dump.txt` capture from the stale state did not show the prior wrong
  PPU-source failure; `ppu.readbyte` and `CIRAM (nametables)` agreed for the
  decoded rows. Root cause is reload/transition state instead. The first
  signature patch fixed only the current-map list after reload; the user's
  follow-up proved the next transition still accepted previous-map NPC RAM
  after those NPCs had moved or changed facing. `objects.lua` now stores
  signatures in `_G.DW_OBJECTS_RELOAD_STATE`, masks off NPC direction/frame
  bits, and exposes `observe_npcs(map_id)` so `main.lua` records the latest
  current-map NPC coordinate signature during normal frames and reload grace.
  On map entry, if NPC RAM still matches the just-observed previous map, the
  browser hides NPCs and retries until RAM changes instead of publishing old
  King/guard or castle entries as current-map objects. Live reload sanity check
  after this second patch: `launcher_probe:object_observe_field_only_patch`
  landed at frame `00060`; on map `0x04`, `current_object` reported a clean
  30-object castle list. User physical retest then confirmed the actual
  post-reload stairs-transition case: map `0x05` shows 4 NPCs, and map `0x04`
  shows 20 NPCs.
- Visited-after-TALK follow-up: live first-town logs showed a real TALK
  dialogue at frame `18346`, followed by
  `VISITED_AUTO skipped: no adjacent NPC matched TALK dialogue`. The TALK
  marker was armed correctly; the miss came from `objects.mark_adjacent_npc_visited()`
  using cached object-list coordinates while BizHawk periodic NPC object
  refresh is disabled. `objects.lua` now falls back to live NPC RAM slots when
  no cached adjacent NPC matches, marking the same stable `npc_N` id so the
  browser shows the NPC as visited once the object list catches up. Live reload
  probe `launcher_probe:visited_live_npc_patch` landed at frame `00060`.
- Guard 1/menu-open false-block follow-up: while testing reachable NPCs on map
  `0x04`, Guard 1 completed at `(18,2)`, then later route attempts from that
  tile recorded false runtime blocks at `(18,1)`, `(17,2)`, and `(18,3)` while
  the field command menu was still open. That boxed object pathability into
  `reachable=0`. `command_menu_blocks_field_movement()` now keeps blocking
  auto-step for a confirmed live command-menu session while either the cursor
  hold is fresh or the raw COMMAND header is still open; TALK/menu-close paths
  still clear the live-session flag before stale PPU text can linger. The live
  session was unboxed with `clear_blocked_tiles:0x04` (`count=3`), reloaded with
  `launcher_probe:guard1_menu_gate_patch`, and verified at `(18,2)` with
  `PATH_STATE ... runtime_count=0`.
- Guard 1/TALK-failure silence follow-up: immediately afterward, the user's
  failed TALK at `(18,2)` did render lower dialogue, but nothing spoke it.
  `report_upper_dialogue_state` captured `lower="'There is no one there."`,
  `prev_lower` equal to the same text, and `announced_lower=""`; the normal
  filtered lower reader saw the text, but the y<=3 row-1 cleaned dialogue path
  scanned the wrong rows for this BizHawk scroll/base state and treated the
  message as empty forever. `read_y1_dialogue()` now accepts the already
  filtered lower dialogue as a fallback when its fixed-row scan finds no
  lowercase text. Important live note: the first attempted patch briefly pushed
  `main.lua` over Lua 5.1's 200-local limit, and BizHawk appears to have
  stopped polling before the corrected patch could reload. The file is fixed,
  `luac -p main.lua` passes, and later live source-reload probes have
  succeeded.
- Delayed-dialogue visited follow-up: the user noticed visited flags were most
  likely to miss when NPC dialogue took a while to read. Logs confirmed it:
  the first Person 1 TALK armed the marker, then the real dialogue arrived
  about 299 frames later, after the old 240-frame pending marker expired, so no
  `VISITED_AUTO` line was emitted. A later faster repeat of the same dialogue
  did mark Person 1. `main.lua` now keeps pending TALK visits for 720 frames
  and logs explicit expiry; `objects.lua` stores `visited_by_map` in
  `_G.DW_OBJECTS_RELOAD_STATE`, and `main.lua` migrates the old module-local
  visited table before clearing cached modules so the first hot reload after
  this patch should not wipe the current playtest's visited flags. Live reload
  probe `launcher_probe:talk_visit_timeout_patch` landed at frame `00060`.
- Person 1 reachable-filter/no-path hint follow-up: live castle logs showed
  Person 1 in `NPCs, reachable`, then auto-walk failed with the closed-door
  hint. The planner itself was not treating Person 1 as truly isolated: the
  reachability filter is intentionally geometry-only and ignores live NPC
  occupancy, while the failed route had already logged an `AUTO_WALK_NPC_BLOCK`.
  The bad part was `infer_no_path_reason()` preferring any nearby
  closed-door frontier before checking whether an NPC-free route exists, so a
  temporary NPC-clutter no-path could be narrated as "blocked by a closed door."
  `route_manager.lua` now checks the NPC-free route first and only falls back
  to the closed-door hint when NPC clutter is not the better explanation.
  Regression: `autowalk_npc_clutter_hint_takes_precedence_over_nearby_closed_door`.
  Live caveat: after reloading `launcher_probe:person1_hint_patch`, a probe
  `auto_walk` hit the post-reload selected object (`Exit to World Map`) instead
  of Person 1 and moved the player from `(13,20)` to `(11,28)`. Runtime blocks
  are clear (`PATH_STATE ... runtime_count=0`), but do not treat that accidental
  route as a Person 1 physical retest.
- The false-visited regression test through failed TALK still behaves correctly
  in manual testing.
- Current investigation target: no active blocker at wrap-up. The stale
  object-browser reload/transition fix is confirmed by user retest, the NPC
  clutter hint is corrected, and the delayed-dialogue visited fix is live after
  a probe-only reload. Continue normal playtesting and watch whether the next
  slow NPC dialogue emits `VISITED_AUTO`.

Validation already run for this batch:
- 2026-05-05 Codex-first tooling refresh validation:
  source-text compile checks for `.codex/hooks/pretool_dw_command_guard.py`,
  `.codex/hooks/session_start_project_context.py`, and `test_tooling.py`;
  `bash -n dw_commands.sh launch_dw.sh launch_bizhawk.sh launch_fceux.sh`;
  TOML/JSON parse checks for `.codex/config.toml` and `.codex/hooks.json`;
  `python3 test_tooling.py`; PowerShell smoke test of `dw_commands.ps1`
  `--json --replace report_position` against a temp copy; and
  `git diff --check`.
- `luac -p config.lua hotkey_filter.lua hotkeys.lua objects.lua
  object_commands.lua route_manager.lua main.lua test_hotkey_filter.lua
  test_hotkeys.lua test_objects.lua test_route_manager.lua`
- `lua test_hotkey_filter.lua`
- `lua test_hotkeys.lua`
- `lua test_objects.lua`
- `lua test_route_manager.lua`
- 2026-05-05 Guard 1 follow-up validation: `luac -p route_manager.lua
  test_route_manager.lua`, `lua test_route_manager.lua`,
  `lua test_auto_step.lua`, and `git diff --check`.
- 2026-05-05 stale command-menu follow-up validation: `luac -p main.lua
  route_manager.lua`, `lua test_route_manager.lua`, `lua test_menu.lua`,
  `lua test_auto_step.lua`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed with the known WSL
  `accessible_output2` warning and `cmd: not found` speech-bridge noise.
- 2026-05-05 autostep/object-browser follow-up validation: `luac -p
  auto_step.lua objects.lua main.lua navigation.lua test_auto_step.lua
  test_objects.lua config.lua`, `lua test_auto_step.lua`,
  `lua test_objects.lua`, and `git diff --check` passed. `git diff --check`
  still prints the known `dw_access.ini` CRLF warning.
- 2026-05-06 object-browser reload follow-up validation: `luac -p
  objects.lua main.lua navigation.lua test_objects.lua test_auto_step.lua
  config.lua`, `lua test_objects.lua`, `lua test_auto_step.lua`, and
  `git diff --check` passed. `git diff --check` still prints the known
  `dw_access.ini` CRLF warning. New regression coverage includes observed
  previous-map NPC signatures surviving an `objects.lua` module reload, plus
  direction/frame-bit-only NPC changes. Live `touch main.lua` plus
  `launcher_probe:object_observe_field_only_patch` passed, and `current_object`
  reported the clean map `0x04` 30-object list after reload.
- 2026-05-06 visited-auto live-RAM follow-up validation: `luac -p
  objects.lua test_objects.lua main.lua`, `lua test_objects.lua`,
  `lua test_auto_step.lua`, live `touch main.lua` plus
  `launcher_probe:visited_live_npc_patch`, and `git diff --check` passed.
  `git diff --check` still prints the known `dw_access.ini` CRLF warning.
- 2026-05-06 delayed-dialogue visited follow-up validation: `luac -p
  main.lua objects.lua test_objects.lua test_route_manager.lua`,
  `lua test_objects.lua`, `lua test_route_manager.lua`, live source reload
  with `launcher_probe:talk_visit_timeout_patch`, and `git diff --check`
  passed. `git diff --check` still prints the known `dw_access.ini` CRLF
  warning. Regression coverage includes visited flags surviving an
  `objects.lua` module reload and staying cleared after `clear_visited:all`.
- 2026-05-06 death-square hazard follow-up validation: `luac -p
  map_reader.lua auto_step.lua route_manager.lua test_map_reader.lua
  test_auto_step.lua`, `lua test_map_reader.lua`, `lua test_auto_step.lua`,
  `lua test_route_manager.lua`, and `git diff --check` passed. `git diff
  --check` still prints the known `dw_access.ini` CRLF warning. Live source
  reload with `launcher_probe:hazard_patch` landed at frame `00060`; the log
  reset cleanly, and `dw_script_error.log` had no new entry beyond older known
  crashes.
- 2026-05-05 reload-cache/diagnostic follow-up validation:
  `luac -p main.lua route_manager.lua test_route_manager.lua`,
  `lua test_route_manager.lua`, `lua test_menu.lua`, `lua test_auto_step.lua`,
  `git diff --check`, and `python3 run_tests.py --allow-missing-speech-dep`
  passed with the same known WSL speech warnings/noise.
- 2026-05-05 reload-lag follow-up validation: `luac -p emulator_compat.lua
  test_emulator_compat.lua`, `lua test_emulator_compat.lua`,
  live `touch main.lua` plus `launcher_probe:reload_detect report_scan_stats`,
  `git diff --check`, and `python3 run_tests.py --allow-missing-speech-dep`
  passed before the later memory-read crash fix.
- 2026-05-05 memory-read crash follow-up validation: `luac -p
  emulator_compat.lua test_emulator_compat.lua` and
  `lua test_emulator_compat.lua`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed with the known WSL
  speech warnings/noise. A live `touch main.lua` could not reload the script
  because the Lua loop had already crashed and was no longer polling commands.
- 2026-05-05 King dialogue wrap validation: `luac -p addresses.lua text.lua
  main.lua debug_tools.lua test_text.lua`, `lua test_text.lua`,
  `python3 run_tests.py --allow-missing-speech-dep`, and `git diff --check`
  passed with known WSL speech warnings/noise and the known `dw_access.ini`
  CRLF warning. A live `touch main.lua` did not trigger command polling, so
  physical script reload/retest is still needed.
- 2026-05-05 King Yes/No prompt overlap validation: `luac -p text.lua
  main.lua test_text.lua`, `lua test_text.lua`, `python3 run_tests.py
  --allow-missing-speech-dep`, and `git diff --check` passed with the known WSL
  speech warnings/noise and the known `dw_access.ini` CRLF warning. Live retest
  still needs a physical Lua reload and another King save/continue prompt.
- 2026-05-05 reload/menu silence validation: `luac -p menu.lua test_menu.lua
  main.lua`, `lua test_menu.lua`, `python3 run_tests.py
  --allow-missing-speech-dep`, and `git diff --check` passed with the known WSL
  speech warnings/noise and `dw_access.ini` CRLF warning. Live reload probe
  passed with `launcher_probe:menu_nt_wrap_patch`; physical command-menu/TALK
  retest is still needed.
- 2026-05-05 PPU/menu diagnostic follow-up validation: `luac -p main.lua
  hotkeys.lua test_hotkeys.lua`, `lua test_hotkeys.lua`, and `git diff --check`
  passed with the known `dw_access.ini` CRLF warning. Live reload probe passed
  with `launcher_probe:menu_dump_diag_patch`.
- 2026-05-05 reload-input follow-up validation: `luac -p emulator_compat.lua
  test_emulator_compat.lua`, `lua test_emulator_compat.lua`, live `touch
  main.lua` plus `launcher_probe:frameadvance_unwrap report_scan_stats
  input_status:after_frameadvance_unwrap`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed with the same known
  WSL speech warnings/noise.
- 2026-05-05 manual-block/P-key follow-up validation: `luac -p config.lua
  route_manager.lua test_hotkey_filter.lua test_hotkeys.lua
  test_route_manager.lua`, `lua test_hotkey_filter.lua`,
  `lua test_hotkeys.lua`, `lua test_route_manager.lua`, live `reload_config
  input_status:after_position_key_remap report_runtime_blocks
  report_upper_dialogue_state`, `python3 run_tests.py
  --allow-missing-speech-dep`, and `git diff --check`. The live log showed
  `RUNTIME_BLOCKS map=0x05 none`; broad harness still has the known WSL
  `accessible_output2` warning and `cmd: not found` speech-bridge noise.
- 2026-05-05 menu/facing/NPC-block follow-up validation so far: `luac -p
  main.lua auto_step.lua route_manager.lua test_auto_step.lua
  test_route_manager.lua`, `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  live `launcher_probe:menu_face_npc_clutter_patch`, and live Guard 1 facing
  retest that stayed at `(4,7)`. Follow-up broad validation:
  `python3 run_tests.py --allow-missing-speech-dep` and `git diff --check`;
  broad harness still has the known WSL `accessible_output2` warning and
  `cmd: not found` speech-bridge noise, and `git diff --check` still has the
  known `dw_access.ini` CRLF warning.
- 2026-05-05 command-menu opening debounce validation: `luac -p main.lua`,
  `lua test_menu.lua`, `python3 run_tests.py --allow-missing-speech-dep`, and
  `git diff --check` passed. The broad harness still has the known WSL
  `accessible_output2` warning and `cmd: not found` speech-bridge noise, and
  `git diff --check` still has the known `dw_access.ini` CRLF warning. A live
  `touch main.lua` probe timed out because the emulator loop was idle and did
  not consume commands.
- `python3 run_tests.py --allow-missing-speech-dep` passed with the known WSL
  `accessible_output2` missing warning and `cmd: not found` speech-bridge noise.
- `git diff --check`

Latest BizHawk transition checkpoint:
- Pending wrap-up commit: BizHawk stabilization and main-menu/playtesting polish
- Previous committed baseline: `a5386bc Make BizHawk the default emulator path`

Previous FCEUX keyboard bridge checkpoint:
- Commit: `a79bd6f Stabilize FCEUX keyboard input bridge`

That commit includes:
- FCEUX native keyboard GamePad.0 disabled on launcher startup.
- `keyboard_bridge.ps1` for Windows real-key polling.
- Foreground-gated key forwarding so terminal typing does not bleed into FCEUX.
- `enable_keyboard_input_bridge=true` config default.
- Runtime bridge file `dw_keyboard_input.txt` ignored.

The BizHawk default transition contains:
- `main.lua` loads `emulator_compat.lua` before the existing modules.
- `emulator_compat.lua` supplies FCEUX-shaped globals under BizHawk.
- `launch_dw.sh` now defaults to BizHawk. Use `./launch_dw.sh --emulator fceux`,
  `./launch_fceux.sh`, or `launch_fceux.ps1` for the FCEUX fallback.
- `launch_bizhawk.sh` and `launch_bizhawk.ps1` still explicitly launch EmuHawk
  with `--lua=main.lua`.
- BizHawk-only PPU scan throttling now reduces gameplay-loop screen scans
  without changing FCEUX behavior.
- `scan_profiler.lua` provides BizHawk-only scan scheduling/profiling plus
  `report_scan_stats` / `reset_scan_stats` debug commands.
- BizHawk keyboard hotkeys from `input.get()` are disabled by default via
  `enable_bizhawk_keyboard_hotkeys=false`, because stray keyboard/screen-reader
  state triggered diagnostic speech during dialogue.
- When full BizHawk hotkeys are off, `hotkey_filter.lua` still permits the
  config-driven `bizhawk_keyboard_hotkey_allowlist`; default entries restore
  player readouts, object explorer/navigation shortcuts J/K/L/O/U/Q,
  `Shift+F` NPC freeze, and compact `Ctrl+N` tile/coordinate diagnostics.
  Heavier developer diagnostics (`Ctrl+M`, `Ctrl+D`, `Ctrl+Y`) are behind
  `enable_bizhawk_diagnostic_hotkeys`; the generated/shipping default is
  `false`, while the current checked-in `dw_access.ini` is intentionally
  `true` for manual testing.
- The `Ctrl+N` tile/coordinate hotkey now speaks only the compact coordinate/tile
  summary by default. The old full `tile_diag.txt` dump is behind
  `tile_diag_dump_on_hotkey=true` because it can stall BizHawk audio.
- `state.lua` now avoids BizHawk's slow `$6003` sprite-CHR cartridge work-RAM
  read during normal field play when enemy HP is clear.
- `objects.lua` now caches static object sources per map so route/path commands
  can refresh live NPC blockers without rereading ROM-backed chests/stairs/
  exits/doors every time.
- `debug_tools.lua` logs `CMD_TIMING command=... ms=...` for command handlers
  over 25 ms, and `main.lua` throttles repeated `CAN_WALK false` debug lines.
- During BizHawk dialogue scans, `main.lua` now clears the PPU cache for dynamic
  text reads so half-rendered dialogue does not look stable for 120 cached
  frames.
- Under BizHawk, object descriptions now skip reachability/path checks by
  default (`bizhawk_object_reachability_descriptions=false`). Object navigator
  keys should speak name/direction quickly; `pathfind` and `auto_walk` still do
  real route work when requested.
- J/K/L/Q object-browser hotkeys explicitly request brief descriptions:
  name/direction/count only, with no reachability path preview and no raw
  player/object coordinate suffix.
- Rapid previous/next object hotkeys now coalesce speech through
  `object_nav_speech_coalesce_frames=18`. J/L still change the selected object
  immediately, but only the latest description speaks after the player pauses;
  K/current-object, filter, pathfind, auto-walk, and other immediate speech
  clear the pending object announcement.
- Under BizHawk, periodic background NPC/object refresh is disabled by default
  (`bizhawk_periodic_npc_refresh=false`). Map changes, deferred map-load
  refreshes, explicit route/path commands, and debug commands still refresh NPCs
  when they need current blockers.
- BizHawk rewrites `D:\emulation\bizhawk\config.ini` from its in-memory
  settings on shutdown when settings have changed. Do not patch `config.ini`
  while EmuHawk is running and expect it to stick; close BizHawk first or patch
  immediately before launch.

Lightweight checks passed during the BizHawk default transition:
- `git diff --check`
- Lua parse checks for `main.lua` and `emulator_compat.lua`
- `bash -n launch_dw.sh launch_bizhawk.sh launch_fceux.sh`
- `./launch_dw.sh --dry-run` reports BizHawk as the default emulator
- `./launch_dw.sh --emulator fceux --dry-run` reports the FCEUX fallback
- `python3 run_tests.py --allow-missing-speech-dep` passed locally; the only
  warning was the expected missing `accessible_output2` package for WSL
  `/usr/bin/python`.
- 2026-04-29 docs follow-up: `CLAUDE.md` and `prompt1.txt` were updated so
  future agents no longer see stale FCEUX-only launch/runtime guidance.
  Refreshed checks passed: `git diff --check`, `bash -n launch_dw.sh
  launch_bizhawk.sh launch_fceux.sh`, both `launch_dw.sh --dry-run` variants,
  and `python3 run_tests.py --allow-missing-speech-dep`. The first sandboxed
  test run failed only because the sandbox blocked writes to `dw_commands.txt`
  and `__pycache__`; the approved rerun passed.
- 2026-04-29 live follow-up: after increasing
  `object_nav_speech_coalesce_frames` to `18` and adding the closed-door
  no-path hint, `python3 run_tests.py --allow-missing-speech-dep` and
  `git diff --check` passed again.
- Latest follow-up after the cartridge work-RAM fix and shorter auto-step retry
  window: `git diff --check`, `bash -n launch_dw.sh launch_bizhawk.sh
  launch_fceux.sh dw_commands.sh`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed. The only warning
  remains the expected missing WSL `accessible_output2` package.
- 2026-04-30 manual BizHawk playtest confirmed the clean early-game flow from
  launch: start/continue, open all throne-room chests, open the `(4,7)` door,
  and walk down the stairs into the castle proper.
- 2026-04-30 wrap-up validation after the fast `N` diagnostic/object-browser
  changes passed: `luac -p hotkeys.lua objects.lua route_manager.lua
  config.lua test_hotkeys.lua`, `lua test_hotkeys.lua`,
  `lua test_route_manager.lua`, `lua test_objects.lua`, and
  `git diff --check`.
- 2026-04-30 route-turn follow-up after the user's first-town playtest passed:
  `luac -p auto_step.lua pathfinder.lua route_manager.lua config.lua
  test_auto_step.lua`, `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  `lua test_pathfinder.lua`, and `git diff --check`. The pathfinder test still
  prints the known WSL-side Tolk/`cmd` warning before passing.
- 2026-04-30 route-planning/object-refresh follow-up passed:
  `luac -p pathfinder.lua objects.lua main.lua test_pathfinder.lua
  test_objects.lua`, `lua test_pathfinder.lua`, `lua test_objects.lua`,
  `lua test_route_manager.lua`, `lua test_map_survey.lua`,
  `lua test_auto_step.lua`, and `git diff --check`. `test_pathfinder.lua` still
  prints the known WSL-side Tolk/`cmd` warning before passing.
- 2026-04-30 route-lag/drift follow-up passed: `luac -p auto_step.lua
  route_manager.lua config.lua pathfinder.lua map_reader.lua objects.lua
  main.lua test_auto_step.lua test_route_manager.lua test_pathfinder.lua
  test_map_reader.lua test_objects.lua test_map_survey.lua`,
  `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  `lua test_pathfinder.lua`, `lua test_map_reader.lua`,
  `lua test_objects.lua`, `lua test_map_survey.lua`, and `git diff --check`.
  `test_pathfinder.lua` still prints the known WSL-side Tolk/`cmd` warning
  before passing.
- 2026-04-30 route-cleanup refresh follow-up passed:
  `luac -p route_manager.lua config.lua test_route_manager.lua`,
  `lua test_route_manager.lua`, `lua test_auto_step.lua`, `lua test_objects.lua`,
  and `git diff --check`.
- Live BizHawk validation after that patch relaunched quick slot 1, selected
  Person 4 and then Person 2 in Brecconary, and completed both auto-walks with
  neutral input, no runtime blockers, no `ROUTE_PLAN_TIMING` spikes, and
  `objects.check_refresh max_ms=0`.
- 2026-04-30 name-entry follow-up passed:
  `luac -p main.lua config.lua hotkeys.lua debug_tools.lua`,
  `lua test_state.lua`, `lua test_hotkeys.lua`, and `git diff --check`.
  The live pre-reload log only showed title/name-entry state with no held input;
  the code patch still needs a Lua reload before user retest.
- 2026-04-30 main-menu follow-up passed:
  `luac -p state.lua main.lua test_state.lua`, `lua test_state.lua`, and
  `git diff --check -- state.lua main.lua test_state.lua`. User logs showed
  erase-confirmation screens being misclassified as field/map `0x00`, which
  let dialogue/map/auto-step logic run on title-menu input. `state.lua` now
  treats the erase confirmation and name-entry grid as title screens even when
  save RAM contains a valid level, `main.lua` keeps auto-step off during
  title-to-field debounce, and the name-entry A guard now requires a short
  stable release before accepting another A press. This still needs a Lua
  reload and live retest of "Erase a quest" plus name entry.
- Important BizHawk input finding from the next retest: normal NES `P1 A` is
  `X`, normal `P1 B` is `Z`, `Start` is `Enter`, and `Select` is `Space` in
  `D:\emulation\bizhawk\config.ini`. `S` is not normal A; it is bound under
  `AllTrollersAutoFire` as NES `P1 A` autofire, with one-frame on/off pulses.
  Avoid `S` for name entry and erase confirmation. If extra A confirms or map
  announcements continue with `X`, collect a fresh `report_title_state` /
  `trace_input:300` capture.
- Hotkey remap follow-up: `hotkeys.lua` now accepts modifier combos such as
  `Ctrl+N` and `Shift+F`, and `hotkey_filter.lua` only passes combo components
  through BizHawk's allowlist when the whole combo is actually held. Current
  layout keeps frequent object keys unmodified (`J/K/L/O/U/Q`), puts less-used
  info hotkeys on `Shift+key`, puts diagnostics on `Ctrl+key`, and avoids
  BizHawk NES control/autofire keys (`X`, `Z`, `Enter`, `Space`, `A`, `S`).
- King-dialogue regression follow-up: live probe after entering the game showed
  `state=field` on map `0x05`, `UPPER_STATE ... lower_len=97`, but no
  `check_dialogue` scan-profile entry; `check_title_screen` had kept running
  in field. Root cause was the title-to-field debounce counter not being
  cleared after "Game started.", so `in_gameplay` stayed false forever.
  `main.lua` now clears `field_from_title_ct` when `FIELD_DEBOUNCE` completes.
  The next live log confirmed king/NPC dialogue auto-read again.
- 2026-05-01 command/dialogue polish passed:
  `luac -p main.lua text.lua menu.lua test_text.lua test_state.lua
  test_hotkeys.lua test_hotkey_filter.lua`, `lua test_text.lua`,
  `lua test_state.lua`, `lua test_hotkeys.lua`, `lua test_hotkey_filter.lua`,
  and `git diff --check -- main.lua text.lua test_text.lua`. `main.lua` now
  speaks the highlighted command item when the field command menu opens, for
  example `Command. TALK`, and `text.lua`/`read_y1_dialogue()` skip persistent
  status rows such as `Bill LV 1 HP 15 MP 0 G 120 E 0` before they can be
  treated as lower dialogue. Needs Lua reload and a quick live retest of command
  menu open plus post-dialogue dismissal.
- Follow-up live retest showed the status row could still speak from the upper
  dialogue path. `report_upper_dialogue_state` confirmed `upper`, `baseline`,
  and `announced` were the status row while `lower_len=0`. `main.lua` now also
  suppresses extracted upper-dialogue `new_text` when that extracted fragment is
  itself status text, logging `UPPER_DIALOGUE_SUPPRESS_STATUS` instead of
  speaking it. Validation: `luac -p main.lua text.lua test_text.lua`,
  `lua test_text.lua`, and `git diff --check -- main.lua text.lua
  test_text.lua`. The patch was auto-reloaded in BizHawk and confirmed with
  `launcher_probe:upper-status-guard-loaded`; it still needs the user's hands-on
  post-dialogue dismissal retest.
- A broader `python3 run_tests.py --allow-missing-speech-dep` run passed its
  Lua test portion, then failed at the known sandbox write boundary while
  trying to write `__pycache__` and `dw_commands.txt`. The rerun requiring
  unsandboxed writes was intentionally not pursued because the session was
  wrapping up.
- 2026-05-01 diagnostic-hotkey gate follow-up passed:
  `luac -p hotkey_filter.lua config.lua test_hotkey_filter.lua`,
  `lua test_hotkey_filter.lua`, `lua test_hotkeys.lua`, `git diff --check`,
  and `python3 run_tests.py --allow-missing-speech-dep`. The full run only
  showed the known WSL-side speech dependency warning / `cmd` noise.
- 2026-05-01 quick manual retest confirmed the diagnostic gate behaves as
  intended with `enable_bizhawk_diagnostic_hotkeys=true`: the heavier diagnostic
  key combos pass through and activate the proper functions.
- 2026-05-01 quick live map `0x05` movement/pathing cycle started from
  `(3,4)` in the throne room. Object enumeration found 9 objects, including the
  closed door at `(4,7)` and stairs at `(8,8)`. `inspect_tile:4,7` still reports
  `reason=door_closed`, while `inspect_tile:8,8` reports `reason=passthrough`.
  `auto_walk` completed a 1-step move to `(4,4)` and a rerouted walk to Guard 3
  ending at `(5,5)`. During the Guard 3 route, the first queued `down` from
  `(4,4)` to `(4,5)` timed out once and logged `NEW BLOCK`, but a controlled
  `probe_edge:DOWN` from `(4,4)` then moved successfully to `(4,5)`. Treat this
  seam as noisy/transient route-executor evidence, not permanent map data.
- The same map `0x05` cycle exposed debug-command hitches: `report_path_state`
  repeatedly logged about 1.4-1.7 seconds, `inspect_move:UP` logged 1.413s,
  `inspect_move:DOWN` logged 0.972s, `pathfind_adjacent:4,4` logged 1.564s,
  `pathfind_to:8,8` logged 1.004s, and `probe_edge:DOWN` logged 1.593s.
  Focused route execution itself looked much healthier: the Guard 3 route
  window had `objects.check_refresh max_ms=0`, `auto_step.update max_ms=1`, and
  `debug_tools.tick max_ms=2`. The player was restored to `(3,4)` afterward.

## BizHawk Default Status

What works:
- BizHawk launches from `./launch_dw.sh` and `./launch_bizhawk.sh`.
- ROM and `main.lua` load.
- Speech bridge starts and speaks.
- Script reaches title flow and can get through "Continue a quest."
- Fresh manual playtesting confirms chest collection, magic-key door opening,
  and stair descent from the throne room work as expected.
- Basic manual testing on the first two maps after the emulator conversion
  found the scripts behaving as expected apart from audio stuttering under
  heavier emulator/script load.
- Missing FCEUX globals already shimmed: `FCEU`, `memory`, `joypad`, `input`, `ppu`, `rom`, `AND`, and `BIT`.
- ROM reads are cached permanently.
- PPU reads are cached across multiple BizHawk frames.

Remaining watch items:
- BizHawk is now the default, and the first early-game door/stairs flow has a
  clean manual confirmation.
- Latest user report after reloading the script and clearing the king dialogue:
  broad lag is mostly under control; object-list navigation still produces a
  small amount of lag. The current worktree has a hotkey-side speech coalescer
  intended to reduce rapid J/L speech-interrupt pressure; it still needs live
  BizHawk confirmation.
- Auto-walk lag/drift is now substantially improved in both live logs and the
  user's hands-on retest. The current worktree addresses the observed causes:
  route-command refresh/freeze overhead, post-route object refresh, and queued
  movement drift from sticky D-pad state after the route inject window.
- Emulator audio can still stop for short stretches under heavier load. Current
  evidence points toward timing/config tuning and reducing synchronous hotkey
  work rather than a game-script correctness problem.

Important clues:
- Earlier title-screen lag improved after PPU read caching.
- The PPU adapter selected a nametable-related domain and initially produced out-of-range warnings before domain scoring was improved.
- `state.detect()` was also doing a full title-text PPU scan during gameplay;
  under BizHawk this now rescans only rarely after field/battle state is
  confirmed.
- `main.lua` now throttles the gameplay PPU-heavy checks under BizHawk:
  yes/no prompt, command/battle menu, merchant screen, lower dialogue, and
  upper dialogue. Stability counters receive elapsed-frame deltas so speech
  timing should remain close to FCEUX.
- `emulator_compat.lua` now keeps the BizHawk PPU cache for 120 frames and
  clears it on real or simulated input.
- During the king's normal boot dialogue, `main.lua` enters a BizHawk-only
  boot-dialogue grace that suppresses command-menu, merchant, and object scans
  and keeps only dialogue/yes-no style scans active.
- Latest live king-dialogue profile after reset: PPU reads dropped to 123,840
  over a 900-frame sample. The active scan profile was only lower dialogue
  (52,800 reads), yes/no prompt (36,480), and upper dialogue (34,560);
  command-menu, merchant, and object refresh scans did not run in that window.
- The previous comparable king-dialogue sample before boot-dialogue grace was
  about 1,039,344 PPU reads; an earlier broad field sample was about 4,157,376.
- User-reported "Level 1. HP 15 of 15..." lines embedded in king dialogue were
  not dialogue-parser output. They were stray BizHawk keyboard hotkeys firing
  the status diagnostic through `input.get()`.
- The first hotkey gate disabled object explorer too. It was replaced with the
  allowlist model so future QoL shortcuts can be added by appending their
  config key name to `bizhawk_keyboard_hotkey_allowlist`. `N` tile/coordinate
  diagnostics is now allowed for playtesting; broad status/raw-dump diagnostics
  like S/D remain blocked by default.
- Live command-file probe while the old hotkey gate was running showed the
  object system itself still worked: `current_object` logged
  `Door: 2 south, 4 west (4 of 6) [player 8,5 obj 4,7]. Not currently reachable`.
- Fresh post-dialogue/player-control profile before the `$6003` fix:
  `state.check_for_changes calls=240 reads=0 ms=26984 avg_ms=112.433`.
  The dominant cost was not PPU scanning, but a per-frame cartridge work-RAM
  read of `addr.CHR_PAGE_SPRITES` (`$6003`) in BizHawk.
- After lag was gone in normal play, user reported audio glitches only while
  route/path commands were processing. A fresh sample around `pathfind` showed
  `debug_tools.tick max_ms=1931` and `objects.check_refresh max_ms=2068`;
  this pointed to synchronous command/object-refresh work rather than the
  steady frame loop.
- Latest live observation after the broader lag fixes: dialogue no longer lags,
  but can speak before all text arrives; object navigator can freeze BizHawk for
  about two seconds; emulator audio can randomly freeze while working in other
  windows. The first two have code-side patches in this worktree. The last
  still needs correlation against `CMD_TIMING`/scan stats and may be host focus
  or emulator scheduling behavior.
- Fresh post-dialogue object-navigation command-file sample after disabling
  periodic BizHawk NPC refresh: `objects.check_refresh calls=14 ms=1 max_ms=1`;
  no `CMD_TIMING` lines were emitted for object commands.
- Fresh real-hotkey sample while the user tapped object navigation:
  `hotkeys.update max_ms=1`, `objects.check_refresh max_ms=1`,
  `debug_tools.tick max_ms=3`, and all screen scans stayed at small single-digit
  max times. This suggests the remaining small object-list hitch is not a Lua
  object-refresh or hotkey-handler spike; treat speech interrupt overhead or
  BizHawk/Windows audio scheduling as more likely unless stronger evidence
  appears.
- The current hotkey patch targets that likely speech side: J/L object
  navigation queues only the latest object description for a short idle delay.
  The delay was increased from 6 to 18 frames after live logs showed 6 frames
  still flushed speech repeatedly during manual object-list tapping.
  `object_nav_speech_coalesce_frames=0` restores immediate speech if the delay
  feels worse in play.
- The next audio-cutout repro was the `N` tile/coordinate diagnostic: after it
  was allowlisted, pressing it caused about 1.5-2 seconds of audio cut-out while
  the full diagnostic dump was built. The hotkey now speaks the compact
  coordinate/tile summary only unless `tile_diag_dump_on_hotkey=true`.
- BizHawk audio-trial settings helped substantially. With
  `SoundBufferSizeMs=200`, `SoundThrottle=true`, `FrameSkip=0`, and
  `Rewind.Enabled=false`, the user could work in other windows with game audio
  running and did not hear the previous background-window audio glitches. One
  audio glitch occurred while focused in the emulator, but it was not
  reproducible.
- Latest BizHawk-specific pathing failure started as a ROM-domain translation
  bug: live `inspect_tile` on known throne-room cells returned `tile=nil`, even
  though the same map was already verified under FCEUX. `emulator_compat.lua`
  now scores ROM candidate domains and supports headerless PRG-only BizHawk ROM
  domains while preserving FCEUX-style `rom.readbyte()` file offsets. A new
  `test_emulator_compat.lua` covers both full iNES and headerless PRG mappings.
- Live follow-up on 2026-04-29 confirmed that map `0x05` now decodes correctly
  under BizHawk: `inspect_tile:8,8` returned `dims=10x10`, `tile=15.0`,
  `reason=passthrough`, and `effective_passable=true`. The remaining no-path
  to the selected stairs is caused by the closed magic-key door at `(4,7)`, not
  bad map data. `route_manager.lua` now adds a closed-door hint to no-path
  object plans, covered by `test_route_manager.lua`.
- Subsequent live playtesting showed that after the door was opened, the script
  still reported `(4,7)` as `door_closed`. Root cause: the BizHawk adapter was
  reading `$600C/$600D` opened-door slots through `mainmemory`; those bytes live
  in cartridge work RAM. `emulator_compat.lua` now routes `$6000-$7FFF` through
  System Bus / PRG-RAM-style domains, with new tests in
  `test_emulator_compat.lua` and `test_map_reader.lua`.
- Manual retest after this fix confirmed the launch-to-chests-to-door-to-stairs
  flow works normally.
- Auto-walk still causes emulator audio pain, especially when a route hits a
  blocked step and retries for several seconds. Local config now shortens that
  window with `auto_step_timeout=45` and `auto_step_block_retry_limit=1`.
- The latest live log from the first-town manual run showed queued auto-walk
  direction changes could continue the previous direction for one more cell:
  after moving south to `(1,4)`, a queued `right` completed at `(1,5)` while
  the planned seam was `(2,4)`, and a later queued `down` from `(3,5)`
  completed at `(4,5)` while the planned seam was `(3,6)`. `auto_step.lua` now
  adds a configurable turn-settle pause only when queued route direction
  changes (`auto_step_route_turn_settle_frames=16`).
- `pathfinder.lua` now keeps chosen-path summaries but suppresses tile-by-tile
  chosen-path dumps unless `pathfind_log_steps=true`, and
  `route_manager.lua` logs `ROUTE_PLAN_TIMING ... ms=...` for plans over
  25 ms so hotkey-triggered `O`/`U` lag is visible even when no `CMD_TIMING`
  line is produced.
- The next live log produced a concrete route-planning spike:
  `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_15 ... path_len=2
  ms=1978.000`. The queued walking phase then completed the expected 2-step
  route with the new turn-settle line, so the lag was in adjacent-route planning
  rather than the step executor. `pathfinder.lua` now sorts adjacent candidates
  by lower-bound distance, skips candidates that cannot beat the current best
  path, and only computes reachable-area/open-exit diagnostics when needed for
  equal-length ties or no-path survey evidence.
- The same user report explained the quickload/town object oddity: Brecconary
  initially showed only "Exit to World Map" because interior map-entry refreshes
  intentionally build static objects first and defer NPC parsing, but BizHawk's
  120-frame object-refresh throttle could delay the second phase. `objects.lua`
  now exposes `needs_refresh(map_id)`, and `main.lua` lets map changes/deferred
  refreshes bypass the periodic throttle.
- Live retest after reloading confirmed the object-refresh fix felt good: the
  user did not notice the objects missing. The next auto-walk log still showed
  two problems: route planning was still slow
  (`ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_4 ... path_len=13
  ms=1836.000`), and the route drifted during turn-settle at `(4,14)` to
  `(5,14)`, causing `route_drift_off_path`. `auto_step.lua` now actively sends
  neutral D-pad frames throughout route-settle, and `map_reader.lua` /
  `pathfinder.lua` now provide and consume per-plan walkability snapshots so A*
  avoids repeated slow map-reader checks.
- Another live retest showed both `U` auto-walk and `O` show-path still lagged:
  auto-walk plans logged `path_len=13 ms=1852.000` and `path_len=10
  ms=1238.000`; show-path logged `path_len=7 ms=1422.000` and even
  `path_len=1 ms=1514.000`. Because a one-step preview still took about
  1.5 seconds, treat the remaining lag as fixed route-command overhead before
  blaming path length alone.
- `route_manager.lua` now skips forced live NPC refresh before BizHawk `O`/`U`
  plans by default (`bizhawk_route_refresh_npcs=false`) and skips BizHawk
  auto-walk's per-frame NPC RAM freeze by default
  (`bizhawk_autowalk_freeze_npcs=false`). FCEUX keeps the old default behavior,
  and both BizHawk behaviors remain opt-in through config.
- The same retest produced two newer drift signatures during turn-settle: after
  a first `right` step from `(0,15)` to `(1,15)`, the player slid to `(2,15)`
  before the planned `up`; after a right segment from `(6,16)` to `(7,16)`,
  the player slid to `(8,16)` before the planned `up`. `auto_step.lua` now also
  neutralizes queued route input after the inject window, so sticky `joypad.set`
  state cannot commit the next tile before settle/turn handling runs.
- `inspect_tile` and `inspect_move` logs now include map dimensions and the
  walkability `reason`, so future bad-grid cases should show whether the model
  is clipping as `out_of_bounds`, using a passthrough, or reading ordinary tile
  data.
- Latest 2026-04-30 quick-slot-1 follow-up: `auto_step.lua` now resets
  movement-start tracking on timeout retry and the later route-settle fixes
  neutralize route-owned input after the inject window. A 2026-05-05 fresh-game
  playtest then showed manual movement/autostep feeling too native and
  timeout-retry heavy, so the default config is back to
  `auto_step_turn_repress_limit=1`. A follow-up log showed the remaining slow
  taps were often early `$003D` subpixel changes from turn-in-place animation;
  `auto_step.lua` now records the frame of the subpixel change and still
  schedules the quick re-press when that change happened very early and no tile
  move followed. Watch future routes for the older false block / route-settle
  drift signatures, but the neutral gap and movement-start release guards
  should keep this safer than the original eager re-press path.
- `objects.lua` previously prewarmed the current interior map grid during
  map-entry refresh to avoid a 1.7-1.9 second first-route spike. As of
  2026-05-05, that prewarm is disabled by default under BizHawk because live
  map transitions showed `objects.check_refresh max_ms=1846`; the first route
  on a new map may pay the lazy grid-build cost instead. FCEUX still prewarms,
  and BizHawk can opt in with `bizhawk_map_entry_prewarm_path_grid=true`.
- Remaining transition-performance note: if the user still hears a post-entry
  audio cutout, compare `objects.check_refresh max_ms` against first-route
  `ROUTE_PLAN_TIMING` / `CMD_TIMING` before moving more work back onto the
  transition frame.
- The latest user retest showed manual overshoot is much better, with remaining
  overshoot mostly when rapid manual movement presses queue up. Auto-walk audio
  is also better, but the user still heard a lag spike near the end of route
  attempts. Fresh logs showed a later auto-walk did reach `(15,19)` adjacent to
  Woman 2 with neutral input and no runtime blockers, while `report_scan_stats`
  showed `objects.check_refresh max_ms=1658`. BizHawk route cleanup now skips
  the immediate post-completion/cancel object refresh by default via
  `bizhawk_route_cleanup_refresh_objects=false`; FCEUX keeps the old refresh.
- Live validation with the cleanup patch loaded completed a short route
  `(0,15)->(1,14)` to Person 4 and a longer route `(1,14)->(9,14)` to Person 2.
  Both ended adjacent to the target with `keys=- joy1=-`, `RUNTIME_BLOCKS none`,
  and `objects.check_refresh max_ms=0`. The first step can still consume one
  timeout retry before movement takes, but it recovered cleanly in both runs.
- User hands-on retest after the cleanup patch confirmed auto-walk is reaching
  intended targets and the lag feels under control.
- The name-entry double-character issue likely comes from a held A/button press
  being accepted on multiple frames by the name grid. `main.lua` now suppresses
  repeated A frames while the name-entry grid is visible, allowing the first
  frame through and forcing A false until release. A new `report_title_state`
  debug command logs title/name-entry cursor RAM, selected tile byte/character,
  controller state, and decoded title rows for future repros.
- BizHawk launchers now support quick slots:
  `./launch_dw.sh --state-slot 1 --no-wait` and
  `./launch_bizhawk.sh --state-slot 1 --no-wait`.

## Recommended Next Work

Best next step:
- Rerun the full Brecconary parked-NPC object survey from `(15,15)` as the next
  confidence check. The narrow exit target now succeeds cleanly under the new
  timing-suspect handling; a full survey will show whether the remaining
  `Guard 2` / `Old Man 1` state issues are gone or need a separate route-settle
  pass.
- Do not promote new Brecconary map blockers from this run. If `(15,17).west`
  or `(9,15).west` recurs during normal play, verify with
  `probe_edge_verify` first; current evidence remains noisy/recovered.
- B1 can then resume as the next dungeon/map stress target. Do not promote
  `(6,3)` west from route-only evidence; its latest verifier was mixed. If B1
  routes get meaningfully stuck again, use fresh `probe_edge_verify` consensus
  before changing permanent map data.

Suggested live check:
- Use `./launch_dw.sh` for BizHawk by default. Use
  `./launch_dw.sh --emulator fceux`, `./launch_fceux.sh`, or
  `launch_fceux.ps1` only when checking the fallback path.
- The old door/stairs verification is now passed manually. Re-run
  `report_door_state` / `inspect_tile:4,7` only if the door regression returns.
- Use the saved post-dialogue state for quick repro loops.
- For the current quick-slot town repro, use
  `./launch_dw.sh --state-slot 1 --no-wait`, wait until `current_object` shows
  town objects, then run `reset_scan_stats`, one `pathfind` or `auto_walk`, and
  `report_scan_stats`.
- Reload the Lua script before judging the new route-turn, route-manager,
  pathfinder, map-reader, or object-refresh patches. A config-only
  `reload_config` is not enough for `auto_step.lua`, `route_manager.lua`,
  `pathfinder.lua`, `map_reader.lua`, `objects.lua`, or `main.lua` changes.
- Use `reset_scan_stats`, play for 10-20 seconds, then `report_scan_stats` if
  lag returns.
- If audio stutters under load, use the cleanest repro available and capture
  `reset_scan_stats` / `report_scan_stats` around only that action. Also check
  fresh `CMD_TIMING` lines before assuming steady-frame-loop lag.
- If route/path command glitches remain, check `CMD_TIMING` lines first, then
  `ROUTE_PLAN_TIMING` lines. For the known Brecconary-style repros, compare
  the old timings after a Lua reload: 1978 ms for a 2-step `npc_15` route,
  1836/1852 ms for 13-step `npc_4` routes, 1238 ms for a 10-step auto-walk,
  and 1422/1514 ms for show-path previews. Also watch for absence/presence of
  `route_drift_off_path`, especially the prior drift points `(4,14)->(5,14)`,
  `(1,15)->(2,15)`, and `(7,16)->(8,16)` during route settle. Use
  `reset_scan_stats`/`report_scan_stats` around exactly one command if timings
  still point away from route planning.
- If map `0x05` shows a fresh `(4,4)` to `(4,5)` route block, reproduce it with
  a controlled `probe_edge:DOWN` before patching anything. The latest probe
  moved successfully after one queued-route block, so the seam is currently
  noisy rather than a confirmed directional blocker.
- If audio cuts out while using debug commands on map `0x05`, check
  `report_path_state`, `inspect_move`, explicit `pathfind_adjacent`, and
  `probe_edge` `CMD_TIMING` lines. The latest run showed second-scale debug
  command hitches even while focused auto-walk execution stayed cheap.
- If no `CMD_TIMING`/`ROUTE_PLAN_TIMING` appears but audio still cuts out,
  inspect `objects.check_refresh max_ms` in `report_scan_stats`; that is now
  the most suspicious remaining script-side spike.
- If random background-window audio freezes remain without fresh
  `CMD_TIMING`/scan-profile spikes, investigate BizHawk/Windows focus or
  priority behavior separately from Lua script performance.
- Keep the current BizHawk audio baseline unless it causes a new problem:
  `SoundBufferSizeMs=200`, `SoundThrottle=true`, `FrameSkip=0`, and
  `Rewind.Enabled=false`. Patch these only while EmuHawk is closed.

Fallback decision:
- Keep FCEUX as an explicit fallback for now, but new gameplay/accessibility
  work should assume BizHawk first.

## Gameplay Direction

Once emulator stability is settled, return to real playtesting:
- Screen reader narration during normal play
- Object navigation usability
- Combat/menu/item/shop/chest/stair workflows
- Route reliability during actual gameplay rather than survey-only loops
- Small professional cleanup as work proceeds

## Active Project Memory Files

Use this hierarchy:
- `AGENTS.md`: project rules, priorities, command model, and accessibility preferences
- `PROJECT_MEMORY.md`: durable architecture facts and long-lived lessons
- `PLAYTESTING.md`: gameplay issue queue and player-facing polish notes
- `session_handoff.md`: this concise active resume
- `handoff_archive/`: historical evidence only

Do not rely on assistant-private memory as the only record of current project state.
