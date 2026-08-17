# Session Handoff - Active Resume

Updated: 2026-08-17

## Release Installation Handoff

- Development-launcher correction (`2026-08-03`): the local default
  `D:\emulation\fceux\bin\qfceux.exe` crashed three consecutive launches with
  native exception `0xc0000005` at `qfceux+0x21eeb5`, two seconds after process
  start. The same developer launcher, ROM, and `main.lua` passed with the
  verified patched runtime under `.tools\fceux-release-runtime-verified`:
  qfceux remained responsive, the frame loop advanced, the exact launcher probe
  was consumed at frame 60, and JAWS spoke the title. `launch_dw.ps1` and
  `launch_dw.sh` now prefer that runtime when both its executable and
  `FCEUX-ACCESSIBILITY-BUILD.txt` marker exist; explicit path/environment
  overrides remain authoritative.
- Explorer-launch hotfix (`2026-07-31`): the published `0.1.0-alpha` package
  exposed a native batch-to-PowerShell quoting bug when the user double-clicked
  `Install Dragon Warrior.cmd` from
  `C:\tmp1\Dragon Warrior Accessibility 0.1.0-alpha`. Both root wrappers passed
  `-PackageRoot "%~dp0"`; because `%~dp0` ends in a backslash, Windows could
  deliver the closing quote as a literal character, and `GetFullPath` failed
  with `Illegal characters in path.` Install and Play now pass `%~dp0.` so the
  quote is unambiguous and PowerShell normalizes the final `\.`. New tests run
  both actual `.cmd` wrappers through `cmd.exe` from a package path containing
  spaces. The focused installer/launcher/package suite passes 31 tests. Two
  PowerShell 7 rebuilds are byte-identical, and the real root installer passed
  through `cmd.exe` after extraction under `C:\tmp1`: exit 0, supported ROM
  hash preserved, and no illegal-path error. The user then manually extracted
  and installed the candidate under `C:\tmp2`; package logs confirm the
  supported ROM, player validation, JAWS `READY`, title narration, and no script
  error. PR #9 merged as `133d65c`. The `v0.1.0-alpha` tag and release target
  now point to that merge, and the public player ZIP, checksum, and hotfix notes
  are updated. The corresponding-source asset is unchanged.
- Release licensing and source packaging are now implemented. Root `LICENSE`
  is MIT under Bill Freeman's name, `LICENSES.md` defines its scope, and the
  player builder rejects placeholder licenses or source notices. The package
  includes the real FCEUX, Qt, SDL2, libarchive, Lua, NVDA Controller Client,
  Python, Python-package, ANGLE, and Mesa llvmpipe notices. The matching
  deterministic corresponding-source ZIP contains the patched tracked FCEUX
  tree plus pinned Qt and NVDA sources. Reproducibility is verified by building
  twice and comparing hashes. Keep that ZIP beside the player ZIP for every
  published release; record its final hash in external release metadata rather
  than inside the source archive itself.
- The release runtime no longer carries eight unused FFmpeg DLLs. The first
  licensed player rebuild reduced the ZIP from 106,057,083 to 47,777,459 bytes,
  a reduction of 58,279,624 bytes. Qt's ANGLE files and `opengl32sw.dll` remain
  intentionally for graphics compatibility and now have matching notices.
  Speech packaging now installs only the official pinned 64-bit NVDA
  Controller Client DLL; JAWS uses its installed COM API, and SAPI5 remains the
  fallback. NVDA wins if NVDA and JAWS are unexpectedly active together.
  Separate final packaged NVDA and JAWS tests are complete; simultaneous-reader
  behavior was intentionally not tested. The final player package contains no
  ROM/save data or FFmpeg DLLs, one screen-reader DLL, complete notices, and no
  placeholder license text. The full local smoke suite, release unit tests, and
  `git diff --check` pass. Two final PowerShell 7 builds are byte-identical:
  516 payload entries, 47,471,642 ZIP bytes, and SHA-256
  `C3877D93EE8A66FE3C04563FB8CB7A146F07795B5D653FB719330112A1D240B7`.
- `0.1.0-alpha` clean-package acceptance completed on `2026-07-31`. JAWS and
  NVDA were tested separately from fresh extractions with no other reader or
  qfceux process active. Both installs verified the supported ROM, selected the
  expected speech backend, reached `READY`, narrated startup, and passed hero
  creation, dialogue, keyboard input, controller input, object navigation,
  autowalk, FCEUX menu pause/resume, private battery-save creation, exit,
  relaunch, Adventure Log discovery, and hero recall. JAWS restored slot 1;
  NVDA restored slot 2. The first JAWS teleport temporarily stopped ordinary
  controls until Start was pressed; later teleport actions worked. The shipped
  README and keyboard guide now describe Start, script reload, and closing
  without saving before relaunch. Keep the underlying teleport/input seam as a
  post-alpha follow-up.
- A clean rebuilt player package now launches and repeat-launches end to end
  from the non-ASCII extraction path
  `C:\tmp\DWA Rebuilt 20260731 – naïve тест 日本語`. The untouched rebuilt ZIP
  contained zero ROMs, setup copied the supported 81,936-byte US Rev 1 ROM with
  SHA-256 `676B89D76CF9E83EED76C0A67F81DA906916F0BCE321CF3A9A39AC78BC9C0845`,
  and first/repeat launch produced responsive qfceux PIDs 38776 then 27476.
  Both runs selected `NVDA reason=auto`, wrote `READY`, narrated the title, and
  retained ASCII Lua aliases in both private config keys; the final package
  keyboard heartbeat advanced from 102 to 105. Using the same corrected source
  immediately before the clean rebuild, the user manually confirmed object
  navigation, Enter opening the title menu, and `F` opening New Quest on first
  launch, then passed a quick manual key test after repeat launch. This proves a
  non-ASCII extraction folder, not a non-ASCII Windows username.
- Root cause of the silent earlier launches was `-bginput 0`. That is a
  Windows-native FCEUX option, but Qt `qfceux.exe` does not register it;
  argument parsing returned an error and silently skipped ROM loading. All Qt
  launch branches now omit it, and use split `--loadlua PATH` syntax where CLI
  Lua loading is requested.
- Three additional package-path/restart bugs are fixed. `Start-Process` now
  embeds quotes around the keyboard-bridge script and output paths, so an
  extracted folder containing spaces does not truncate them. The launcher also
  refreshes `SDL.LuaScript` and `SDL.LastLoadLua` only after an old FCEUX has
  fully exited, preventing its shutdown save from clearing the next launch's
  autoload path. For non-ASCII paths, player-facing logs keep the original path
  while FCEUX receives Windows 8.3 aliases for its executable, ROM, Lua, and
  private config directory; rooted Lua aliases are preserved instead of being
  expanded back to Unicode by Windows PowerShell 5.1. Fourteen focused launcher
  tests cover these regressions.
- Stock Qt FCEUX loads a configured Lua script before its emulator worker
  starts, so a frame-advancing script deadlocks startup. The release workflow
  carries `release\fceux-v2.6.6-deferred-startup-lua.patch`, which defers the
  configured script until the first completed emulation frame. The
  reproducible builder `release\build_fceux_runtime.ps1` pins upstream commit
  `34eb7601c415b81901fd02afbd5cfdc84b5047ac` and emits a required build marker.
  The fresh verified executable SHA-256 is
  `AB8C668B6DFA87352B3911312ACFBE5BB928E36B49CB597AACD8685FDA75EEE1`.
- The release-ready keyboard
  reference now lives at `release\Keyboard Commands.txt`; four focused tests
  keep its 26 accessibility bindings aligned with `dw_access.ini` and verify
  that developer dump shortcuts stay out of the player guide. PR #7 added the
  final `README.md` at commit `82ffbad`; `codex/game-jam-release` adds verified
  release corrections for unsupported ROM opt-in, speech backends, teleport
  save-state risk, JoyToKey scope, keyboard-guide discovery, and stock FCEUX
  startup limits. Licensing, third-party
  notices, corresponding source, runtime pruning, and strict packaging checks
  are complete. The jam version is `0.1.0-alpha`; the final NVDA, JAWS,
  gameplay/save/relaunch matrix passes, and the player was rebuilt with the
  documented teleport recovery. Publish the corresponding-source ZIP beside
  the player ZIP and record both hashes in release metadata. A non-ASCII
  Windows username remains a future test.

## Immediate FCEUX Handoff

- Northern Cave-to-Tantegel connected return is implemented and fully live-
  verified. Selecting Tantegel near World Map `(81,1)` composes
  `kol_rain_shrine_staging -> tantegel_kol`; the derived shrine-return copy
  stops outside Kol at west doorstep `(103,10)`. Initial validation found two
  legacy reverse-route ordering defects. Normal movement plus a same-origin
  raw hold confirmed `(80,2)->DOWN` blocked, while west to `(78,2)` then south
  to `(78,3)` passed. A later continuous segment from `(76,5)` skipped the
  adjacent radius-one `(75,5)` pin and tried the wrong eastern descent. The two
  affected return waypoints now force horizontal-first travel before descending.
  On the uninterrupted acceptance run, both corrected turns passed, frame
  `6405` handed off outside Kol without a map change, and frame `13317` entered
  Tantegel Castle map `0x04`. Final audit at frame `16140` confirmed Castle
  `(11,29)`, route/path nil, and zero runtime blockers. No timing retry,
  blocked, canceled, drift, battle, runtime-block, or Kol-entry event occurred.
  Focused tests pass `223/223` overworld routes and `123/123` route manager;
  Lua syntax, `git diff --check`, all 33 host-runnable Lua suites, and all 68
  Python tests pass. The user's continuous-autowalk config remains local and
  unstaged.
- Rimuldar-to-Tantegel connected return is fully live-verified. Selecting
  Tantegel at World Map `(102,72)` composes `swamp_cave_south ->
  kol_swamp_cave_staging -> tantegel_kol`, preserves the castle destination
  during manual cave traversal, and bypasses Kol at west doorstep `(103,10)`.
  The first loaded run exposed that `kol_swamp_cave` still crossed the known
  permanent `(96,28)->UP` block even though the main Kol route already avoided
  it; queued movement and a clean same-origin raw hold both failed with no NPC
  or runtime blocker. The direct return and its derived non-entry staging copy
  now use the proven `(96,32) -> (98,32) -> (98,26) -> (96,21)` detour. On the
  uninterrupted acceptance run, frame `40185` handed off inside Swamp Cave,
  frame `45469` handed off outside Kol without a map change, and frame `52381`
  entered Tantegel Castle. A lag-related cave-exit stall at `(104,44)->UP`
  emitted `event=blocked` at frame `42119`, then the same edge succeeded on the
  next activation at frame `42973`; it is timing evidence, not geometry. One
  cave-interior retry also recovered. Later keyboard-bridge heartbeat lease
  expirations slowed the emulator but caused no drift or cancellation. Final
  audit at frame `52860` confirmed Castle `(11,29)`, route/path nil, and zero
  runtime blockers. Focused tests pass `216/216` overworld routes and `123/123`
  route manager; Lua syntax, `git diff --check`, all 33 host-runnable Lua
  suites, and all 68 Python tests pass. The user's continuous-autowalk config
  change remains local and unstaged.
- Mountain Cave-to-Tantegel connected return is implemented and live-verified.
  Selecting Tantegel from World Map `(29,57)` composes
  `mountain_cave_return -> kol_return_staging -> tantegel_kol`. The first leg
  exactly reverses the established cave spur to Western desert east road
  `(18,64)`; frame `6002` handed off there without injecting movement. Frame
  `16786` handed off outside Kol at west doorstep `(103,10)` without entering
  town, and frame `23698` entered Tantegel Castle map `0x04`. Final audit at
  frame `24420` confirmed `(11,29)`, route/path nil, and zero runtime blockers.
  The initial `(29,57)->LEFT` step used both configured timing retries and then
  succeeded; no later retry and no blocked, failed, canceled, drift, battle, or
  runtime-block event occurred. Focused tests pass `211/211` overworld routes
  and `123/123` route manager; Lua syntax, `git diff --check`, all 33
  host-runnable Lua suites, and all 68 Python tests pass. The user's
  continuous-autowalk config change remains local and unstaged.
- Hauksness-to-Tantegel selection is corrected and live-verified. Selecting
  Tantegel from World Map `(25,89)` now uses a Hauksness-only selection anchor
  on `tantegel_kol`, while the unchanged distance guard stages the trip through
  `kol_return_staging`; Mountain Cave and other origins retain their prior
  route choice. The loaded run started `kol_return_staging` at frame `3720`,
  handed off outside Kol at west doorstep `(103,10)` at frame `18906` without
  entering town, and arrived in Tantegel Castle map `0x04` at frame `25818`.
  Final audit at frame `26580` confirmed `(11,29)`, route/path nil, and zero
  runtime blockers. No blocked, failed, canceled, drift, battle, runtime-block,
  or nonzero-timeout event occurred. Focused route tests pass `209/209`,
  route-manager tests pass `123/123`, Lua syntax and `git diff --check` pass,
  and the full gate passes all 33 host-runnable Lua suites plus 68 Python tests.
  The user's continuous-autowalk config change remains local and unstaged.
- The connected reverse backbone from Eastern Great Swamp Search Area to
  Tantegel is implemented and live-verified. Selecting Tantegel at World Map
  `(89,112)` composes `cantlin_return_staging -> hauksness_return_staging ->
  kol_return_staging -> tantegel_kol`. The three hidden legs are derived from
  the existing live-validated return routes and stop outside their intermediate
  destinations: Cantlin northwest turn `(68,91)`, Hauksness west doorstep
  `(24,89)`, and Kol west doorstep `(103,10)`. The loaded continuous run handed
  off at frames `8730`, `13898`, and `28570` without entering Cantlin,
  Hauksness, or Kol, then entered Tantegel Castle map `0x04` at frame `35482`.
  No blocked, failed, canceled, drift, battle, runtime-block, or nonzero-timeout
  event occurred. Final audit at frame `36000` confirmed Tantegel Castle
  `(11,29)`, route/path nil, and zero runtime blockers. Focused route tests pass
  `206/206`, route-manager tests pass `123/123`, and the full gate passes all 33
  host-runnable Lua suites plus 68 Python tests. The user's continuous-autowalk
  config change remains local and unstaged.
- Connected Eastern Great Swamp routing and Cantlin pass-through polish are
  live-verified. Selecting the search area from World Map `(43,43)` composes
  `kol_staging -> hauksness_staging -> cantlin_staging ->
  great_swamp_cantlin`. Kol and Hauksness remain exterior handoffs. Hidden
  `cantlin_staging` derives the validated Hauksness-to-Cantlin approach only
  through northwest turn `(68,91)`, then hands directly to the Great Swamp
  route's south notch `(68,92)` instead of entering Cantlin map `0x0A`.
  Direct Cantlin travel still enters town, and accidental town entry remains a
  fallback handoff. The initial loaded run completed the full connected route
  to safe search-area pin `(89,112)` with no blocker, drift, timeout retry,
  cancellation, or exhausted retry. After the bypass patch, a focused loaded
  run from Hauksness west doorstep `(24,89)` traversed the normal route,
  handed off at `(68,91)`, and continued south without a map change or route
  anomaly. Final tag `CANTLIN_BYPASS_FINAL_20260816` confirmed World Map
  `(57,104)`, route/path nil, and zero NPC/runtime blockers after the deliberate
  stop. Focused route tests pass `203/203`; Lua syntax, `git diff --check`, all
  33 host-runnable Lua suites, and all 68 Python tests pass.
- Connected Rimuldar routing is fully live-verified. Selecting Rimuldar from
  World Map `(43,43)` composed `kol_staging -> swamp_cave -> rimuldar` instead
  of synthesizing the prior unvalidated 51-step shortcut. The loaded route
  handed off outside Kol at west doorstep `(103,10)` without entering town,
  then entered Swamp Cave map `0x15` at north interior `(0,0)` and activated
  the Rimuldar leg without injecting movement. The user autowalked a perfect
  cave route to south stair `(0,29)` and exited at World Map `(104,49)`, where
  the preserved route resumed through `(93,49)`. It passed the established
  north-wall corridor, including `(99,69)->south`, and entered Rimuldar map
  `0x0B` at `(29,14)`. Final tag `RIMULDAR_CONNECTED_ARRIVAL_20260815`
  confirmed route none, path nil, and zero runtime blockers. No blocker,
  cancellation, timing-retry, or exhausted-retry event occurred. Direct starts
  at `(104,49)` remain unchanged. Focused route tests pass `199/199`; the full
  gate passes all 33 host-runnable Lua suites plus 68 Python tests. This slice
  is accepted. The user's complete rerun also reached Rimuldar cleanly. It
  exposed one stale south-exit warning about live validation; that player-facing
  speech now says, `Poison swamp ahead after leaving the cave. Watch HP while
  crossing.` A regression covers both the useful hazard warning and removal of
  the developer language; the focused and full gates remain green.
- Garinham and Erdrick's Cave Brecconary-entry polish is live-verified. Their
  outbound routes from Tantegel now replace
  intermediate town entrance `(48,41)` with the already live-proven west
  bypass `(47,41)`, radius 0, then turn north to the unchanged Bridge south
  bend `(44,38)`. The reverse `tantegel` and `tantegel_kol` safety routes were
  audited and already skip Brecconary; the direct `brecconary` route still
  ends at `(48,41)` and enters map `0x08`. New regressions failed against both
  old outbound waypoints before the source patch. Focused route tests now pass
  `194/194`; the full gate passes all 33 host-runnable Lua suites plus 68
  Python tests. Separate clean loaded runs from World Map `(43,43)` completed
  `(43,43) -> (47,41)`, turned north through `(44,38)`, and never entered map
  `0x08`. Garinham entered map `0x09` at `(0,14)`; Erdrick's Cave entered map
  `0x1C` at `(0,0)`. Final tags `GARINHAM_BYPASS_ARRIVAL_20260815` and
  `ERDRICK_BYPASS_ARRIVAL_20260815` each confirmed route/path nil and zero
  runtime blockers. Neither run logged a blocker, cancellation, or exhausted
  retry. This slice is accepted.
- Kol/Hauksness intermediate-town avoidance is live-verified. The direct `kol`
  route replaces Brecconary entrance `(48,41)` with the live-proven west
  doorstep `(47,41)`, then goes north before reconnecting at Bridge south bend
  `(44,38)`. All routes that use Kol only as a hub now stage through hidden
  `kol_staging`, copied from the direct route but ending at Kol west doorstep
  `(103,10)`. Reaching that overworld tile hands off without entering Kol
  `(104,10)`; direct Kol selection still enters town, and map `0x07` remains a
  fallback handoff if the town is entered accidentally. This covers Northern
  Cave, Swamp Cave, Hauksness/Cantlin, and Mountain Cave staging. Regressions
  failed first on old `(48,41)` / `kol` behavior, then focused tests passed
  `191/191`; Lua syntax, `git diff --check`, and the native Windows broad gate
  of all 33 host-runnable Lua suites plus 68 Python tests pass. After the
  unexpected system restart, fresh tag `KOL_STAGING_RESTART_BASELINE_20260815`
  confirmed a clean World Map `(43,43)` baseline. The continuous Hauksness run
  used `(47,41)` without entering Brecconary map `0x08`, emitted
  `event=handoff route=hauksness ... from_route=kol_staging` at `(103,10)`, and
  turned west without entering Kol map `0x07`. It completed every remaining
  waypoint and entered Hauksness map `0x03` from `(24,89)`. Final tag
  `KOL_HAUKSNESS_POLISH_FINAL_20260815` confirmed `(0,10)`, route none, path
  nil, and zero NPC/runtime blockers. The user's immediate Cantlin follow-up
  then proved the remaining Hauksness entry: frame `23131` queued the final
  `(24,89)->RIGHT` step, frame `23159` entered map `0x03`, and only then handed
  off to `cantlin_hauksness`. Fresh tag
  `CANTLIN_HAUKSNESS_ENTRY_VERIFY_20260815` confirmed Hauksness `(0,10)`, active
  Cantlin guidance, path nil, and zero runtime blockers. The source fix adds
  hidden `hauksness_staging`, derived from the established route through
  exterior `(24,89)`, and uses it only for the Cantlin intermediate leg.
  Handoff there skips the already-reached doorstep and targets `(22,89)` west;
  direct Hauksness travel still enters the ruins, and map `0x03` remains a
  fallback handoff. Focused tests pass `191/191`, the full gate passes all 33
  Lua suites plus 68 Python tests, and `git diff --check` passes. Loaded
  validation reached exterior `(24,89)` at frame `15739`, handed off from
  `hauksness_staging` without entering map `0x03`, and immediately queued two
  LEFT steps toward `(22,89)`. It reached `(22,89)` at frame `15836` and
  continued normally on `cantlin_hauksness`. Frame `21307` entered Cantlin map
  `0x0A`; fresh tag `CANTLIN_TOWN_BYPASS_FINAL_20260815` confirmed `(15,0)`,
  route none, path nil, and no runtime blockers. The follow-up is
  live-accepted.
- The eighth connected itinerary is fully live-verified for `Tantegel -> Kol ->
  Western desert east road -> Mountain Cave`. Mountain Cave now stages through an internal
  `mountain_cave_connector` whose waypoints are copied at load time from the
  established Hauksness route only through shared pin `(18,64)`. The connector
  then hands off without movement to the existing five-segment Mountain Cave
  spur ending at World Map `(29,57)` / map `0x16` `(0,7)`. Far Tantegel starts
  compose `kol -> mountain_cave_connector -> mountain_cave`; local starts at
  `(18,64)` and `(16,61)` remain direct. Travel-object focus, guidance refresh,
  both handoffs, cancellation, prefix identity, and source-route immutability
  are covered. A clean loaded continuous pass from World Map `(104,10)` crossed
  the shared Hauksness prefix, emitted the connector-to-Mountain-Cave handoff at
  `(18,64)`, continued without another activation, and entered Mountain Cave
  map `0x16` at `(0,7)`. Fresh tag `MCAVE_CONNECTED_ARRIVAL_20260815` reported
  route none, path target nil, and zero NPC/runtime blockers. Focused tests pass
  `189/189`; the native Windows broad gate passes all 33 host-runnable Lua
  suites plus 68 Python tests. The user then manually repeated and accepted the
  route; fresh tag `MCAVE_MANUAL_ACCEPTANCE_20260815` independently confirmed
  Mountain Cave `(0,7)`, route/path nil, and zero NPC/runtime blockers. The
  user's full Tantegel-origin pass then started `kol` with
  `staged_from=mountain_cave`, entered and exited Brecconary, entered Kol and
  handed off to `mountain_cave_connector`, handed off again at `(18,64)`, and
  entered Mountain Cave map `0x16` at `(0,7)`. One timeout retry at Tantegel
  `(43,43) -> UP` recovered; no blocker, cancellation, or retry exhaustion
  occurred. The later fresh audit at World Map `(43,43)` reported route/path
  nil and zero blockers. This slice is accepted; early Brecconary/Kol entry is
  separate route-polish work.
- The seventh connected itinerary is live-verified for `Tantegel -> Kol ->
  Hauksness -> Cantlin`. Cantlin's Travel object and new plain `cantlin` alias
  now start the existing `kol` route from World Map `(43,43)`, retain Cantlin
  as the final destination, hand off to `hauksness` at Kol, then hand off to
  `cantlin_hauksness` at Hauksness. The new ordered continuation list preserves
  existing two-leg staging behavior, waits for another auto-walk activation at
  each handoff, survives Travel-guidance refresh, and clears fully on cancel.
  Direct starts at Hauksness `(25,89)` and the Eastern Great Swamp Search Area
  `(89,112)` remain unchanged. Loaded acceptance from `(43,43)` completed the
  Kol leg, handed off to `hauksness`, completed that corridor, handed off to
  `cantlin_hauksness`, and entered Cantlin at `(15,0)`. Both handoffs paused for
  manual town exits as designed. There were no blocker, cancellation, or
  retry-exhaustion events; final tag `CANTLIN_CONNECTED_ARRIVAL_20260815`
  reported route none, path target nil, and zero runtime blockers. Focused
  route tests pass `184/184`; the native Windows broad gate passes all 33
  host-runnable Lua suites plus 68 Python tests. Early Brecconary/Kol town
  entries remain known separate polish and are not a failure of this slice.
- The sixth connected itinerary is live-verified for `Tantegel -> Kol ->
  Hauksness`. A far Hauksness selection at World Map `(43,43)` now starts the
  established `kol` route, retains Hauksness as the final Travel destination,
  and hands off at Kol `(104,10)` to the existing live-validated Hauksness
  corridor. Direct starts already near Kol, Garinham, Cantlin, or the western
  route remain unchanged. The checked-in and generated configs now expose
  `overworld_auto_walk_continuous=false`, preserving waypoint mode as the player
  default while allowing continuous mode as an explicit option. Continuous
  mode queues later route waypoints until arrival
  or interruption, speaks the destination once plus warnings and terminal
  arrival, and leaves battle/menu/dialogue cancellation authoritative. Focused
  tests pass `179/179` overworld routes, `123/123` route manager, and `3/3`
  config tests; the broad gate passes all 33 host-runnable Lua suites plus 68
  Python tests. Loaded travel with continuous mode temporarily enabled from
  `(43,43)` started `kol` with
  `staged_from=hauksness`; the known early route entered Brecconary and one
  initial timing retry recovered automatically. After the manual town exits,
  Kol entry emitted `event=handoff route=hauksness ... from_route=kol`, and one
  continuous activation from `(104,10)` completed the remaining corridor with
  zero timeout, blocker, or cancellation events. It entered Hauksness map
  `0x03` from `(24,89)`. Fresh tag `HAUKSNESS_ARRIVAL_20260814` confirmed
  Ruins of Hauksness `(0,10)`, route none, path nil, and zero NPC/runtime
  blockers. Early-route town entry remains separate polish; this slice is
  closed.
- The connected Magic Temple itinerary is complete and loaded. Selecting Magic
  Temple at Swamp Cave South `(104,49)` starts the established `rimuldar` leg,
  hands off inside Rimuldar `0x0B` `(29,14)` without moving automatically, and
  preserves `magic_temple` after the player exits to World Map `(102,72)`. The
  second leg completed all 22 waypoints and arrived at Magic Temple
  `(108,109)`. Fresh tag `MAGIC_TEMPLE_CONNECTED_ARRIVAL_20260814` confirmed
  route none, path nil, and zero NPC/runtime blockers. Manual acceptance then
  proved `(93,52)->DOWN` is engine-blocked. The outbound route now turns west
  through `(92,52)`, `(86,52)`, `(86,54)`, `(83,54)`, `(83,56)`, `(85,56)`,
  `(85,58)`, and `(88,58)`. After reload, every replacement waypoint and the
  original 13-step continuation to `(88,71)` completed without a blocked,
  canceled, seam-retry, or runtime-block event. Fresh tag
  `MAGIC_TEMPLE_RIMULDAR_DETOUR_LOADED_20260814` confirmed World Map `(88,71)`,
  path nil, zero blockers, and the next Rimuldar waypoint active. Temple edges
  `(103,113)->RIGHT` and `(104,113)->DOWN` were
  timing-only: the first passed a same-origin raw hold and the second completed
  on retry. No blocker was added. Focused route tests pass `175/175`; the broad
  gate passes all 33 host-runnable Lua suites plus 68 Python tests. The user's
  final manual pass completed at `(108,109)`. Visible stalls at
  `(97,71)->UP`, `(107,71)->DOWN`, `(103,113)->RIGHT`, and
  `(104,113)->DOWN` each completed on the next route activation. Fresh tag
  `MAGIC_TEMPLE_MANUAL_ACCEPTED_20260814` confirmed route none, path nil, and
  zero NPC/runtime blockers. This slice is ready to publish.
- The connected Charlock itinerary is complete and loaded. Selecting Charlock
  outside Rimuldar at `(102,72)` stages through `swamp_cave_south`, enters
  Swamp Cave map `0x15` at `(0,29)`, waits for the player's STAIRS exit, and
  preserves `charlock_castle` for the continuation from World Map `(104,49)`.
  The full live pass completed every bridge, inlet, island, and castle waypoint
  and entered Charlock map `0x02` at `(10,19)`. Fresh tag
  `CHARLOCK_FULL_CONNECTED_ARRIVAL_20260813` confirmed route none, path nil,
  and no NPC/runtime blockers. Auto-step stalls at `(99,69)->LEFT` and
  `(51,64)->RIGHT` passed unchanged-origin raw holds; the `(90,72)->UP` carry
  recovered normally. No blocker was added. Focused tests pass `170/170`; the
  broad gate passes all 33 host-runnable Lua suites plus 68 Python tests. This
  connected-route slice is closed; retain the three non-destructive artifacts
  for an optional route-polish pass. The user's final manual acceptance also
  completed the entire itinerary with several bounded retries but no blocked
  or canceled route events. Fresh tag `CHARLOCK_MANUAL_ACCEPTED_20260813`
  confirmed Charlock map `0x02` `(10,19)`, route/path nil, and zero
  NPC/runtime blockers.
- The connected Rainbow Bridge itinerary is complete and loaded. Selecting
  Rainbow Bridge from the Rimuldar side stages through `swamp_cave_south`,
  names the cave as the current leg and the bridge as the final destination,
  and hands off at Swamp Cave map `0x15` `(0,29)` without starting movement.
  Live route fallout corrected the direct north carry from `(107,72)` through
  `(107,70)`, reset four diagonal turns, and changed the north-wall bypass to
  LEFT then DOWN because both route execution and a same-origin raw probe
  proved `(98,70)->DOWN` blocked while `(97,70)->DOWN` passed. After reload,
  the full route completed from exact `(98,70)`, entered/exited the cave,
  traversed the bridge inlet detour, and arrived at `(65,49)`. Final tag
  `RAINBOW_CONNECTED_COMPLETE_20260813` confirmed route/path nil and no runtime
  blockers. Manual acceptance later exposed slow passable movement from
  `(99,68)` DOWN to `(99,69)`. The loaded sustained-hold fix completed that
  edge in 33 frames with zero retries, advanced toward `(98,69)`, and left no
  path or runtime blockers. Focused route tests pass `169/169`; the native
  Windows broad gate passes all 33 host-runnable Lua suites plus 68 Python
  tests. The final user round trip reached `(65,49)` and returned through Swamp
  Cave to World Map `(104,49)`. Two timing stalls succeeded on retry, while
  two off-path carries recovered without blocking completion; keep these as
  optional route-polish work. Fresh tag `RAINBOW_MANUAL_COMPLETE_20260813`
  confirmed route none, path nil, and no NPC or runtime blockers. No blocker
  was promoted.
- A complete blind-player game run reached the original `The End` screen.
  King Lorik's ending dialogue and the full staff credits were automatically
  narrated. Fresh tag `GAME_END_TERMINAL` confirmed level byte `255`, the
  expected non-gameplay/title classification, stale final Tantegel coordinates
  `(10,8)`, no active menu/dialogue or mod input guard, and a healthy speech
  bridge. An A-button state was observed without leaving the ending screen, so
  this is the intended ROM terminal loop, not a mod control lock. Future
  endgame polish may suppress the premature `Title screen.` announcement and
  two decorative-glyph fragments after the real copyright credits; neither
  blocked completion or the credits narration.
- The final Dragonlord victory exposed a high-priority speech delivery bug.
  The screen and filtered dialogue cache contained `Thou hast done well in
  defeating the Dragonlord.`, and `speech_bridge.log` recorded the exact line,
  but it was sent as ordinary queued speech after a long combat sequence and
  JAWS announced nothing before the next interrupt. `battle.lua` now identifies
  only the terminal Dragonlord victory, and both lower-dialogue paths in
  `main.lua` send that line with interrupt priority; ordinary victories remain
  queued. The regression failed first, then the complete battle (`44/44`) and
  text (`74/74`) suites and Lua syntax passed. After manual reload on the final
  victory page, the bridge logged the line as `interrupt:` and JAWS spoke it.
  All subsequent Ball of Light and restoration dialogue was spoken, followed
  by the intended move to World Map `(48,48)`. A fresh loaded probe confirmed
  field state, full HP/MP, no active menu/dialogue/input guard, and a healthy
  JAWS bridge. The final-victory accessibility path is closed end to end.
- Charlock's remaining B1/B2 stair network is complete and loaded. The four
  live-proven pairs are B1 `(14,9)` to B2 `(8,9)`, B1 `(19,7)` to B2
  `(9,8)`, B1 `(2,14)` to B2 `(0,1)`, and B1 `(2,4)` to B2 `(0,0)`.
  Direct movement from `(0,1)` north onto `(0,0)` worked, so the guide-based
  `(1,0)` detour was unnecessary and was not modeled. `objects.lua` exposes
  all eight endpoints, while `map_reader.lua` adds only the two live-proven B2
  boundary passthroughs `(0,0)` and `(0,1)`. Regressions failed before source
  changes and then passed `113/113` object tests, `81/81` map-reader tests, Lua
  syntax, and `git diff --check`. After restart/reload, all four B1 and all four
  B2 Travel names resolved uniquely. STAIRS at B1 `(2,4)` entered B2 `(0,0)`;
  both boundary cells loaded with `reason=passthrough`, and the final state at
  B2 `(0,0)` has no runtime/NPC blockers, active path, or input guard. This
  closes the visible decoys and remaining B1/B2 optional connector graph.
- The Charlock false inner branch and deliberate B6 loop are live-proven.
  B4 `(8,1)` entered B5 `(4,0)`; hidden top-boundary cells `(5,0)..(7,0)`
  connect to the ordinary 23-step inner corridor ending at descent `(5,5)`.
  That stair entered B6 `(0,0)`, where the complete hidden top row leads east
  to loop stair `(9,0)`. STAIRS there returned to B6 `(0,0)` on the same map.
  Two apparent blocks at `(3,0)->(4,0)` occurred during a confirmed control
  lock and are discarded; after Start recovery the edge and remaining row
  moved cleanly. Source now adds B5 passthroughs `(4,0)..(7,0)` and B6
  passthroughs `(0,0)..(9,0)`. Verification passes `79/79` map-reader and
  `109/109` object tests, Lua syntax, and `git diff --check`. After reloading,
  source-only planning produced exactly `9 east` from B6 `(0,0)`, autowalk
  completed at `(9,0)` with no runtime blockers, and STAIRS returned to B6
  `(0,0)`. The false branch and loaded same-floor loop are complete.
- The Erdrick's Sword branch is complete and live-proven in both directions.
  From B4 `(7,7)`, STAIRS entered B3 `(7,7)`; the unbranched corridor reached
  B3 `(2,2)`, then B2 `(9,1)`. The adjacent B2 link crosses hidden boundary
  cells `(9,0),(8,0)` into B1 `(15,1)`. B1 runs north to `(15,0)`, east across
  `(16,0)..(19,0)`, turns southwest at `(19,2)->(18,2)`, and follows the
  modeled zigzag to stair `(13,7)`. That stair entered the B2 sword room at
  `(4,4)`; the chest at `(5,5)` produced `Thou hast found the Erdrick's Sword.`
  Equipment byte `$00BE` changed to `0xFF`, and Attack rose from `0x73` (115)
  to `0x7F` (127). The full reverse route returned the hero to B4 `(7,7)`.
  Source now adds only the seven cleanly proven boundary passthroughs: B1
  `(15,0)..(19,0)` and B2 `(8,0),(9,0)`. The focused suite passes `79/79`
  map-reader tests, Lua syntax, and `git diff --check`. The loaded forward and
  reverse routes were subsequently validated without runtime blockers.
- Charlock Castle and the complete main dungeon spine are decoded and
  live-proven through Dragonlord. Ground floor `0x02` uses SEARCH at hidden
  stair `(10,1)`; B1 `0x0F` descends at `(8,19)`; B2 `0x10` descends at
  `(3,0)`; B3 `0x11` can route directly from `(7,0)` to descent `(1,6)` without
  using its optional false-return loop;
  B4 `0x12` crosses from `(0,9)` to descent `(2,2)`; B5 `0x13` follows the east,
  south, and west perimeter from `(9,0)` to `(0,0)`; and B6 `0x14` crosses its
  lower component from `(0,6)` to final descent `(9,6)`. Dragonlord's Lair
  `0x06` begins at `(10,29)`, winds around the outer corridor, crosses the four
  live-proven raw-type-0 passages `(28,13)`, `(28,14)`, `(25,16)`, and
  `(25,21)`, and reaches the east-side boss approach `(17,24)`. TALK there
  produced `Welcome, Bill. I am the Dragonlord--King of Kings.`, proving the
  final NPC at `(16,24)`; loaded object browsing now labels him `Dragonlord`.
  Source-only navigation completed the final eight westward steps with no
  runtime blocks. Verification passes `79/79` map-reader and `109/109` object
  tests, Lua syntax, and `git diff --check`. A later loaded component audit
  confirmed B4 `(2,2)`, `(8,1)`, and `(7,7)` share one walking component;
  B5's main and false-inner stair groups are disconnected; and B6's lower main
  route is disconnected from the top-row loop. The main spine again completed
  with no runtime blockers. The reverse stair at lair `(10,29)` then returned
  to B6 `(9,6)`, revealing that Travel navigation lacked the lair-side stair.
  `objects.lua` now exposes `South Stairs Up` at `(10,29)`; all 110 object tests,
  Lua syntax, and `git diff --check` pass. After reload and re-entry, Travel
  reported `South Stairs Up: here (1 of 1)` at `(10,29)`, completing live
  verification. A follow-up audit proved the generic raw-type-5 `Door` at that
  stair false and the real treasure-room door at `(17,12)`: OPEN from east stand
  `(18,12)` facing west consumed one key and wrote opened-door RAM `(17,12)`.
  Source now exposes named `Treasure Room Door` with both interaction stands and
  gates planner access through `(17,12)` on that RAM state. The regressions failed
  on false `door_10_29` and then on missing `door_closed` handling before the
  respective fixes. Loaded inspection then reported `reason=door_open`, and
  ordinary movement crossed the door both ways. All six treasure chests are
  live-reached: `(11,11)` Herb, `(11,12)` 680 gold, `(12,12)` Magic Key,
  `(11,13)` Wings, `(12,13)` Cursed Belt, and `(13,13)` Herb. A fresh six-chest
  raid exposed that successful inventory-delta tracking could still miss the
  final Herb at `(13,13)`. ROM-backed chests now read the game's authoritative
  eight-slot taken-treasure coordinate array at `$601C-$602B`; `GetTreasure`
  writes that array before awarding contents, and it survives Lua reloads while
  retaining the original game's overworld-reset behavior. Hidden SEARCH
  treasures keep the separate fallback cache. After manual reload, fresh marker
  `chest_ram_reload` was consumed on map `0x06` at `(13,13)`, Herbs were `4`,
  and one complete object-list cycle logged all six exact chest coordinates as
  `Chest (opened)`. All `114/114` object tests, the broad repository gate, Lua
  syntax, and `git diff --check` pass. The ordinary safe-return route
  then crossed the opened door and completed from the treasure room to lair
  stair `(10,29)` with zero runtime blockers; two Armored Knights and one Red
  Dragon were combat-only interruptions. Current live checkpoint is lair
  `(10,29)` on `South Stairs Up`; STAIRS should return to B6 `(9,6)`. The
  earlier pre-dialogue save boundary remains available for the eventual boss
  attempt.
- Charlock Castle overworld geometry is live-proven on
  `codex/charlock-rainbow-bridge-route`. From the formed bridge landing
  `(63,49)`, ordinary movement reached the island south road `(56,64)`, west
  rise `(49,57)`, east approach `(51,49)`, and castle coordinate `(48,48)`.
  Entering `(48,48)` changed to Charlock map `0x02` at `(10,19)`; leaving south
  returned to World Map `(48,48)`. `overworld_routes.lua` now defines strict
  `charlock_castle` and exact island-reverse `charlock_return` routes, beginning
  from the safe post-cave doorstep `(103,49)` and sharing the proven Rainbow
  Bridge inlet detour. A follow-up review found that selecting either final
  route from Rimuldar `(102,72)` synthesized a direct northbound segment across
  craggy terrain. Both routes now stage through the established
  `swamp_cave_south` chain unless the player is already on their validated
  corridor. The selected destination remains bound across autowalk refreshes
  and recalculation; `(92,57)` uses the westbound recovery instead of retrying
  its blocked north edge. No blocker was promoted. Focused route tests pass
  `154/154`, and the broad runner now includes this route suite. The first
  loaded return exposed two stateful carry hazards: a
  one-tile stop at `(50,62)` drifted south, and settling at `(61,50)` after an
  eastbound approach trapped all tested exits even though the inbound
  north-to-south arrival had escaped west. Input/OAM diagnostics were clean,
  so neither finding became map data. Source now uses the live southwest
  recovery chain through `(50,63),(52,63),(52,64)` and crosses `(61,50)` only
  as part of a continuous east-then-north turn. The next reload attempt found that
  a nearby Rainbow Bridge object refresh could replace `charlock_return`
  before the new turn ran; source now marks that bridge object compatible and
  the loaded regression logged `active_matches=true`. The route then completed
  `(58,50)->(61,49)`, reached bridge tile `(64,49)`, and continued through
  `(65,49)` to `(67,49)`. Settling at `(67,49)` after an eastbound approach
  made DOWN exhaust both retries even though the outbound south-origin turn is
  live-proven. No blocker was added; source now crosses `(67,49)` continuously
  from `(65,49)` to `(67,50)`. Current state is `(67,49)` with the return route
  active and REPEL expired. Recovery staging and reload at `(65,49)` then
  showed that the route policy correctly chooses the shorter
  `rainbow_bridge_return` alternate there; its duplicate `(67,49)` stop now
  has the same continuous-turn correction. Force-teleport staging then caused
  a temporary control lock; a manual command-menu open/close restored movement,
  so those failures were not promoted. From a naturally reacquired `(65,49)`,
  a raw hold proved the slow eastbound edge and carried to `(67,49)`; DOWN
  reached `(67,50)`. Both return variants now use a 60-frame sustained-hold
  cadence marker on that turn. The loaded return continued through every east
  road checkpoint and entered Swamp Cave `0x15` at `(0,29)`, emitting
  `event=arrived` and clearing route/path state with no runtime blockers.
  After reload, loaded `charlock_castle` then ran from the safe World Map
  doorstep `(103,49)` across the bridge and corrected island chain into
  Charlock map `0x02` at `(10,19)`, emitting `event=arrived` and clearing
  route/path state with no runtime blockers. REPEL expiration caused one
  player-cleared pause without losing route state. Autowalk exhausted cadence
  retries on `(58,55)->LEFT` and `(50,61)->LEFT`, while unchanged-origin raw
  holds moved cleanly to `(57,55)` and `(49,61)`; no blocker was promoted.
  Those two outbound waypoints now use the established 60-frame sustained-hold
  window. These route fixes were subsequently exercised during the complete
  Charlock dungeon pass; the current live state is the pre-Dragonlord
  checkpoint described above.
- FCEUX menu/input isolation and selected-teleport recovery are release-gated
  on the 2026-07-31 launcher baseline. `launch_dw.ps1` installs a valid empty
  native keyboard profile, enables `SDL.PauseOnMainMenuAccess = 1`, and runs a
  modifier/menu/dialog-aware bridge with a fail-closed heartbeat. A controlled
  `Alt+F`, three-Down, Escape pass left Mountain Cave `(0,7)` unchanged with no
  bridge `ACTIVE`/`APPLY` event; ordinary Right/Left/F/D/Enter input then
  produced matching press/clear events. Repeated selected teleports did not
  reproduce the control hard lock, but exposed stale FCEUX `Down` causing a
  false `Shift+Down` attempt when Shift was newly pressed. Teleport hotkeys now
  require a fresh non-modifier trigger edge. The post-reload acceptance chord
  produced only exact teleport, landed on the F1 chest `(13,5)`, released Enter
  after 7 frames, and immediately opened/closed the game command menu with F/D.
  Initial `INPUT_FIX_FINAL` state was neutral at map `0x16` `(13,5)` with
  `buttons=0x00`, no suppression/pending face/state guard, and the chest
  selected. The user's broader Tantegel acceptance then logged 21 successful
  selected teleports across travel targets, services, and NPCs; 25 trigger
  releases completed in 5-16 frames, multiple NPC holds ended when TALK
  dialogue opened, and there were zero release timeouts, OAM-stuck signatures,
  or bridge-lease expirations. Fresh probe
  `TANTEGEL_TELEPORT_VALIDATED_20260731` is neutral on World Map `(43,43)` at
  Tantegel Castle with all guards clear. Verification passes 240 focused Lua
  tests, 11 bridge-policy tests, PowerShell/Lua syntax, and `git diff --check`.
  This checkpoint supersedes the older `(0,7)` current-state sentence in the
  Mountain Cave geometry note.
  During final `0.1.0-alpha` package acceptance, the first selected teleport
  temporarily stopped ordinary controls until Start was pressed; subsequent
  teleport actions completed normally. Treat this as a known alpha recovery
  case and post-release investigation item, not permanent map evidence.
- Mountain Cave travel and both dungeon floors are complete. The bidirectional
  World Map routes connect `Western desert east road` `(18,64)` with cave
  entrance `(29,57)`; F1 entry/exit is `(0,7)`. F1 map `0x16` models its
  live west/top boundary, walls, the `(8,2).north/south` upper-loop barrier,
  and the northeast chest `(13,5)` via passthroughs `(11,0)..(13,0)`. B2 map `0x17` models
  live-proven type-0/type-8 walls, every boundary passthrough, all four chest
  tiles `(1,6)`, `(2,2)`, `(3,2)`, `(10,9)`, and all three stair pairs:
  northwest A `(0,0)<->(0,0)`, central B `(6,5)<->(6,5)`, and southeast C
  `(12,12)<->(12,12)`. A and C are isolated pockets; B reaches the treasure
  area. Two manual return routes and a normal-origin raw probe proved
  `(8,1)->DOWN` into `(8,2)` blocks just like the already modeled south-side
  approach. After adding `(8,2).north`, the final loaded-source return moved
  from chest `(13,5)` to exit `(0,7)` without a reroute or runtime blocker;
  battle interruptions resumed from fresh field probes. The user then manually
  validated the corrected route and reported it clean. Current FCEUX state is
  F1 exit `(0,7)`, field clear, HP `115/115`, MP `75/97`, EXP `20341`, gold
  `21537`, and intact level-18 stats. Focused verification passes 147
  overworld-route, 107 object, and 71 map-reader tests plus Lua syntax and
  `git diff --check`.
- A second manual `rimuldar_magic_temple` return validation completed with
  substantially cleaner timing. The route advanced through all 22 waypoints,
  changed to Rimuldar map `0x0B`, and emitted `event=arrived` at `(29,14)`.
  Seven bounded retry events recovered automatically; there was no drift,
  seam brute-force fallback, timing-retry escalation, temporary blocker, or
  runtime blocker. Six battles occurred, four while a route segment was
  active, and continuation remained safe. Fresh probe
  `TEMPLE_RETURN_VALIDATED_20260728` confirms Rimuldar `(29,14)`, route
  `none`, no active path, and no runtime blocks.
- Magic Temple map `0x0E` interior navigation is now source-clean. Live
  same-origin raw probes promoted the exit stair `(0,4)` as a passthrough and
  confirmed directional walls at `(2,4).east/west`,
  `(2,5).east/south/west`, and `(4,3).west`, `(4,4).west`, `(4,6).west`.
  After reloading navigation modules and clearing all map-0x0E runtime blocks,
  source-only autowalk completed from `(3,6)` to exit `(0,4)` in 5 steps and
  from the exit to the Old Man stand `(3,5)` in 6 steps, facing east. That
  source-only interior pass ended at Magic Temple `(3,5)`, with no active path
  or runtime blocks. Verification passes all 70 map-reader tests, Lua syntax,
  and `git diff --check`.
- Magic Temple travel is now source-pinned and live geometry-validated in both
  directions. The outbound `magic_temple` route reached World Map `(108,109)`;
  `STAIRS` entered map `0x0E` at `(0,4)`. After the sage exchanged the Stones
  of Sunlight and Staff of Rain for the Rainbow Drop while retaining Erdrick's
  Token, `STAIRS` at the same interior tile returned to `(108,109)`. The
  corrected Travel exit is therefore `(0,4)`, not the stale `(4,4)`.
- The reverse `rimuldar_magic_temple` route reached Rimuldar map `0x0B` at
  `(29,14)` and emitted `event=arrived` at index 22. That route pass ended at
  Rimuldar `(29,14)`, route `none`, no active path, no runtime blocks, HP
  `115/115`, MP `93/97`, and intact level-18 stats. Geometry is proven, but
  auto-walk timing is not fully clean: the reverse mountain pocket drifted
  `(108,111)->(107,111)->(106,111)`, and queued steps
  `(103,111)->LEFT` and `(101,107)->RIGHT` exhausted both retries before
  same-origin raw probes moved through. Forward hard stops at
  `(110,86)->LEFT`, `(102,107)->LEFT`, and `(104,113)->DOWN` likewise passed
  same-origin probes. Keep all of these as executor timing evidence; no World
  Map blocker was added.
- Queued auto-walk routes now have a route-specific two-retry timing-recovery
  budget via `auto_step_route_block_retry_limit=2`. Manual taps remain at zero
  retries and non-route injected/probe steps retain the general one-retry
  budget. This is live-proven on the Cantlin-to-Eastern-Great-Swamp reverse
  forest: `(60,93)->DOWN` and `(50,99)->DOWN` both exhausted retry 1, used the
  new retry 2, and completed without player intervention. Three other forest
  seams completed after retry 1. Across the full `(73,102)->(48,104)` pass
  there were zero hard timing stops, zero off-path drifts, and no runtime
  blockers. One `can_walk_false` cancellation occurred only after
  `(68,91)->(68,92)` completed, when REPEL-expiry dialogue opened; the route
  resumed safely after the user restored REPEL.
- Fresh live state is World Map `(48,104)`, active route
  `great_swamp_cantlin`, next waypoint `Southern plains west road` index 25,
  no active path, and no runtime blocks. Verification passes 145 auto-step,
  113 route-manager, 127 overworld-route, and 1 config test, Lua syntax,
  `git diff --check`, and the full repository harness. WSL reports only the
  known optional `accessible_output2` warning and non-failing Windows-only
  speech-bridge `cmd: not found` diagnostic.
- Cross-waypoint overworld turn timing is live-validated on
  `codex/cantlin-hauksness-return`. The shorter
  `auto_step_route_pre_turn_inject_limit=10` now survives both the guarded
  re-press and its bounded timing retry instead of reverting to the ordinary
  limit of 12. Live forward/reverse checks completed cleanly at
  `(22,95)->RIGHT`, `(23,95)->LEFT`, `(23,106)->DOWN`,
  `(23,107)->LEFT`, and `(22,107)->DOWN`; the guarded re-press used 10 on the
  observed cross-waypoint turns, with no drift or blocker promotion. The
  deepest bounded timing-retry preservation is deterministic-test evidence
  because that branch did not naturally recur after the final reload.
- One unrelated ordinary non-final step at `(23,102)->DOWN` produced a
  timing-only false block after the same edge had already passed; its retry
  succeeded. Keep it as executor timing evidence, not World Map data. Three
  battles interrupted the route and resumed safely. Fresh final state is
  World Map `(22,108)`, field control, no active path or runtime blocks,
  HP `84/100`, MP `72/90`, and intact level-17 stats.
- Current-source verification passes 144 auto-step, 113 route-manager, 127
  overworld-route, and 43 battle tests, Lua syntax, `git diff --check`, and the
  full repository harness. WSL reports only the known optional
  `accessible_output2` warning and the known non-failing Windows-only speech
  bridge `cmd: not found` diagnostic.
- Hauksness-to-Cantlin named route is now live-validated end to end on
  `codex/cantlin-hauksness-return`. The final 57-waypoint
  `cantlin_hauksness` route starts at Hauksness World Map entrance `(25,89)`
  and entered Cantlin from `(73,101)` at waypoint 57. The arrival event changed
  to map `0x0A` at `(15,0)`; fresh probe `CANTLIN_ARRIVAL_20260726` confirmed
  route `none`, field control, neutral controller byte `0x00`, and no runtime
  blocks.
- Live validation replaced two reverse-only jogs with observed north-carry
  splices. From `(50,100)`, the strict `(50,99)` segment sustained its press
  and accepted carry at `(50,98)` before continuing east to `(52,98)`. From
  `(64,93)`, the strict `(64,92)` segment accepted carry at `(64,91)` before
  continuing east to `(68,91)`. Both use route-local sustained-hold and settle
  controls; neither is permanent or runtime blocker data.
- The final long east segment settled at `(74,91)`, so recovery from
  `(74,99)` initially tried the blocked east-column descent. The Cantlin final
  waypoint now plans horizontal-first: the validated replay moved left to
  `(73,99)`, then south into town. Combat and a REPEL-expiry dialogue
  interruption both preserved safe route recovery. No map blockers were added.
- Final verification passes 127 overworld-route, 113 route-manager, 140
  auto-step, and 43 battle tests plus Lua syntax and `git diff --check`. The
  full repository harness completed every code/configuration check; its only
  nonzero item is the known optional WSL `accessible_output2` dependency.
- Cantlin-to-Hauksness named route is live-validated end to end on
  `codex/cantlin-hauksness-return`. The corrected 58-waypoint
  `hauksness_cantlin` route starts from the actual Cantlin exit landing
  `(73,102)`, follows the western/southern forest chain, and entered Hauksness
  from doorstep `(24,89)` by one strict east step. Final proof at frame
  `195814` was `event=arrived route=hauksness_cantlin waypoint=Hauksness
  index=58`; a fresh probe confirmed Ruins of Hauksness map `0x03` at `(0,10)`,
  route `none`, menu/dialogue closed, and no runtime blocks.
- This live pass captured two recoverable route-aware settle overshoots:
  `(33,116)->(32,116)` and `(22,89)->(22,88)`. Both cancelled with
  `route_drift_off_path`, preserved the next route waypoint, and recovered on
  a fresh `auto_walk`. Queued block reports at `(70,91)->LEFT`,
  `(68,91)->DOWN`, `(56,95)->LEFT`, and `(20,110)->UP` passed same-origin raw
  probes. Keep all of these as executor timing evidence, not World Map block
  data.
- Fresh publication verification passes: 118 overworld-route tests, 113
  route-manager tests, 140 auto-step tests, 43 battle tests, Lua syntax,
  `git diff --check`, and the full repository harness. WSL reports only the
  known optional `accessible_output2` warning; its Windows-only speech bridge
  launch also emits the known non-failing `cmd: not found` diagnostic.
- Prior pre-feature live state was World Map `(20,88)` after the user completed Hauksness
  guidance in both directions with the final route-aware carry source loaded.
  Fresh probe `AUTOWALK_ROUTE_CARRY_20260725` confirmed no active route or
  path, `RUNTIME_BLOCKS map=0x01 none`, controller byte `0x00`, healthy speech,
  and intact level-17 stats: HP `94/100`, MP `40/90`, STR `0x48`, AGI `0x46`,
  ATK `0x64`, DEF `0x55`, spells `0xFF/0x11`. No stat-integrity warning or
  movement-reset line appears in the fresh log.
- Bidirectional Hauksness route smoke testing and post-run stat-integrity
  validation passed, with a log-evidence limitation: the pre-restart route log
  was not preserved, so natural guarded-twitch release, exact final-carry
  acceptance, and a strict final-segment `carry=(nil,nil)` arrival were not
  captured. Do not claim those live; exact waveform release, route-aware carry
  acceptance/rejection, and strict-final behavior are automated-verified.
  Focused totals are 108 overworld-route, 113 route-manager, and 140 auto-step
  tests. All bytecode checks, `git diff --check`, and the full repository
  harness pass; WSL reports only the known optional `accessible_output2`
  warning.
- Prior Cantlin clarification, now superseded by the bidirectional named
  routes: its direct World Map approach and town exit are live-proven. Entry
  from the northern route at `(73,101)` and the older southern proof from
  `(73,103)` both land at Cantlin `(15,0)`;
  selected-object return reaches `(20,28)` facing south toward transition
  `(20,29)`, whose actual World Map landing is `(73,102)`.
  `overworld_routes.lua` now provides both Cantlin-to-Hauksness and
  Hauksness-to-Cantlin guidance.
- Historical 2026-07-24 checkpoint was Ruins of Hauksness map `0x03` at exit `(0,10)`,
  facing west after the final source-only Axe Knight-to-exit replay. HP is
  `89/100`, MP `78/90`, level-17 stats are intact, no path is active, and
  `RUNTIME_BLOCKS map=0x03 none`. The entrance-to-Axe Knight route completed at
  safe stand `(17,12)` facing east, then the fully loaded reverse route
  completed back at the exit. Combat interruptions resumed cleanly; each
  completion restored all four parked NPC slots with zero deferred.
- The earlier lower-pocket reload check was world map `(24,91)`, route
  `kol_hauksness`, next waypoint `Hauksness lower pocket`, with no active path,
  NPC blockers, or runtime blocks. The natural lower-west-drop segment ended
  at `(24,93)` without carrying; a same-origin RIGHT probe recreated the prior
  `(25,93)` carry landing. The loaded recovery then executed `LEFT, UP, UP` to
  `(24,91)` and advanced correctly.
- Earlier the same session, generic `kol` was reload-verified from a fresh
  `(54,15)` baseline. It reached `(74,18)` and then completed `Kol southwest
  track` to `(84,26)` with eight DOWN moves before ten RIGHT moves, without
  retrying the blocked `(77,18)->RIGHT` edge. Two earlier bridge segments each
  needed one retry after movement-started timing stalls; do not promote those
  stalls as map blockers.
- 2026-07-24 the Hauksness-to-Kol return route `kol_hauksness` reached Kol
  end-to-end. Its arrival state was Kol map `0x07` at `(19,23)`,
  `OVERWORLD_ROUTE: event=status route=none`, menu closed, and
  `RUNTIME_BLOCKS map=0x07 none`. The same-destination route-variant fix is
  live-proven: with ordinary Kol selected, logs retained `kol_hauksness`
  through the Garinham cutoff. Two real west-side geometry failures were
  isolated with same-origin probes: `(56,15)->RIGHT` into `(57,15)` and
  `(77,18)->RIGHT` into `(78,18)` were blocked, while the south-first lanes
  were clean. `kol_hauksness` now plans vertical-first for `Northeast bridge
  west bend` and `Kol southwest track`; generic `kol` now also uses
  vertical-first ordering for `Kol southwest track`. Focused regressions pass
  in the 106/106 route suite, and route-manager tests pass 111/111. The generic
  ordering is live-verified after a full Stop/Run as recorded above. Several
  other queued steps failed but passed same-origin raw probes, notably
  `(54,15)->RIGHT`, `(93,36)->UP`, and `(93,35)->RIGHT`; keep those as executor
  timing evidence, not map blockers.
- 2026-07-22 Hauksness overworld geometry is live-validated end-to-end. The
  hero entered Ruins of Hauksness map `0x03` at `(0,10)`; final status is
  `OVERWORLD_ROUTE: event=status route=none` and
  `RUNTIME_BLOCKS map=0x03 none`. Do not call auto-walk fully clean yet:
  `(15,90)->UP` and final entrance `(24,89)->RIGHT` each timed out under
  auto-walk but succeeded from the same origin under raw `probe_edge`, so they
  are executor/timing evidence rather than permanent blockers. The
  horizontal-first Western desert seam fixes are live-verified: from
  `(16,27)`, south-shelf guidance moved LEFT to `(15,27)` before descending to
  `(15,28)`; from the west-wall carry landing `(1,54)`, south-road guidance
  moved RIGHT before descending and completed at `(2,64)` without retrying the
  blocked `(1,63)->DOWN` edge. Runtime blocks remained empty. The return route
  is now also validated as recorded above. The coordinate-sensitive combat
  sliding-window bug is source-patched and live-verified: a post-reload Wraith
  battle at the exact `(20,88)` reproduction coordinate logged and spoke each
  opening, attack, damage, and reward once. Battle-only token comparison
  suppresses punctuation-shifted and suffix-only redraws while preserving
  appended counterattacks and rewards; the captured Wyvern sequence is covered
  by the 43/43 battle regression suite.
- 2026-07-24 Hauksness interior objective navigation is source-only
  live-validated in both directions. From exit `(0,10)`, object guidance
  reached safe Axe Knight stand `(17,12)` and faced east toward the fixed
  encounter at `(18,12)`; the reverse guidance returned to `(0,10)` and faced
  west. Runtime blockers remained empty after reload, NPC parking restored
  cleanly after every route and battle interruption, and level-17 stats
  remained intact. The landmark exposes the visible encounter location but
  does not reveal the intentionally buried Erdrick's Armor square.
- 2026-07-22 the waypoint-scoped movement-reset A/B was rejected and removed.
  From a clean `(15,89)` baseline, the reset fired at `(24,89)` while movement
  RAM was still active (`move=0x07`, `sub=0x1A`) and carried into map `0x03`
  during final settle without the intended entry segment. Stats remained
  clean, but this is an unsafe executor side effect, not a successful fix.
  FCEUX has been reloaded with the override absent; keep the global reset
  setting false.

- 2026-07-20 user manual Rimuldar service sweep passed every service route.
  The Weapons Merchant route only needed a wait-and-retry when a roaming NPC
  occupied the corridor; it succeeded after the NPC moved. Treat this as
  transient NPC interference, not permanent geometry or a new blocker.

- 2026-07-20 Rimuldar Magic Key return is fully live-verified after reload.
  Normal entry `(29,14)` to key stand `(4,5)` completed in 52 steps with no
  runtime blockers. Selected Travel object `exit_0_3` then queued six steps,
  reached in-town exit stand `(0,3)`, faced west, and cleared the route without
  leaving Rimuldar. Autowalk returned six steps to `(4,5)`, then the full
  key-stand-to-east-exit route queued 51 steps, reversed the proven x=0/top-bank
  path, reached `(29,13)`, and faced east. Final state is
  `PATH_STATE target=nil` and `RUNTIME_BLOCKS map=0x0B none`. Timing retries at
  `(4,4)->DOWN`, `(4,5)->LEFT`, and `(3,4)->UP` all crossed and cleared their
  temporary edges; none became permanent blockers. The direct false bridge
  `(3,5)->(2,5)` remains closed as `(2,5).east`. Agent validation ended at
  Rimuldar `(29,13)`; the subsequent manual service sweep moved the player, so
  the current live coordinate is not recorded. Focused suites pass: map reader
  67/67, objects 99/99, and pathfinder 21/21; the full seven-check smoke gate
  passes.

- 2026-07-17 Rimuldar Wings-pocket return and Weapons Merchant routing are
  source-only live verified. The opened-door Wings return pass reached each
  promoted origin through normal movement and paired route failures with
  same-origin raw probes; the resulting directional-only boundary batch is in
  `map_reader.lua` with exact regression coverage. For the weapon shop, the
  real public stand is `(23,9)`, facing north toward Merchant 2 at `(23,7)`;
  the older `(24,7)` prompt proof was teleport-only inside the enclosed room.
  After a full Lua reload with `RUNTIME_BLOCKS map=0x0B none`, the source route
  completed `(23,9)->(29,14)` in 21 steps. Normal object browsing then selected
  `Weapons Merchant`, planned the inverse 21-step route (`11 west, 5 north,
  5 east`), and completed at `(23,9)` with automatic north facing. TALK opened
  `We deal in weapons and armor. Dost thou wish to buy anything today?` and
  marked the merchant visited. A roaming `Guard 2` at `(19,9)` caused two
  honest transient `No path found` results; retrying after he moved succeeded,
  with no runtime block added. Final live state is `(23,9)`, menu closed,
  selected Weapons Merchant visited, and runtime blocks none. The full smoke
  runner and focused suites pass (`map_reader` 67, `objects` 99, `pathfinder`
  20, `route_manager` 110, object commands 3).

- 2026-07-17 Rimuldar Magic Key route and safe NPC parking guard are live
  verified. With `auto_walk_park_mobile_npcs=true`, map `0x0B` now logs
  `AUTO_WALK_NPC_PARK_SKIP ... reason=walkable_origin origin=(0,0)` and uses
  the existing frozen/live-NPC path instead of writing parked NPC coordinates
  onto the real route cell. One normal-entry run from `(29,14)` and one
  same-map reset repeat each queued the 52-step outer-bank route, crossed
  `(1,0)->(0,0)` without retry, turned south to `(0,1)` without leaving
  Rimuldar, and reached the public key-shop stand `(4,5)`. Final live state
  is `PATH_STATE target=nil` and `RUNTIME_BLOCKS map=0x0B none`. The
  isolated stop-at-`(0,0)` waveform concern did not reproduce on the real
  route, so `auto_step.lua` was not changed. The direct merchant-to-entry
  shortcut through `(3,5)->LEFT` is live-blocked without an NPC, and source
  closes `(2,5).east`. The corrected return may use the nearby west exit or
  continue north from `(0,3)` along the proven outer-bank route to the east
  town entrance; the west exit is shorter.

- 2026-07-15 Cantlin checkpoint complete for now. The user manually validated
  both directions between Town Entrance and the Magic Key Merchant with the
  eastern door open, and confirmed the expected `No path found` result when
  doors are closed. The Golem was defeated; fresh live state at Cantlin
  `(15,0)` reports quest flag `0x42`, six keys, every door RAM slot `(0,0)`,
  and `RUNTIME_BLOCKS map=0x0A none`. A new closed-door save state was taken.

- 2026-07-14 Cantlin Magic Key Merchant and NPC movement status validated. Object
  speech identifies live NPC movement as `stationary`, `roaming`, or
  `movement unknown`. Fixed `npc_11` sells Magic Keys at `(27,6)`; TALK succeeds
  from public stand `(27,8)` facing north across counter `(27,7)`. The shop is
  intentionally key-locked behind eastern door `(26,9)`, opened from `(25,9)`
  facing east. After town reentry relocked the door, route failures plus
  same-origin raw probes confirmed `(27,5).north`, `(27,1).south`, and
  `(28,2).west`; all three are now permanent directional blockers with tests.
  Runtime mirrors produced a clean return through `(24,2)` and `(24,1)` to
  Town Entrance `(16,0)`. After clearing those mirrors, all three source edges
  remained blocked and the closed-door planner returned clean `No path found`
  for `(16,0)->(27,8)`. Current hero is `(16,0)`, doors closed, six keys, and
  runtime blocks none. Focused tests pass: objects 99, map reader 61, route
  manager 104.

- 2026-07-13 Cantlin Golem and closed-door service baseline confirmed. Moving
  north on the World Map from `(73,101)` to `(73,100)` triggered the fixed
  `A Golem draws near!` battle at `(73,100)`. Victory changed quest flags from
  `0x40` to `0x42`, confirming the one-time clear bit; moving south from that
  cell then entered Cantlin at `(15,0)`. All door RAM slots were zero and
  `RUNTIME_BLOCKS map=0x0A none`. With NPCs frozen separately for each leg,
  closed-door round trips passed between entrance `(16,0)` and Tool Merchant 2
  `(4,7)`, Inn `(8,5)`, Tool Merchant `(5,12)`, Fairy Water Merchant
  `(20,13)`, and Weapons Merchant `(25,26)`. Premium Weapons Merchant
  `(26,12)` correctly returned `No path found` with `reason=closed_door`; no
  map blocker was promoted. Initial unfrozen attempts exposed idle roaming NPCs
  escaping parking, but the reloaded full-mobility-history fix passed unfrozen
  round trips for all five reachable fixed services, parking six to eight
  roaming slots per leg. No `AUTO_WALK_NPC_BLOCK` or
  `AUTO_WALK_BLOCKER_FOUND` event occurred. One return paused at `(15,0)` only
  because the command menu was genuinely open; it completed after closing the
  menu. Premium Weapons Merchant still correctly reports `reason=closed_door`.
  Roaming Weapons Merchant `npc_4` moved from `(22,4)` to `(22,5)` but remained
  unreachable from its current pocket, so selected-object navigation refused
  safely. Current hero is Cantlin `(16,0)`, doors closed, menu closed, runtime
  blocks none.

- 2026-07-13 Tool Merchant 2 confirmed and routed. Fixed `npc_12` at `(2,7)`
  opened a Buy/Sell shop from `(4,7)` facing west; inventory is Herb 24 G and
  Torch 8 G. Source now labels it `Tool Merchant 2`, service=true, with counter
  stand `(4,7)` facing west. Blocker-hunt retries and same-origin raw probes
  confirmed `(3,7).east` from `(4,7)->LEFT` and `(3,8).south` from
  `(3,9)->UP`; both are promoted to Cantlin directional data. After a live
  navigation-module reload and clearing the one-cell runtime overlay,
  source-only routes completed `(3,9)->(4,7)`, `(4,7)->(16,0)`, and
  `(16,0)->(4,7)` with no new blocker and no runtime blocks. All 61 map-reader
  and 98 object tests pass. Current hero is `(4,7)`, facing west at Tool
  Merchant 2's counter, with menu/dialogue closed and RUNTIME_BLOCKS none.

- 2026-07-13 SEARCH trace resolved the remaining post-52 fragments. Fresh live
  evidence showed "Bill searched the ground all about. 99 LBut there found
  nothing." and a later standalone "MP 63ll" after the menu closed. The EXP
  row was absent from the transient numeric context, so 99 could not match the
  earlier derived-slice list; L was a single fused status label; ll was the
  current hero-name tail. text.lua now removes an otherwise-unmatched bare
  number only after an already completed sentence under strong status context,
  repairs a single status letter fused before a second capital (LBut -> But),
  and classifies status-value rows with any one- or two-letter lowercase name
  tail rather than hard-coding Bill. Semantic reward/stat/shop numbers and
  ordinary L-words remain covered. The diagnostic trace now waits for terminal
  punctuation to avoid logging each growing redraw. All 70 text and 7 field-
  guard tests pass; text.lua, main.lua, and test_text.lua byte-compile; git
  diff --check passes. Current hero remains (15,1), RUNTIME_BLOCKS none. Reload
  main.lua and retest failed SEARCH plus the post-menu-clear pause once.

- 2026-07-12 command-result numeric status-slice fix pending reload. Fresh
  post-reload speech exposed valid SEARCH/TAKE results contaminated as
  "Bill searched the ground all about. 6", "But there found 152 nothing.",
  and after the first filter reload, "But there found 52 nothing." Earlier
  command results also included
  "'There is no one there. 6", and "There is nothing to take here, Bill. 6".
  A live report with the menu closed showed lower rows 6, 52, and 99 while
  the status window held LV 16, G 1520, and E 13994. text.lua now derives
  every contiguous numeric slice from visible status values and removes it only
  in suspicious redraw positions; semantic reward and level-up numbers remain.
  The exact regressions failed before source, then all 66 text and 7 field-guard
  tests passed; LuaJIT byte-compilation and git diff --check also pass. Current
  hero is (15,1) with no runtime blockers. Reload main.lua, exercise the command
  menu results once, then resume Person 2 / npc_12 at (2,7).

- 2026-07-12 Person 2 approach paused on a second status fragment. The initial
  route began while hero and fixed Old Man 2 both occupied (27,6), likely from
  selected teleport. West, south, north, and east movement all raw-held
  blocked from that overlap state. These four results are contaminated origin
  evidence: do not promote (26,6).east, (27,7).north, (27,5).south, or
  (28,6).west from this pass. All temporary runtime edges were cleared and the
  hero was relocated to known-safe entrance (15,1). Before the clean Person 2
  route could start, lower dialogue cached BillE13E1399 16Bill and the old
  script refused auto-walk. Exact text and movement-guard regressions failed
  before source; text.lua now recognizes the narrow fused-name/two-GE-value
  plus digit-prefixed-name pattern. All 63 text and 7 field-guard tests pass.
  Current hero is (15,1), no runtime blocks, old script still has the fragment
  cached. Reload main.lua, then route to stable Person 2 / npc_12 at (2,7).
- 2026-07-12 Cantlin dialogue-scroll lock at (27,6): after SEARCH, the lower
  scan assembled 1520Bill3 from status rows (G 1520, hero name Bill, trailing
  status digit). MENU_STATE showed no real menu or prompt, but PREV.dialogue
  and announced dialogue both retained the 9-character fragment, causing
  object hotkeys to report Wait for dialogue to finish. The exact text failed
  passive-status and field-action-guard regressions before the fix. text.lua
  now recognizes a numeric value wrapped around a short capitalized name and
  trailing numeric status fragment. All 63 text and 7 field-guard tests pass,
  and text.lua byte-compiles. Current live script is pre-fix and still cached;
  reload main.lua, then verify object controls at (27,6).
- NPC follow-up from the user's manual conversation pass: live RAM currently
  identifies Old Man 1 as stable slot 6 at (14,28), Merchant 1 as stable slot
  2 at (9,7), Person 2 as stable slot 12 at (2,7), and the NPC at the stopped
  position (27,6) as fixed Old Man 2 / slot 11. The user reports Old Man 1 has
  an important clue and Merchant 1 gives an armor-location clue. External NES
  script/layout references confirm Cantlin has two tool shops, so Person 2 is
  a plausible second seller, but do not label it until live TALK opens the
  tool transaction prompt. After reload, test Person 2 at (2,7).
- 2026-07-12 Cantlin fixed-service circuit complete after the stable-slot full
  reload. Live report_npcs confirmed slot 10 Inn, slot 13 Radish Merchant
  service=false, slot 14 Tool Merchant, slot 15 Premium Weapons Merchant,
  slot 16 Fairy Water Merchant, and slot 19 Weapons Merchant. Source-only
  blocker-mode round trips passed for entrance (15,1) <-> fixed Weapons stand
  (25,26) and entrance (15,1) <-> Premium stand (26,12). Fairy Water forward
  reached (20,13); return later stopped at (16,12)->LEFT into (15,12).east.
  Route retries and a same-origin raw probe blocked without NPC or runtime
  contamination. After mirroring that edge, return completed at (15,1).
  Source/tests now add east to the existing (15,12) directional entry; the
  focused assertion failed before promotion and all 61 map tests pass after.
  Current hero is (15,1), all five doors open, one key, with the single
  (15,12).east runtime mirror. Reload main.lua before the next pass.
- 2026-07-12 Cantlin stable service identities: the post-reload NPC table had
  inactive slot 5, so duplicate Merchant display names renumbered. Fixed slot
  10 at (8,3) became generic Merchant 3 and was excluded from Services,
  while fixed slot 13 at (2,12) inherited the Inn role and inferred stand
  (4,12). Confirmed Cantlin roles now prefer stable npc_<slot> IDs while
  retaining name fallbacks for older fixtures. After
  reload_navigation_modules, report_npcs shows slot 10 as Inn, service=true,
  and slot 13 as Radish Merchant, service=false; Services again routes the Inn
  to (8,5). Source-only blocker-mode round trips completed entrance (15,1)
  <-> Inn (8,5) and entrance (15,1) <-> Tool Merchant (5,12) with no runtime
  blockers. The reloaded Fairy Water return also completed source-only from
  (20,13) to (15,1). The new inactive-slot regression failed before the fix
  and all 97 object tests pass afterward. Current hero is (15,1), all five
  doors open, one key, and RUNTIME_BLOCKS none; reload main.lua before
  continuing.
- 2026-07-12 Cantlin premium-shop route RESOLVED: fixed Guard 4 at `(24,12)`
  is the Flame Sword 9800 G / Silver Shield 14800 G seller. The earlier
  `(24,13)` north-facing TALK proof came from an isolated private-side tile.
  NES map alignment plus normal-route probing found the real public stand:
  `(27,12)->LEFT` enters raw type-15 `(26,12)`, while another LEFT into counter
  cell `(25,12)` blocks. TALK from `(26,12)` facing west opened the same shop.
  `map_reader.lua` now exposes only `(26,12)` as the additional passthrough,
  and `objects.lua` routes `Premium Weapons Merchant` there facing west.
  Blocker-mode routes completed both ways between practical entrance `(15,1)`
  and `(26,12)` in 24 steps; selected-object autowalk reports `Already there`,
  faces west, and holds Guard 4. `merchant.lua` still disambiguates the split
  14800-G `Silver` row as `Silver Shield`. The user manually verified the
  Services-selected route, shop prompt, Flame Sword row, and Silver Shield row.
  Focused suites pass 61 map and 96 object tests.

- 2026-07-12 Fairy Water route: TALK from `(20,13)` facing east toward Woman 2
  `(22,13)` opened the 38-GOLD prompt. Source-only entrance routing reached
  the fixed counter stand cleanly. Return routing repeatedly blocked at
  `(17,13)->LEFT` into `(16,13).east`; a same-origin raw probe agreed with
  no NPC or runtime contamination. After mirroring that edge, return completed
  at practical entrance `(15,1)`, and a fresh selected-service route completed
  back at `(20,13)` facing east. Source/tests now include `(16,13).east`;
  61 map tests pass. Current hero is `(20,13)`, all five doors open, one key,
  with that single runtime mirror. Reload `main.lua` before the next live pass.

- 2026-07-12 Cantlin Weapons Merchant clarification: stationary slot 19 is
  `Weapons Merchant` at `(27,26)`, with public stand `(25,26)`; the user has
  already validated that route both ways. Nearby slot 4 is now labeled
  `Roaming Weapons Merchant`. In the current save it patrols x=22, rows 3
  through 6, inside the verified sealed upper-east compartment. Normal and
  skip-NPC planners return `No path found`, frontier analysis has
  `hidden_bridge_candidates=0`, and four two-away TALK checks all returned
  `There is no one there`: north `(22,1)->(22,3)`, south
  `(22,8)->(22,6)`, west `(20,5)->(22,5)`, and east `(24,4)->(22,4)`.
  Do not assign slot 4 a static stand or remove compartment walls; its
  adjacent-NPC route remains valid when it wanders into the reachable town
  component. Live Services output confirms the new label and NPC freeze is off.

- 2026-07-11 Cantlin service validation: the user confirmed the Tool Merchant
  route and both the forward Inn route and Inn interaction. Inn return stopped
  at `(16,2)->UP` into `(16,1).south`; the normal-origin probe and 3/3 verifier
  all blocked without NPC or state contamination. Source/tests now make
  `(16,1)` fully blocked. With the south approach mirrored live, return routing
  used `1 east, 2 north, 1 west` through x=17 and completed at Town Entrance
  `(16,0)`. Current live state is `(16,0)`, all five doors open, runtime block
  count 1. Reload Lua before clearing the overlay.

- 2026-07-11 Cantlin north lane: normal movement proved all `y=0` cells
  `(1,0)..(29,0)`. Travel exposes Town Entrance `(16,0)`, north exit `(23,0)`
  via safe stand `(23,1)`, northeast exit `(29,0)` via `(28,0)`, and southeast
  exit `(20,29)`.
  The exact carry repro now passes live: `(4,1)->UP` needed a seam retry,
  queued `initial_settle=16`, stayed in Cantlin, then reached `(1,0)` west.
  Initial route settles reset movement immediately; 88 auto-step tests pass.
  Clean normal-origin probes plus 3/3 verifiers promote north approaches on
  `(1..3,1)`, `(6..13,1)`, and `(26..28,1)`; existing arrival-shelf proof
  keeps `(15..16,1).north`. Descents at `x=4`, `x=5`, `x=14`, and `x=17..25`
  moved. `(23,1)->UP` proved a directional north exit, landing on World Map
  `(73,102)` before the queued east step. Source guards `(23,0).south`.
  A teleport-seeded `(17,0)->RIGHT` failure was disproved after normal
  reacquisition; the edge moved and carried to `(19,0)`. `sweep_walk`
  trusted-boundary handling remains covered by 51 tests.
  Fresh source-only routing with no runtime blocks completed `9 east, 2 south`
  from `(16,0)` through open x=25 to `(25,2)`; x=18 also descended cleanly.
  Post-reload `(6,0)->DOWN` then blocked directly and 3/3 with no artifact.
  Its runtime mirror made the route choose `1 west, 2 south` through x=5.
  Current live state: Cantlin `(5,2)`, all five doors open, runtime block count
  1 for `(6,1).north`; reload Lua before clearing it. Focused object and
  map-reader suites pass 94 and 60 tests.

- 2026-07-10 Cantlin Travel-exit correction: `objects.lua` had the sole Travel
  object pinned to placeholder `(14,29)` behind the striped damage barrier,
  while prior live movement proved `(20,29)` immediately changes to the World
  Map. It now exposes `exit_20_29` with safe stand `(20,28)` facing south and no
  `exit_14_29`. Live `reload_navigation_modules` changed Travel from `2 south,
  10 west` to object `(20,29)`, stand `(20,28)`. Route cleanup then promoted
  same-origin 3/3 `(23,27).east/west`, `(24,28).north`, and `(22,28).north`.
  With those three runtime cells active, selected-object autowalk completed at
  `(20,28)`, faced south, announced `exit here`, and stayed stable across two
  position samples. All five doors remain open. Reload `main.lua` before
  clearing the three-cell overlay.
  Follow-up from fixed Weapons Merchant slot 19 at `(27,26)` proved the user's
  return blocker was not roaming Merchant slot 4: `(23,26)->DOWN` into
  `(23,27).north` blocked 3/3 with `npc_blocked=false`. Source/tests and the
  live overlay now include it; the replanned return completed at `(20,28)` and
  faced south. Reload `main.lua` before clearing this four-cell overlay.

- 2026-07-10 Cantlin essential-service route cleanup: blocker-mode routes
  completed both ways from practical entrance `(15,1)` to Inn stand `(8,5)`
  (19 steps), Tool Merchant stand `(5,12)` (21 steps), and fixed Weapons
  Merchant stand `(25,26)` (35 steps), with no new blockers on those six legs.
  A preceding return from `(22,27)` found `(21,27).east`; same-origin
  `probe_edge_verify:LEFT,3` confirmed `moved=0 blocked=3` without contamination.
  Source/test plus a live runtime mirror now include that edge, and the retried
  33-step return reached `(15,1)`. Mobile Weapons Merchant 2 remains correctly
  position-dependent: current slot 4 at `(22,6)` is inside the verified
  upper-east compartment, both normal and skip-NPC planners return `No path
  found`, and frontier analysis reports `hidden_bridge_candidates=0`. Do not
  remove any of the 34 modeled compartment boundaries. Prior same-day evidence
  already proves object-selected routing works when Merchant 2 is reachable at
  `(17,4)`. A later user-observed bouncing route was targeting the south
  `Exit to World Map` `(14,29)`, not practical entrance `(15,1)`. Cleaning that
  path and the subsequent entrance route promoted seven same-origin 3/3 edges:
  `(19,28).east`, `(19,25).north`, `(17,24).east/north`,
  `(17,21).east/south`, and `(18,20).south`. With all seven mirrored live,
  blocker mode completed to `(15,1)` and stayed stable across immediate and
  four-second position checks. One seam-retry completion briefly reported
  `(17,23)` before later position `(16,23)`; a controlled normal step and the
  final route did not reproduce the carry, so retain it as a timing watch item.
  Current hero position is `(15,1)`, all five doors are open, and five runtime
  cells mirror the newest source entries. Reload `main.lua` before clearing the
  overlay or beginning the next route-cleaning pass.
- 2026-07-10 Cantlin barrier/timing checkpoint: autowalk from `(4,12)` toward
  Travel exit `(14,29)` crossed the lower striped barrier and left the hero at
  4 HP. `map_reader.lua` now marks the full 16-cell barrier footprint at
  `x=11..18, y=26..28` as damage hazards; normal routing excludes it, while
  `debug_pathfind_to_allow_hazards:14,29` identifies the unsafe shortcut.
  `(12,27).north` also verified 3/3 blocked from `(12,26)->DOWN`. After debug
  recovery to safe `(9,25)`, a 30-step hazard-free route completed to practical
  entrance `(15,1)`. The same-frame `reload_navigation_modules next_filter`
  bug was reproduced as `NPCs. No objects`: a fresh `objects` module was not
  initialized until a later frame. Object-command registration now primes the
  live map synchronously after reload, and the exact same batch reports
  `Merchant 1 (1 of 19)`. Focused checks pass: 59 map-reader and 3 object-command
  tests. Current checkpoint is `(15,1)`, all five doors open, menu/dialogue
  closed, one key, and `RUNTIME_BLOCKS none`.
- 2026-07-10 Cantlin reachability audit after Services reload fix: explicit
  `reload_navigation_modules` followed by Services now reports `Inn (1 of 4)`
  and route-manager selection agrees; the stale `Eastern Building Door (10 of
  25)` result is gone. The four entries enumerate as mobile Weapons Merchant,
  Inn, Tool Merchant, and fixed Weapons Merchant. Object-selected
  `auto_walk_blocker` then targeted mobile Merchant 2 at `(17,4)`, completed
  three east steps to `(17,3)`, faced south, and held the target with no runtime
  blocks or dialogue residue. The same-frame `reload_navigation_modules
  next_filter` batch can transiently report `NPCs. No objects`; splitting the
  commands by two seconds immediately reports all 19 NPCs, so this is a debug-
  batch timing artifact rather than a player workflow defect. Reachability
  audit results: all 4 Services reachable, the sole Travel exit reachable, all
  5 opened Doors reachable, and 18 of 19 NPCs reachable. The only false
  negative was dialogue-only Radish Merchant `(2,12)`, despite prior TALK proof
  from public stand `(4,12)` facing west. A fresh 22-step blocker-mode route
  from `(17,3)` reached `(4,12)` without blockers or runtime patches.
  `objects.lua` now lets explicit role overrides carry interaction coordinates
  even when `service=false`, and Radish Merchant uses `(4,12)` facing west.
  All 92 object tests pass. Current live checkpoint is Cantlin `(4,12)`, all
  five doors open, menu/dialogue closed, `RUNTIME_BLOCKS none`. Reload
  `main.lua`, then repeat the NPC reachability audit; expected result is 19
  reachable and 0 unreachable.
- 2026-07-10 Cantlin Merchant 2 and Services reload pass: the user live-
  validated every command-menu option plus Merchant 2, SPELL, and ITEM after
  the `llE` row-filter fix; fresh log output contained clean SEARCH/TALK/action
  dialogue with no suffix. From Merchant 2's valid south stand `(15,5)`,
  blocker-mode auto-walk completed four north steps to entrance `(15,1)`.
  After parking Merchant 2 at `(14,4)`, normal and skip-NPC planners agreed on
  stand `(14,3)`, and the reverse route completed `2 south, 1 west` with no
  blockers, dialogue cancellation, or runtime overlay. A subsequent Services
  filter check exposed a module-reload bug: the filter announced `Services`,
  but route descriptions and `next_object` remained on `Eastern Building Door`
  `(10 of 25)`. Root cause was `main.lua` reloading `objects.lua` while the
  long-lived `route_manager.lua` retained its old `objects` table.
  `route_manager.refresh_navigation_modules()` now rebinds that dependency; a
  focused regression failed on stale `Chest` and now passes on reloaded
  `Weapons Merchant`. All 104 route-manager tests pass. Current live checkpoint
  is Cantlin `(14,3)`, menu/dialogue closed, all five doors open,
  `RUNTIME_BLOCKS none`; NPC freeze released and Merchant 2 was last reported
  at `(16,3)`. Reload `main.lua`, switch to Services, verify the list contains
  four services rather than the stale door list, then run object-selected
  `auto_walk_blocker` to the mobile Weapons Merchant.
- 2026-07-10 Cantlin isolated-pocket and passive-fragment pass: the reload
  confirmed Merchant 1 / Merchant 3 remain browsable but `service=false`, all
  five doors were open, and `RUNTIME_BLOCKS none`. From the debug-created
  `(1,1)` checkpoint, `auto_walk_blocker:15,1` found false exits into
  `(2,1).west` and `(1,2).north`. Same-origin `probe_edge_verify:...,3` gave
  both `classification=confirmed_blocked`, `moved=0 blocked=3`, with no NPC,
  timeout, drift, map change, interruption, or teleport-artifact contamination.
  After runtime mirroring, normal and skip-NPC planners each visited only the
  origin and returned `No path found`, confirming `(1,1)` is an isolated
  debug-created pocket. Source and focused map tests now include both edges.
  The hero was repositioned to practical entrance `(15,1)`. A first Merchant 2
  attempt accidentally resolved occupied coordinate `(5,11)` to Guard 2, then
  canceled at `(15,4)` because the old running loop saw
  `PREV.dialogue_len=3`. A corrected empty-coordinate route to `(8,9)`
  immediately reproduced the same cancellation and captured exact phantom
  dialogue `llE`. `text.lua` now classifies that fused lowercase-name/uppercase-
  status-label token as passive noise, and the per-frame `can_walk` gate now
  uses `field_action_guard.dialogue_blocks_movement`; real dialogue still
  blocks. Focused checks pass: 58 map, 58 text, and 7 field-guard tests.
  Current live checkpoint is Cantlin `(15,4)`, menu/dialogue closed, all doors
  open, `RUNTIME_BLOCKS none`; mobile Weapons Merchant 2 has resumed wandering
  and was last reported at `(0,3)`. Reload `main.lua`, report/freeze the fresh
  merchant position, choose an unoccupied adjacent coordinate, and retry the
  Merchant 2 route to validate that `llE` no longer cancels movement.
- 2026-07-10 Cantlin dialogue-merchant classification after reload: fresh
  baseline was Merchant 7 stand `(25,26)`, all five doors open, no runtime
  blocks, and the previous `(13,8).south` source blocker active. Merchant 3 was
  frozen at `(4,27)`; debug landing at `(5,27)` facing west and live TALK read
  `My Grandfather Wynn once had a shop on the east side of Hauksness.`
  Merchant 1 was then frozen at `(1,0)`; debug landing at `(1,1)` facing north
  and live TALK read `Grandfather used to say that his friend, Wynn, had buried
  something of great value at the foot of a tree behind his shop.` Both are
  dialogue-only hint NPCs, not shops. `objects.lua` keeps their generic
  `Merchant 1` / `Merchant 3` NPC labels but excludes both from Services;
  `luajit test_objects.lua` passes all 92 tests. Before the role checks, a
  frozen single-target route from `(25,26)` toward Merchant 3 initially planned
  22 steps and reached `(3,29)`, but stopped at `route_churn_cap` with
  `failure_class=command_timing_or_state_issue`. Its broad 19-cell suspect set
  is scratch evidence only and must not be promoted without isolated same-origin
  verification. Current live checkpoint is Cantlin `(1,1)`, all five doors
  open, menu/dialogue closed, NPCs frozen, and `RUNTIME_BLOCKS none`. Reload
  `main.lua` before judging the two Services exclusions in the live navigator.
  After reload, inspect the resulting Services list and continue route
  validation only for confirmed shops: Inn, Tool Merchant, and the two Weapons
  Merchant entries.

- 2026-07-09 Cantlin Merchant 7 route completion after restored-state restart:
  clean baseline was `(8,25)`, all five doors open, menu closed, and no runtime
  blocks. Same-origin 3/3 verifiers promoted `(8,24).south`, `(10,25).west`,
  `(23,11).north`, `(22,11).north`, `(21,11).north`, `(21,21).west`, and
  `(21,26).east`; the route reached Merchant 7 stand `(25,26)` before an
  emulator restart. After restoring the same save, navigation refresh confirmed
  the first batch and `(20,29).north` were live with `RUNTIME_BLOCKS none`.
  The continuation promoted `(13,8).south`, `(17,14).north`, `(21,13).west`,
  `(23,21).north`, `(22,21).north`, `(21,21).north`, `(24,24).east`,
  `(23,25).east`, and `(19,25).east`. Every promoted direction was
  `attempts=3 moved=0 blocked=3 classification=confirmed_blocked`, with no
  NPC block, timeout, drift, map change, interruption, or teleport artifact.
  Final uninterrupted validation completed `(15,1)->(25,26)`, then
  `(25,26)->(15,1)`, then `(15,1)->(25,26)` again in the same emulator state.
  Merchant 7 / `Weapons Merchant` is therefore route-complete in both
  directions. Current live checkpoint: Cantlin `(25,26)`, all five doors open,
  menu/dialogue closed, and nine post-restart runtime cells mirroring source
  edits. Reload `main.lua` before judging those nine additions without the
  overlay. Next useful work is the next unclassified Cantlin service, with
  mobile Merchant 3 still the strongest targeted follow-up.

- 2026-07-09 Cantlin Merchant 7 return/reverse validation after reload:
  baseline was public stand `(25,26)`, all five doors open, menu/dialogue
  closed, and `RUNTIME_BLOCKS none`. The return route reached the practical
  entrance `(15,1)` after same-origin `probe_edge_verify:...,3` promoted
  `(25,22).south`, `(23,23).east`, `(24,22).south`, `(24,24).north`,
  `(26,22).south`, `(27,20).south`, `(24,14).south`, `(15,13).south`,
  `(16,14).south/west`, `(14,14).south`, `(13,14).south`,
  `(12,14).south/west`, and `(11,13).south`. Every verifier was 3/3
  `confirmed_blocked`, with no NPC block, drift, timeout, map change,
  interruption, or teleport-artifact suspicion. Full reverse validation from
  the entrance then promoted `(21,11).west` and the lower vertical wall at
  `(21,26..28).west`. After those mirrors, A* tried to cross the lower wall by
  entering `(20,29)` from `(20,28)`; movement succeeded but immediately
  changed to the World Map. Source now guards `(20,29).north` from ordinary
  in-town routing while keeping the transition cell physically standable.
  The hero escaped a Starwyvern encounter on the second RUN attempt and
  re-entered Cantlin from overworld `(73,103)->UP`, but map re-entry cleared
  the runtime overlay and all opened-door RAM slots. Current live state is
  Cantlin `(15,2)`, `RUNTIME_BLOCKS none`, all five doors closed, one key.
  Reload the all-doors-open save state, then reload `main.lua` before the next
  route pass. Retry entrance `(15,1)` to Merchant 7 stand `(25,26)`; stop and
  record rather than following any newly selected south-edge transition.
  During the return route, parking mobile Merchant 3 while the hero occupied
  `(15,14)` temporarily removed that slot and shifted generic merchant labels;
  moving off the cell restored the NPC and normalized `Radish Merchant`,
  `Tool Merchant`, and `Weapons Merchant`, so no label source change was made.

- 2026-07-09 Cantlin Tool Merchant completion and Merchant 7 pass after reload:
  clean baseline was Cantlin `(10,5)`, all five doors open, menu/dialogue
  closed, and no runtime blocks. Same-origin `probe_edge_verify:...,3`
  confirmed `(7,6).east` and `(9,6).west`; with both mirrored live, the
  Tool Merchant stand `(5,12)` routed to the practical entrance `(15,1)`
  and the reverse entrance-to-stand route also completed. A targeted Merchant
  3 survey reached adjacent once, but the merchant is mobile
  (`move=0xEE`) and wandered before TALK, so no role was promoted.
  Merchant 7 is stationary at `(27,26)`. A focused route to public stand
  `(25,26)` promoted verifier-clean `(23,21).east`,
  `(24,22).north`, `(25,22).north`, `(26,22).north`, and
  `(27,24).north`; the route then completed. TALK from `(25,26)` facing
  east opened `We deal in weapons and armor...`, so `objects.lua` now
  labels Merchant 7 as `Weapons Merchant` with that fixed counter stand.
  Current live checkpoint: `(25,26)`, NPCs frozen, menu/dialogue closed,
  `RUNTIME_BLOCKS map=0x0A count=7` mirroring this pass. Reload
  `main.lua` before judging the new source blockers and Merchant 7 label
  without the runtime overlay. Best next check: route from Merchant 7's stand
  back to entrance `(15,1)`, then validate the full entrance-to-Merchant 7
  route after the reload.

- 2026-07-09 Cantlin Tool Merchant return-to-entrance pass after the user's
  reload: baseline confirmed the Tool Merchant label/stand source was live
  (`Services -> Tool Merchant`, object `(7,12)`, interaction `(5,12)` facing
  east). Route work from the Tool Merchant side back toward the practical town
  entrance `(15,1)` promoted a large verifier-clean hidden-wall batch, all via
  same-origin `probe_edge_verify:...,3` with `classification=confirmed_blocked`,
  `moved=0 blocked=3`, no drift/map change/interruption: `(6,1..4).west`,
  `(6,5).west`, `(6,6).south/west`, `(7,4).south`, `(7,7).south/west`,
  `(9,2).east`, `(9,3).east`, `(9,4).east/south`, `(10,1).south`,
  `(10,6).east/north`, `(10,7).east`, `(11,1).south`,
  `(11,4).north/west`, `(11,8).north`, `(12,1).south`,
  `(12,4).north/south`, `(12,8).north`, and `(13,2).west`,
  `(13,3).west`, `(13,5).west`, `(13,6).west`, `(13,7).west`. Current live
  checkpoint: Cantlin `(10,5)`, NPCs frozen, menu closed, no dialogue/merchant
  state, current-pass runtime overlay `RUNTIME_BLOCKS map=0x0A count=25`.
  Source tests pass, but FCEUX needs a manual `main.lua` reload before these
  newest source blockers are live without the runtime overlay. Next pickup:
  after reload, retry `auto_walk_blocker:15,1`; without reload, the current
  runtime overlay already mirrors this batch.

- 2026-07-09 Cantlin Merchant 5/6 follow-up after the user's reload:
  Merchant 5 at `(2,12)` is a non-service `Radish Merchant`; TALK from
  `(4,12)` facing west produced only the radish dialogue, and
  `debug_route_frontier_skip_npcs:2,13,30` found `hidden_bridge_candidates=0`.
  Merchant 6 at `(7,12)` is now live-confirmed as the `Tool Merchant`.
  Adjacent routing to Merchant 6 deliberately collapsed after verifier-clean
  blockers were modeled, and `debug_route_frontier_skip_npcs:7,12,40` found
  no hidden bridge into the adjacent pocket. Counter-stand probes then showed
  `(9,12)` facing west and `(7,14)` facing north both return `There is no one
  there`, while `(5,12)` facing east opens the tool-shop prompt:
  `Welcome. We deal in tools. What can I do for thee?` `objects.lua` now
  labels `Merchant 6` as `Tool Merchant` and routes it to `(5,12)` facing
  east. This pass promoted additional same-origin `probe_edge_verify:...,3`
  Merchant 6 blockers: `(8,13).east`, `(6,11).north/west`, `(8,13).south`,
  `(7,13).south`, `(6,12).west`, and `(6,13).west/south`. The earlier
  Merchant 6 source blockers from this pass remain `(14,11).east`,
  `(7,11).north/west`, `(15,12).north`, `(8,12).east`, and `(8,11).east`.
  Passive upper-dialogue contamination from command/status overlays, e.g.
  `COMMAND BillTALK ... LV 16`, is also patched in source: when lower dialogue
  is visible, `main.lua` now stores the clean lower text as the processed upper
  marker via `text.upper_marker_for_lower_dialogue`. Current live checkpoint:
  Cantlin `(5,12)`, NPCs frozen, command menu closed, no lower/merchant
  dialogue active, runtime overlay `RUNTIME_BLOCKS map=0x0A count=5` for
  `6,11(north,west)`, `6,12(west)`, `6,13(south,west)`,
  `7,13(south)`, and `8,13(east,south)`. FCEUX needs a manual `main.lua`
  reload before the new source blockers, Tool Merchant label/stand, and upper
  dialogue marker fix are live. After reload, select Services and route to
  `Tool Merchant`; it should use `(5,12)` facing east.

- 2026-07-09 Cantlin Merchant 5 route pass resumed after the user reloaded
  `main.lua`. Reload baseline confirmed `POSITION map=0x0A(Cantlin) x=8 y=6`,
  all five opened door slots, menu closed, and `RUNTIME_BLOCKS map=0x0A none`,
  proving the previous source blockers were live. The route toward Merchant 5
  at `(2,12)` then promoted same-origin `probe_edge_verify:...,3` blockers
  `(8,11).north`, `(2,11).north`, `(3,11).east`, `(3,12).east`,
  `(3,13).east`, `(3,14).east`, `(3,15).east/south`, and `(2,15).south`.
  A continuation from `(3,16)` then promoted `(1,16).east`, `(1,17).east`,
  `(2,18).north`, `(3,18).north`, `(4,18).north`, `(3,11).north`,
  `(1,11).north`, `(5,15).north`, `(6,15).north`, and `(7,15).north`. Current
  reload pass from `(7,14)` promoted `(8,15).north`, `(8,18).east`,
  `(1,18).south`, `(2,18).south`, `(3,18).south`, `(5,18).south`, and
  `(4,18).south`, all with same-origin `probe_edge_verify:...,3`
  `classification=confirmed_blocked`, `moved=0 blocked=3`. Current live
  checkpoint: Cantlin `(4,19)`, NPCs frozen, menu closed, and current-pass
  `RUNTIME_BLOCKS map=0x0A count=7` for the newest source-only edges. The
  latest parked-NPC planner still has a Merchant 5 route to stand `(2,13)`:
  `2 east, 1 north, 5 west, 5 north, 1 east`, facing north toward Merchant 5
  at `(2,12)`. Next pickup can reload `main.lua` to absorb this batch, then
  run `auto_walk_blocker:2,13` from `(4,19)`; without a reload, the live
  runtime overlay already mirrors the newest continuation batch.

- 2026-07-09 Cantlin service-route follow-up resumed after the user reloaded
  `main.lua`. Fresh baseline from Cantlin `(24,4)` had all five opened door
  slots, `RUNTIME_BLOCKS map=0x0A none`, and Merchant 2 / `Weapons Merchant`
  at `(22,6)` still produced `No path found`; the frontier check again found
  no hidden bridge candidates into the merchant-side component. The route back
  to the practical entrance `(15,1)` promoted `(16,1).east`, and the current
  Merchant 1 hunt promoted verifier-clean blockers `(6,5).east`,
  `(7,6).north`, `(8,4).south`, `(9,6).north/south`, `(10,7).west`,
  `(10,8).south/west`, `(11,4).south`, `(11,8).south`, and `(12,8).south`.
  With those blockers mirrored into runtime, the live route chain completed
  from the entrance-side work through `(8,5)`, down to row 9, west to `(4,9)`,
  then back to stand probes `(8,7)` and `(8,6)`. Merchant 1 kept wandering
  during coordinate-stand attempts, ending frozen at `(12,5)`, so no shop
  prompt or durable role label was promoted for Merchant 1. Current live
  checkpoint: hero at Cantlin `(8,6)`, NPCs frozen, menu closed, current-pass
  runtime overlay `count=10` cells with `(9,6)` carrying both `north` and
  `south`. Reload `main.lua` before relying on the new source-only blockers if
  the runtime overlay is cleared. Best next work: use object-selected autowalk
  or a targeted survey for moving Merchant 1, or pivot to static service NPCs
  such as Merchant 5 / Merchant 6 / Merchant 7 / Merchant 3.

- 2026-07-08 Cantlin service decoding began from the user's all-doors-open save
  state. Baseline confirmed map `0x0A`, all five opened door slots
  `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`, and no runtime blocks.
  The first completed service route is from the practical entrance tile
  `(15,1)` to `Merchant 4`'s interaction tile `(8,5)`: with the patched static
  blockers, the route detours through row 9 and reaches `(8,5)`. TALK from
  `(8,5)` facing north opened the live Inn prompt: `Welcome to the traveler's
  Inn. Room and board is 100 GOLD per night.` `objects.lua` now labels that
  NPC as `Inn` with the same counter-style service format used by other towns.
  Merchant 2 route work also produced live TALK proof for the weapons/armor
  prompt from adjacent contact, so `objects.lua` now labels `Merchant 2` as
  `Weapons Merchant` while keeping adjacent-NPC routing; the entrance-to-
  Merchant 2 route is still incomplete. Promoted verifier-clean Cantlin
  service-route blockers in `map_reader.lua` now include the earlier
  `(13,1..8).east`, `(16,1).west`, `(18,3).east/south/west`,
  `(18,6).east/north/west`, `(19,2).north/south`,
  `(20,2).north/south`, `(21,2).north`, and `(21,3..6).west` set plus the
  post-reload follow-up edges `(18,2).north/west`, `(18,7).south/west`,
  `(19,7).north/south`, `(20,7).north/south`, `(21,7).south`,
  `(22,2).north`, `(22,7).south`, `(23,2).east/north`,
  `(23,3).east`, `(23,4..6).east`, and `(23,7).east/south`, with
  regression coverage in `test_map_reader.lua`. Current live checkpoint:
  hero at Cantlin `(24,4)`, menu closed, Merchant 2 / `Weapons Merchant`
  frozen at `(22,4)`, and `RUNTIME_BLOCKS map=0x0A count=12` mirroring
  source edits made after the last manual reload. `debug_route_frontier_skip_npcs:22,5,80`
  from `(24,2)` found no untested bridge into the merchant-side component, and
  TALK from `(24,4)` facing west while Merchant 2 was held at `(22,4)` returned
  `There is no one there`. Do not promote a fixed Weapons Merchant counter
  stand yet; either reload `main.lua` to absorb the source blockers and resume
  with a fresh moving-NPC route, or pivot to the next Cantlin service route.

- 2026-07-07/08 Cantlin door decoding resumed from a clean live baseline:
  `POSITION map=0x0A(Cantlin) x=20 y=22`, `DOOR_STATE keys=6 slots=none`,
  and `RUNTIME_BLOCKS map=0x0A none`. Four western-shop door hypotheses were
  verified with the non-teleport `verify_door_stand` workflow and all were
  clean negatives: stand `(5,12)` facing right expected `(6,12)`, stand
  `(5,12)` facing up expected `(5,11)`, stand `(4,12)` facing up expected
  `(4,11)`, and stand `(4,12)` facing right expected `(5,12)`. Each manual
  OPEN produced "There is no door here", `verify_door_after` logged
  `expected_present=false`, keys stayed `6 -> 6`, and door RAM stayed empty.
  A tentative eastern-building candidate `verify_door_stand:25,13,UP`
  repeatedly failed to ready because walking to `(25,13)` churned around
  timing-sensitive edges, especially near `(22,15)->UP`; it was manually
  stopped with no runtime blocks and door RAM still empty. The actual eastern
  building door was then confirmed at cell `(26,9)`: `verify_door_stand:25,9,RIGHT`
  readied at the public west stand, manual OPEN played the door sound, and
  `verify_door_after` logged `expected_present=true`, keys `6 -> 5`, and
  opened-door RAM `0=(26,9)`. The central right door was then confirmed at
  cell `(15,25)`: `verify_door_stand:15,24,DOWN` readied at the north stand,
  manual OPEN played the door sound, and `verify_door_after` logged
  `expected_present=true`, keys `5 -> 4`, and opened-door RAM
  `0=(26,9) 1=(15,25)`. The central left door was then confirmed at cell
  `(14,25)`: `verify_door_stand:14,24,DOWN` readied at the north stand,
  manual OPEN played the audio message, and `verify_door_after` logged
  `expected_present=true`, keys `4 -> 3`, and opened-door RAM
  `0=(26,9) 1=(15,25) 2=(14,25)`. After the app restart, the pending manual
  OPEN at `(4,20)` was recovered with `verify_door_after`: stand `(4,20)`
  facing south confirmed western-shop north door cell `(4,21)`, keys `3 -> 2`,
  and opened-door RAM slot `3=(4,21)`. The final guide-backed western-shop
  east door was then confirmed from stand `(7,25)` facing east:
  `verify_door_after` logged `expected_present=true`, keys `2 -> 1`, and
  opened-door RAM slot `4=(8,25)`. `map_reader.lua` now models all five
  Cantlin door-icon cells in `MAP_DOOR_CELLS[0x0A]`: `(26,9)`, `(15,25)`,
  `(14,25)`, `(4,21)`, and `(8,25)`. `objects.lua` exposes
  `door_26_9` as `Eastern Building Door`, `door_15_25` as `Central Right
  Door`, `door_14_25` as `Central Left Door`, `door_4_21` as
  `Western Shop North Door`, and `door_8_25` as `Western Shop East Door`.
  Focused map/object tests pass. Current live state after verification:
  Cantlin `(7,25)`, keys 1, door RAM
  `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`, no runtime blocks, and
  input byte `buttons=0x00`. FCEUX needs a manual `main.lua` reload before the
  latest source-side door object/path data is live.

- Earlier FCEUX source-level input debugging is summarized below, but current
  active work has returned to Cantlin door/service decoding. A focused handoff
  for the PowerShell/Windows build remains in
  `work_notes/fceux_input_debug_handoff.md`.
- FCEUX `v2.6.6` was cloned to `/mnt/d/modding/fceux-input-debug`
  (`D:\modding\fceux-input-debug`) on branch
  `codex/input-hardlock-diagnostics`. It contains opt-in trace instrumentation
  behind `FCEUX_DW_INPUT_TRACE=1` for Qt key/gamepad input, Lua input masks,
  core gamepad merge, `$4016` strobe/serial reads, savestate load boundaries,
  and watched CPU/Lua RAM writes for `$0038-$004F` including `$0047`
  `BUTTONS_PRESSED`.
- Build is complete. The diagnostic binary is
  `D:\modding\DragonWarrior1\.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`
  with SHA256
  `D3AEBB34138EF9FC026FAF8F90BEF9867B3434AAF6B3948474359A1D7B6A520F`.
  It was built with VS 2022 Build Tools, Qt `5.15.2 win64_msvc2019_64`,
  SDL2 `2.24.1`, and locally built libarchive `3.6.2`; the deployed `bin`
  folder contains the needed Qt/SDL/libarchive DLLs. Trace strings such as
  `QT_KEY`, `LUA_READ_JOYPAD`, `READ_GP`, `RAM_WRITE`, and `LUA_MEM_WRITE`
  are embedded in the executable. Default RAM-write tracing is now quiet: it
  logs `$0047` / `BUTTONS_PRESSED` only when the old or new byte is nonzero or
  the byte changes; the broad `$0038-$004F` stream requires
  `FCEUX_DW_INPUT_TRACE_VERBOSE=1`.
- 2026-07-07 quiet-trace repro showed the direct `.tools` launch was using a
  separate `.tools\fceux-build-tools\build-fceux\bin\fceux.cfg` with native
  keyboard-backed `GamePad.0` still enabled. `survey_target:Old Man 4,park_npcs`
  reproduced at Cantlin `(24,23)`: Lua forced `0x10` for movement, FCEUX
  `QT_GAMEPAD` supplied raw `pads=[01,00,00,00]`, and the merged input became
  `$0047 buttons=0x11`, opening the command menu. There was no nearby `QT_KEY`
  event in the trace tail, so treat this as stale native keyboard GamePad.0
  state being ORed with Lua automation.
- A later direct restart/reload proved that hand-editing the `.tools`
  `fceux.cfg` is not durable enough: after FCEUX came back up, the same file
  again showed `SDL.Input.GamePad.0.DeviceType = Keyboard`,
  `SDL.ToggleMenu = 0`, `SDL.Hotkeys.MainMenuHide = Alt+/`, and
  `SDL.Hotkeys.FullScreen = Alt+Return`. Command polling and the Cantlin state
  were healthy, but the native keyboard path was active again. For the next
  clean repro, launch the diagnostic binary through `launch_dw.ps1 -FceuxPath`
  so the launcher applies its mitigations immediately before startup, or add a
  source-level trace/guard that names or suppresses the `DTestButton` source.
- 2026-07-07 launcher-run diagnostic update: launching through `launch_dw.ps1`
  preserved the `.tools` runtime config while FCEUX was running
  (`DeviceType = None`, `ToggleMenu = 1`, Alt menu/fullscreen hotkeys blank).
  The old raw native `A` merge did not recur, but
  `survey_target:Old Man 4,park_npcs` still aborted at Cantlin `(25,23)` on a
  queued-route `DOWN` timeout with `$0047 buttons=0x20`. The FCEUX trace showed
  raw host input stayed `0x00`; Lua had forced `Down`, FCEUX delivered it
  through `$4016`, and Dragon Warrior left `$0047` latched until Lua cleanup.
  This is a self-injected route-block timing false positive, not the same raw
  `GamePad.0` config bug. `debug_tools.lua`, `map_survey.lua`, and
  `route_manager.lua` now allow only timing-suspect `route_blocked` events
  whose game byte exactly matches the just-injected direction, logging
  `INPUT_CONTAMINATION_IGNORED ... reason=route_blocked_self_input`; other
  idle/startup/wrong-button contamination still aborts. FCEUX needs a manual
  Lua script reload before this refined behavior is live.
- Post-reload/save-restore retest confirmed that refined guard live: the
  first `(25,23)->DOWN` queued-route timeout logged
  `INPUT_CONTAMINATION_IGNORED ... reason=route_blocked_self_input` and
  continued. The follow-up seam retry still wedged at `(25,23)` with
  `$0047=0x20`; auto-clear made `$0047=0x00`, and manual
  `reset_movement_state` made `$003C/$003D=0x00/0x00`, but raw injected
  `A` still did not open the field menu. The FCEUX trace showed
  `LUA_READ_JOYPAD output=0x01` / `UPDATE_INPUT joy=[01,00,00,00]` during
  the raw-A windows, with no matching `B4016`, `STROBE_GP`, `READ_GP`, or
  `JPREAD` in that tail segment. Current best evidence: the FCEUX/Lua input
  merge is delivering `A`, but the ROM is not polling `$4016` while wedged.
  `report_cpu_state:fceux_wedged` then caught the ROM at `$B9F8`/`$B9ED`.
  ROM bank 0 decodes this as a sprite-OAM clear loop that loads `Y` from
  `$004E`, writes `0xF0` to `$0200,Y`, adds 4, and exits only when `Y==0`.
  The wedged state had `$004E=0x2A`, which can never reach zero by adding 4.
  Follow-up added `report_oam_offset[:TAG]` and a quiet
  `watch_oam_offset[:on|off|status|TAG]`. A first live arm proved `$004E` is
  too hot for per-write logging, so verbose output is now separated as
  `watch_oam_offset_verbose[:TAG]` for tiny captures only. After a manual Lua
  reload, restore the clean Cantlin save state if needed, arm quiet
  `watch_oam_offset:repro`, and reproduce
  `survey_target:Old Man 4,park_npcs` to catch `OAM_OFFSET_STUCK` with the
  recent `$004E` write context.
- Quiet watcher follow-up caught the bad writer context: the stuck value
  `$004E=0x2A` maps to NPC object-table slot 14 (`0x2A / 3`), and the recent
  writer was the ROM's object draw path (`STX $4E` at `$B970`, logged after the
  write as `pc=0xB972`). The root cause is the mod parking non-target NPCs at
  low coordinate `(31,31)`: Dragon Warrior only skips renderer slots whose low
  x/y coordinate bits are `(0,0)`, so `(31,31)` still renders and can leave a
  non-multiple-of-4 object offset in `$004E` before the OAM clear loop. Source
  mitigation changed survey and autowalk NPC parking to low coordinate `(0,0)`
  while preserving high sprite/direction bits.
- Post-fix clean validation passed after the user restored the Cantlin save
  state: baseline was `(20,22)`, `$0047 buttons=0x00`, and `$004E=0x60`
  with `aligned=true` / `reaches_zero=true`. Re-running
  `survey_target:Old Man 4,park_npcs` produced no `OAM_OFFSET_STUCK`
  (`watch_oam_offset:status` stayed at `stuck_reports=0`) and controls did not
  hard-lock. The remaining failure is route geometry/churn, not the FCEUX/OAM
  input wedge. Nine live-confirmed Cantlin seams were promoted to
  `MAP_DIRECTIONAL_BLOCKS[0x0A]`: `(21,23).west`, `(21,24).west`,
  `(21,24).east`, `(21,24).south`, `(22,23).south`, `(23,24).west`,
  `(23,25).west`, `(23,25).south`, and `(24,24).south`. The first post-reload
  check proved the prior eight seams were live (`RUNTIME_BLOCKS map=0x0A none`)
  and exposed/confirmed `(24,24).south` as seam 9. FCEUX needs one more manual
  `main.lua` reload before the latest `map_reader.lua` data is live; after
  reload, confirm no runtime blocks remain before rerunning the Old Man 4
  check.

## Current State

- Cantlin town decoding has started, but the first parked-NPC survey exposed a
  boxed engine pocket and should not be treated as clean permanent map data.
  Fresh command polling was verified, baseline was Cantlin `map=0x0A` at
  `(20,24)` with `keys=6` and no runtime blocks, and
  `report_survey_start:park_npcs` was viable with 20 reachable targets. Survey
  run 1 reached `Merchant 1` and `Guard 2`, then stalled on `Old Man 4`
  `(22,22)` and was manually stopped. After recovery from FCEUX LeftAlt/input
  latch and a movement-state reset, clean same-origin probes from the stopped
  tile `(25,23)` showed all four exits blocked despite open static previews:
  left to `(24,23)`, down to `(25,24)`, up to `(25,22)`, and right to
  `(26,23)`. Runtime blocks used during the check were cleared; final live
  state was Cantlin `(25,23)`, no runtime blocks. A later hard-lock
  investigation showed Lua command polling and `qfceux` were still alive and
  the keyboard bridge was neutral, but FCEUX/Lua still reported stable stale
  `LeftAlt` and game input RAM stayed at `buttons=0x20`; treat movement
  evidence from that live state as contaminated. Follow-up recovery attempts
  showed `recover_fceux_input.sh` can clear the stale Alt report temporarily,
  but `clear_input` and raw `START`/`B` did not clear `buttons=0x20`; no Codex
  relaunch was attempted because `SDL.AutoResume = 0` and no current Cantlin
  quickslot was obvious. Follow-up source guardrail: `probe_edge`,
  `probe_edge_verify`, and seeded edge probes now refuse to start when Lua joy
  and the bridge are idle but game input RAM still reports a held button; after
  reload, focused unit tests passed and `launcher_probe:codex_guard_reload`
  confirmed the live script. The replay started clean at Cantlin `(20,22)`
  (`buttons=0x00`, no runtime blocks) and survey preflight was viable with 21
  reachable targets, but `survey_objects:park_npcs` immediately looped on
  `Old Man 4` with movement-start twitches timing out in all four directions
  from `(20,22)`. `inspect_move:20,22,UP/DOWN/LEFT/RIGHT` reports all four
  destinations passable, and recovery cleared stale `LeftAlt`, but a small
  post-recovery `simulate_input:RIGHT` still only twitched and left the hero at
  `(20,22)`. Treat the replay's `(19,22)`, `(21,22)`, `(20,21)`, and `(20,23)`
  blocker candidates as contaminated/do-not-promote. Manual recovery replay:
  after the user verified movement and reloaded Lua, command polling was live,
  baseline at `(18,24)` was clean, and `auto_walk_blocker:19,24` successfully
  moved east to `(19,24)` via seam retry. The next parked-NPC survey again
  routed toward `Old Man 4`, returned to the `(25,23)` pocket, and reproduced
  the stale game input byte (`buttons=0x20`) while Lua/bridge input were idle.
  The new guard worked live: `probe_edge:LEFT` refused with
  `EDGE_PROBE_ABORT reason=input_contaminated ... buttons=0x20`; standard
  `recover_fceux_input.sh` still did not clear that byte. Follow-up source
  guardrail now shares that contamination detector with survey and auto-walk:
  surveys refuse at startup, abort on tick/route events without recording
  candidates, and auto-walk refuses before planning or rerouting before seam
  observations are recorded. Live retest after save-state restore exposed one
  false positive: survey tick treated normal active `auto_step` injected
  movement as contaminated because `$0047` was briefly nonzero while
  joy/bridge were idle. `map_survey.lua` now skips the tick-time contamination
  check while `auto_step.get_active_step_state()` is active; startup,
  route-event, and auto-walk block guards still apply. FCEUX needs a manual Lua
  reload before this refined live behavior is active. After reload, a fresh
  baseline at Cantlin `(20,21)` was clean (`buttons=0x00`, no runtime blocks),
  and the refined tick guard allowed active movement/rerouting to proceed
  instead of aborting on normal injected movement. The survey still eventually
  locked during `Old Man 4` seam-retry exploration: it stopped at `(23,26)`
  with Lua joy/bridge idle but game input RAM stuck at `buttons=0x80`; standard
  `recover_fceux_input.sh` did not clear the byte. Next recommendation: do not
  continue surveys or edge probing from `(23,26)` or `(25,23)` until a fresh
  manual recovery/save-state restore clears the stuck game input byte; after
  recovery, avoid treating the `Old Man 4` route churn as Cantlin geometry
  until the emulator lock source is understood. A narrower
  `survey_target:Guard 2,park_npcs` from restored `(20,22)` then exposed one
  more tick-guard timing false positive: immediately after a queued step
  completed, `$0047` briefly read `buttons=0x80` while the route was still
  active but no individual step was active; a follow-up snapshot at `(22,8)`
  was clean (`buttons=0x00`, no runtime blocks). `map_survey.lua` now also
  skips tick-time contamination checks while `auto_step.is_route_active()` is
  true. After reload, `launcher_probe:codex_after_reload_20260705` confirmed
  command polling and a clean Cantlin `(20,22)` baseline (`buttons=0x00`, no
  runtime blocks). Retrying `survey_target:Guard 2,park_npcs` no longer
  false-aborted on route-active input bytes, but it entered runaway route churn
  toward the top-wall guard approach and was manually stopped at `(12,5)` after
  69 blocked events / 43 temporary route blocks. Post-stop state was healthy:
  Cantlin `(12,5)`, `buttons=0x00`, no runtime blocks, no active path. Treat
  the large `Guard 2` suspected-tile list as route-churn diagnostic noise, not
  promotable map geometry. Follow-up source guardrail: `map_survey.lua` now
  caps one target at more than 32 route-block events, logs
  `SURVEY_ROUTE_CHURN_ABORT`, cancels the active route, restores/finishes the
  survey, and classifies the capped target as `command_timing_or_state_issue`
  so the evidence stays review-only. After the user reloaded Lua,
  `launcher_probe:codex_churn_reload_20260705` confirmed the new code was live
  from a clean Cantlin `(20,22)` baseline. A focused
  `survey_target:Guard 2,park_npcs` succeeded against the currently moving
  guard at `(24,10)`, ending adjacent at `(23,10)` with one reroute-only
  suspect `(21,11)`; do not promote that by itself. A broad
  `survey_objects:park_npcs` attempt from `(23,10)` produced no target data
  because a command menu/dialogue was open, then `stop_survey` restored all 19
  parked NPCs and `simulate_input:B` closed the menu. A focused
  `survey_target:Old Man 4,park_npcs` reproduced the real FCEUX contamination
  before the route-churn cap could fire: at `(23,26)`, while still under the
  cap, Lua/bridge input were idle but game input RAM stuck at `buttons=0x80`.
  The survey and auto-walk guards refused, restored all 19 NPCs, recorded no
  target results/candidates, and left no runtime blocks or active path.
  `recover_fceux_input.sh` did not clear `buttons=0x80`; current live state is
  contaminated at Cantlin `(23,26)`. Next recommendation: restore a clean save
  state or otherwise clear the stuck button byte before any more Cantlin
  movement, survey, or edge probing. Follow-up reload/hypothesis check:
  `launcher_probe:codex_ram_hypothesis_reload_20260705` confirmed polling from
  a clean Cantlin `(18,23)` baseline (`buttons=0x00`), and a 180-frame idle
  input trace showed only benign stale `LeftAlt`. The recent overworld timing
  helpers can write movement RAM `$003C/$003D`, but code inspection found no
  direct writes to `$0047` / `BUTTONS_PRESSED`. A focused
  `survey_target:npc_18,park_npcs` reproduced the lock at frame `137384` on a
  queued-route `DOWN` from `(25,23)`: movement had twitched
  (`movement_started=true`, frame 4), then blocked after 36 frames, and the
  game input byte stuck at `buttons=0x20` while Lua/bridge input were idle.
  Guard cleanup restored all 20 parked NPCs, recorded no target evidence, and
  left no runtime blocks or active path. Manual `reset_movement_state` cleared
  `$003C/$003D` from `0x08/0x08` to zero but did not clear `$0047`; `clear_input`
  also left `$0047=0x20`. Next diagnostic: add a debug-only command or guarded
  recovery path that explicitly clears `$0047` so we can tell whether the game
  immediately relatches the byte or can recover without a save-state restore.
  Source follow-up added `clear_game_input` in `debug_tools.lua`: it reads
  `$0047`, writes `0x00`, re-reads the byte, and logs
  `GAME_INPUT_CLEAR before=... after=... addr=0x0047`. `debug_hooks.txt`
  documents the command and `test_debug_tools.lua` covers the exact one-byte
  write/log behavior. After a fresh emulator/script reload on 2026-07-06,
  `clear_game_input` was unit-tested and verified live from a clean Cantlin
  `(20,22)` baseline, logging `before=0x00 after=0x00`; the next
  `survey_target:npc_18,park_npcs` run hit the route-churn cap instead of
  reproducing stuck `$0047`, restored all 20 NPCs, and left Cantlin `(20,22)`
  with `buttons=0x00`, no runtime blocks, and no active path. Real recovery
  from a contaminated byte is still unproven until the stuck state recurs.
  A follow-up focused rerun again hit the route-churn cap cleanly, and a broad
  `survey_objects:park_npcs` run churned on `Old Man 4` until manually stopped
  at 28 timing-block events; it also left clean input/state, but its
  manual-stop suspected-tile list is diagnostic only and must not be promoted.
  Source follow-up: the shared input-contamination guard now logs
  `INPUT_CONTAMINATION_CAPTURE`, auto-clears `$0047`, logs
  `GAME_INPUT_AUTO_CLEAR`, opens a short raw-neutral
  `GAME_INPUT_AUTO_NEUTRAL` window, and emits a delayed
  `GAME_INPUT_AUTO_CLEAR_CHECK` sample; `map_survey.lua` also downgrades
  manual-stop route/churn evidence to `command_timing_or_state_issue` so
  manual stops do not generate promoted Cantlin blockers. A bridge-off live A/B
  still reproduced contamination at `(25,23)` on a queued-route `DOWN`; manual
  controls remained dead until the user restored a save state, after which
  `buttons=0x00`, no runtime blocks, and `bridge_override=off` were confirmed
  at `(25,23)`. Recovery from a real stuck byte remains unproven. FCEUX needs a
  manual Lua reload before the raw-neutral auto-clear behavior is live.
  Post-reload hard-lock testing showed a deeper failure mode: after
  `isolate_input:180`, `recover_fceux_input.sh`, and `reset_movement_state`,
  Lua still saw manual directions and raw injected `START`/`A`, but the hero
  did not move and neither injected nor physical controller `A` opened the
  normal field command menu. A later post-restore retest narrowed this further:
  the FCEUX trace showed raw injected `A` present in FCEUX (`joy=[01]`), but
  no `$4016` strobe/read events during the raw-A windows. This state is below
  the mod-visible input layers and appears to be the ROM not polling
  controller input. `report_cpu_state[:TAG]` is now implemented but needs a
  manual FCEUX Lua reload before use; next recovery after capture is
  save-state restore.
  Guide/reference notes are in `project_resources/maps/cantlin/`.
- Cantlin overworld approach reached the town in live FCEUX. From the validated
  western/southern trail, the final clean entry sequence was: clean re-baseline
  at World Map `(74,101)`, west carrying through `(73,101)` to `(72,101)`,
  south carrying through `(72,102)` to `(72,103)`, east carrying through
  `(73,103)` to `(74,103)`, short raw left nudge back to `(73,103)`, then
  same-origin `probe_edge:UP` from `(73,103)` triggered `map change -> 0x0A
  (Cantlin)` and landed in-town at `(15,0)`. No Golem encounter fired during
  this approach in the current save/state; regular Green Dragon/Werewolf
  encounters near `(79,101)`, `(77,101)`, and `(74,101)` were random battles,
  not the fixed boss. Detailed route evidence is in
  `work_notes/current_investigation.md`.
- Hauksness / Haukness / Damdara overworld guidance now uses the
  Garinham/western-continent route instead of the stale Tantegel/Rock Mountain
  Cave branch. Live FCEUX validation reached the destination: from the lower
  western lane `(15,93)`, `auto_walk_blocker:25,89` climbed to row 89, crossed
  east to `(24,89)`, then the single right step triggered
  `map change -> 0x03 (Ruins of Hauksness)` and route arrival at in-town
  `(0,10)`. The source route keeps the Kol-side opening through the known
  north road to `Erdrick's Cave road`, turns back through the Garinham connector,
  then follows the live-validated desert detours through `(5,4)`, `(15,28)`,
  `(29,82)`, `(15,93)`, `(15,89)`, and `(24,89)`. No fixed overworld boss
  triggered on entry; the tough Demon Knight / Wraith Knight / Knight fights
  observed near Hauksness behaved like random encounters. FCEUX needs a manual
  Lua reload before judging the patched source route live.
- Rimuldar / Remuldar Magic Key merchant access is live-resolved. The old
  `(1,8)->RIGHT` target was a false lead. From entry `(29,14)`, the intended
  normal route follows `x=29` north to `(29,2)`, crosses row 2 west to
  `(21,2)`, climbs to `(21,0)`, follows `y=0` west to `(0,0)`, descends `x=0`
  to `(0,3)`, and crosses the real far-left bridge `(1,3)->(2,3)`. At `(1,0)`,
  turn LEFT into `(0,0)` and then DOWN; entering `x=0` horizontally below the
  top row exits to the World Map. Fixed `Person 4` at `(27,0)` blocks the
  tempting full-top-row route: a normal self-review pass crossed through
  `(26,0)`, then `(26,0)->RIGHT` timed out with `npc_blocked=true`. Fixed
  `Merchant 1` at `(2,4)` is bypassed through
  `(3,3)->(4,3)->(5,3)->(5,4)->(5,5)->(4,5)`. `Old Man 1` remains the Magic
  Key seller at `(4,7)`, but the real public TALK stand is `(4,5)` facing south
  across impassable counter `(4,6)`, not `(4,6)`. Live TALK opened the 53 G
  Magic Key prompt; it was cancelled cleanly. The follow-up route audit
  returned the hero to Rimuldar entry `(29,14)` with six keys, menu/dialogue
  closed, and `RUNTIME_BLOCKS map=0x0B none`. Those source gaps were
  subsequently repaired and source-only live verified; use the current
  Immediate FCEUX Handoff above for active route status.
- Garin's Grave / Grave of Garinham route decoding is complete for current
  playtesting needs.
- The detailed final Garin's Grave wrap-up was archived to
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_wrapup_full.md`.
- The detailed scratchpad evidence was archived to
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_scratchpad.md`.
- Garinham grave-return stairs now have a verified escape to the inn by
  leaving town and re-entering from the world map. The old `(19,10)` lower
  bridge was verifier/teleport fallout and is no longer modeled as a
  passthrough. A later manual route check found the return-side top-edge bypass:
  `(12,0)->RIGHT` enters `(13,0)`, `(13,0)->RIGHT` enters `(14,0)`, and
  `(14,0)->LEFT` returns to `(13,0)`. Follow-up grave-stairs route polishing
  proved the row-0 bypass continues one step farther via `(14,0)->RIGHT` into
  `(15,0)`, then descends through `(15,1)` and reaches the grave stairs at
  `(19,0)` along row 1. `map_reader.lua` now models `(13,0)`, `(14,0)`, and
  `(15,0)` as Garinham passthrough cells, preserves `(14,1)` as blocked from
  north/east/west, and closes the false shortcut edges exposed from `(9,3)`
  onward, including the post-reload `(6,7)->UP` and `(3,7)->UP` cleanup. Reload
  `main.lua` in FCEUX before judging the live planner against this source fix.
- Garinham `Grave Route Door` now preserves both verified interaction sides:
  north-side `(17,9)` facing south from the grave-route component, and
  public-side `(17,11)` facing north toward closed door cell `(17,10)`.
  `objects.lua` exposes them through `interaction_points` so the existing
  alternate-stand route planner can choose the reachable side after a full
  FCEUX Lua reload. This fixes object routing to the door stand, but does not
  prove a clean route onward to the grave stairs.
- Garinham's inner locked-building door is now modeled at `(4,6)` with object
  stand `(4,7)` facing north. It leads to a one-cell guard pocket at `(4,5)`;
  `(4,5)->UP` is blocked as `(4,4).south`, and the side exits are stationary
  guards, so do not treat it as a grave-route shortcut without new event proof.
- FCEUX remains the normal gameplay and agent-driven runtime for this repo.
  BizHawk is still useful for explicit automation/debug/reload/profiling work,
  but it is not the default route-testing runtime.
- FCEUX native Player 2 hotkeys were tried and preserved on local branch
  `codex/fceux-player2-buttons` as commit `1c63fea`; do not treat that branch
  as merge-ready. Live testing proved the Lua probe could log `joy2=...`, but
  native `GamePad.1` did not expose spare controller buttons as Player 2 input
  even after editing `D:\emulation\fceux\bin\fceux.cfg`. Next likely path is a
  bridge-based fallback instead of native FCEUX Player 2 mapping.
- Brecconary Magic Key cleanup is complete for current alpha-prep playtesting.
  The inn west-room door is now
  live-confirmed at door cell `(5,23)`, opened from `(6,23)` facing west; the
  old `(5,22)` model is a ghost. The opened-door side uses passthrough
  `(3,23)`, blocks false west exit `(3,23)->WEST` as `(2,23).east`, and keeps
  `(8,23)->UP` blocked as `(8,22).south` after restored-route autowalk plus a
  same-origin raw probe timed out. The old `(7,21).west` one-way block was
  stale: `verify_walked_edge:6,21,right` crossed `(6,21)->RIGHT`, and
  `auto_walk_blocker:1,15` then reached the entrance-side stand `(1,15)` from
  `(8,21)` via `4 north, 7 west, 2 north` with no runtime blocks left.
- Brecconary exit-tile object browsing needs the latest `route_manager.lua`
  reload before judging `reachable` pathability from `(0,15)`. Live state on
  map `0x08` showed `(0,15)` is a non-walkable engine-boundary tile even while
  the hero is standing there; old pathability flood-fill treated that as a
  one-tile component and exposed only `Exit to World Map`. The patch seeds the
  reachable set from adjacent walkable cells in that boundary-start case.
  Live workaround already applied: `pathability_filter:all` restored the full
  object list (`Exit to World Map: here (1 of 23)`).
- Brecconary Fairy Water routing is verified clean to and from the merchant.
  The seller
  is a moving Woman behind the northeast counter at `(24,3)..(24,5)`, but the
  live-confirmed trigger is fixed: route to `(22,4)` facing east and hold the
  target NPC briefly at `(24,4)`, not into the blocked pocket at `(23,row)` or
  to a same-row `(22,row)` stand.
  `map_reader.lua` now closes the fresh route/manual blockers around that
  counter: `(20,3).east`, `(20,5).east`, `(21,2).south`, `(22,2).south`, and
  `(23,3..5).west`. An earlier TALK test also captured a possible FCEUX input-lock
  state where Lua saw controlled `A` presses and command polling stayed alive,
  but the ROM did not open the field command menu. Treat that as a secondary
  diagnostic path only if the fixed `(22,4)` stand plus `(24,4)` target hold
  still fails after reload; `report_input_guard_state` is staged for that case.
- Kol Magic Key door discovery is now pinned in source. `Western Building Door`
  is door cell `(7,12)`, opened from `(8,12)` facing west; `West Side Door` is
  door cell `(1,14)`, opened from `(1,15)` facing north. The stale
  `(7,12).east` wall is removed because it was the closed door, while
  `(7,11).east` remains a real directional blocker. False checked candidates:
  `(1,13)` from `(1,14)` facing up, `(1,3)` from `(1,4)` facing up, and
  `(1,4)` from `(2,4)` facing left all produced no-door/no-key-delta results.
  Post-reload route validation now reaches both Kol door stands and returns to
  the town exit cleanly.
- Kol West Side Door route cleanup found that the old `(2,14)` stand was a
  stale model, not an unreachable required tile. The user manually reached
  `(1,15)`, pressed north, and the follow-up `DOOR_STATE` showed keys `0` with
  opened-door slot `1=(1,14)`, confirming the public stand is `(1,15)` facing
  north. The false route through `(3,18)->LEFT` is now closed, `(2,17)` is
  modeled as a real passthrough, and the remaining false exits are modeled:
  `(2,15).west`, `(2,16).south/west`, `(2,18).east/west`, plus `(4,14).east`
  and `(4,14).south`.
- Opened West Side Door return routing to the Kol exit is now clean in live
  FCEUX with the runtime overlay that was promoted to `map_reader.lua`.
  Starting from the opened-door side, same-origin probes closed
  `(2,10).south`, `(3,10).south`, `(4,11..13).west`, `(2,14).north/west`,
  and `(3,14).north`; with those edges active,
  `auto_walk_blocker:19,23` reached `(19,23)` and faced south.
- Kol route validation is clean for the current door/service set. The live
  FCEUX log shows route-complete autowalks to and back from `West Side Door`,
  `Western Building Door`, `Tool Merchant`, `Weapons Merchant`, and `Inn`;
  each return reached `Exit to World Map` at `(19,23)` and faced south. The
  validation sequence contains no `AUTO_WALK_BLOCKER_FOUND`, `AUTO_WALK: no
  path`, `reason=stop on blocker`, or `live_input_interrupt` lines.
- Kol Tool Merchant route polish promoted the current blocker batch in
  `map_reader.lua`: `(16,22).east`, `(1..4,10).north`, `(4,10..13).east`,
  `(7,9).west`, and `(7,13).east/west`. The current Tool Merchant identity is
  still valid from selected-teleport TALK proof at `(12,21)` facing east. A
  later manual route check found the missing public throat: `(1,16)->DOWN`
  enters `(1,17)`, even though `(1,17)` ROM-decodes as tile-0/non-walkable;
  once standing on `(1,17)`, the planner finds the Tool Merchant route again.
  The missing entrance-side connector to that throat is `(5,14)`: after a clean
  restore from the town entrance, `debug_route_frontier_skip_npcs` flagged
  `(5,14)/(6,14)/(7,14)` as wall-looking one-cell bridge candidates, and a
  normal walk to `(5,13)` plus same-origin `probe_edge:DOWN` moved through
  tile-0 `(5,14)` and settled at `(5,15)`. `map_reader.lua` now models only
  proven `(1,17)` and `(5,14)` as Kol passthroughs. The earlier post-`(1,17)`
  reload route also tried the standable `(1,19)` pocket; same-origin probes
  proved its east, south, and north exits blocked, so `(2,19).west`,
  `(1,20).north`, and `(1,18).south` are now directional blockers. Final
  entrance-to-stand cleanup found the lower public bridge: from normally walked
  `(3,15)`, `probe_edge:DOWN` carried through `(3,16)` onto tile-0 `(3,17)`,
  then `(3,17)->DOWN` exited to the target-side lane. `map_reader.lua` now
  models `(3,17)` as the narrow Tool Merchant bridge and closes the route
  false exits `(5,16).north`, `(2,15).east`, `(2,16).east`, `(3,14).south`,
  and `(10,19).west`; post-reload validation reached the stand from the town
  exit and returned cleanly. Do
  not promote the later post-teleport `(1,16)->DOWN` or `(1,16)->RIGHT`
  failures: even the ordinary east step to `(2,16)` falsely blocked from that
  seed, so the live movement state was contaminated. Kol also exposed stale
  lower-window status residue (`ll` / `Bill`) after movement, probe, and
  command-menu activity; `main.lua` now suppresses known passive status/name
  fragments during field play, command menu, and SPELL submenu while still
  respecting STATUS/ITEM submenus, prompts, and merchants, so `J/K/L/O`, edge
  probes, command-menu speech, and spell-list speech should not remain stuck
  behind those fragments. Reload `main.lua` before live-testing that dialogue
  guard fix. A follow-up held-ITEM menu bug was also fixed in `merchant.lua`:
  the merchant parser no longer treats full command-menu backdrop plus
  inventory entries, or status rows plus unpriced inventory entries, as a shop
  offer list, preventing `MERCHANT_SELECT` speech such as item names with bogus
  prices while browsing items. A later live attempt still produced
  `MERCHANT_SELECT` before any `CMD_ITEM_FIRE`; `check_command_menu()` now lets
  ITEM ownership run before merchant detection. After a full emulator restart,
  the remaining root cause was that the cursor-jump detector never fired before
  merchant ownership; the direct A press on confirmed ITEM(1,1) now sets
  `submenu_mode = "ITEM"` first, with the older cursor-jump detector retained as
  a fallback. A final follow-up fixed the remaining bulk inventory speech:
  after ITEM ownership worked, `check_dialogue()` still announced visible item
  rows as lower dialogue (`Silver Harp Cursed Belt Gwaelin's Love Torch`).
  STATUS and ITEM submenu windows are now absorbed by the generic lower
  dialogue reader because those screens are spoken from cursor/RAM state; SPELL
  still absorbs uppercase/no-lowercase spell-list rows but now lets lowercase
  spell-result dialogue announce if it appears before `submenu_mode` clears.
  A later manual Kol speech pass found two staged fixes in `main.lua`: field
  spell casts had only spoken MP deltas, and ITEM menu entry repeated the first
  item (`Items. Dragon's Scale` then `Dragon's Scale`). ITEM entry now remembers
  the first spoken item and suppresses only the matching delayed cursor update.
  Post-reload live verification confirmed RADIANT spoke its result dialogue
  (`Bill chanted the spell of RADIANT.` / `But nothing happened.`), and ITEM
  entry no longer immediately repeats the first item. A later Tool Merchant
  sell-list retest confirmed the full merchant summary no longer repeats on
  lower inventory rows; the game only renders Herb's sell price in-list, while
  other item prices appear in the confirmation dialogue.
  A later Kol wrap-up test found deferred `U` autowalk could start while the
  field command menu was visibly open because hotkeys ran before
  `check_command_menu()` armed `CMD.menu_live` for that frame. `main.lua` now
  blocks field movement on raw COMMAND text only when a visible cursor tile is
  present, and `hotkeys.lua` speaks the current guard reason when a deferred
  autowalk release is cancelled. Reload `main.lua` before live-testing these
  menu/parser/guard fixes.
- Tantegel Castle downstairs Magic Key merchant return polish is promoted in
  `map_reader.lua`: the merchant-to-throne-room-stairs route closed the false
  east/northeast cuts at `(22,6).north`, `(21,5).east`, `(21,4).east`,
  `(23,6).north`, `(23,9).north`, `(24,9).east`, `(24,10).east`,
  `(25,6).south`, `(17,6).south`, and `(15,5).east`. With those runtime blocks
  active, `auto_walk_blocker` reached `Stairs Up to Tantegel Castle Throne Room`
  at `(7,7)` via the west detour. Reload `main.lua` in FCEUX before judging the
  live planner against this source fix. The reverse route back to the Magic Key
  merchant then confirmed `(13,9).west` from `(12,9)->RIGHT` and `(19,6).west`
  from `(18,6)->RIGHT`; with both runtime edges active, `auto_walk_blocker`
  reached the merchant stand at `(24,3)`. The `(18,6)->DOWN` retry moved on seam
  retry and should stay open. The Magic Key merchant <-> main entrance route is
  also promoted: same-origin route/probe evidence closed `(18,14).north`,
  `(18,15).west`, `(23,2).south`, `(23,6).east`, `(25,6).north/west`,
  `(26,6).north/south`, `(27,6).east`, `(27,7).east/west`, and
  `(28,24..28).east`; with that runtime overlay, `auto_walk_blocker` reached
  the exit stand at `(11,29)` and returned to the merchant stand at `(24,3)`;
  the follow-up `(23,2).south` edge came from same-origin `probe_edge:up` at
  `(23,3)`.
  Reload `main.lua` before judging the live planner without those runtime
  blocks.
- Tantegel Castle downstairs Sun Shrine stairs route polish is promoted in
  `map_reader.lua`: same-origin route/probe evidence from the Sun Shrine-side
  lane confirmed the east approaches into `(27,9)`, `(27,10)`, and
  `(27,12)..(27,19)` are blocked from x=28. With those runtime edges active,
  `auto_walk_blocker:7,7` reached `Stairs Up to Tantegel Castle Throne Room`
  from `(28,19)`, and the reverse route `auto_walk_blocker:28,19` reached the
  Sun Shrine-side stand again. The x=28 vertical moves and the `(6,17)` west/east
  crossings moved on seam retry and should stay open. Reload `main.lua` before
  judging live planning without the runtime overlay.
- Sun Shrine map `0x0C` chest / old-man cleanup is promoted in `map_reader.lua`:
  route retries plus same-origin probes closed `(3,3).north/west`,
  `(3,4).east/west`, `(3,5).east/west`, `(3,6).west/south`,
  `(4,3).north/south`, `(5,3).north/south`, `(6,3).north/east`,
  `(6,4).east/west`, `(6,5).east/west`, and `(6,6).east`. With those runtime
  blockers active, a fresh `auto_walk_blocker:4,7` from the Tantegel stairs
  `(0,4)` reached the old-man stand through the x=2 lane, row 7 bypass, and
  east-side pocket, and `auto_walk_blocker:0,4` returned to the stairs through
  the lower bypass. The explicit `(2,2)->DOWN` recheck moved through `(2,3)`,
  `(4,5)->RIGHT` moved on route retry, and the x=2 vertical moves plus row-7
  bypass should stay open. Reload `main.lua` before judging live planning
  without the runtime overlay.
- Rain Shrine / Northern Cave map `0x0D` Staff of Rain return-route cleanup is
  promoted in `map_reader.lua`: same-origin route/probe evidence closed
  `(5,4)->UP` as `(5,3).south` and `(8,8)->DOWN` as `(8,9).north`. With those
  runtime edges active, `auto_walk_blocker:4,9` reached the exit at `(4,9)` via
  the row-8 bypass. The x=8 descent lane above row 9, the row-8 westbound lane,
  and `(4,9).north` moved and should stay open. Reload `main.lua` before
  judging live planning without the runtime overlay.
- Rain Shrine old-man object population is patched in `objects.lua`: re-entering
  from the world map, flipping from map-entry terrain into NPC terrain, or
  reloading the script while already inside Rain Shrine no longer treats the
  old man's already-known NPC signature as stale previous-map residue. He
  should appear after the normal one-frame deferred NPC refresh instead of
  waiting roughly 10-15 seconds. Reload `main.lua` before judging the live
  object browser against this source fix.
- Swamp Cave rescue branch is now live-confirmed through Gwaelin. Door cell
  `(5,20)` is open in slot `0`, Gwaelin is reached from `(5,19)` facing north
  toward `(5,18)`, the escort prompt was accepted, and final field state was
  map `0x15` at `(5,19)` with `combat=0x09`, `quest=0x40`, runtime blocks none.
  Object navigation now exposes Princess Gwaelin as a Swamp Cave NPC target
  before the escort bit, then hides her once `combat` bit `0x01` is set. Next
  gameplay step is escorting her back to Tantegel Castle.
- Swamp Cave known-route polish is promoted in `map_reader.lua`: the Gwaelin
  door / Princess route, south-stairs route, and return route to the North Exit
  now include the walked directional blockers found by `auto_walk_blocker` plus
  direct `probe_edge` checks. The live middle strip `(2,16)..(2,18)` is modeled
  as passthrough, and the latest return overlay reached `(0,0)` through row 21,
  `(2,13)..(2,8)`, and the x=0 corridor. Follow-up route polish from the x=0
  corridor back to the Princess stand confirmed `(2,12)->RIGHT` blocked into
  `(3,12).west`, then a north-exit route check confirmed `(3,13)->UP` blocked
  into `(3,12).south`; runtime-patched routes reached both `(5,19)` and
  `(0,0)`. Follow-up top-corridor polish confirmed `(0,2)->RIGHT` into
  `(1,2).west`, `(0,5)->RIGHT` into `(1,5).west`, the walked `(1,6)` pocket
  exits into `(1,5).south`, `(2,6).west`, and `(1,7).north`, plus
  `(0,7)->RIGHT` into `(1,7).west`. The next noisy route from `(3,4)` then
  confirmed `(3,5).north`, `(4,4).west`, `(2,6).north`, `(3,5).west`,
  `(2,3).south`, `(4,4).north`, and `(5,14).north`, while preserving
  `(0,8)->RIGHT` as the first open east re-entry; after combat cleared, the
  route reached `(5,19)`. Entrance-to-entrance polish then confirmed
  `(1,23)->DOWN` blocked into `(1,24).north`; with that runtime edge active,
  the north-exit-to-south-stairs route detoured through row 23, descended at
  x=3, and reached `(0,29)`.
  Static tests cover the south-stairs route, reverse route to the door stand,
  opened-door return route, and latest return blockers. FCEUX must reload
  `main.lua` before live planning reflects these source edits; the current live
  runtime overlay already contained the equivalent blockers during validation.
- A live FCEUX hang after `O` path preview plus close-timed D-pad taps left
  command polling stopped with no fresh `dw_script_error.log` entry. The fix
  debounces `O`, `R`, `U`, and `Shift+O` object/path route hotkeys by suppressing
  `auto_step` direction-edge tracking for 8 frames before planning/speech.
  A post-reload repro showed the ROM still accepted controller input while the
  Lua loop stopped, with the final repeated log line in
  `auto_step cancel manual_tap early-twitch wait`. `auto_step.lua` now avoids
  reissuing neutral `joypad.set` frames in that physical-tap cancel branch and
  applies a short direction-edge dampening window after the cancel, so rapid
  retaps are not converted into another synthetic manual step immediately.
  Later repros spoke `Wait for movement to finish`, which proved blocked
  object hotkeys were hitting the guarded object-control path during active
  movement. That path now suppresses nearby direction edges for any object
  hotkey blocked by the movement-settle guard, including blocked `O`, `U`, and
  `J/K/L`, but does not use the teleport-style controller suppression that
  pauses `auto_step.update` during active movement. It also logs/flushed
  `OBJECT_HOTKEY_BLOCKED` breadcrumbs if this still recurs. `test_hotkeys.lua`
  and `test_auto_step.lua` cover the allowed hotkey debounce, blocked-`O`,
  blocked-`U`, and blocked-`J/K/L` debounce without teleport suppression,
  manual early-twitch cancel cleanup, and rapid-retap dampening. A later
  dialogue repro stopped the Lua loop after blocked `K` spoke `Wait for dialogue
  to finish`, with no new `dw_script_error.log` entry and a timed-out
  `launcher_probe`. `hotkeys.lua` now also treats dialogue / upper-dialogue
  blocked object controls as lightweight direction-edge debounce only, avoiding
  teleport-style neutral `joypad.set` suppression during dialogue. The new
  `test_hotkeys.lua` regression covers blocked `K` during active dialogue. A
  follow-up live state capture showed the command menu was fully clear
  (`raw_open=false`, `active_block=false`) while lower dialogue remained stuck
  on compact status residue (`PREV.dialogue="BillG2234"`). `text.lua` now
  treats generic short-name-plus-`G`/`E` numeric fragments such as `BillG2234`,
  `IvyE1298`, and `RexG42` as passive status noise, so that residue cannot keep
  object controls blocked after dialogue/menu cleanup. A later post-dialogue
  upper-window repro spoke `MBill GLV  15` just before
  `UPPER_DIALOGUE_STALE_CLEAR`; the passive status classifier now also catches
  generic status-letter/name fragments followed by uppercase status-label
  clusters and numeric residue, e.g. `MBill GLV  15` and `MIvy GLV  15`.
  A dialogue timing pass then found north-edge NPC lines reaching final visible
  length roughly 4 seconds before speech; the row-1 lower dialogue reader now
  filters low-row passive status/name crumbs before they can reset the stable
  text timer. A later selected-teleport repro in Garinham stopped command
  polling after object browsing / selected teleport plus TALK, again with no
  fresh `dw_script_error.log` entry. FCEUX selected-object teleport hotkeys now
  pass `suppress_input=false`, and the shared teleport input suppressor skips
  immediate neutral `joypad.set` on FCEUX while preserving BizHawk behavior.
  Post-reload validation reached Guard 2 at `(3,4)`, completed the teleport
  guard, survived command-menu TALK attempts, and answered fresh launcher
  probes afterward. The user then manually verified selected teleport to Guard
  2 without a crash; this is one of Brecconary's key trap guards, so keep this
  as the important end-to-end FCEUX confirmation. FCEUX needs a manual Lua
  reload before these timing / teleport-input fixes are live.

## Garin's Grave Result

- The Silver Harp route is stable both directions from the lower-stair side.
- The Cursed Belt route is solved: from B3 `Northwest Stairs Up`, the route to
  the west chest uses the top-edge false-boundary cells, left-edge strip, and
  chest-side false-wall cells; the return/escape route is also modeled.
- The player has opened the west chest and confirmed the Cursed Belt.
- The B1 entrance-to-down-stairs route and return route have been manually
  validated after the final blocker patches.
- The B2 northwest-side escape back to `Stairs Up` has been live-validated via
  the left-edge false-boundary strip and bottom/right corridor.
- The false reachable-object routes from the B3 northwest component are pruned;
  the expected reachable objects there are the opened chest and local
  `Northwest Stairs Up`.
- B3 lower-stair / Silver Harp side, B3 northeast and southeast pockets, and
  the B4 connector are closed enough for normal play.

## Final Tooling / Cleanup Notes

- The first connected overworld itinerary is implemented in source for
  `Tantegel -> Kol -> Northern Cave`, intentionally without enabling the other
  staged routes yet. A Northern Cave selection from Tantegel activates the
  existing Kol route while preserving the Northern Cave Travel target. `R`
  reports `Current leg to Kol. Final destination: Northern Cave` plus the next
  waypoint. Reaching exterior Kol `(104,10)` or entering map `0x07` emits a
  structured `event=handoff route=northern_cave ... from_route=kol`, refreshes
  the route marker to `route_northern_cave_02`, and waits for another `U`
  instead of moving automatically. `Shift+U` still stops only current or
  pending auto-walk while preserving guidance; explicit route stop clears the
  complete itinerary. Live FCEUX/JAWS acceptance is complete. Starting from
  Tantegel road `(43,43)` preserved Northern Cave while status named Kol as the
  current leg. Entering Kol produced `event=handoff route=northern_cave
  waypoint=Kol forest west edge index=2 from_route=kol`; the hero stayed at
  Kol `(19,23)` for 508 frames with `PATH_STATE target=nil`. After exiting to
  World Map `(104,10)`, a refreshed Kol selection initially caused bare `U` to
  replace the Northern Cave route. `route_manager.lua` now distinguishes bare
  `U`/`auto_walk`, which follows active guidance, from explicit object-target
  calls, which may still switch destinations. The loaded fix reproduced the
  exact conflict (`target=Kol`, `active_route=northern_cave`,
  `follow_active=true`) and completed 11 ordinary steps to `(96,13)`. Final
  state is route `northern_cave`, next `West of Kol forest bend` `(92,10)`,
  path nil, and no runtime blockers. The legacy Kol route also uses the
  live-proven `(98,32) -> (98,26)` east detour around blocked
  `(96,28) -> UP`; the x98 north leg completed normally after reload.
  Regression coverage includes final-target binding, status, guidance refresh,
  exterior/interior handoff including stale terrain offset, no automatic
  movement, post-refresh bare-`U` continuation, explicit cancellation, and a
  guard proving later final-progression staging still stops at its hub. Focused
  checks pass `164/164`
  overworld-route and `116/116` route-manager tests; the authoritative gate
  passes all 33 host-runnable Lua suites and 68 Python tests, with clean Lua
  syntax and `git diff --check`. The user then manually completed the combined
  Tantegel-to-Northern-Cave route and confirmed the connected behavior worked
  as expected. The remaining observation is separate legacy polish: some early
  overworld routes still enter intermediate towns. Track that independently;
  it does not block this connected-route checkpoint or the Swamp Cave slice.
  Fresh review marker `MANUAL_COMBINED_REVIEW_20260813` confirmed the user's
  final checkpoint on World Map `(92,10)`: route `northern_cave`, next `Rain
  shrine east-shore detour`, path nil, no runtime blockers, and Kol still
  selected.
- The second connected itinerary, `Tantegel -> Kol -> Swamp Cave`, now opts
  into the same explicit handoff model. `SWAMP_CAVE_STAGING` names canonical
  `swamp_cave` as its continuation so a far start cannot retain the shorter
  `swamp_cave_bridge` alternate after Kol. Loaded status from Tantegel
  `(43,43)` named Kol as the current leg and Swamp Cave as the final
  destination. The Kol trigger emitted `event=handoff route=swamp_cave
  waypoint=Kol forest west edge index=2 from_route=kol`, queued no movement,
  and bare `U` followed the active route despite stale unrelated object focus.
  After a natural Kol entry/exit, a clean local run traversed every existing
  Swamp Cave waypoint through the x98 south-road detour, `(92,37)` bridge lane,
  `(94,40)->(94,41)` poison-swamp drop, row-41 lane, and `(104,43)` doorstep.
  The final step entered map `0x15` at `(0,0)` and logged `event=arrived`.
  Fresh tag `SWAMP_CONNECTED_ARRIVAL_20260813` confirmed HP `149/149`, path
  nil, runtime blocks none, and no overworld route active. Two force-seeded
  movement timeouts were teleport contamination and were not promoted. The
  focused route suite passes `164/164`; the full gate passes all 33
  host-runnable Lua suites plus 68 Python tests. The user then manually
  completed the full Tantegel-to-Swamp-Cave route. Fresh structured events show
  `route=kol staged_from=swamp_cave` at frame `71501`, the Kol handoff at frame
  `84046`, and Swamp Cave arrival at frame `89299`. Probe
  `SWAMP_MANUAL_ACCEPTANCE_20260813` at frame `92640` confirmed map `0x15`
  `(0,0)`, HP `149/149`, no active path, no runtime blockers, and no active
  overworld route. This connected-route slice is closed.
- Player-facing auto-walk cancellation is implemented in source with
  configurable default `Shift+U`. `hotkeys.lua` handles it before field and
  object-control guards, cancels a pending `U` release, and calls the shared
  `route_manager.stop_auto_walk("player hotkey")` path. That path clears queued
  auto-step movement, force-releases direction input, clears target/route/NPC
  context, and preserves the separate selected object and guided overworld
  destination. Active or deferred cancellation interrupts with `Auto-walk
  stopped`; idle use queues `No auto-walk is active`. The debug
  `stop_auto_walk` command now uses the same cleanup path. `Shift+U` replaced
  `Backspace` because JAWS intercepts Backspace; backslash was rejected after
  it disrupted emulator audio. The chord handler also suppresses the
  overlapping plain-`U` start action so release cannot restart a route. After
  loading that final handler, the user live-tested two 13-step FCEUX/JAWS
  routes from Dragonlord's Lair `(11,17)`. `Shift+U` stopped them at frames
  2868 and 3190; the second had reached `(10,18)`, and no deferred start or
  queued step appeared after key release. Fresh acceptance probe
  `SHIFT_U_ACCEPTED` at frame 7680 confirmed `(10,19)`, `PATH_STATE target=nil`,
  zero runtime blockers, and ready speech. Focused tests pass `42/42` hotkey,
  `115/115` route-manager, `2/2` config, `10/10` hotkey-filter, and `4/4`
  release-guide checks. The authoritative gate passes all 33 host-runnable Lua
  suites and 68 Python tests.
- The offline release gate is authoritative again. `run_tests.py` now
  discovers all root Lua/Python tests instead of carrying a stale partial Lua
  manifest, runs 33 host-runnable Lua suites plus 68 Python unit tests, syntax-
  checks every root Lua/Python file, and explicitly skips only
  `test_screen.lua` and `test_speech.lua` because they require live FCEUX
  globals. Windows fallout is fixed: `test_debug_tools.lua` uses the available
  temporary directory instead of hard-coded `/tmp`; shell tests launch through
  resolved Git Bash with its `usr\bin` helpers on PATH; and the interactive
  `test_tolk.py` was renamed `speech_smoke.py` so unittest discovery cannot
  speak or exit unexpectedly. The expanded `python run_tests.py` gate passes
  end to end. PowerShell may not resolve bare `lua`, but the runner currently
  finds `C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe`.
- New non-teleport verifier helpers were added after the Garinham door/route
  fallout: use `verify_walked_edge:DIR` or `verify_walked_edge:X,Y,DIR` to
  route to an origin without teleport, then run the normal raw `probe_edge`
  logic from the reached tile. Keep legacy `probe_edge_verify` as
  forensic/review-only when teleport artifacts are plausible. For doors, use
  `verify_door_stand:X,Y,DIR`, manually OPEN after `DOOR_VERIFY_READY`, then
  run `verify_door_after` to compare keys/opened-door RAM. Reload `main.lua`
  in FCEUX before live-testing these new source changes.
- `auto_walk_blocker` / `auto_walk_blocker:X,Y` now run normal local-map
  autowalk in first-blocker mode. They stop at the first confirmed blocked
  queued step, log `AUTO_WALK_BLOCKER_FOUND`, speak/report the failed edge, and
  print the matching `add_blocked_edge:X,Y,DIR` runtime-patch suggestion.
- Timing-suspect movement-start timeouts run the normal seam retry before
  being reported as patchable blockers, which keeps timing noise out of
  permanent map data.
- Movement-changing field actions now refuse while command menus, prompts,
  dialogue, active routes, or probe/survey/crawl flows can consume input.
- `sweep_walk` now writes `sweep_status.txt` while active and, on finish,
  `sweep_walk_MM_runNNN.json`, `sweep_walk_MM_runNNN_summary.txt`, and the
  existing `dw_crawl_MM.txt` review snippet. Its JSON includes explicit
  `unknowns`, `dynamic_blockers`, `transitions`, and `unsafe_aborts` buckets
  for single-edge probe outcomes. Reload `main.lua` in FCEUX before
  live-testing newly edited sweep code.
- Post-reload Garinham validation hammered the timing-suspect split with four
  normal-movement 120-edge `sweep_walk` runs from the central/lower-left
  component. All four hit `reason=max_edges` with zero passthrough exports,
  zero directional exports, and zero unsafe aborts; remaining observations
  stayed in timing-suspect unknown/unstable or informational door buckets.
- Tantegel and Swamp Cave follow-up runs gave `sweep_walk` broader coverage,
  including hostile-map interruptions. Random encounters now stop the active
  sweep with `reason=battle_interrupted` /
  `source_classification=battle_interrupted`; start a new sweep manually after
  combat returns to field control.
- Resume-from-JSON support is intentionally deferred. The current field design
  is simpler and safer: battle interruption is a terminal graceful exit, not a
  pause that waits through combat.
- The crawler no longer writes movement RAM during sweep step cleanup. Hostile
  Swamp Cave reruns after that change kept player stats clean across battle
  interruptions, so this should stay a hard rule unless fresh evidence proves
  otherwise.
- The long sweep break-in scratchpad was archived; the active scratchpad is
  concise again.
- A local CodeRabbit review of the cleaned uncommitted diff completed with
  zero findings.
- A CodeRabbit review found one test-harness cleanup issue in
  `test_map_reader.lua`; the B2 pathfinder test now restores module/env state
  through a finally-style helper even if an assertion fails.

## Durable References

- Current gameplay notes: `PLAYTESTING.md`
- Durable project lessons: `PROJECT_MEMORY.md`
- Garin's Grave map reference: `project_resources/maps/garins_grave/README.md`
- Archived full handoff:
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_wrapup_full.md`
- Archived scratchpad:
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_scratchpad.md`
- Sweep break-in archive:
  `handoff_archive/HANDOFF_2026-06-21_sweep_walk_break_in_scratchpad.md`

## Next Work

1. Expand the verified itinerary behavior to one more existing staged route.
   The smallest next slice is `Tantegel -> Kol -> Swamp Cave`, reusing the same
   Kol handoff while leaving all other staged destinations disabled.
2. Live-test that slice with the same acceptance contract: preserve the final
   Travel target, name current and final legs, do not move automatically at
   Kol, and make bare `U` follow the active second leg despite object refresh.
3. Keep off-network recovery separate until a second connected route proves
   the handoff mechanism generalizes cleanly.
4. Circle back in a separate task to polish first-generation routes that enter
   intermediate towns; do not mix that audit into connected-route expansion.
5. For live FCEUX work, keep battle/control-lock evidence separate from map
   geometry.
