# Current Investigation Scratchpad

Updated: 2026-06-16

This file is the temporary scratchpad for the active Garin's Grave work. Older
line-by-line probe transcripts were compacted on 2026-06-15; durable route
facts are in `session_handoff.md`, `PLAYTESTING.md`,
`project_resources/maps/garins_grave/README.md`, and the dated handoff archive.

## Active Target

- Current gameplay target: continue Garin's Grave object-route cleanup after
  the player claimed the Cursed Belt from the B3 west chest `(1,1)`.
- Most important next live check: after manual FCEUX Lua reload, verify the
  cleaned B3 NW-side object filter and B2/B3 permanent model without runtime
  blockers.

## 2026-06-16 B1 `auto_walk_blocker` Cleanup

- User-tested `auto_walk_blocker` on B1, and log review confirmed the new mode
  handled timing-suspect movement-start timeouts by running seam retry before
  suggesting blocker patches.
- Route-local evidence exposed two B1 suspects:
  `(16,7)->DOWN` into `(16,8)` and `(17,18)->DOWN` into `(17,19)`.
- From normally reached `(16,7)`, two current-position `probe_edge:DOWN`
  checks blocked into `(16,8)` with `raw_hold_timeout` while the model preview
  still reported open/effective passable. Runtime edge added:
  `add_blocked_edge:16,7,DOWN`.
- `auto_walk_blocker:17,18` reached `(17,18)` without reporting a blocker.
  It reran several timing retries, all of which cleared as passable seam
  observations. From normally reached `(17,18)`, two current-position
  `probe_edge:DOWN` checks blocked into `(17,19)` with `raw_hold_timeout`.
  Runtime edge added: `add_blocked_edge:17,18,DOWN`.
- With `(17,19).north` active, `debug_pathfind_to:17,19` exposed a tiny
  alternate path through `(18,19)->LEFT`. `auto_walk_blocker:17,19` stopped at
  that edge with `AUTO_WALK_BLOCKER_FOUND`, then two same-origin
  `probe_edge:LEFT` checks from `(18,19)` confirmed the east approach blocked.
  Runtime edge added: `add_blocked_edge:18,19,LEFT`.
- With `(17,19).north/east` active, `debug_pathfind_to:17,19` exposed the
  west approach through `(16,19)->RIGHT`. `auto_walk_blocker:17,19` stopped at
  that edge too, then two same-origin `probe_edge:RIGHT` checks from `(16,19)`
  confirmed it blocked. Runtime edge added: `add_blocked_edge:16,19,RIGHT`.
- Promoted to permanent B1 map data as `(16,8).north`,
  `(17,19).north`, `(17,19).east`, and `(17,19).west`. Keep noisy
  `(18,8).south` unpromoted.

## 2026-06-16 B3 Northwest Object-Pruning Pass

- Fresh FCEUX baseline from B3 `Northwest Stairs Up` `(14,1)` had
  `RUNTIME_BLOCKS map=0x1A none`.
- `pathability_filter:reachable` reported five objects: `Northwest Stairs Up`,
  opened chest `(1,1)`, `Upper Stairs Down` `(9,5)`, `Southeast Stairs Up`
  `(18,13)`, and `Southwest Stairs Up` `(2,17)`.
- Live `auto_walk:9,5` exposed two route-shaped blocked edges:
  `(5,1)->DOWN` into `(5,2)` and `(1,6)->DOWN` into `(1,7)`.
- Same-origin probes from normally walked origins confirmed both:
  `EDGE_PROBE_RESULT ... from=(1,6) dir=down dest=(1,7) status=blocked` and
  `EDGE_PROBE_RESULT ... from=(5,1) dir=down dest=(5,2) status=blocked`.
- Runtime injection for continued testing:
  `add_blocked_edge:1,6,DOWN` and `add_blocked_edge:5,1,DOWN`.
- With those runtime blockers active, `debug_pathfind_to:9,5`,
  `debug_pathfind_to:18,13`, and `debug_pathfind_to:2,17` all returned
  `No path found`; the reachable filter dropped to the opened chest plus
  local `Northwest Stairs Up`.
- Promoted to permanent B3 map data as `(1,7).north` and `(5,2).north` with
  focused `test_map_reader.lua` coverage. FCEUX source reload is still needed
  before judging live planner behavior without the runtime overlay.

## 2026-06-15 Live Cursed Belt Route Pass

- Fresh FCEUX baseline confirmed B3 `(1,1)` with `OBJECT: Chest: here` and no
  runtime blocks.
- From the chest side, `debug_pathfind_to` initially showed possible exits to
  B3 `(14,1)`, `(2,17)`, `(18,13)`, and `(9,5)`, but live movement exposed the
  one-way trap:
  - `auto_walk:2,17` moved from `(1,1)` to `(2,1)`.
  - `(2,1)->RIGHT` into `(3,1)` blocked twice during route retry.
  - Same-origin `probe_edge:RIGHT` from normally reached `(2,1)` also blocked.
  - Runtime-only injection for continued search: `add_blocked_edge:2,1,RIGHT`
    (`RUNTIME_BLOCK map=0x1A x=3 y=1 dirs=west`).
- After teleport-only repositioning to accessible B3 southwest landing `(2,17)`,
  `debug_pathfind_to:1,1` returned `No path found` with the runtime edge active.
- `debug_route_frontier:1,1,40` from `(2,17)` reported four hidden-bridge
  candidates into the target-side component:
  - `(6,17)->DOWN` into `(6,18)`, hidden exit left to `(5,18)`
  - `(5,15)->UP` into `(5,14)`, hidden exit up to `(5,13)`
  - `(4,14)->RIGHT` into `(5,14)`, hidden exit up to `(5,13)`
  - `(8,17)->DOWN` into `(8,18)`, hidden exit right to `(9,18)`
- `auto_walk:6,17` reached candidate origin `(6,17)`, then a random battle
  started. Next clean step after combat: confirm still at `(6,17)`, then run
  `probe_edge:DOWN`.
- After combat, fresh `log_state` confirmed field state at `(6,17)`.
- `probe_edge:DOWN` from `(6,17)` into `(6,18)` blocked. The model already
  treats `(6,18)` as non-walkable, so this first hidden-bridge candidate is
  closed; no map promotion needed.
- Attempted to route to the next candidate origin `(5,15)`, but another battle
  interrupted at `(4,17)` before arrival. During the route retry, autowalk
  observed `(6,17)->UP` into `(6,16)` and `(5,17)->UP` into `(5,16)` as
  blocked. Treat these as UNRESOLVED route-retry evidence only until clean
  same-origin probes can confirm or disprove them.
- Next clean step after current combat: confirm field state and position,
  likely `(4,17)`, then resume toward `(5,15)` or probe nearby unresolved
  north/up seams if still on their origin side.
- Fresh follow-up after player refresh/re-entry:
  - user manually confirmed the southwest-stair row between `(2,17)` and
    `(4,17)` is passable both eastbound and westbound
  - fresh baseline: B3 `(4,17)`, full HP/MP, no runtime blocks
  - re-injected the previously confirmed runtime-only one-way closure
    `add_blocked_edge:2,1,RIGHT`
  - planner route from `(4,17)` to candidate origin `(5,15)` was
    `(4,17)->(4,16)->(4,15)->(5,15)`
  - live route retries instead found the north entries from `(4,17)`,
    `(5,17)`, `(6,17)`, `(7,17)`, and `(8,17)` into row 16 blocking; keep
    these as UNRESOLVED route-retry evidence until same-origin probes confirm
    any specific edge
  - route then found `(3,17)->UP` into `(3,16)` passable
  - battle interrupted while attempting `(3,16)->UP` toward `(3,15)`, so that
    next edge is DO NOT PROMOTE / unresolved until post-combat probing
- Next clean step after current combat: confirm field state and position,
  expected near `(3,16)`, then probe `UP` from `(3,16)` before resuming the
  route toward `(5,15)` / chest `(1,1)`.
- Follow-up after user manually confirmed `(3,15)<->(3,16)`:
  - log verified `probe_edge:3,16,up` moved to `(3,15)` and
    `probe_edge:3,15,down` moved back to `(3,16)`
  - `auto_walk:4,15` reached `(4,15)` through normal movement; combat then
    interrupted, but post-combat position remained `(4,15)`
  - clean same-origin `probe_edge:RIGHT` from `(4,15)` into `(5,15)` blocked;
    runtime-only overlay now marks `(5,15).west`
  - `probe_edge:UP` from `(4,15)` moved to `(4,14)`, but
    `probe_edge:RIGHT` from `(4,14)` into hidden candidate `(5,14)` blocked
  - `auto_walk:6,15` eventually reached `(6,15)` by the right-side corridor:
    `(9,17)->(9,14)->(7,13)->(7,15)->(6,15)`
  - clean same-origin `probe_edge:LEFT` from `(6,15)` into `(5,15)` blocked;
    runtime-only overlay now marks `(5,15).east,west`
  - direct probes confirmed row-16 approach blockers from clean origins:
    `(7,15)->DOWN` into `(7,16)`, `(7,15)->RIGHT` into `(8,15)`,
    `(6,15)->DOWN` into `(6,16)`, `(7,14)->RIGHT` into `(8,14)`, and
    `(8,13)->DOWN` into `(8,14)`
  - `auto_walk:8,17` reached `(8,17)` cleanly through
    `(8,13)->(9,13)->(9,17)->(8,17)`
  - clean same-origin `probe_edge:DOWN` from `(8,17)` into hidden candidate
    `(8,18)` blocked; runtime-only overlay marks `(8,18).north`
  - fresh `debug_route_frontier:1,1,100` from `(8,17)` still reports
    `target_reachable=false`, with hidden candidates reduced to three:
    `(6,17)->DOWN`, `(5,15)->UP`, and `(4,14)->RIGHT`
  - `(6,17)->DOWN` and `(4,14)->RIGHT` already have clean blocked evidence
    from this investigation; `(5,15)->UP` appears stranded because `(5,15)`
    is sealed from east and west, but no same-origin probe from `(5,15)` is
    possible yet
  - current stop state: a Wolflord battle started at B3 `(7,17)` immediately
    after `probe_edge:LEFT` from `(8,17)` moved to `(7,17)`
- Next clean step after current combat: confirm field state at/near `(7,17)`,
  then either re-probe/add runtime for `(6,17)->DOWN` or run
  `debug_pathfind_to:5,15` / `debug_route_frontier:1,1,100` with the current
  overlay to decide whether any non-hidden route toward `(5,15)` remains.
- Follow-up from the same runtime-overlay pass:
  - clean same-origin probes confirmed and runtime-injected the remaining
    row-16/hidden-bridge closures exposed by the planner:
    `(4,17)->UP`, `(4,15)->DOWN`, `(7,17)->UP`, `(8,17)->UP`, and
    `(9,14)->LEFT`
  - the prior clean `(4,14)->RIGHT` hidden-bridge block was also added to the
    runtime overlay as `(5,14).west`
  - with those runtime closures active, `debug_pathfind_to:5,15` returned
    `No path found [no_path]`
  - `debug_route_frontier:1,1,100` from B3 reported
    `target_reachable=false` and `hidden_bridge_candidates=0`; remaining
    bridge candidates are modeled directional blockers, not hidden-wall exits
  - live same-origin probes then verified these top-ranked modeled blockers as
    real engine blockers, with `approach_blocked=true` / `effective_passable=false`:
    `(6,3)->LEFT`, `(6,3)->UP`, `(6,4)->LEFT`, `(6,5)->LEFT`,
    `(5,6)->UP`, `(4,6)->UP`, `(4,6)->LEFT`, `(4,7..13)->LEFT`,
    `(2,8)->UP`, `(2,8)->RIGHT`, `(2,8)->LEFT`, `(2,9..13)->RIGHT`,
    `(2,9..13)->LEFT`, `(2,14)->LEFT`, `(2,14)->DOWN`,
    `(3,14)->UP`, `(9,4)->UP`, `(9,4)->RIGHT`, `(9,5)->RIGHT`, and
    `(8,3)->RIGHT`
  - battle interruptions occurred several times; each movement probe was
    resumed only after a fresh field-state/position check
  - current stop state for this note: field state on B3 at `(8,3)`,
    runtime overlay count `12`, `target_reachable=false`,
    `hidden_bridge_candidates=0`
  - post-stop promotion: the direct-probe runtime-only blockers from this pass
    are now in `map_reader.lua` with focused `test_map_reader.lua` assertions;
    after the next manual FCEUX Lua reload, rerun frontier/pathfind checks
    without relying on the old runtime overlay
  - next useful probes, if continuing from `(8,3)`: either walk the long route
    to the lower-right cluster around `(9,13)` / `(9,14)` / `(9,15)`, or
    revisit the nearer untested right-exit candidates from `(4,11)`,
    `(4,12)`, and `(4,13)`
- 2026-06-16 resume after manual FCEUX reload:
  - baseline from B3 `(8,3)` had no runtime blockers; permanent model alone
    gave `debug_route_frontier:1,1,100` with
    `target_reachable=false`, `hidden_bridge_candidates=0`, and
    `debug_pathfind_to:1,1` returned `No path found [no_path]`
  - same-origin probes re-confirmed the near row-11/13 band as modeled:
    `(4,11)->LEFT`, `(4,12)->LEFT`, `(4,13)->LEFT`,
    `(4,13)->RIGHT`, `(4,12)->RIGHT`, and `(4,11)->RIGHT` all blocked
    with matching directional model evidence and no runtime/NPC contamination
  - lower-right cluster progress:
    `(9,17)->RIGHT`, `(9,17)->DOWN`, `(9,16)->RIGHT`, and
    `(9,15)->RIGHT` all blocked as modeled under same-origin probes
  - passable route evidence from the same pass moved cleanly through
    `(4,17)->(5,17)->(6,17)->(7,17)->(8,17)->(9,17)` and then north to
    `(9,14)`
  - battle interruptions were handled as contamination, not blocker evidence;
    after the final Wolflord battle at `(9,14)`, the one-minute wait still
    showed state `battle`, so live commands stopped there
  - next clean step after combat: confirm field state at `(9,14)`, then probe
    `(9,14)->RIGHT`; if still clear, continue to `(9,13)` and test
    `(9,13)->RIGHT` and `(9,13)->UP`
- 2026-06-16 continuation after player MP refill/restart:
  - fresh baseline from B3 `(9,13)/(9,14)` had `RUNTIME_BLOCKS map=0x1A none`
  - same-origin probes confirmed the user's read of `(9,14)`: left/right are
    blocked as modeled, while north/south movement is open
  - direct probes from the current/southwest component rechecked the nearby
    top-ranked bridge candidates as modeled blockers:
    `(9,13)->RIGHT`, `(9,13)->UP`, `(8,13)->UP`, `(7,13)->UP`,
    `(6,13)->UP`, `(6,13)->LEFT`, `(4,7)->LEFT`, `(4,6)->UP`,
    `(4,6)->LEFT`, `(5,6)->UP`, `(6,5)->LEFT`, `(6,4)->LEFT`,
    `(6,3)->LEFT`, and `(6,3)->UP`
  - planner route from NW `Northwest Stairs Up` `(14,1)` initially claimed
    `4 west, 1 north, 1 west, 1 south, 8 west` to west chest `(1,1)`, but
    clean same-origin probes blocked `(14,1)->LEFT` twice; runtime edge
    `(13,1).east` was added for continued testing
  - replanning then claimed the top-row detour
    `1 south, 4 west, 2 north, 1 west, 1 south, 8 west`; live probes reached
    `(9,0)` through `(10,0)->LEFT`, confirming the top seam remains real, but
    `(9,0)->DOWN` blocked twice; runtime edge `(9,1).north` was added
  - `debug_route_frontier:1,1,80` from the NW pocket then exposed one hidden
    candidate `(10,2)->LEFT` into `(9,2)`; same-origin probe blocked, and
    runtime edge `(9,2).east` reduced `hidden_bridge_candidates` to `0`
  - with runtime closures for `(13,1).east`, `(9,1).north`, and `(9,2).east`,
    path-only checks from B3 `Northwest Stairs Up`, `Northeast Stairs Up`,
    `Southwest Stairs Up`, `Southeast Stairs Up`, `Central Stairs Up`,
    `Upper Stairs Down`, and `Lower Stairs Down` all returned
    `No path found` to west chest `(1,1)`
  - current live FCEUX position after the path-only sweep is B3 `(10,9)`;
    runtime blocker count is `3`. After source reload, those three should be
    permanent and runtime blockers should be empty.
- 2026-06-16 user/manual return-route discovery follow-up:
  - fresh log/state confirmed the player reached B3 `Northwest Stairs Up`
    `(14,1)` after the manual escape route; current runtime blocks were only
    the already-confirmed `(1,3).north` and `(2,3).north` chest-pocket south
    exits
  - live log line `SEAM_OBSERVATION map=0x1A cell=(0,3) approach=north
    result=moved moved=2` verified `(0,2)->DOWN` into `(0,3)`
  - reverse movement logged `SEAM_OBSERVATION map=0x1A cell=(0,2)
    approach=south result=moved moved=2`, proving the `(0,2)<->(0,3)` edge is
    bidirectional in the live engine
  - route snapshots from actual player positions at `(0,3)`, `(0,4)`, and
    `(0,5)` all planned paths to `Northwest Stairs Up`; those cells decode as
    x=0 `engine_boundary`, so the permanent model now scopes B3 passthroughs
    for `(0,2)`, `(0,3)`, `(0,4)`, and `(0,5)`
  - manual rightward bump attempts from `(0,3)`, `(0,4)`, and `(0,5)` produced
    early-twitch cancels rather than clean `blocked_only` seam observations;
    DO NOT PROMOTE those east exits as directional blockers without a cleaner
    same-origin probe/log line
  - return-route cleanup after the user parked at the first blocker supplied
    the cleaner evidence:
    - same-origin `probe_edge:RIGHT` from `(0,3)` blocked into `(1,3)`;
      runtime edge `(1,3).west` was injected
    - reroute reached `(0,4)`; same-origin `probe_edge:RIGHT` blocked into
      `(1,4)`; runtime edge `(1,4).west` was injected
    - reroute reached `(0,5)`; same-origin `probe_edge:RIGHT` blocked into
      `(1,5)`; runtime edge `(1,5).west` was injected
    - same-origin `probe_edge:DOWN` from `(0,5)` moved into decoded-boundary
      cell `(0,6)`, proving another scoped B3 passthrough; follow-up probes
      moved `(0,6)->RIGHT` and `(1,6)->RIGHT`
    - route retry from `(2,4)->UP` into `(2,3)` blocked once, but this is
      UNRESOLVED route-retry evidence only; do not promote `(2,3).south`
      without a clean same-origin probe
    - same-origin `probe_edge:RIGHT` from `(8,1)` blocked into `(9,1)`;
      runtime edge `(9,1).west` was injected
    - after that closure, planner collapsed until the false-boundary top entry
      was tested; same-origin `probe_edge:UP` from `(8,1)` moved into `(8,0)`,
      and `probe_edge:RIGHT` from `(8,0)` moved into `(9,0)`
    - a Drollmagi battle started at `(9,0)` before probing farther; after the
      one-minute wait the log still reported `battle`, so live route testing
      stopped there
  - post-stop promotion: only the direct-proven return-route facts above were
    patched into `map_reader.lua`: B3 passthroughs `(0,6)` and `(8,0)`, and
    directional blocks `(1,3).west`, `(1,4).west`, `(1,5).west`, and
    `(9,1).west`
  - post-reload validation after user cleared combat and reloaded FCEUX:
    runtime blockers were empty at B3 `(14,1)`, and the permanent planner found
    an entry route to west chest `(1,1)`
  - live `auto_walk:1,1` reached the chest after one Wraith Knight battle
    interruption at `(8,1)`; the route ultimately used
    `(2,6)->(1,6)->(0,6)->(0,5)->(0,4)->(0,3)->(0,2)->(1,2)->(1,1)`
  - live `auto_walk:14,1` from the chest returned to `Northwest Stairs Up`
    `(14,1)` with no persistent runtime blocks
  - the entry/return validation exposed and direct-probed these false
    shortcuts from normally reached origins:
    `(4,1)->LEFT` into `(3,1)` = `(3,1).east`,
    `(4,3)->LEFT` into `(3,3)` = `(3,3).east`,
    `(2,4)->LEFT` into `(1,4)` = `(1,4).east`,
    `(2,4)->UP` into `(2,3)` = `(2,3).south`,
    `(2,5)->LEFT` into `(1,5)` = `(1,5).east`,
    `(1,6)->UP` into `(1,5)` = `(1,5).south`, and
    `(10,1)->RIGHT` into `(11,1)` = `(11,1).west`
  - these latest shortcut closures are now patched into `map_reader.lua` with
    `test_map_reader.lua` assertions; manual Lua reload is still needed before
    live planner checks reflect this final cleanup batch

## 2026-06-16 B2 West-Chest Escape Route Pass

- Fresh baseline after taking the stairs back from the B3 west-chest side was
  B2 `(1,2)`.
- Live route to `Stairs Up` `(11,2)` was verified:
  - `(1,2)->LEFT` entered decoded-boundary cell `(0,2)`
  - left-edge strip moved down through `(0,3)` to `(0,11)`
  - `(0,11)->DOWN` blocked
  - `(0,11)->RIGHT` moved into `(1,11)`
  - normal route then reached `(11,2)` via the lower/right corridor
- Clean same-origin probes closed the false shortcuts the planner wanted before
  the strip route:
  - `(1,3)->UP` into `(1,2)` = `(1,2).south`
  - `(1,1)->DOWN` into `(1,2)` = `(1,2).north`
  - `(1,1)->RIGHT` into `(2,1)` = `(2,1).west`
  - `(1,2)->RIGHT` into `(2,2)` = `(2,2).west`
  - `(1,8)->RIGHT` into `(2,8)` = `(2,8).west`
  - `(1,8)->DOWN` into `(1,9)` = `(1,9).north`
- Direct probes also rechecked `(1,3..7)->RIGHT` into `(2,3..7)` as blocked;
  those were already covered by permanent B2 directional data.
- Final live stop state from this pass: B2 `(11,2)`.
- Post-stop promotion: B2 passthroughs `(0,2)` through `(0,11)` and the six
  new B2 directional faces above are patched in `map_reader.lua` with focused
  `test_map_reader.lua` coverage. Manual Lua reload is still needed before the
  live planner uses this model.
- UNRESOLVED: the reverse route from B2 `Stairs Up` `(11,2)` back to the
  northwest stair side is not live-proven. If the object browser exposes it
  after reload, verify the reverse direction before treating it as a durable
  two-way route.

## 2026-06-16 B2 Northwest Stair Escape Extension

- User reported a new false blocker between `(0,1)` and `(1,1)` and a blocker
  at `(0,9)->RIGHT`.
- Log review found clean passable evidence before agent commands:
  - `(1,1)->LEFT` into `(0,1)` moved four times
  - `(0,1)->RIGHT` into `(1,1)` moved three times
  - `(0,1)->DOWN` into `(0,2)` moved
- Same-origin live probe from current B2 `(0,9)`:
  - `probe_edge:RIGHT` into `(1,9)` blocked with `raw_hold_timeout`
  - runtime overlay injected `add_blocked_edge:0,9,RIGHT`, recorded as
    `RUNTIME_BLOCK map=0x19 x=1 y=9 dirs=west`
- With that runtime edge active, `debug_pathfind_to:11,2` from `(0,9)` found:
  `2 south, 13 east, 9 north, 2 west`.
- Live autowalk then reached `Stairs Up` `(11,2)` through the bottom/right
  route. Confirmed route shape:
  `(0,9)->(0,10)->(0,11)->(1..13,11)->(13,2)->(11,2)`.
- Battles interrupted at `(13,8)` and `(13,5)` during timing retries; both were
  cleared and treated as contamination. The retried edges later moved, so do
  not promote those timing retries as blockers.
- Final live state: B2 `(11,2)`, runtime overlay count `1` for `(1,9).west`.
- Post-stop promotion: `map_reader.lua` now includes B2 passthrough `(0,1)` and
  directional block `(1,9).west`, with focused `test_map_reader.lua` coverage.
  Manual Lua reload is needed before live planning uses the permanent version.

## Current Emulator Rule

- FCEUX is the normal gameplay and agent-driven runtime.
- BizHawk is opt-in for explicit automation/debug/reload/profiling work only.
- Do not steer normal Garin's Grave route work back to BizHawk just for agent
  convenience; the lag slows route/seam testing too much.

## Durable Garin's Grave Facts

- B3 top-row false boundary:
  - live movement proved `(9,0)<->(10,0)` is bidirectionally passable
  - `map_reader.lua` has scoped B3 passthroughs for `(8,0)`, `(9,0)`,
    `(10,0)`, `(0,2)` through `(0,6)`, `(1,2)`, and `(2,2)`
  - 2026-06-16 follow-up proved the top seam alone was insufficient:
    `(14,1)->LEFT`, `(9,0)->DOWN`, and `(10,2)->LEFT` are now modeled, while
    the later `(8,0)` plus left-edge strip route opens the west chest path
  - `test_map_reader.lua` covers the passthrough cells, direct closure
    assertions, and the live-confirmed route shape from west chest back to
    `Northwest Stairs Up`
- B2 from `Stairs Up` `(11,2)`:
  - reaches `Stairs Up`, `Northeast Stairs Down`, `Southeast Stairs Down`, and
    `Southwest Stairs Down`
  - prior permanent model returned `No path found` for `Northwest Stairs Down`
    `(1,1)` and `Central Stairs Down` `(5,6)`
  - latest B2 escape passes live-verified the route from `Northwest Stairs
    Down` `(1,1)` / northwest landing `(1,2)` back to `Stairs Up`; reverse
    direction from `Stairs Up` to the northwest stair side remains unverified
    after the new passthrough patch
- B3 southeast-stair component:
  - does not route to west chest `(1,1)`
  - reachable-object filter reports only local `Southeast Stairs Up`
- B3 northeast-stair and southeast/up pockets:
  - pruned to local return stair only after same-origin live blocker evidence
- B3 lower-stair / Silver Harp side:
  - route to chest `(13,6)` and back to `Lower Stairs Down` `(10,9)` is stable
  - the save already had Silver Harp when the chest was opened
- B4 connector:
  - west/east stair connector remains stable both directions

## Evidence Rules To Keep

- Promote permanent map data only from clean normal-walked route evidence plus
  same-origin `probe_edge` agreement when possible.
- Treat battle, menu/dialogue, stale queued commands, teleport seed state,
  explicit-origin verifier artifacts, and FCEUX `LeftAlt` latch noise as
  contamination until disproven.
- `low_exit_count` and isolated-start survey failures are start-tile viability
  warnings, not direct proof that the target is blocked.
- B2 is an intended six-stair hub. Do not seal extra stair objects just to
  shorten object lists.
- Player-facing internal stair labels should stay spoiler-safe: use spatial
  labels plus visible `Up`/`Down`, not exact destination floors.

## Recent Tooling Cleanup

- Edge-flow command starters now share `edge_flow_guard.lua`.
- `probe_edge`, `probe_edge_verify`, `probe_edge_after_raw`, and
  `probe_edge_after_raw_to` refuse while any edge probe/verifier/seeded probe
  state is active.
- Regression coverage lives in `test_edge_flow_guard.lua`.

## Where To Look For Detail

- Current restart summary: `session_handoff.md`
- Active gameplay/playability notes: `PLAYTESTING.md`
- Garin's Grave map orientation and route summary:
  `project_resources/maps/garins_grave/README.md`
- Historical full evidence:
  `handoff_archive/HANDOFF_2026-06-07_garins_grave_b2_b3_wrapup_full.md`
