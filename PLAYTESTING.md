# Playtesting Notes

Updated: 2026-05-13

This file tracks the shift from map decoding toward actual blind-player gameplay.

## Latest Notes

- Object browsing now avoids full NPC-list rebuilds on plain browse/readout
  keys under BizHawk. The first moving-NPC fix made Person 1 and other moving
  NPCs track again, but calling `objects.update_npcs()` on `J`/`K`/`L` brought
  back a 1.5-2 second emulator/audio freeze between object-browser presses.
  `objects.describe_current()` now reads only the selected NPC slot live for
  spoken direction/distance, while `J`/`K`/`L`, filter readouts, and
  command-file object browsing skip the full rebuild. Route/planning actions
  (`R`, `O`, `U`, `pathfind`, `auto_walk`) and explicit pathability refreshes
  still refresh the full NPC list before planning. Live command-file browse
  proof after reload produced object descriptions with no `CMD_TIMING` warning;
  the user's focused physical `J`/`L` retest confirmed this brought the delay
  down to a fraction of a second between hops. Treat this as a successful first
  tuning pass unless the remaining small pause becomes a normal-play problem.

- Brecconary Merchant 4 public access update: the user found a small walkable
  pocket at `(22,25)`/`(23,25)`. Fresh live evidence at `map=0x08` confirmed
  the player at `(23,25)` with no runtime blockers, `(22,25)<->(23,25)` as
  passable, `(23,25)->RIGHT` into `(24,25)` as directionally blocked, and TALK
  from `(23,25)` facing east opening the tool shop (`MERCHANT_ACTION:
  Merchant. Buy.`). This supersedes the earlier conclusion that Merchant 4 was
  isolated: route the service to `(23,25)` facing east, but keep the movement
  seam into `(24,25)` blocked.

- Brecconary Merchant 4 public route breakthrough: `(17,25)` is a confirmed
  false-wall passthrough. A focused static graph pass showed it was a single
  missing cell that would connect public origin `(1,15)` to the public tool-shop
  stand `(23,25)`, and live `probe_edge_verify:16,25,RIGHT,3` moved into
  `(17,25)` 3/3 times with no runtime blocker pollution. After reload,
  `debug_pathfind_to:23,25` from `(1,15)` produced a 38-step route through
  `(16,25)->(17,25)->(18,25)` and on to `(23,25)`. One validation attempt
  aborted early from an open-floor overshoot before reaching the new bridge, so
  the map route is fixed but the movement-validation timing quirk remains.

- Brecconary Merchant 4 noise-hardening pass: the current live map is
  confirmed as `map=0x08(Brecconary)`, not castle data. `(27,25)->DOWN` into
  `(27,26)` is a confirmed false-wall passthrough: verifier movement succeeded
  3/3, with six moved observations total, and post-reload
  `inspect_move:27,25,DOWN` reports `effective_passable=true`. The lower-right
  bypass that A* invented after this was false: validation failed at
  `(28,27)->DOWN`, and a direct check blocked the same edge, so `(28,28).north`
  is now modeled as a directional block. The remaining clean no-path from
  `(27,25)` to Merchant 4's stand `(25,26)` is currently caused by live NPC
  occupancy around `(27,27)/(27,28)`, not by a new map blocker. A parked-NPC
  survey then reproduced the timing-noise problem by treating the confirmed
  passable `(27,26)` edge as blocked during auto-step retries, so
  `route_manager.lua` now keeps blocked-only seam memory diagnostic-only; only
  explicit manual commands such as `add_blocked_edge` promote runtime blockers.
  Follow-up manual testing found another public-route frontier seam:
  `(22,25)->LEFT` into `(21,25)` is hard engine-blocked. Pre-patch
  `inspect_move:22,25,LEFT` said `effective_passable=true`, so
  `map_reader.lua` now models `(21,25).east` directionally for Brecconary.
  The next planned route from live `(23,22)` exposed `(23,22)->DOWN` into
  `(23,23)`: validation could not move through it, and the user manually
  confirmed the engine definitely blocks it. `map_reader.lua` now models
  `(23,23).north` directionally. The validation tool itself was hardened to
  stop duplicate injected steps and to cancel active auto-step state on abort,
  which prevents post-abort seam noise from being written. It also uses a
  validation-only forced D-pad release after injected validation arrivals, so
  normal manual-cancel behavior stays intact. Final live reload from `(25,22)`
  reported no path to `(25,26)` with runtime blockers still empty.
  Follow-up manual cluster check found the vertical x=22 approach open through
  `(22,26)`'s north edge: `(22,21)` is open from the south, `(22,22)` through
  `(22,25)` are open north-to-south, and only the south exit from `(22,26)` is
  closed. East/west on those cells was not checked. The live model already
  matches this, so this pass added regression coverage rather than new blocker
  data. A validation pass then reached `(25,22)` cleanly and failed on
  `(25,22)->DOWN` into `(25,23)`; the user manually confirmed that edge is
  actually open from north to south, so that failure is treated as validation
  noise and `(25,23).north` is pinned open. A follow-up validation then reached
  `(27,28)` and failed on `(27,28)->LEFT` into `(26,28)`; live inspect still
  said that edge was passable, but repeated manual taps also blocked there and
  the user confirmed it is engine-blocked. `map_reader.lua` now models
  `(26,28).east` directionally, leaving other approaches to `(26,28)` open for
  future checks. Reload proof showed `inspect_move:27,28,LEFT` now blocked by
  the model with runtime blockers empty. The next generated detour failed
  immediately on `(27,28)->DOWN` into `(27,29)` even though static inspect still
  said that down edge is passable. Repeated manual down taps also blocked
  there, and the user confirmed the south exit is engine-blocked. `map_reader.lua`
  now models `(27,29).north` directionally too. Reload proof showed
  `inspect_move:27,28,DOWN` now blocked by the model with runtime blockers
  empty. The next generated detour failed immediately on `(27,28)->RIGHT` into
  `(28,28)` while static inspect still said that right edge was passable.
  Repeated manual right taps also blocked there, and the user confirmed the
  east exit is engine-blocked. `map_reader.lua` now models `(28,28).west`
  alongside the existing `(28,28).north` block. Reload proof showed
  `inspect_move:27,28,RIGHT` now blocked by the model with runtime blockers
  empty, and from live `(27,28)` the route to Merchant 4's interaction tile
  `(25,26)` now reports clean no-path (`visited=52`).
- Manual wall-bump responsiveness follow-up: Brecconary logs showed physical
  wall bumps producing `manual_tap` auto-step timeouts after 45 frames, which
  can make real collisions feel much worse than a normal held-key bump. The fix
  keeps manual movement from adding a synthetic tap-to-step hold when the target
  edge is already a known static permanent or directional blocker. The player
  can still deliberately hold a direction into a wall, and debug/probe injected
  steps can still test known blockers, but quick released taps into known walls
  now stop at `AUTO_STEP_REFUSED_STATIC_BLOCK` instead of writing another seam
  observation. Live reload proof: `LAUNCHER_PROBE:
  codex_static_wall_refusal_reload` at `map=0x08(Brecconary) x=24 y=25`.
  Follow-up logs showed the same post-release hang still happened on unmodeled
  wall/NPC collisions from `(24,25)`, so physical `manual_tap` now releases the
  synthetic D-pad as soon as the movement subpixel twitches instead of holding
  into the obstruction until timeout. Debug/probe injected steps and queued
  route verification still keep the more conservative early-twitch behavior.
  Reload proof: `LAUNCHER_PROBE: codex_manual_tap_release_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
  One more log pass showed why this still felt bad: the turn-repress recovery
  rearmed the same direction after the release, then held it into the wall/NPC
  until timeout. Physical `manual_tap` now also suppresses that re-press after
  any movement-subpixel twitch; debug/probe injection and queued routes keep
  their conservative re-press behavior. Reload proof:
  `LAUNCHER_PROBE: codex_manual_repress_suppressed_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
  The user's half-second timing clue then matched the remaining log path:
  released physical bumps were still reaching the normal 45-frame blocked-step
  publication, which writes seam/NPC block evidence. Physical `manual_tap` now
  silently cancels about 20 frames after a twitch if the tile has not changed,
  so normal released wall bumps do not publish blocked seam events. Reload
  proof: `LAUNCHER_PROBE: codex_manual_twitch_silent_cancel_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
- Brecconary weapon-shop throat and blocker-policy follow-up: manual movement
  proved `(5,7)<->(5,6)` is open both ways, matching the earlier manual
  proof that `(5,7)<->(5,8)` is open. `map_reader.lua` no longer models
  `(5,6).south` or `(5,8).north`; the remaining local modeled wall is the
  east edge into `(6,7)`. Fresh live reload
  `LAUNCHER_PROBE: codex_manual_promotion_reload` plus `inspect_move:5,7,UP`
  reported `effective_passable=true` with no directional blocker. A hostile
  verifier repro still reported `probe_edge_verify:5,7,UP,3` as
  `confirmed_blocked`, but the new policy correctly kept
  `runtime_added=false`, logged `manual_promotion_required=true`, and left
  `RUNTIME_BLOCKS map=0x08 none`. Treat verifier consensus as suspect
  evidence only; use `add_blocked_edge:X,Y,DIR` or `add_blocked_tile:X,Y`
  only after manual review.
- Previous Brecconary Merchant 4 alternate-pocket check: the user manually verified
  `Merchant 4` is the normal tool merchant. The raw trigger at `(24,25)`
  opens the tool shop while facing east, but it is not public floor:
  `(24,25)->LEFT` and `(23,25)->RIGHT` both blocked 5/5. The then-confirmed
  alternate interaction tile is
  `(25,26)` facing north: `(25,27)->UP` moved into `(25,26)` 3/3 despite a type-0
  decode, and TALK there opened the tool shop/item list. `map_reader.lua` still
  treats `(25,26)` as a passthrough, but later manual/live evidence superseded
  this as the normal service target: `objects.lua` now routes Merchant 4's
  service interaction to `(23,25)` facing east. The route from public origin
  `(1,15)` is still blocked, though: after reload, `debug_pathfind_to:25,26`
  and `debug_pathfind_to:25,27` both returned no path, and the remaining lower
  southeast frontier seams `(14,28)->RIGHT`, `(15,27)->DOWN`,
  `(15,27)->RIGHT`, and `(16,26)->DOWN` are all live-blocked. The boundary is
  one-way in places: `(16,27)->UP` and `(15,28)->LEFT` moved cleanly, and
  `(25,26)->DOWN` blocked 5/5 despite `(25,27)->UP` entering the stand. A later
  inside-out validation from `(25,27)` exposed two more false exits:
  `(25,27)->LEFT` into `(24,27)` and `(25,27)->DOWN` into `(25,28)` both
  blocked 5/5. With those modeled, `(25,27)` can no longer path back to public
  space (`visited=2`), and public origin `(1,15)` still cannot path to the
  tool-shop interaction tile `(25,26)` (`visited=406`) with no runtime blocks.
  A later public-route attempt reached `(22,26)`, but the user manually
  verified `(22,26)->DOWN` into `(22,27)` is hard engine-blocked; model that as
  `(22,27).north`, not a full-cell blocker. This no longer means Merchant 4 is
  globally isolated; it only means the older `(25,26)` alternate pocket has no
  public route. A
  follow-up suspect-cell pass found no safe route-opening patch: `(26,25)` and
  `(26,27)` blocked 5/5, `(23,27)` blocked from `(23,26)`, and the potential
  false-wall cells `(23,26)`, `(24,26)`, and `(27,26)` produced passable or
  mixed evidence without forming a reliable connector to `(25,26)`. Runtime
  blocks stayed empty, so leave these as manual-check candidates for now.
- Brecconary Merchant 4 tool-shop item-list speech is fixed. The open list
  showed `Herb 24`, `Torch 8`, and split `Dragon's 20` / `Scale`, but the
  merchant detector reported `offers=""` because its catalog only included
  equipment names. The shop catalog now includes normal item-shop goods, so the
  live open list reports `offers="Herb, Torch, Dragon's Scale"` and speaks
  `Herb. 24 gold.`, `Torch. 8 gold.`, and `Dragon's Scale. 20 gold.` as the
  cursor moves.
- Brecconary Merchant 4 Buy/Sell prompt speech is fixed. The first shop prompt
  shows `BUY` and `SELL` over stale command-menu rows, so the field command
  reader mislabels D9 `0`/`1` as `TALK`/`STATUS`. The merchant reader now has
  an action mode for `What can I do for thee?`: D9 `0` speaks `Buy`, D9 `1`
  speaks `Sell`, and cursor-blink row churn does not repeat the prompt.
- Brecconary Merchant 4 close-out dialogue overlap is fixed. While the merchant
  reader owns a shop prompt/list, `main.lua` now keeps the lower-dialogue
  baseline synchronized with the visible prompt. Closing the item list now
  speaks only `I will be waiting for thy next visit.` instead of dragging the
  prior welcome / `What dost thou want?` text back into the farewell.
- Brecconary current door-attribution check: from the public origin `(1,15)`,
  with NPC blockers skipped and door RAM simulated, the known doors split the
  current live NPC table cleanly. `Northeast Door` `(21,6)` unlocks `Woman 1`;
  the user manually verified that `Woman 1` is the Fairy Water merchant, so
  this target is expected to be locked behind that door. `Inn West Room Door`
  `(5,22)` unlocks `Old Man 1` at his current `(1,20)` position and `Guard 4`.
  Opening both doors still does not route to
  `Weapons Merchant` stand `(5,6)`, the center-east room (`Person 3`,
  `Old Man 2`, `Guard 2`), the southeast room (`Person 1`, `Person 5`),
  `Guard 3`'s lower-left room, or `Merchant 4`'s southeast tool-shop region.
  Treat those as route/seam follow-ups rather than known-door-gated NPCs.
- Brecconary door/classification pass: Mike's RPG Center labels the services as
  inn, weapon/armor shop, item shop, Fairy Water/special item shop, and curse
  remover; Realm of Darkness and Gamer Corner note the Fairy Water shop needs a
  Magic Key, and Gamer Corner lists two Brecconary locked doors: northeast
  building and west room in the inn. The object locator previously exposed no
  doors on map `0x08`; it now exposes `Northeast Door` `(21,6)` and
  `Inn West Room Door` `(5,22)`, and `map_reader.lua` checks both through the
  opened-door RAM array. With both doors synthetically open in RAM, the
  earlier static pass made only `Guard 4` and `Woman 1` reachable; the current
  live-NPC refinement also puts `Old Man 1` behind the inn west-room door.
  `Weapons Merchant`, `Person 3`, `Person 5`, `Old Man 2`, `Merchant 4`, and
  `Person 1` remain no-path, with current live additions `Guard 2` and
  `Guard 3`, so they are missing route/blocker-data follow-ups rather than
  known door-gated targets. Older direct verifier evidence that said
  `(5,7)->(5,6)` was blocked is now considered timing-noise evidence, not a
  map fact; manual movement and static inspect show the weapon-shop stand seam
  is open.
  Closed-door no-path hints are now target-aware: opening the reachable door
  frontier must actually make the selected object reachable before the player
  hears the magic-key/door advice.
- Brecconary false-blocker poke-around: a follow-up topology pass showed that
  opening one of `(20,12)/(21,12)/(22,12)/(24,12)` would connect the
  Person 3 / Old Man 2 room in the model, while southeast bridge candidates
  would connect `Person 5`, `Person 1`, or `Merchant 4`. Live verifier probes
  blocked all checked candidates, including `(24,13)->UP`, `(21,8)->DOWN`,
  `(17,10)->RIGHT`, `(21,16)->DOWN`, `(25,14)->DOWN`, `(17,20)->DOWN`,
  `(16,25)->RIGHT`, `(16,26)->RIGHT`, `(14,28)->RIGHT`,
  `(15,27)->DOWN`, `(15,27)->RIGHT`, `(22,13)->UP`, `(21,13)->UP`,
  `(20,13)->UP`, `(19,13)->UP`, and `(16,22)->RIGHT`. Runtime blocks were
  cleared after each verifier pass, and the player was restored to `(1,15)`.
- Selected-object NPC teleport follow-up: while checking Brecconary NPCs before
  leaving town, `Shift+Enter` was found to teleport onto the selected NPC's
  occupied tile. The hotkey now resolves an NPC landing first: service NPCs use
  their interaction stand when one is modeled, otherwise the first open
  cardinal adjacent cell is used. The resolver reads the selected NPC slot's
  live RAM position without forcing a full object-list rebuild, skips occupied
  adjacent cells, and logs `TELEPORT_SELECTED` with the target and landing.
  Follow-up logs showed the Weapons Merchant counter landed correctly at
  `(5,6)` but TALK still missed because the hero was not facing north, so
  selected NPC teleports now queue one raw post-teleport facing tap after the
  normal input-suppression window, neutralize input afterward, and log
  `TELEPORT_FACE`. A later retest showed `Shift+Enter` could leak through as
  Start if the hotkey was still physically held after the fixed suppression
  window, leaving the game in a menu/control-stuck-feeling state until Enter
  was pressed again. Teleport suppression now watches the non-modifier trigger
  key (`Enter` or an arrow), keeps Start/D-pad neutral until release, and only
  then runs the facing tap. A second live repro of the "hung" state showed
  input was actually neutral and the menu was closed; the selected Woman 3
  teleport had landed at `(5,7)`, where the first read treated UP/DOWN/RIGHT as
  blocked while LEFT was the NPC. The DOWN edge was later manually disproved
  and removed from the model; Brecconary still records the confirmed UP and
  RIGHT seams, and selected NPC teleport skips adjacent landings that have no
  non-target escape.
  Post-restore live testing also fixed the auto-visited marker for counter
  services when another object is selected: TALK from the weapon-shop stand
  `(5,6)` with `Exit to World Map` selected now marks `Weapons Merchant`
  visited instead of logging a no-adjacent-NPC skip.
  Next manual check: select a Brecconary NPC and press `Shift+Enter`; the hero
  should land next to or at the interaction stand for that NPC, face the target,
  and then TALK should reach the NPC/counter. Woman 3 at `(4,7)` should land at
  `(4,8)`, facing north, not at the trapped `(5,7)` stand.
- Brecconary west-wing throat follow-up: manual movement proved the pocket near
  `(3,7)` was artificially pathability-empty because live-passable type-0
  cells were missing passthrough entries. `(3,7)`, `(2,9)`, and `(3,9)` are now
  modeled as passthrough cells. Repeated `(3,7)->UP` attempts into `(3,6)`
  blocked 5/5 with no NPC or runtime block, so `(3,6)` remains closed. After
  reload, live inspect reports the throat cells as `reason=passthrough`, and
  the reachable-object filter from `(3,7)` now exposes 16 reachable objects
  instead of leaving the pocket empty.
- Brecconary east-wing throat follow-up: manual movement proved `(22,24)` is
  another live-passable type-0 false wall. `(22,24)->UP` into `(22,23)` and
  `(22,23)->DOWN` back into `(22,24)` both moved repeatedly. Before the patch,
  live inspect reported `(22,24)` as `reason=tile_type` with no permanent,
  runtime, NPC, or directional block, so this snuck in through the base town
  tile decoder rather than a learned runtime blocker. `map_reader.lua` now
  models `(22,24)` as a passthrough; after reload, the reachable-object filter
  from `(22,24)` reports 18 reachable objects.
- Brecconary weapon-shop throat bad-blocker bucket: manual movement proved the
  `(5,7)<->(5,8)` and `(5,7)<->(5,6)` edges are open both ways. These were not
  ROM tile false walls; they were stale directional blocks promoted from noisy
  selected-NPC/verifier timing evidence. Before the fixes,
  `inspect_move:5,7,DOWN` and later `inspect_move:5,7,UP` showed the model
  alone was blocking the move while tile, permanent, NPC, and runtime blockers
  were clear. `map_reader.lua` now removes both vertical directional blocks
  while keeping the still-modeled east seam into `(6,7)`.
- Combat spell-list narration first pass: after exiting Erdrick's Cave, a world
  map fight with a Red Slime exposed that battle spell menus were not being
  read. Live capture showed the SPELL submenu with cursor `D8=0 D9=0` and upper
  text containing `HEAL` / `HURT`, but the old battle parser treated cursor
  `(0,0)` as top-level `FIGHT`. `battle.lua` now recognizes visible known spell
  names on the battle spell-list screen, and `main.lua` keeps a battle spell
  submenu mode that announces the selected spell with MP cost. Live reload proof
  logged `BATTLE_SPELL: Spells. Heal. 4 MP` on the parked first spell. Next
  combat checks: move within the spell list, back out to the top-level battle
  menu, and cast a spell to verify result narration.
- Combat spell-list lag follow-up: the first spell-reader patch was too eager
  and decoded the upper battle window every battle-menu poll, which lagged out
  combat. The spell-screen detector is now only a one-time recovery probe for
  reload/attach into an unknown battle menu state; normal SPELL entry is tracked
  from the A press and should not continuously rescan upper PPU rows.
- Combat spell-list polish follow-up: live grinding confirmed most lag was gone
  but some glitching remained at battle start, SPELL menu entry, and Heal/Hurt
  cursor movement. The current disk patch removes the routine battle-start
  recovery scan, detects an A-held top-level SPELL -> `(0,0)` transition without
  an upper-window scan, and makes spell-list speech interrupt stale queued spell
  names. This patch is statically validated, but the last BizHawk auto-reload
  stopped polling after writing only a fresh log header, so it still needs a
  manual reload/restart before live judgment.
- Combat spell-list polish follow-up 2: the user's next live test confirmed
  combat-start lag is gone, with remaining glitching isolated to SPELL menu
  entry and Heal/Hurt cursor movement. `main.lua` now avoids the generic
  field-menu `COMMAND` PPU scanner in battle entirely; battle menu and spell
  list tracking read the already-cached D8/D9 cursor RAM instead, while keeping
  the expensive upper-window spell-list detector only for reload-directly-into-
  battle recovery. The script reloaded cleanly afterward; next fight should
  judge SPELL entry/cursor feel.
- Combat opening dialogue follow-up: live logs showed battle-state detection
  and menu speech were now prompt, but `A Red Slime draws near!` did not log
  until roughly 216-246 frames after battle start. Because menu/spell speech
  can queue ahead of that late stable-dialogue announcement, the latest patch
  resets lower-dialogue baselines on battle start, interrupts immediately with
  `Battle!`, and lets the first coherent `draws near` line interrupt queued
  menu speech as soon as it is complete. Next fight should confirm opening
  announcements are not delayed or skipped.
- Combat action-dialogue speed follow-up: after the opening fix, the user
  confirmed battle starts announce properly but action/damage lines were still
  arriving late in the round. Battle dialogue now has a narrowly-scoped fast
  path for complete action/damage sentence prefixes (`attacks`, HP
  reduced/decreased, misses/dodges) after a short 6-frame confirmation, using
  interrupting speech so stale menu chatter does not delay the result. Victory
  and reward pages intentionally stay on the normal stable reader, and leaked
  gold macro artifacts such as `GOLD Gold increases` are normalized. Next fight
  should judge whether attacks and damage land soon enough without making
  combat speech too chattery.
- Combat action-line miss follow-up: fresh logs showed a quick Slime fight at
  frame 7800 going from `A Slime draws near!` directly to reward text, while
  longer Red Slime rounds spoke attacks and damage. This pointed at one-hit
  kills where the text window briefly contained a complete `Bill attacks!`
  prefix followed by an incomplete `reduced by` fragment and then reward text.
  The normalizer now preserves complete action prefixes before dropping
  truncated damage fragments, and the fast path extracts the eligible action
  prefix before reward text begins. Next one-shot Slime should still speak at
  least `Bill attacks!`.
- Combat action-line repeat follow-up: the user heard `Bill attacks` repeat in
  one later fight. Logs showed one Red Slime damage line announced three times
  as the PPU rendered equivalent dot-artifact variants: `Hit . Points`,
  `been . reduced`, and trailing `5. .`. `battle.normalize_dialogue()` now
  removes isolated dot tiles between words and duplicate punctuation-dot
  artifacts before overlap/fast-path comparison. Stronger-enemy testing should
  verify that each round's action/damage line speaks once without losing the
  next round.
- Erdrick's Cave B2 first chest-route pass: the new B2 map `0x1D` had no
  permanent directional seam model, so auto-walk toward the chest at `(9,3)`
  kept learning hidden one-way maze walls during play and eventually gave up.
  Direct `probe_edge_verify` checks promoted only 5/5 blocked approaches:
  `(5,3).south`, `(6,4).west`, `(6,5).east/south`, `(7,4).south`,
  `(8,5).west/south`, `(9,5).south`, `(5,8).south/east`, and `(7,8).west`.
  A second pass from the stairs/chest route added `(1,6).south` and
  `(2,6).south`; route-observed `(4,7).west` and `(2,6).east` were directly
  mixed, so they intentionally stay out of permanent data. A final focused
  verifier pass added `(3,5).south`, `(4,4).east`, `(4,5).east`,
  `(4,6).east/west`, `(5,7).north/east`, `(5,8).west`, `(7,8).east`, and
  `(8,7).south`. A morning follow-up after a normal stairs-to-chest route
  promoted `(6,5).west`, `(7,9).east`, `(7,7).north`, `(8,7).north`,
  `(4,7).south`, and `(4,7).west` after fresh 5/5 verifiers. After enabling
  BizHawk auto-reload and reloading for real, validation exposed `(8,7).east`
  as blocked 5/5 and `(2,6).east` as blocked 10/10; both are now modeled. With
  runtime blocks cleared, `debug_pathfind_adjacent:9,3` from B2 stairs now
  reports no path to any chest-adjacent tile. Additional bridge spot checks
  reconfirmed `(5,3).south`, `(6,4).west`, `(9,5).south`, and `(7,4).south`
  blocked 10/10. A reverse pass from chest-side `(8,3)` toward stairs added
  `(9,5).north`, `(7,4).north`, `(6,4).north`, `(5,3).east`, `(5,2).east`, and
  `(5,1).east` after clean 10/10 direct verifiers. A later chest-to-stairs
  route naturally failed at `(8,4)->DOWN` and `(8,4)->LEFT`; fresh direct
  repeats promoted `(8,5).north` and `(7,4).east` after both verified blocked
  15/15. Walkthrough context confirmed B2 should be a normal loop to the tablet
  rather than a special-gated puzzle. A later route-shaped raw pass and fresh
  `probe_edge_verify:8,9,LEFT,15` restored `(7,9).east` after 15/15 blocked
  evidence; the earlier raw crossing evidence was timing-confounded. A
  walkthrough-guided left-edge pass found the missing route shape: the intended
  loop uses B2 edge passthrough cells `(0,4)` through `(0,7)`, then returns into
  the interior. `(0,8)`, `(0,9)`, and `(0,3)` were blocked or mixed and remain
  unmodeled. That pass also promoted `(1,3).south`, `(2,3).south`, and
  `(4,3).west` after clean 5/5 verifiers. A follow-up stairs-to-chest reroute
  got deeper, then exposed an upper-left choke. Newly modeled route blockers
  are `(1,5).west`, `(4,4).west`, `(4,3).north`, `(5,2).west`,
  `(4,1).south`, `(3,1).south`, `(3,5).north/west`, `(2,3).east`,
  `(2,1).south`, and `(1,1).south`; `(1,1).south` also verified blocked 15/15
  directly. The graph then needed one more narrow edge opening:
  `(1,2)->LEFT` moved into `(0,2)` 15/15, and forced-origin `(0,2)->UP` moved
  into `(0,1)`. The next autowalk reached `(0,1)` and failed into `(1,1)`;
  `(0,1)->RIGHT` verified blocked 15/15. Follow-up graph checks and live probes
  proved the top-edge continuation: `(0,1)->UP` into `(0,0)` passed 15/15,
  probes moved right through `(1,0)`..`(6,0)`, row-1 downward entries from
  x=1..5 blocked, and `(6,0)->DOWN` moved into `(6,1)`. Static tests pass, the
  running script reports `(0,0)` and `(6,0)` as `reason=passthrough`, and
  `debug_pathfind_adjacent:9,3` from stairs `(8,9)` chooses chest-adjacent
  `(8,3)` with a 42-step route and `Face east`. Live auto-walk is now
  two-way playable: stairs-to-chest reached the chest after one reroute bounce
  near `(7,2)`, and chest-to-stairs bounced through several return-trip dead
  branches before reaching B2 stairs `(8,9)`. Runtime blocks cleared afterward,
  leaving `RUNTIME_BLOCKS map=0x1D none`. The B2 maze is done enough for now:
  avoid spending more time perfecting optional return-trip bounces unless
  normal gameplay exposes a fresh blocker. Next preferred playtesting focus is
  away from pathfinding, likely combat dialogue tuning while exiting the
  dungeon.
- Brecconary autowalk stress survey: from the town entrance, `(0,15)` proved to
  be the isolated transition tile and `(1,15)` correctly hit the
  `low_exit_count` survey-start guardrail, so the parked-NPC survey ran from
  open tile `(15,15)`. It completed with `targets=21`, `successes=7`,
  `gated_or_isolated=8`, `state_issues=6`, and zero suspected engine blockers.
  Follow-up state showed `RUNTIME_BLOCKS map=0x08 none` and no strong survey
  candidates. The state issues were false interruptions caused by normal
  post-arrival `AUTO_WALK_FACE` / NPC-hold behavior between survey targets;
  `survey_safe` autowalk now suppresses those actions while normal player
  autowalk keeps them.
- Fresh Brecconary rerun after that fix improved to `12` successes and `0`
  state issues. The remaining two suspect blockers were checked directly:
  `(5,2)->DOWN` into `(5,3)` is a real engine block and is now modeled as
  `(5,3).north`; `(19,14)->RIGHT` into `(20,14)` is passable 5/5 and is now
  covered by a survey-classifier guard for orphaned routes that actually landed
  on the suspected tile.
- Next Brecconary survey exposed route drift rather than new blockers. Two
  queued routes overshot by one tile after timeout retry/settle handling, and
  the old survey queue appended those retries after later targets. That made
  several later targets fail from a stranded `(7,10)` start. The retry ordering
  is now fixed so drift retries run immediately, and queued auto-step no longer
  holds early subpixel twitches after a timeout retry.
- Autostep timing follow-up: queued routes now keep holding through early
  movement-subpixel twitches, but timing-suspect turn re-press twitches report
  early to the route manager as direct retry opportunities instead of waiting
  for a full wall timeout. Survey ignores those timing-suspect route blocks as
  map candidates. Live Brecconary proof from `(15,15)` to the world-map exit:
  the route reached `(1,15)` with `movement_succeeded=true`,
  `blocked_events=0`, `suspected_engine_blocked=0`, and
  `RUNTIME_BLOCKS map=0x08 none`.
- BizHawk 2.11.1 side-install check: user transferred save data and reloaded
  in Brecconary under `/mnt/d/emulation/bizhawk-2.11.1/EmuHawk.exe`. Current
  live state reported `POSITION: map=0x08(Brecconary) x=0 y=15`; speech bridge
  was ready with `error=none`; `dw_script_error.log` had no entries newer than
  the earlier `MER` refactor crash.
- Short scan profile on 2.11.1 while idle in Brecconary showed no large
  frame-loop spikes. Biggest steady costs were PPU text/menu scanners:
  `check_yesno_prompt avg_ms=3.566 max_ms=10`, `check_merchant_screen
  avg_ms=1.823 max_ms=6`, and `check_command_menu avg_ms=1.499 max_ms=5`.
  `state.check_for_changes avg_ms=0.009 max_ms=1`, confirming the old `$6003`
  cartridge-work-RAM lag is not present in this run.
- Aggregate PPU stats are still high (`reads=65493755`, `cache_hits=45887003`,
  `cache_misses=19606752`), so the next emulator-API experiment should focus
  on whether BizHawk 2.11.1's bulk/string byte-reading support can reduce
  contiguous menu/dialogue/nametable scans rather than expecting individual
  `readbyte` calls to become free.
- Bulk-read experiment live result: after enabling BizHawk's automatic script
  reload and reloading the patched script, `PPU_STATS` reported nonzero
  `bulk_reads` and `bulk_bytes`. A 2,280-frame Brecconary sample used
  `bulk_reads=46482`, `bulk_bytes=1290432`. Compared with the prior 2.11.1
  idle sample, average scanner costs improved substantially:
  `check_yesno_prompt 3.566ms -> 1.246ms`, `check_merchant_screen 1.823ms ->
  0.302ms`, `check_dialogue 1.119ms -> 0.337ms`, and `check_upper_dialogue
  0.790ms -> 0.254ms`. `check_command_menu` improved more modestly from
  `1.499ms -> 1.126ms`.
- Follow-up route-lag sample in Brecconary: from `(1,15)`, forced
  `pathability_filter:refresh` over 21 objects took `59ms` and logged
  `CMD_TIMING command=pathability_filter:refresh ms=59.000`. Scan profiling
  attributed the spike to `debug_tools.tick max_ms=60`, while
  `objects.check_refresh` stayed `0ms`; this points at reachability/pathability
  computation, not PPU scanning or object refresh.
- Same sample selected `Guard 2` at `(4,8)`. Plain `pathfind` planned a 9-step
  route to `(4,9)` without crossing the 25ms `ROUTE_PLAN_TIMING` threshold.
  `auto_walk` then completed all 9 steps from `(1,15)` to `(4,9)` with each
  movement finishing in 23-28 frames, no timeout/retry reroute, and normal
  post-arrival facing/hold. Current player position after the test is `(4,9)`.
- Object pathability refresh follow-up: the refresh now uses one map-wide
  reachable-cell pass rather than one A* search per object. After a live reload
  probe, `pathability_filter:refresh` from Brecconary `(4,9)` over 21 objects
  returned normally and produced no `OBJECT_PATHABILITY_TIMING` or `CMD_TIMING`
  warning, so the command stayed below the existing 25ms timing threshold. The
  earlier 59ms sample was from `(1,15)`, so keep watching this during normal
  browsing, but the direct per-object pathfinding cost has been removed.
- Reroute-lag follow-up: the spike during Merchant 2-to-exit travel was a real
  auto-step timeout on the unmodeled Brecconary edge `(5,13)->LEFT` into
  `(4,13)`, not a scan-loop or crash issue. The map now blocks `(4,13)` from
  the east approach. After reload, a path-only probe from `(5,6)` to the
  world-map exit chose the detour through `(5,9)->(4,9)` and avoided the old
  timeout edge. Player position was restored to Brecconary `(1,15)`.
- Inn route/name follow-up: `Merchant 2` is now named `Weapons Merchant` and
  `Merchant 3` is now named `Inn` in the Services object list. The inn service
  routes to the public stand tile `(8,21)` facing east; live TALK from there
  opened `Welcome to the traveler's Inn... Room and board is 6 GOLD per night.`
  A first retest exposed a timeout on `(7,17)->RIGHT` into `(8,17)`, so that
  west approach is now modeled as blocked. After reload, auto-walk from
  Brecconary `(1,15)` queued 17 steps for `Inn`, reached `(8,21)`, and faced
  east with no new blocked edge. Player position was restored to `(1,15)`.
- Weapons merchant item-list follow-up: after the clean route to the Brecconary
  weapon counter, TALK/YES reached `What dost thou wish to buy?` but the item
  list was silent. This was not a speech backend failure; `report_merchant_state`
  was reading the wrong screen rows. `merchant.lua`/`main.lua` now try the old
  fixed shop reader first, then live scrolled contexts including the alternate
  nametable base. Live proof recovered all six offers and spoke the selected
  item; a down/up cursor pulse spoke `Copper Sword. 180 gold.` then
  `Club. 60 gold.`
- Spell menu follow-up: after the player reached level 3 and learned Heal, the
  SPELL list opened but did not speak its contents. Live state showed the
  command menu header was still detected, speech was ready, and no dialogue or
  upper-window text was available; the missing piece was a SPELL submenu reader.
  `main.lua` now tracks `submenu=SPELL` and `items.lua` maps D9 to known
  spells. The visible field list only shows `>HEAL` and does not show a
  per-spell MP cost, so accessibility speech adds NES spell costs from metadata.
  Live reload/re-entry proof under BizHawk now speaks exactly
  `Spells. Heal. 4 MP`, then `report_menu_state` shows `submenu=SPELL` with
  speech ready and no backend error.
- Erdrick's Cave B1 first-floor cleanup: after entering the cave, object
  browsing initially showed Brecconary-style NPC ghosts. `objects.lua` now
  limits live NPC parsing to town/castle terrain contexts, so dungeon/cave
  maps keep only their static objects. Live reload proof on `map=0x1C` showed
  exactly `Exit to World Map` at `(0,0)` and the old hard-coded
  `Stairs Down to B2` at `(1,1)`; the NPC filter reported no objects. Probes
  also confirmed the entrance path `(0,0)->(1,0)->(1,1)` and reverse, so
  `map_reader.lua` models `(0,0)` and `(1,0)` as Erdrick B1 passthrough cells.
  After reload, `pathfind_to:1,1` from the entrance returned
  `Path: 1 east, 1 south`, and
  `report_survey_start` was viable with `targets=2` and `reachable_area=83`.
- Survey battle safety: autonomous surveys now pause on `battle_started`
  instead of recording the interrupted target as a map failure. The active route
  is cancelled, route context is cleared, and the same target is retried when
  field movement is safe again. This should make dungeon surveys tolerable once
  random encounters start appearing; low HP still aborts the survey before
  resuming movement.
- Erdrick's Cave B1 targeted survey pass: starting from the entrance `(0,0)`
  correctly tripped the survey `low_exit_count` guardrail, so the first-floor
  survey seed is `(2,2)`. From that seed, `Exit to World Map` surveyed
  successfully. The earlier `Stairs Down to B2` survey only proved reachability
  to the old modeled coordinate; using STAIRS at `(1,1)` produced
  `'There are no stairs here.`
- Erdrick's Cave stair-coordinate correction: the ROM stair-down table has
  `1C 09 09`, and live STAIRS from B1 `(9,9)` moves to B2 `(8,9)`. Live STAIRS
  from B2 `(8,9)` returns to B1 `(9,9)`. `objects.lua` now uses those paired
  coordinates instead of the old `(1,1)` guesses. After reload,
  `current_object` at B1 `(9,9)` reports `Stairs Down to B2: here`.
- Route execution briefly produced noisy blocked-move observations at `(2,1)`
  and `(1,2)`, but direct edge probes from `(2,2)` moved north and west
  successfully; treat those as route timing noise, not map data.
- Erdrick's Cave B1 route-block follow-up: a live route from the corrected B1
  stairs `(9,9)` back to the entrance completed at `(0,0)` and had no battle
  events in the log. It did expose real hidden maze seams around `(3,4)`.
  Direct probes after clearing runtime blocks confirmed `(3,4)->UP`,
  `(4,4)->UP`, `(3,4)->LEFT`, and `(3,4)->DOWN` block in-engine despite
  walkable decoded tiles. `map_reader.lua` now models those as directional
  blocks only; after reload, `pathfind_to:0,0` from `(9,9)` chose a route
  around that central cluster.
- Erdrick's Cave B1 entrance-to-stairs follow-up: another live pass exposed
  additional real directional seams at `(2,4)` from the west, `(1,5)` from the
  north, `(7,2)` from the west, `(6,3)` from the north, `(5,7)` from the
  north, `(6,6)` from the west, `(8,8)` from the north/west, and `(8,9)` from
  the west. After reload, auto-walk from entrance `(0,0)` to
  `Stairs Down to B2` reached `(9,9)` and ended with no runtime blocks.
  One-off route observations at `(6,4)` from the west were not promoted because
  direct probes moved successfully. No battle or encounter markers appeared in
  the latest B1 log.
- Erdrick's Cave B1 probe-hardening follow-up: a later route got worse after
  four newest one-probe additions and produced many reroutes plus contaminated
  runtime blocks. Rolled back `(4,3)` from the east, `(4,1)` from the south,
  `(6,3)` from the west, and `(6,6)` from the north until repeated
  `probe_edge_verify` consensus reconfirms them. Route-only blocked
  observations now stay as soft seam evidence instead of hard runtime map
  blockers.

## Current Goal

Run the early game as a player would, using the accessibility mod as the primary interface. Capture friction, missing narration, confusing commands, pathfinding recovery problems, and quality-of-life improvements.

## Focus Areas

Location awareness:
- Announce current map, coordinates when useful, facing, exits, nearby objects, and hazards
- Make it easy to recover orientation after movement or teleport/debug commands

Object interaction:
- Verify NPC, chest, door, stair, shop, and inn workflows
- Ensure object navigation explains whether a target is reachable
- Prefer actionable failure reasons over generic no-path messages

Menus and combat:
- Confirm menu cursor narration is reliable
- Confirm combat narration exposes HP, enemy state, results, and turn outcomes clearly
- Identify missing item/spell/shop narration needed for normal play

Movement and routing:
- Prefer routes that feel stable during actual play, not only during survey loops
- Log route failures with enough context to reproduce
- Avoid permanent map-data changes without direct blocker evidence

QoL feature check:
- `auto_walk` should now speak progress on longer routes and speak completion.
- After auto-walking to an NPC, the target should be held briefly so the player
  has time to use TALK. The route should also face the target after arrival so
  TALK does not fail with "There is no one there." For moving NPCs, the hold
  should pin the selected NPC slot to the planned object coordinates rather
  than a stale live position.
- Object filters are All, NPCs, Services, Treasure, Travel, and Doors; `Q`
  cycles forward, `Shift+J` and `Shift+L` move filter categories without
  scrolling objects, and `Shift+K` jumps back to All.
- Location readout is `Shift+W` now. Do not use the old `Shift+P` habit in
  BizHawk; this machine's BizHawk global hotkeys bind `P` to Quick Load.
- `Shift+O` cycles the separate pathability filter: All, Reachable, and
  Unreachable. This stacks with the object category filter, ignores moving NPC
  occupancy, and is intended for sanity-checking larger maps without making
  rapid J/K/L browsing run pathfinding every tap.
- Overworld route guidance exists for the first dungeon and the first safety
  returns. Select the `Erdrick's Cave`, `Brecconary`, or `Tantegel Castle`
  Travel object and press `R`, or use `route_guidance`,
  `start_overworld_route:cave`, `start_overworld_route:brecconary`, or
  `start_overworld_route:castle` from the command file. Press `R` again, run
  `route_status`, or browse the Travel filter to hear the next route waypoint.
  If a route is active and another guided Travel destination is selected,
  pressing `R` replaces the old route with a route to the new destination. If
  the player has drifted far off the expected waypoint, pressing `R` on the
  active route waypoint recalculates the next marker from the current position;
  `route_recalculate` / `recalculate_overworld_route` do the same from the
  command file. `stop_overworld_route` cancels the active route.
  This is manual guidance only: it does not enable overworld auto-walk, so the
  player still fights normal random encounters and grows during the trip.
  After starting the route, `current_object` should report a `Route next`
  waypoint rather than the plain landmark. `O` remains the plain heading/path
  preview for the selected object, and `U` remains reserved for auto-walk
  behavior.
- The Erdrick's Cave route includes a one-time bridge warning about stronger
  monsters beyond the crossing. During live testing, check whether this is
  helpful and quiet enough. The route now uses additional mountain-pinch
  markers after live evidence showed the old long heading from `(30,32)` led
  into blocked terrain: `East choke approach`, `Eastern mountain lane`,
  `North ridge bend`, then `North trail marker`. `East choke approach` at
  `(35,32)` and `Eastern mountain lane` at `(35,24)` are exact markers now;
  this prevents the route from advancing one tile early and telling the player
  to turn before the choke lane has really been cleared.
- The Erdrick's Cave route also uses the lower bridge detour after live
  evidence showed the direct first-bridge-to-pinch leg could block: from
  `Brecconary road`, it now routes to `Bridge south bend`, `Bridge lower west
  lane`, `Bridge west bend`, `Upper bridge lane`, and `East choke approach`.
  The immediate repro was a blocked north move from `(45,34)` into `(45,33)`,
  followed by blocked north attempts from `(41,35)`, `(40,35)`, and `(39,35)`
  when the detour was still too diagonal. A later log showed the old
  `Mountain pinch turn` marker caused a short west-then-east reversal, so it
  is no longer a mandatory step on this bridge/east-choke segment.
- The Brecconary and Tantegel Castle safety routes reverse the cave route's
  mountain-lane and bridge markers, using `East choke approach`, `Upper bridge
  lane`, `Bridge west bend`, `Bridge lower west lane`, and `Bridge south bend`
  before heading directly to safety. Live return evidence showed blocked
  direct moves into `(39,34)`, `(41,34)`, and `(42,34)`, while the lower bend
  through `(44,38)` reached town cleanly. The old safety marker at `(45,34)`
  was removed because it sent the player north, then immediately back south
  toward town. These routes warn once that monsters
  should become safer after the bridge and complete on the destination maps
  (`0x08` for Brecconary; `0x04` / `0x05` for Tantegel Castle).
- Read-only hotkey speech now queues instead of interrupting current speech:
  position, HP/MP, level, gold, experience, stats, screen text, and `R` route
  guidance/status use non-interrupting speech. While a manual step is still
  settling, `R` may report an active route's status, but starting a new route
  or using movement-changing object controls waits for stable movement and
  says `Wait for movement to finish`.
- Visited flags are session-only and map-scoped. Use `Shift+V` or
  `mark_visited` to mark manually; `clear_visited` clears the current map and
  `clear_visited:all` clears all maps. After TALK dialogue, the auto-visited
  marker now falls back to live NPC RAM if the cached object list has stale NPC
  coordinates, which can happen under BizHawk's disabled periodic NPC refresh.
  It also recognizes modeled service interaction stands such as Brecconary's
  weapon-shop counter even when that merchant is not the currently selected
  object. The marker stays armed for slow dialogue stabilization and survives
  BizHawk source reloads, so delayed NPC text should still mark the talked-to
  NPC without losing existing visited flags on `touch main.lua`.
- Selected-object teleport uses `Shift+Enter` for the selected object, with
  NPCs landing at an adjacent or service interaction cell, and
  `Shift+direction` for an adjacent landing on that side of the target.
- Watch selected-object teleport near doors/stairs and moving NPC clusters.
  The first manual test did not show lost keyboard input after teleport; logs
  showed the player boxed in at `(4,6)` on map `0x05` by NPCs at `(3,6)` and
  `(5,6)`, the door south, and a noisy north doorway edge.
- Direct selected-object teleport to an unwalkable target should speak a simple
  player-facing refusal, without mentioning debug-only `near` or `force` flags.
- Latest manual pass: Guard 1's route recovered and reached an adjacent tile,
  but the post-arrival facing input stepped into the guard's planned tile
  because the NPC hold used his wandered live position. `route_manager.lua` now
  holds the selected NPC at the planned target tile, and the false-visited case
  still behaves correctly.
- Stale command-menu cache was confirmed from live logs: after a TALK/dialogue
  attempt, `EVENT: command menu opened` had no matching close event, and later
  `auto_walk` commands were blocked before planning. `main.lua` now treats the
  raw `COMMAND` header match as scanner input only unless a confirmed live
  field-menu session is active. Movement and auto-walk stay blocked for that
  confirmed live session while the cursor hold or raw header is present, so a
  still-open command menu cannot let auto-step record false field blocks after
  the cursor blink/hold expires; TALK and menu-close paths clear the live flag
  before lingering PPU text can freeze field movement.
- Console reloads can leave required modules cached. A Guard 1 retest after a
  console reload still used the old `route_manager.lua` target-hold code and
  walked the hero onto Guard 1's tile at `(7,5)`. `main.lua` now clears project
  modules from `package.loaded` before requiring them. After a fresh reload,
  the visible lower text `'There is no one there.` was logged and spoken, while
  `report_upper_dialogue_state` reported `menu_raw=true menu_active=false`.
- A later Guard 1 playtest at `(18,2)` found a different TALK-failure silence:
  the normal filtered lower reader captured `'There is no one there.`, but the
  y<=3 row-1 cleaned dialogue path missed it and left `announced_lower` empty.
  The row-1 reader now falls back to the already-filtered lower dialogue when
  its fixed-row scan finds no lowercase text. An intermediate bad reload hit
  Lua 5.1's local limit, but the corrected file validates and later live
  reload probes have succeeded.
- Person 1 in the reachable NPC list can still be temporarily blocked by moving
  NPC traffic because the reachable filter intentionally ignores live NPC
  occupancy. The player-facing no-path hint should call that NPC clutter, not a
  closed door, when an NPC-free route exists. `route_manager.lua` now prioritizes
  that explanation over nearby closed-door frontiers. Live note: the reload
  verification accidentally auto-walked the post-reload selected `Exit to World
  Map`; current logged position after cleanup was map `0x04` `(11,28)` with
  runtime blocks clear.
- Reload-lag follow-up: after module-cache clearing, the old BizHawk shim's
  `FCEU` global survived reload and made `emulator_compat.lua` falsely detect
  FCEUX, disabling BizHawk scan throttling. The live symptom was a fresh log
  header with very slow frame progress and `report_scan_stats` saying
  `SCAN_PROFILE unavailable: not running under BizHawk`. `emulator_compat.lua`
  now detects real BizHawk APIs before trusting a stale `FCEU` shim; live
  `touch main.lua` recovery reached `launcher_probe:reload_detect` at frame 60
  and produced normal BizHawk scan stats.
- Reload-input follow-up: after the BizHawk/FCEUX detection fix, stale wrapped
  `joypad`/`input` tables could still be captured as native on reload. That
  could make `joypad.read()` empty and make `joypad.set()` neutralize controls,
  matching the observed `X`/`Z` failures and odd emulator-key behavior.
  `emulator_compat.lua` now unwraps previous adapter closures back to native
  BizHawk APIs and replaces its `FCEU.frameadvance` wrapper on every reload.
  Live reload check reached frame 180, reported `cache_flushes=179`, and had no
  stuck keys in `input_status`.
- Pathfinding confusion follow-up: the no-path behavior after manual movement
  around Guard 1/door terrain was caused by manual blocked steps being promoted
  into runtime blockers on map `0x05`. `route_manager.lua` now treats
  `queued_route=false` blocks as diagnostic seam observations only. A live
  post-reload snapshot reported `RUNTIME_BLOCKS map=0x05 none`.
- Guard 1 overlap follow-up: post-arrival facing was still being interpreted by
  `auto_step` as a player tap, which could walk onto the NPC square. The live
  retest after the suppression patch stayed at `(4,7)` with Guard 1 one tile
  north at `(4,6)`.
- Route-blocking follow-up: if a queued route is blocked by a live NPC, it
  should now be treated as temporary NPC movement instead of map geometry. A
  separate chest route from `(4,7)` hit a current runtime seam block at
  `(4,6)` from the south; current NPC blockers were elsewhere, so that case is
  not NPC clutter.
- Command-menu open follow-up: after the King dialogue fix, opening the command
  menu could still briefly speak the last-used cursor selection before settling
  on TALK. `main.lua` now debounces the opening announcement for six frames and
  uses the first real cursor movement or settled cursor item, so the expected
  open line is `Command. TALK` without a stale selection first. After killing
  and restarting the script, the user physically retested the fix and confirmed
  it worked as expected.
- Death-square follow-up: manual movement found a damaging/death tile on
  Tantegel Castle map `0x04` at `(10,18)`. Entering it from `(10,19)` logged
  `Lost 15 HP. HP 0`, then the normal `Thou art dead.` / Death King recovery
  sequence. Death King dialogue narration passed. The tile is now modeled as a
  hazard, not a wall, so auto-walk, teleport walkability, and tap-to-step
  extension avoid it while deliberate held manual movement remains under
  player control.
- Reachable NPC dialogue pass: the user finished dialogue testing all
  reachable NPCs in this part of Tantegel Castle. Waiting for NPC movement
  remained tedious enough that Guard 1 was reached by teleport. The castle
  merchant-labeled NPCs behaved as dialogue-only NPCs in this pass; keep an
  eye on whether they ever sell later, and consider removing them from the
  Services filter if they stay dialogue-only.
- First-town merchant follow-up: Brecconary `Merchant 1` also behaved as a
  dialogue-only NPC (`Please, save us from the minions of the Dragonlord.`),
  despite being listed under Services. When the merchant moved near the top of
  town, the y<=3 dialogue reader spoke only `Please, save us from`. The row-1
  dialogue path now prefers the richer normal lower-window candidate when the
  fixed y<=3 row scan catches only part of a multi-line message.
- Brecconary service-discovery follow-up: the user talked to all reachable
  townspeople in the first town and still did not find an inn keeper or real
  merchant service. Woman 3 said she was near the shop. The shop/inn actors may
  be blocked targets, may be represented differently than normal wandering
  NPCs, or may need a shop-counter/object interaction path rather than ordinary
  TALK-to-NPC handling.
- Brecconary weapon-shop follow-up: the true weapon/armor merchant is
  `Merchant 2` at `(5,4)`. The safe public access path reaches the doorway/
  counter square at `(5,6)`; face north and TALK even though the merchant object
  is two tiles north. The route enters through `(5,8)->(5,7)->(5,6)`; both
  `(5,7)` and `(5,6)` are false-wall passthrough tiles in the map model. Routes from the merchant pockets to the
  world-map exit proved `(4,4)`, `(4,5)`, `(4,6)`, `(5,5)`, `(6,4)`, and
  `(6,5)` are trap/service-pocket cells for autonomous movement; the map model
  keeps those pathfinder-forbidden and also blocks the false `(8,5)->LEFT`
  shortcut into `(7,5)`.
- Brecconary Merchant 2 item-list narration regression is fixed after the
  `main.lua` local-reduction refactor. The shop list is rendered in fixed
  screen/menu rows even while field scroll registers remain non-zero, so
  merchant scanning now reads screen coordinates by default. Live proof after
  reload: the list reported all six offers and a Down input spoke
  `Clothes. 20 gold.`
- Brecconary counter-service discovery: raw map block `0xF` marks the shop
  counter/large-tile trigger. `Inn` at `(10,21)` is the inn keeper; TALK from
  the public stand tile `(8,21)` while facing east opens `Welcome to the
  traveler's Inn... Room and board is 6 GOLD per night.` `Merchant 4` at
  `(25,25)` is the tool shop; TALK from `(24,25)` while facing east opens
  `Welcome. We deal in tools.` `objects.lua` now exposes these confirmed
  service interaction tiles directly, while keeping the generic adjacent raw
  large-tile inference for future service counters. Later Merchant 4 probing
  superseded the route target: `(24,25)` remains a blocked movement seam and
  `(25,26)` remains an alternate pocket; normal service routing should use the
  public `(23,25)` stand facing east.
- Weapon-shop item list follow-up: the buy/yes-no prompt worked, but the item
  list initially spoke field command labels and raw cursor coordinates because
  the shop list also shows a `COMMAND` header and reuses menu cursor RAM.
  `merchant.lua` now decodes the visible scrolled shop rows and prices, and
  `main.lua` suppresses command-menu speech whenever that merchant layout or
  lower shop dialogue is present. The merchant scan also keeps running while
  the shop prompt sets the generic dialogue hint, so the item reader does not
  starve after a buy/error/continue cycle. Live validation completed a Copper
  Sword not-enough-gold loop and returned to the list with `Bamboo Pole. 10
  gold.` instead of `STATUS` / `SEARCH`.
- Ctrl+W crash follow-up: the script crashed immediately after `Ctrl+W` with a
  fresh `dw_script_error.log` entry in `snapshot.update`; the fatal line was
  adapter logging through BizHawk `console.log()` while memory fallback was
  active. Adapter logging is now protected. A follow-up reload-window crash
  also showed temporarily unavailable BizHawk memory APIs, so the adapter now
  fails closed for unavailable reads/writes instead of crashing. The second
  live reload succeeded and speech reported ready.

## Initial Gameplay Pass Checklist

Use this as a lightweight first pass:
- Start or load a normal early-game state
- Confirm speech backend readiness with `speech_status`
- Confirm player state with `report_position` or `log_state`
- Navigate around the starting castle/interior without visual assumptions
- Interact with the king/throne-room objects if available
- Use stairs/doors/exits intentionally
- Visit the first town and interact with NPCs/shops if reachable
- In town, verify visited flags and Services/Treasure/Travel filter categories
- On the world map, select `Erdrick's Cave`, `Brecconary`, or `Tantegel
  Castle`, press `R` or run `route_guidance`, browse the small Travel route
  layer, verify `current_object` selects `Route next`, and verify
  `route_status` plus one route-progress announcement
- Enter a simple combat encounter and evaluate narration
- Record every point where the player would feel lost, under-informed, or unable to recover

## Open Gameplay Issues

### GP-002

Severity: Medium

Area: Command menu narration / map-position sensitivity

Status:
Resolved for the latest King/dialogue and command-menu opening reports. Keep
watching this area during normal play, but there is no active blocker at the
2026-05-05 wrap-up.

Description:
Manual testing found that in certain parts of the map, the command menu or
dialogue options do not read correctly. The latest scripted snapshots only saw
the status row (`menu_raw=false menu_active=false lower=""`), so the bug was
not present at capture time. `main.lua` now keeps command-menu scanning active
during current/recent player input even while BizHawk dialogue throttling is
active, but automated simulated A/B presses did not open the field menu in the
live session.

Next evidence to collect:
- Reproduce one bad command-menu read.
- Immediately capture `report_position`, `input_status`, and ideally
  `report_upper_dialogue_state` plus `report_movement_state:menu_bad_region`.
- Compare with a nearby position where the command menu reads correctly.
- Check whether the issue correlates with scroll/camera bytes, row-1 command
  menu parsing, or map-specific PPU layout.
- For King/dialogue silence specifically, the latest bad-state `Ctrl+D` dump
  contained no visible command/menu/dialogue text in raw PPU, and the live
  parser state also saw only status text with speech ready. The diagnostic
  samplers now clear BizHawk's PPU cache first; if the next dump is still blank
  while text is believed to be visible, treat it as a capture-timing or
  alternate-domain problem rather than a normal parser-row bug. The next
  `Ctrl+D` dump should include a `PPU source comparison` section to compare
  native `ppu.readbyte` with available nametable-like BizHawk memory domains.
- Follow-up resolved the source issue: native BizHawk `ppu.readbyte` was the
  blank source, while `CIRAM (nametables)` had the actual King question,
  `COMMAND`, and Yes/No/menu text. The compatibility layer now prefers that
  nametable memory domain. Live reload proof spoke the King question and
  `YES NO prompt. YES`; continue playtesting menu/dialogue normally from here.
- The remaining silent King farewell was a separate stale-base issue. The dump
  had the farewell text (`Goodbye now... Take care...`) in the nametable, but
  `PPUCTRL` reported `base_nt=0` while the text still required NT1-first screen
  order. The lower-dialogue reader now tries the alternate nametable order when
  it contains more lowercase dialogue. Retest on the next King save/continue
  flow; the final farewell should now speak.
- A follow-up confirmed the King dialogue path is working. Continue with normal
  command-menu playtesting.
- After a script restart, the command-menu opening debounce also passed the
  physical retest: the previous selection is no longer spoken before TALK.

### GP-001

Severity: High

Area: Emulator default / BizHawk performance

Status:
BizHawk swap accepted as successful enough to continue normal playtesting from
the BizHawk path. First clean early-game flow was confirmed manually on
2026-04-30, and basic manual testing on the first two maps after the conversion
found scripts behaving as expected. Remaining audio stutters or small narration
bugs should be handled as ordinary gameplay polish unless fresh logs show a new
large script spike.

Description:
BizHawk is now the default emulator path. It can launch the ROM and
accessibility script, and the script can speak through title/continue flow.
Early gameplay was initially super laggy once the game proper started, but the
current BizHawk-only throttles have substantially reduced scan load during the
king's boot dialogue.

Reproduction steps:
- Launch with `./launch_dw.sh`
- Continue an existing quest
- Wait until the game proper starts

Observed behavior:
- Title flow and speech work.
- Lag improves with compatibility-layer PPU caching and gameplay scan
  throttling.
- During the king's normal boot dialogue, current profiling shows only
  dialogue/yes-no scans running; command-menu, merchant, and object refresh
  scans are suppressed.
- Lag did not fully stop after king dialogue ended in the live script that was
  running before the latest state-detector patch.
- Spoken status summaries appearing inside king dialogue were caused by stray
  BizHawk keyboard hotkeys, not by dialogue parsing. BizHawk keyboard hotkeys
  are now disabled by default.
- The object explorer initially stopped working under BizHawk because the first
  hotkey gate blocked every keyboard shortcut. The current patch restores the
  default object/navigation hotkeys through `bizhawk_keyboard_hotkey_allowlist`.
  The `N` tile/coordinate diagnostic is also allowed for playtesting, while
  broader status/raw-dump diagnostics stay blocked.
- Pressing `N` then provided a clean audio-cutout repro: the spoken coordinate
  check was coupled to the full `tile_diag.txt` dump and could stall audio for
  about 1.5-2 seconds. The current patch keeps `N` to the compact spoken
  coordinate/tile summary by default; set `tile_diag_dump_on_hotkey=true` only
  for slow forensic dumps.
- A command-file `current_object` probe still returned an object description,
  so this was a keyboard-filter issue rather than an object-list failure.
- Normal play audio is now reported smooth, but route/path commands can still
  glitch emulator audio while processing. A live sample showed command/object
  refresh spikes rather than steady frame-loop lag: `debug_tools.tick
  max_ms=1931` and `objects.check_refresh max_ms=2068`.
- Dialogue is no longer lagging, but live testing showed it could speak before
  all new text arrived. The current patch clears BizHawk's PPU cache for
  dynamic dialogue scans so partially rendered cached text should not announce
  as stable.
- Object navigator caused an approximate two-second BizHawk freeze. The current
  patch makes BizHawk object descriptions skip reachability/path checks by
  default; explicit `pathfind` and `auto_walk` still do the heavier work.
- Object-browser hotkeys now explicitly request brief descriptions only:
  name/direction/count, without path reachability previews or raw coordinate
  debug suffixes. Explicit `O` pathfind and `U` auto-walk remain the route-work
  commands.
- After reloading with the latest object-refresh patch, broad lag is mostly
  under control. Object-list navigation still causes a small amount of lag, but
  profiling no longer shows script-side object/hotkey spikes.
- Rapid J/L object navigation now coalesces speech by default with
  `object_nav_speech_coalesce_frames=18`: selection changes immediately, but
  only the latest object description speaks after a short pause. K/current
  object still speaks immediately. The first 6-frame trial still flushed
  repeatedly during manual tapping, so this wider delay needs live BizHawk
  audio confirmation.
- The BizHawk audio config trial helped: with `SoundBufferSizeMs=200`,
  `SoundThrottle=true`, `FrameSkip=0`, and `Rewind.Enabled=false`, background
  window work no longer reproduced the previous audio glitching. One glitch
  occurred while focused in the emulator, but it has not reproduced.
- Wrap-up manual testing on 2026-04-30 covered the first two maps at a basic
  level. Apart from audio stuttering, script behavior matched expectations
  after the emulator conversion.
- Random emulator audio freezes were also observed, especially while working in
  other windows. This still needs correlation with `CMD_TIMING` and scan stats;
  if no script spike appears, treat it as a BizHawk/Windows focus or scheduling
  issue rather than the Lua loop.
- Normal movement/menu responsiveness after reloading the latest script still
  needs a fresh player-control check.
- Standing by the king on map `0x05`, auto-walk to the selected stairs returned
  "No path found". After the ROM-domain fix, live probes now show sane map
  dimensions and tile data: `(8,8)` is passable stair/corridor passthrough,
  while `(4,7)` is a closed magic-key door. The remaining no-path is normal
  locked-door route state, not a BizHawk ROM decode failure.

Expected behavior:
- Emulator remains responsive enough for normal play while the accessibility
  script runs.

Evidence:
- PPU caching improved title lag but not field lag enough.
- Current hypothesis is that field gameplay runs too many PPU-heavy scans each
  frame under BizHawk's slower Lua memory-domain APIs.
- A BizHawk-only scan-throttle patch has been added for title-state rescans,
  yes/no prompt scans, command/battle menu checks, merchant analysis, lower
  dialogue, and upper dialogue.
- Latest king-dialogue sample after boot-dialogue grace: `PPU_STATS
  reads=123840 cache_hits=108736 cache_misses=15104`; active scan profiles
  were lower dialogue, yes/no prompt, and upper dialogue only.
- Latest post-dialogue/player-control sample before the state patch:
  `state.check_for_changes calls=240 reads=0 ms=26984 avg_ms=112.433`. The
  source was the BizHawk path reading `$6003` every frame for sprite CHR/battle
  detection.
- Latest route/path command patch caches static object sources per map, adds
  `CMD_TIMING` logging for slow command handlers, and throttles repeated
  `CAN_WALK false` debug lines.
- Latest object/dialogue patch clears dynamic text PPU cache reads under
  BizHawk and adds `bizhawk_object_reachability_descriptions=false` so object
  navigator speech is quick by default.
- Latest post-dialogue object-list samples:
  `objects.check_refresh max_ms=1` for command-file object navigation, and a
  real-hotkey sample showed `hotkeys.update max_ms=1` plus
  `objects.check_refresh max_ms=1`. The earlier two-second object-refresh spike
  is no longer present with `bizhawk_periodic_npc_refresh=false`.
- The object-nav speech coalescer is covered by `test_hotkeys.lua`; tests cover
  delayed J/L speech, rapid-tap latest-only speech, K/current-object immediate
  speech, route-action clearing, and `object_nav_speech_coalesce_frames=0`.
- `emulator_compat.lua` now scores BizHawk ROM candidate domains/address
  mappings so headerless PRG-only ROM domains still emulate FCEUX
  `rom.readbyte()` offsets. New validation: `test_emulator_compat.lua` covers
  full iNES and headerless PRG domain layouts.
- Live follow-up on 2026-04-29 confirmed the map `0x05` stair path now decodes
  correctly under BizHawk: `inspect_tile:8,8` returned `dims=10x10`,
  `tile=15.0`, `reason=passthrough`, and `effective_passable=true`;
  `inspect_move:4,6,DOWN` returned `reason=door_closed` for `(4,7)`.
- Route messaging now detects a closed-door frontier on no-path plans and tells
  the player to get/use a magic key instead of only saying "No path found".
  Covered by `test_route_manager.lua`.
- Live playtesting after this still showed the door as closed after the player
  opened it. Root cause: BizHawk `memory.readbyte()` was still reading
  `$600C/$600D` opened-door slots through `mainmemory`, but DW1 stores those
  slots in cartridge work RAM. `emulator_compat.lua` now routes `$6000-$7FFF`
  reads through System Bus / PRG-RAM-style domains, and
  `test_emulator_compat.lua` plus `test_map_reader.lua` cover opened-door RAM.
- Manual retest after the cartridge-RAM fix confirmed the expected flow from
  game launch: open all throne-room chests, open the `(4,7)` door, and walk
  down the stairs into the castle proper.
- The same run showed auto-walk audio pain around blocked-step retries. Local
  config now uses `auto_step_timeout=45` and `auto_step_block_retry_limit=1`
  to shorten blocked-route retry windows.
- A 2026-05-05 fresh-game playtest found manual autostep feeling like native
  BizHawk movement: direction keys worked, but the player often had to hold
  until the game turned or stepped. Recent logs showed many 45-frame
  `auto_step timeout retry` paths, and the checked-in config had quick
  turn-only re-presses disabled. `auto_step_turn_repress_limit` is now `1`
  again so a tap that only turns gets one prompt follow-up press before the
  slower timeout retry path. Follow-up logs showed early subpixel changes could
  still mark a turn-in-place as movement started, suppressing that quick
  re-press until the timeout path; `auto_step.lua` now treats very early
  subpixel-only starts as eligible for the turn re-press too.
- The same fresh-game pass exposed stale object-browser NPCs after entering
  the second map from the throne room: old map `0x05` NPCs could remain
  selected on map `0x04` until routing hit a blocking live NPC and refreshed
  the list. Fresh Lua startup transitions cleanly; the repro returned only
  after touching `main.lua` for a BizHawk reload. The stale-state PPU dump did
  not show the prior wrong-source bug, so the fix is reload/transition-state
  based. The first signature patch fixed the current map after reload but not
  the next transition. The current patch keeps accepted NPC signatures in
  `_G.DW_OBJECTS_RELOAD_STATE`, observes the latest current-map NPC coordinate
  signature during normal gameplay frames, masks off direction/frame bits, and
  hides NPCs on map entry while RAM still matches the just-observed previous
  map. Retest by touching `main.lua`, waiting for reload to settle, using
  STAIRS between map `0x05` and `0x04`, and checking the NPC filter for the
  destination map's NPCs rather than the map just left. User retest confirmed
  the desired result after reload: 4 NPCs on map `0x05`, and 20 NPCs on map
  `0x04`.
- A later 2026-04-30 first-town manual run reported that route/path commands
  still caused lag, name-entry clicks could double-enter letters, and movement
  could overshoot cells. The live `dw_debug.log` did not contain `CMD_TIMING`
  or scan-profile spikes for the hotkey-triggered `O`/`U` work, so route-plan
  timing is now logged separately as `ROUTE_PLAN_TIMING`.
- The same log showed a concrete queued auto-walk overshoot pattern: after a
  south step to `(1,4)`, the next queued `right` step completed at `(1,5)`
  while the planned seam was `(2,4)`; after a right segment to `(3,5)`, the
  next queued `down` completed at `(4,5)` while the planned seam was `(3,6)`.
  `auto_step_route_turn_settle_frames=16` now pauses queued routes before
  changing direction, while straight segments can still chain quickly.
- Chosen-path summaries remain in the log, but tile-by-tile chosen-path dumps
  are now opt-in with `pathfind_log_steps=true` because the detailed dump is
  slow and noisy during ordinary playtesting.
- Focused wrap-up validation after making `N` cheap and object browsing brief
  passed `luac -p hotkeys.lua objects.lua route_manager.lua config.lua
  test_hotkeys.lua`, `lua test_hotkeys.lua`, `lua test_route_manager.lua`,
  `lua test_objects.lua`, and `git diff --check`.
- Route-turn follow-up validation passed `luac -p auto_step.lua pathfinder.lua
  route_manager.lua config.lua test_auto_step.lua`, `lua test_auto_step.lua`,
  `lua test_route_manager.lua`, `lua test_pathfinder.lua`, and
  `git diff --check`. `test_pathfinder.lua` still prints the known WSL
  Tolk/`cmd` warning before passing.
- A follow-up live log after reloading showed the queued route turn-settle
  working for a 2-step route, but also exposed the remaining autowalk lag as
  route planning: `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_15 ...
  path_len=2 ms=1978.000`. `pathfinder.lua` now prunes adjacent candidates that
  cannot beat the current shortest landing path and defers reachable-area
  diagnostics unless needed for an equal-length tie or no-path evidence.
- The same run's quickload/town object issue matched a two-phase object refresh:
  static objects were available first, while NPCs were deferred until a later
  refresh. Under BizHawk scan throttling that delay could leave only "Exit to
  World Map" in Brecconary briefly. `objects.needs_refresh(map_id)` now lets
  map-entry and deferred NPC refreshes bypass the periodic 120-frame throttle.
- Route-planning/object-refresh validation passed `luac -p pathfinder.lua
  objects.lua main.lua test_pathfinder.lua test_objects.lua`,
  `lua test_pathfinder.lua`, `lua test_objects.lua`, `lua test_route_manager.lua`,
  `lua test_map_survey.lua`, `lua test_auto_step.lua`, and `git diff --check`.
- Live retest after script reload confirmed the object list populated quickly,
  but auto-walk still choked and then cancelled for path drift. The log showed
  `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_4 ... path_len=13
  ms=1836.000`, followed by drift during turn-settle: after reaching `(4,14)`
  and preparing to turn up, the player slid to `(5,14)` and the route cancelled
  with `route_drift_off_path`.
- `auto_step.lua` now actively neutralizes the D-pad during route-settle frames,
  not just the first post-step release frames. `pathfinder.lua` now uses a
  per-plan walkability snapshot from `map_reader.lua`, with a fallback per-search
  cache, so A* does not repeatedly call the slower map-reader walkability path.
- Latest live retest showed auto-walk lag is reduced but still audible, and
  `O` show-path lags too. The log showed auto-walk route plans at `path_len=13
  ms=1852.000` and `path_len=10 ms=1238.000`; show-path route previews logged
  `path_len=7 ms=1422.000` and `path_len=1 ms=1514.000`. Because the 1-step
  preview still lagged, the likely culprit is fixed route-command overhead,
  especially forced live NPC refresh/freezing under BizHawk.
- BizHawk now skips forced live NPC refresh before `O`/`U` route plans by
  default (`bizhawk_route_refresh_npcs=false`) and skips auto-walk's NPC RAM
  freeze by default (`bizhawk_autowalk_freeze_npcs=false`). FCEUX keeps the
  previous behavior, and both BizHawk options can be turned back on for a
  blocker/NPC-specific investigation.
- The same log still showed route drift: after a first `right` step from
  `(0,15)` to `(1,15)`, settle before a planned `up` drifted to `(2,15)`; after
  a right segment from `(6,16)` to `(7,16)`, settle before a planned `up`
  drifted to `(8,16)`. `auto_step.lua` now actively releases route-owned D-pad
  input after the inject window as well as during turn-settle frames.
- Latest route-lag/drift validation passed `luac -p auto_step.lua
  route_manager.lua config.lua pathfinder.lua map_reader.lua objects.lua
  main.lua test_auto_step.lua test_route_manager.lua test_pathfinder.lua
  test_map_reader.lua test_objects.lua test_map_survey.lua`,
  `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  `lua test_pathfinder.lua`, `lua test_map_reader.lua`,
  `lua test_objects.lua`, `lua test_map_survey.lua`, and `git diff --check`.
- 2026-04-30 follow-up from quick slot 1 in Brecconary: warming the current map
  grid during map-entry object refresh removed the first usable `O` /
  `auto_walk` route spike to Person 2; the prior cold route was about
  1.7-1.9 seconds. 2026-05-05 live castle play then showed that moving the cost
  to map entry made transitions hitch under BizHawk (`objects.check_refresh
  max_ms=1846`), so BizHawk now skips map-entry grid prewarm by default and
  builds the grid lazily on first route/path use. FCEUX keeps prewarming, and
  BizHawk can opt in with `bizhawk_map_entry_prewarm_path_grid=true`.
- The same live route reached the intended adjacent tile `(10,15)` and ended
  with neutral input. The old turn-settle drift signatures did not reappear.
  There is still a smaller executor issue: the first facing/step from the town
  entrance can consume one timeout/brute-force retry before walking succeeds.
- If audio still cuts out shortly after quickload or map entry, first inspect
  `objects.check_refresh max_ms` and whether it coincides with lazy first-route
  path-grid work before moving any cost back onto the transition frame.
- Latest user retest: manual walking overshoot is much better, with remaining
  overshoot mostly when several movement presses are entered rapidly. Auto-walk
  audio is improved, but a lag spike still happened near the end of route
  attempts. Fresh logs showed the latest route reached the intended adjacent
  tile `(15,19)` with neutral input and no runtime blockers; the suspicious
  spike is `objects.check_refresh max_ms=1658` from route cleanup. BizHawk now
  skips the immediate post-route object refresh by default with
  `bizhawk_route_cleanup_refresh_objects=false`.
- Live validation after reloading the patch completed two Brecconary auto-walks:
  Person 4 from `(0,15)` to `(1,14)`, then Person 2 from `(1,14)` to `(9,14)`.
  Both ended adjacent to the target with neutral input and no runtime blockers.
  Around the longer 10-step route, `objects.check_refresh max_ms=0`,
  `debug_tools.tick max_ms=3`, and `auto_step.update max_ms=1`.
- User hands-on retest after that patch confirmed auto-walk is behaving much
  better, reaching intended targets, and the lag seems under control.
- King dialogue follow-up: the main King greeting now reads in correct screen
  order, but the Yes/No prompts initially repeated the tail of the previous
  dialogue page before the question. The worktree now strips that overlap so
  the save prompt should speak just `Will thou tell me now...` and the continue
  prompt should speak just `Dost thou wish to continue thy quest?` before
  `YES NO prompt`.
- Latest lag check: BizHawk's config is already on the safer audio/throttle
  baseline. The latest scan stats instead point at script-side spikes,
  especially object refresh and route/movement work. For the next lag repro,
  use `reset_scan_stats`, perform one action, then `report_scan_stats` before
  changing emulator timing settings.
- Reload/menu silence follow-up: after reload near the King, speech backend
  diagnostics were healthy but the command-menu scanner saw no menu at
  `scroll_tiles=22 base_nt=1`. The worktree now scans both nametable wrap
  orders for command-menu and Yes/No UI text. Retest physically by opening the
  command menu and using TALK near the King; automated debug A input still does
  not reproduce a real menu open here.
- The first PPU dump for the remaining silence did not include an active menu
  or dialogue page and only covered lower rows. `Ctrl+D` now writes a full
  0-29-row PPU dump with decoded NT0/NT1 wrap orders and parser match hints.
  If silence remains, capture `Ctrl+D` while the menu or dialogue is actually
  visible, or use `report_menu_state` while holding the bad state.
- Main-menu erase/name-entry follow-up: the latest live log showed the erase
  confirmation being treated as `field` on map `0x00`, causing extra dialogue,
  bogus auto-step block logs, and the false "Game started" / "Unknown Map 0"
  path. `state.lua` now keeps erase confirmation and name entry in title state,
  and `main.lua` now suppresses repeated A frames on name entry until a short
  stable release. `report_title_state` can log the visible title rows and
  selected name-grid cell if the issue needs another capture after reload.
- The next input check found that `S` is BizHawk's NES `P1 A` autofire binding,
  while normal A is `X`. Retest name entry and erase confirmation with `X`, not
  `S`; the map announcement after erase likely came from an extra autofire
  confirm into real gameplay.
- Mod hotkeys were regrouped to avoid BizHawk controls: common object actions
  stay on bare keys (`J/K/L/O/U/Q`), info commands use `Shift+key`, diagnostics
  use `Ctrl+key`, freeze NPCs is `Shift+F`, and tile diagnostics is `Ctrl+N`.
- King dialogue regression: after the hotkey/menu fixes, the king's lower
  dialogue was present (`lower_len=97`) but not automatically read because
  `in_gameplay` stayed false after the title-to-field debounce. `main.lua` now
  clears that debounce after "Game started."; the next live log confirmed king
  and NPC dialogue auto-read again.
- Command menu and post-dialogue status polish: command-menu openings now speak
  the highlighted item immediately, such as `Command. TALK`, instead of only
  saying `Command.`. The lower dialogue reader now skips persistent status rows
  like `Bill LV 1 HP 15 MP 0 G 120 E 0`, including hero names with lowercase
  letters, so the status line should not speak after dialogue dismissal.
- Follow-up log evidence showed the remaining status-line speech was coming
  from the upper dialogue reader, not the lower one: `report_upper_dialogue_state`
  showed `upper="Bill LV ..."` and `lower_len=0`. The upper reader now suppresses
  extracted `new_text` fragments that are themselves status text and logs
  `UPPER_DIALOGUE_SUPPRESS_STATUS` when that path is caught.
- BizHawk launchers now support `--state-slot N`; quick slot 1 can be loaded
  with `./launch_dw.sh --state-slot 1` or `./launch_bizhawk.sh --state-slot 1`.
- 2026-05-01 quick live map `0x05` route cycle: from throne-room `(3,4)`,
  object enumeration found 9 objects and the door/stairs data still looked sane
  (`inspect_tile:4,7` = `door_closed`, `inspect_tile:8,8` = `passthrough`).
  Auto-walk reached a nearby chest and then Guard 3. The Guard 3 route first
  logged `NEW BLOCK` for `(4,4)` down into `(4,5)`, but a controlled
  `probe_edge:DOWN` from `(4,4)` moved successfully, changing the seam evidence
  to noisy/transient rather than a confirmed map blocker.
- The same cycle found player-facing hitch risk in debug commands, not focused
  route execution: `report_path_state`, `inspect_move`, explicit
  `pathfind_adjacent`, and `probe_edge` all produced roughly 1-1.7 second
  `CMD_TIMING` lines. The focused Guard 3 auto-walk window itself reported
  `objects.check_refresh max_ms=0`, `auto_step.update max_ms=1`, and
  `debug_tools.tick max_ms=2`.
- 2026-05-05 crash during live play: `dw_debug.log` reset to a bare header and
  `dw_script_error.log` showed `snapshot.update: 69` from BizHawk
  `mainmemory.read_u8` during `game_snapshot.update`. The memory adapter now
  catches direct RAM API errors and falls back to `System Bus`, but because the
  script was already dead, this still needs a manual BizHawk script reload or
  emulator relaunch before gameplay retest.
- 2026-05-05 King dialogue glitch: the line was spoken as
  `greatly pleased 'I am thou hast that rned, Bill. retu`. Logs confirmed the
  same scrambled string in `EVENT: dialogue`, so the speech backend was not at
  fault. The fix teaches the PPU text reader to assemble rows in visible screen
  order using horizontal scroll plus the active nametable bit. Retest after a
  manual script reload: TALK to the King should read the sentence in normal
  order, starting with `I am greatly pleased...`.
- 2026-05-09 B1 auto-walk timing follow-up: the noisy return-route reroutes
  were partly false route-executor timeouts caused by early movement-subpixel
  twitches, not new engine blockers. After the autowalk timing patch, a clean
  live B1 pass from entrance to stairs reached `(9,9)` with only the known
  `(6,3).west` direct-retry failure, and the return route reached `(0,0)`
  without blocked events or runtime blockers.

Recommended next step:
- The narrow Brecconary exit target is now clean after the autostep timing
  patch. A full parked-NPC object survey from `(15,15)` is the next useful
  confidence check before moving on to broader playtesting.
- Continue real early-game playtesting from the BizHawk path. Good next targets
  are combat narration, shops/inns, item/spell flows, and any remaining menu or
  dialogue polish that shows up naturally. If the post-dialogue status row
  appears again, check for `UPPER_DIALOGUE_SUPPRESS_STATUS` and
  `report_upper_dialogue_state` before changing the dialogue parser again.
- Future Erdrick's Cave B2 polish task: revisit the chest-to-stairs return route
  from chest-adjacent `(8,3)` to B2 stairs `(8,9)` when pathfinding cleanup is
  back in scope. Use direct verifiers/probes on the return-trip bounce
  candidates before changing permanent map data; the current route is playable
  and should not block the pivot to combat/dialogue work.
- While testing object navigation, rapidly tap J/L and listen for reduced audio
  hitching. Use K to speak the current selection immediately. If the short delay
  feels worse than the old behavior, set `object_nav_speech_coalesce_frames=0`
  in `dw_access.ini` and reload the script.
- Keep the current BizHawk audio trial settings for now. Apply future config
  patches while EmuHawk is closed; live edits can be overwritten when the
  emulator exits.
- Good next experiments: tune BizHawk audio buffer/throttle settings, then
  compare one clean repro at a time with `reset_scan_stats` /
  `report_scan_stats`, fresh `CMD_TIMING` lines, and fresh
  `ROUTE_PLAN_TIMING` lines.
- Retest manual movement overshoot in normal play. The route executor now
  clears injected D-pad after movement starts, but manual cell-jumping still
  needs the user's hands-on confirmation.
- Retest auto-walk from quick slot 1 without pressing it immediately after
  launch. Use `current_object` first; if it says "No objects found", wait for
  the deferred object refresh, then select the target and try `O` / `U`.
- If auto-walk still feels choppy after objects are populated, capture
  `reset_scan_stats`, exactly one `auto_walk`, then `report_scan_stats`. A
  fresh `objects.check_refresh max_ms=...` line matters most if the hitch
  happens at route completion/cancel; `ROUTE_PLAN_TIMING` still matters if the
  hitch happens before movement starts.
- If the throne-room `(4,4)->(4,5)` route block appears again, do not promote it
  to map data from a single auto-walk. Reprobe with `probe_edge:DOWN` from
  `(4,4)` and compare against the latest noisy evidence.

When adding issues, use this format:
- ID
- Severity
- Area
- Description
- Reproduction steps
- Observed behavior
- Expected behavior
- Evidence or relevant log lines

## Useful Commands

State and speech:
- `speech_status`
- `log_state`
- `report_position`
- `current_object`
- `reset_scan_stats`
- `report_scan_stats`

Object navigation:
- `next_object`
- `prev_object`
- `next_filter`
- `pathability_filter`
- `pathfind_adjacent:X,Y`
- `auto_walk`

Path/debug recovery:
- `report_path_state`
- `inspect_tile:X,Y`
- `inspect_move:DIR`
- `report_runtime_blocks`
