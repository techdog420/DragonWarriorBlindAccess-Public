# Broader Travel and field-dialogue acceptance

Status: representative pass complete on 2026-10-15; coverage limits below.
Prepared: 2026-10-13 against `63c64d6` on `main`.

## Progress

- Charlock selector gap reproduced in loaded FCEUX at normally walked `(51,50)`.
  Ten existing south-island destination variants now match the known island
  corridors. The 150-case regression and full native 42-Lua-suite/68-Python-test
  gate pass. After manual reload, all 16 loaded selectors passed at `(51,50)`;
  Brecconary's corrected one-north opening completed normally.
- Real field TALK result reached at `(51,49)` with Brecconary retained and
  movement stopped. The game kept its command menu present behind the text;
  physical status/refusal/dismissal is now player-accepted. D cleared both the
  command menu and text without restarting movement; standalone dialogue-onset
  cancellation remains a separate coverage limitation.
- Initial 2026-10-13 whole-map audits completed with no decoded unreachable cells.
  Counts precede the later entry-filter hardening; retain that distinction.
- Western `(11,14)` loaded selection reproduced another mountain-cutting
  opening. A general corridor check now redirects disconnected openings into
  bounded recovery and excludes unsafe corner entries. Focused regressions
  pass, including the final native 42-Lua-suite/68-Python-test gate. Loaded
  recovery used safe south steps and retained Brecconary through battles. One
  final carry to `(11,31)` cancelled conservatively; stale guidance then
  recalculated without motion and explicit resume completed three guided legs.
- Additional 16-destination start/preview/status batches near Kol `(93,35)`,
  Rimuldar `(103,72)`, and Hauksness `(73,96)` used guarded debug positioning.
  These broaden selector coverage, not live collision proof. They exposed
  staging IDs restricting recovery to the wrong origin/entrance. A public
  request ID now preserves destination selection across recovery. All new
  regressions failed before the fix and pass afterward:346 route / 169 manager
  tests, plus the unchanged 154 auto-step tests. Final native gate passed on
  2026-10-13; manual reload and both Swamp Cave previews passed on 2026-10-15.
- All 16 model audits were repeated after all fixes: unreachable 0, max safe
  distance 117, safe-within-limit7122..7196, safe-over-limit398..472.
- A normally reached `(90,108)` planned 113 safe steps toward Brecconary.
  Battles interrupted the first 3 steps; after player-cleared battles and REPEL,
  explicit resumes completed four 24-step checkpoints plus the final 14-step
  network entry. Every checkpoint and the boundary stopped exactly despite
  continuous Travel. Explicit guided resume passed. Kol arrival cleared
  guidance and stopped movement; normal exit returned to the overworld.
- The player accepted physical Shift+R/U refusal/D dismissal for real REPEL
  text with a spell submenu present. Fresh `90000` confirmed unchanged stopped
  `(96,10)`, clear field/menu/text and path nil/blocks0. Explicit resume then
  completed the next 3-step guided leg. Final fresh `91440`: clear field at
  `(96,14)`, Brecconary retained, movement stopped, HP 149/149, MP 85/121.

## Coverage limits and watch items

- TALK retained the command menu; REPEL retained the spell submenu. Both real
  result/refusal/dismissal slices are player-accepted. Independent dialogue-only
  onset cancellation remains unit coverage; no RAM flags were injected to
  manufacture a live case. Physical in-battle Shift+R was not player-confirmed.
- The isolated western `(11,30)->(11,31)` final carry remains a timing watch.
  Five later recovery checkpoint/network stops landed exactly. Reproduce the
  original case before changing timing; it is not terrain blocker evidence.
- The decoded model has no ordinary safe, non-transition hazard-only origin:
  remaining hazard-required origins are poison cells. Existing live Charlock
  first-step hazard stopping and host recovery-guard tests cover the safety
  mechanisms; a separate off-network hazard-only refusal was not walked live.
- The 2026-10-13 recovery-reload evidence is reconstructed from exact tool-output
  excerpts after the active log was truncated during a host gate. Full2026-10-15
  debug/speech backups were preserved. See the focused evidence files.
- Quest-dependent cave crossings and every destination/cell/state were not
  replayed. Keep model coverage, loaded movement, and player speech acceptance
  distinct when describing this completed representative pass.

## Goal and existing evidence

Validate destination selection from additional world-map regions, safe recovery
from off-network starts, and retained guidance through real field dialogue.
Keep model coverage, loaded movement evidence, and player speech acceptance
distinct. Map cleanup remains complete; reopen geometry only for a fresh failure.

The 2026-10-02 Tantegel menu/battle/drift slice and Hauksness selector slice
are already recorded in `PLAYTESTING.md`. The physical Shift+R check during
battle was missed; retained guidance after battle was player-confirmed.

## Initial investigation (2026-10-13, before fixes)

- The checkout was clean at `63c64d6` before preparing this plan.
- No FCEUX/BizHawk process was found. `dw_debug.log` was last written on
  2026-10-02. Neither its frames nor `(67,50)` establish current game state.
- Existing corridor matrix tests cover 16 supported Travel targets. They
  provide substantial source coverage but do not establish live collision.
- `audit_overworld_recovery:ROUTE_ID` already performs a read-only whole-map
  classification. It reports network cells separately from safe recovery,
  longer safe recovery, hazard-required, unreachable, and transition cells.
  Its global network count alone does not validate each destination's selector
  from those cells. Check selected legs and their actual step sequences too.
- A read-only LuaJIT preview checked all 16 canonical destinations at six
  coordinates (96 previews); every request resolved. At `(56,57)`, which the
  model classifies as on-network, these openings warrant investigation:

  | Requested destination | Selected leg | Next waypoint | Steps |
  | --- | --- | --- | --- |
  | Tantegel | `charlock_return` | island southeast corridor `(56,56)` | 1 north |
  | Brecconary | `brecconary` | Brecconary `(48,41)` | 24, north first |
  | Erdrick's Cave | `erdrick` | Brecconary west bypass `(47,41)` | 25, north first |
  | Rimuldar | `kol_staging` | Brecconary west bypass `(47,41)` | 25, north first |

  At `(56,56)`, Tantegel chooses the established one-east turn, while those
  other requests still begin north. These are model candidates for the first
  repro, not newly proven blocked tiles. A short opening alone is not enough:
  Brecconary's suspect opening is within the usual 24-step bound.
- Field movement already checks real lower/upper dialogue separately from
  menus. `field_action_guard.lua` ignores passive status fragments but blocks
  actual dialogue. `auto_step.update(false)` cancels queued movement; the route
  manager preserves guidance and clears any armed swamp confirmation.

## Pass 1: resolve the Charlock selector candidate

1. Use the existing `test_overworld_routes.lua` corridor-cell helper to compare
   all 16 destination objects across the established Charlock return corridor.
   Check retained final destination and connected opening geometry, not only
   path length. Alias/object parity belongs in focused regression cases.
2. Once FCEUX is loaded, establish a fresh probe, clear field/menu, neutral
   input, current guidance, HP/MP, and no unexplained queued path or blockers.
3. Position on the established island corridor; `(56,57)` / `(56,56)` are the
   first comparison points. Debug positioning may select a test region, but
   reacquire the edge origin by normal walking before judging collision.
4. Compare Tantegel with Brecconary and Rimuldar in separate start/status
   batches. Inspect the proposed opening before walking; diagnose the first
   disagreement rather than blindly executing a long shortcut.
5. If confirmed, reuse the established return/staging helpers with the smallest
   selector change and regression. Preserve final destinations and geometry.
   Run focused tests, request one manual FCEUX Lua reload, then verify fresh
   selection and a short walked opening. No speculative terrain overrides.

## Pass 2: real field-dialogue acceptance

Use a normal TALK command on an empty overworld tile, outside any transition
or hazard. Confirm the actual result text and parser state in the live log.
This avoids consuming items or exposing a hidden SEARCH reward.

1. Start a short guided leg. Open the game's command menu, then select TALK.
   Verify destination retention and stopped movement through the result.
2. Opening the menu may cancel movement before dialogue begins. Record that
   sequence honestly; it does not independently prove dialogue-onset cancellation.
3. While the real result text is active and the command menu no longer owns
   the input, test Shift+R for retained destination/next waypoint, then U for
   refusal. Expect the dialogue-specific refusal, no movement, and no queued
   path. If the window clears too quickly, use a game result that waits for
   acknowledgement; do not replace live evidence with injected RAM flags.
4. Dismiss normally, leave the field idle without U, and confirm no restart.
   One explicit U should resume from the current tile and preserve destination.
5. Reuse guard and executor tests for independent dialogue-onset cancellation
   and clearing hazard authorization; add an integration regression only where
   existing tests leave a concrete gap. Label simulated-state evidence as such.
6. If a battle occurs during a later leg, obtain the previously missed physical
   Shift+R confirmation before clearing it; avoid a separate random-battle grind.

## Pass 3: broaden destination and recovery coverage

Use five origin families: western castle/bridge, Kol road, Rimuldar/cave south,
Hauksness/Cantlin return, and Charlock island. Choose exact safe stand cells
after decoded inspection and a fresh live baseline.

- Reuse source matrix tests for all 16 destinations across those families.
  Add cases for missing corridors and justified selection boundaries.
- Run existing read-only recovery audits for the 16 canonical route IDs, one
  at a time. Preserve structured counts and representative exception cells.
  Do not promote a model `unreachable` result to a game collision claim.
- Check all 16 destination selectors in loaded FCEUX, distributed across the
  origin families; compare current leg, next waypoint, retained final target,
  read-only status, and cancellation. Repeat suspicious combinations first.
- Walk representative cases for: a new on-network origin/destination, a nearby
  safe recovery, a safe recovery longer than 24 steps with checkpoint stops,
  deliberate drift, and a staged handoff/map transition. Verify recovery stops
  even when continuous Travel is enabled and requires explicit U at boundaries.
- Check a hazard-only recovery refusal without entering the hazard. Landmark
  transition cells must remain excluded as recovery endpoints. Quest/item gates
  and spoiler-safe search-area presentation remain part of expected behavior.
- Let these representative legs cover the shared execution mechanisms. Full
  traversal of every already accepted route is unnecessary for this pass.

Canonical audit IDs:
`tantegel`, `brecconary`, `erdrick`, `garinham`, `kol`, `northern_cave`,
`mountain_cave`, `swamp_cave`, `swamp_cave_south`, `rainbow_bridge`, `rimuldar`,
`magic_temple`, `cantlin_hauksness`, `hauksness`, `great_swamp_cantlin`,
`charlock_castle`.

## Execution and completion

- Initial player setup: load the verified FCEUX runtime and a pre-Dragonlord
  victory save with the existing late-game travel prerequisites; leave clear
  overworld field. No precise coordinates are required from the player.
- Use existing `dw_commands.ps1 --replace`, fresh `launcher_probe` tags,
  `--require-live`, and bounded waits. Keep status speech last or separate so
  diagnostics do not overwrite the player's acceptance prompt.
- Use `work_notes/current_investigation.md` for uncertain findings, then save
  expensive evidence before reload. Record baseline, destination/leg, positions,
  cancellation reason, explicit resume, speech result, and evidence type.
- After source changes: focused route/manager/auto-step/field-guard suites,
  then the full `python -u run_tests.py` gate, manual Lua reload, and live repro.
  The final native gate passed on 2026-10-13 after all source edits; live-only
  screen/speech suites remain separate from the host gate.
- Restricted-context runtime preflight failed with `Illegal System DLL
  Relocation`; LuaJIT ran the pure previews and focused suites. The restricted
  full gate also hit shell/temp-directory access errors. The normal host gate
  passed with the installed Lua 5.1/luac and all checks intact. No runtime
  installation or global setting change was needed.
- Close each covered slice explicitly. Remaining quest-dependent, unreachable,
  or untested cases retain their labels. Model coverage plus representative
  live passes must not be described as every cell/state being player-accepted.
- Promote verified status changes into `TASKS.md`, `PLAYTESTING.md`, and the
  concise handoff. Publish implementation changes only on user request.
