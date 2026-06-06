# Session Handoff - Active Resume

Updated: 2026-06-05

## Latest: B2 stair-hub audit says all six stair objects are intentionally reachable; do not seal extra stair routes (2026-06-05, uncommitted)

- User noticed several other B2 stair points still showing reachable besides
  the return stair `(11,2)` and the southwest progression stair `(1,10)`, and
  asked whether some of them should really be sealed off.
- Live object roster from `POSITION map=0x19(Garin's Grave B2) x=11 y=2`:
  - `Stairs Up to B1` at `(11,2)`
  - `Northeast Stairs Down to B3` at `(12,1)`
  - `Southeast Stairs Down to B3` at `(12,10)`
  - `Center Stairs Down to B3` at `(5,6)`
  - `Northwest Stairs Down to B3` at `(1,1)`
  - `Southwest Stairs Down to B3` at `(1,10)`
- Planner/object-filter evidence from the current east-side component:
  - `pathability_filter:unreachable`
    - `PATHABILITY_FILTER: Travel, unreachable. No objects`
  - direct planner routes exist from `(11,2)` to every down stair:
    - `(12,1)` => `1 north, 1 east`
    - `(12,10)` => `2 east, 8 south, 1 west`
    - `(5,6)` => `1 east, 2 south, 7 west, 2 south`
    - `(1,1)` => `2 east, 9 south, 8 west, 2 north, 4 west, 8 north`
    - `(1,10)` => `2 east, 9 south, 12 west, 1 north`
- Local map-reference check:
  - `project_resources/maps/garins_grave/README.md` and the bundled Realm of
    Darkness composite map both describe B2 as a stair hub with those exact six
    stair cells.
  - Guide bias recorded there:
    - nearby return-side stair and center stair are dead-end/trap leads
    - northwest and southeast stairs lead toward the Cursed Belt branch
    - southwest stair is the main progression lead
- Conclusion:
  - do **not** add permanent blockers just to make the extra B2 stair objects
    disappear from reachability
  - current model/object browser behavior is consistent with the intended B2
    layout
  - if one of those stair routes later fails live, treat it as a targeted seam
    or movement/timing issue and verify it directly rather than assuming the
    stair should be isolated

## Latest: B2 south edge of row 9 promoted at `(6,9..8,9).south`; `(5,10)->UP` stays mixed (2026-06-05, uncommitted)

- User asked to check and patch the remaining south-edge row-9 candidates if needed.
- Direct live verification:
  - `probe_edge_verify:6,10,UP,5`
    - `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(6,9).south`
  - `probe_edge_verify:7,10,UP,5`
    - `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(7,9).south`
  - `probe_edge_verify:8,10,UP,5`
    - `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(8,9).south`
  - earlier same-pass control check:
    - `probe_edge_verify:5,10,UP,5`
      - `moved=2 blocked=3 classification=inconclusive_teleport_artifact`
      - keep `(5,9).south` unmodeled
- Permanent model:
  - `map_reader.lua` now models B2 `0x19`:
    - `(6,9).south`
    - `(7,9).south`
    - `(8,9).south`
  - `test_map_reader.lua` flips the old open/mixed assumptions and adds the
    three positive regressions
- Runtime sync:
  - injected:
    - `add_blocked_edge:6,10,UP`
    - `add_blocked_edge:7,10,UP`
    - `add_blocked_edge:8,10,UP`
  - latest readback:
    - `POSITION map=0x19(Garin's Grave B2) x=8 y=10`
    - `RUNTIME_BLOCKS map=0x19 count=11`
    - includes `(1,9).south`, `(2,10).south`, `(6,9).south`, `(7,9).south`,
      `(8,9).south`, plus earlier top-right seams
- Planner / live sanity:
  - from `(8,10)`, `debug_pathfind_to:11,2` became:
    - `Path: 5 east, 8 north, 2 west`
  - `auto_walk:11,2` followed that reroute cleanly through the east column to
    `(13,2)`, then a `Wolf` battle interrupted the final seam retry at
    `(12,2)->LEFT` into `(11,2)`
  - that last edge is lower confidence as a blocker because a previous run
    already completed through it; treat the interruption as battle noise unless
    it reproduces cleanly after combat
- Next best live follow-up:
  - after the user clears the fight, simply rerun:
    - `auto_walk:11,2`
  - if more cleanup is wanted after that, the remaining row-9 south-edge holdout is:
    - `probe_edge_verify:5,10,UP,5` only if we want to keep pressing on the mixed seam
- Verification:
  - live `probe_edge_verify:6,10,UP,5`
  - live `probe_edge_verify:7,10,UP,5`
  - live `probe_edge_verify:8,10,UP,5`
  - live `debug_pathfind_to:11,2`
  - live `auto_walk:11,2` until Wolf interruption near the stair
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`

## Latest: B2 southwest return cleanup promoted `(1,9).south` and `(2,10).south`; route back to B1 stairs now completes (2026-06-05, uncommitted)

- User said the earlier `(12,6)->DOWN` probe looked solid and asked to continue.
- Direct live verification:
  - `probe_edge_verify:12,6,DOWN,5`:
    - `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(12,7).north`
  - after the Wolf interruption near the southwest B3 stairs:
    - `probe_edge_verify:1,11,UP,5`
      - `moved=6 blocked=0 classification=confirmed_passable`
      - keep `(1,10)` open from the south
    - `probe_edge_verify:1,10,UP,5`
      - `moved=0 blocked=5 classification=confirmed_blocked`
      - promote `(1,9).south`
  - later west-pocket follow-up:
    - `probe_edge_verify:2,11,UP,5`
      - `moved=0 blocked=5 classification=confirmed_blocked`
      - promote `(2,10).south`
- Runtime follow-up:
  - injected:
    - `add_blocked_edge:1,10,UP`
    - later `add_blocked_edge:2,11,UP`
  - latest readback:
    - `POSITION map=0x19(Garin's Grave B2) x=2 y=11`
    - `RUNTIME_BLOCKS map=0x19 count=8`
    - `(1,9) dirs=south`
    - `(2,10) dirs=south`
    - plus earlier `(8,3).east`, `(10,2).east`, `(11,3).east,north`,
      `(12,3).east,west`, `(12,7).north`, `(11,10).east`
- Planner and route outcome:
  - with `(1,9).south` injected, `debug_pathfind_to:11,2` from `(1,10)` became:
    - `Path: 1 east, 7 north, 9 east, 1 north`
  - `auto_walk:11,2` from `(1,10)` completed all the way to
    - `POSITION map=0x19(Garin's Grave B2) x=11 y=2`
  - the route exposed several cleanup candidates while still completing:
    - clean likely real seam:
      - `(2,11)->UP` into `(2,10)`; later confirmed 5/5 and promoted
    - lower-confidence south-edge row-9 band:
      - route-only hits at `(5,10)->UP`, `(6,10)->UP`, `(7,10)->UP`,
        `(8,10)->UP`
      - direct verifier on `(5,10)->UP` settled at
        `moved=2 blocked=3 classification=inconclusive_teleport_artifact`
        and should stay unmodeled for now
- Permanent model:
  - `map_reader.lua` now models B2 `0x19`:
    - `(12,7).north`
    - `(1,9).south`
    - `(2,10).south`
  - `test_map_reader.lua` adds the matching regressions
- Next best live follow-up:
  - keep the new permanent model/runtime seed and direct-verify the remaining
    south-edge row-9 candidates one at a time:
    - `probe_edge_verify:6,10,UP,5`
    - `probe_edge_verify:7,10,UP,5`
    - `probe_edge_verify:8,10,UP,5`
  - only promote any of those if they avoid the mixed teleport-artifact pattern
- Verification:
  - live `probe_edge_verify:12,6,DOWN,5`
  - live `probe_edge_verify:1,11,UP,5`
  - live `probe_edge_verify:1,10,UP,5`
  - live `debug_pathfind_to:11,2`
  - live `auto_walk:11,2`
  - live `probe_edge_verify:5,10,UP,5`
  - live `probe_edge_verify:2,11,UP,5`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`

## Latest: B2 `(9,3)->LEFT` promoted as one-way seam `(8,3).east`; next live lead is `(12,7).north` after battle (2026-06-05, uncommitted)

- User asked to start the next pass with `(9,3)->LEFT`, then continue.
- Direct live verification:
  - `probe_edge_verify:LEFT,5` from `(9,3)`:
    - `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(8,3).east`
  - reverse `probe_edge_verify:RIGHT,5` from `(8,3)`:
    - `moved=6 blocked=0 classification=confirmed_passable`
    - keep the reverse face open
- Runtime follow-up:
  - injected:
    - `add_blocked_edge:9,3,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=5`
    - `(8,3) dirs=east`
    - `(10,2) dirs=east`
    - `(11,3) dirs=east,north`
    - `(12,3) dirs=east,west`
    - `(11,10) dirs=east`
- Planner change from the top-right pocket:
  - after runtime injection, `debug_pathfind_to:1,10` from `(12,3)` became:
    - `Path: 5 south, 1 east, 3 south, 12 west, 1 north`
- Follow-up autowalk findings before battle interruption:
  - the route moved cleanly down the east side through:
    - `(12,4)`, `(12,5)`, `(12,6)`
    - then `(13,6)` through `(13,11)`
  - first new likely blocker:
    - `(12,6)->DOWN` into `(12,7)`
    - blocked once on the queued step and again on seam retry:
      - `SEAM_OBSERVATION map=0x19 cell=(12,7) approach=north result=blocked`
      - counts currently blocked `1` / moved `0`
    - this is only route evidence so far; do not promote yet
  - later `(12,11)->LEFT` was interrupted by battle during seam retry and is
    currently lower-confidence than `(12,7).north`
- Current live stop:
  - battle state at `POSITION map=0x19(Garin's Grave B2) x=12 y=11`
  - current enemy:
    - `Wolf`
- Permanent model:
  - `map_reader.lua` now models B2 `0x19` `(8,3).east`
  - `test_map_reader.lua` adds the regression asserting `(8,3).east`
- Next best live follow-up after the user clears the fight:
  - direct-verify `probe_edge_verify:12,6,DOWN,5`
  - then, only if still needed, revisit `(12,11)->LEFT`
- Verification:
  - live `probe_edge_verify:LEFT,5` from `(9,3)`
  - live reverse `probe_edge_verify:RIGHT,5` from `(8,3)`
  - live `debug_pathfind_to:1,10` from `(12,3)` after runtime injection
  - live route pass until battle interruption
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 `(12,3)<->(11,3)` west seam closed on both faces; planner now peels south first (2026-06-05, uncommitted)

- User reported the planner was still starting from live `(12,3)` with a west
  step, but the engine said no.
- Fresh log context before direct probing:
  - route planning from `(12,3)` still said:
    - `Path: 11 west, 7 south`
  - the only movement evidence was a canceled `manual_tap` with an
    early-twitch wait, which was not strong enough to patch
- Direct live verification:
  - `probe_edge_verify:LEFT,5` from `(12,3)`:
    - `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(11,3).east`
  - reverse `probe_edge_verify:RIGHT,5` from `(11,3)`:
    - `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - stronger reverse-face tiebreaker:
    - three separate fresh-start cycles of `teleport_to:11,3`,
      `report_position`, `probe_edge:RIGHT`
    - all three blocked at `raw_hold_timeout`
    - promote `(12,3).west`
- Permanent model:
  - `map_reader.lua` now models both faces of the seam:
    - `(11,3).east`
    - `(12,3).west`
  - `test_map_reader.lua` adds both regressions
- Runtime sync:
  - injected:
    - `add_blocked_edge:12,3,LEFT`
    - `add_blocked_edge:11,3,RIGHT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=4`
    - `(10,2) dirs=east`
    - `(11,3) dirs=east,north`
    - `(12,3) dirs=east,west`
    - `(11,10) dirs=east`
- Immediate live planner sanity check after runtime injection:
  - from `POSITION map=0x19(Garin's Grave B2) x=12 y=3`
  - `debug_pathfind_to:1,10` became:
    - `Path: 1 south, 3 west, 1 north, 8 west, 7 south`
  - interpretation:
    - the planner no longer tries to drive straight west through the sealed
      `(12,3)<->(11,3)` seam
- Next best live follow-up:
  - continue from this new reroute and harvest the next blocker it actually
    hits, rather than spending more time in the top-right pocket
- Verification:
  - live `probe_edge_verify:LEFT,5` from `(12,3)`
  - live `probe_edge_verify:RIGHT,5` from `(11,3)`
  - live three-shot fresh-start `probe_edge:RIGHT` tiebreaker from `(11,3)`
  - live `debug_pathfind_to:1,10` from `(12,3)` after runtime injection
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 top-right pocket resolved into one-way seam `(12,3).east`; north face stays open (2026-06-05, uncommitted)

- User asked to directly verify and patch the remaining suspect entry-side
  cells around `(12,3)`.
- Clean live results:
  - `probe_edge_verify:LEFT,5` from `(13,3)`:
    - `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(12,3).east`
  - first `probe_edge_verify:DOWN,5` from `(12,2)` was interrupted by a
    `Metal Scorpion` after three moved attempts:
    - `classification=inconclusive_interrupted`
  - clean rerun of `probe_edge_verify:DOWN,5` from `(12,2)`:
    - `moved=5 blocked=1 classification=inconclusive_teleport_artifact`
    - the only blocked result was the stability recheck after five moved
      attempts, so this does not justify `(12,3).north`
  - reverse `probe_edge_verify:UP,5` from `(12,3)`:
    - `moved=6 blocked=0 classification=confirmed_passable`
    - keep `(12,3).north` open
- Code/data patch:
  - `map_reader.lua` now models B2 `0x19` `(12,3).east`
  - `test_map_reader.lua` flips the old absence assertion into a positive
    regression for `(12,3).east` and keeps `(12,3).north` explicitly open
- Runtime sync:
  - injected:
    - `add_blocked_edge:13,3,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=4`
    - `(10,2) dirs=east`
    - `(11,3) dirs=north`
    - `(12,3) dirs=east`
    - `(11,10) dirs=east`
- Current live stop:
  - `POSITION map=0x19(Garin's Grave B2) x=12 y=2`
- Next best live follow-up:
  - if the return route still chatters mid-map, start with the route-only
    south-facing suspects such as `(8,9).south` and nearby middle-lane cells
    rather than revisiting this top-right pocket
- Verification:
  - live `probe_edge_verify:LEFT,5` from `(13,3)`
  - live `probe_edge_verify:DOWN,5` from `(12,2)` twice
  - live reverse `probe_edge_verify:UP,5` from `(12,3)`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 entry-side north lip promoted as `(11,3).north`; reverse face still battle-contaminated (2026-06-05, uncommitted)

- User asked to start the next pass with the previously suspected
  entry-side seam `(11,2)->DOWN` into `(11,3)`.
- Fresh route evidence had already strengthened it before the direct check:
  - live reroute from `Stairs Up to B1` at `(11,2)` again took
    `Path: 1 south, 10 west, 7 south`
  - the same route-only seam observation rose to:
    - `SEAM_OBSERVATION map=0x19 cell=(11,3) approach=north result=blocked`
      with blocked `5` / moved `0`
- Direct verifier result on the forward face:
  - after closing a lingering command menu with `simulate_input:B`,
    `probe_edge_verify:11,2,DOWN,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - promote `(11,3).north`
- Reverse-face follow-up:
  - first `probe_edge_verify:11,3,UP,5` moved on attempt 1, then a
    `Metal Scorpion` battle interrupted attempt 2
  - after the fight, a second `probe_edge_verify:11,3,UP,5` again moved on
    attempt 1, then another `Metal Scorpion` battle interrupted attempt 2
  - current interpretation:
    - reverse face looks likely passable, but battle contamination kept it
      below promotion quality, so only `(11,3).north` is modeled
- Runtime sync:
  - existing runtime before this pass:
    - `(10,2) dirs=east`
    - `(11,10) dirs=east`
  - injected during the later battle:
    - `add_blocked_edge:11,2,DOWN`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=3`
    - `(10,2) dirs=east`
    - `(11,3) dirs=north`
    - `(11,10) dirs=east`
- Current live stop:
  - battle state at `POSITION map=0x19(Garin's Grave B2) x=11 y=3`
- Code/data patch:
  - `map_reader.lua` now models B2 `0x19` `(11,3).north`
  - `test_map_reader.lua` adds the regression asserting `(11,3).north`
- Next best live follow-up after the user clears the fight:
  - rerun `probe_edge_verify:11,3,UP,5` for a clean reverse-face answer
  - if still needed after that, the next unresolved entry-side pocket remains
    `(12,3).north` / `(12,3).east`
- Verification:
  - live route-log confirmation that `(11,3).north` reached blocked `5` / moved `0`
  - live `probe_edge_verify:11,2,DOWN,5`
  - two reverse-side `probe_edge_verify:11,3,UP,5` attempts, both
    interrupted by battle after an initial moved result
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 entry-side first west step confirmed as one-way seam `(10,2).east`; next live follow-up is `(11,3).north` after battle (2026-06-05, uncommitted)

- User reported the southwest-stair return route now basically works, but the
  entry-side planner from `Stairs Up to B1` at `(11,2)` still wanted `1 west`
  and that first step felt engine-blocked.
- Live baseline:
  - `POSITION map=0x19(Garin's Grave B2) x=11 y=2`
  - current runtime before the new check still had the earlier lower detour
    seam:
    - `RUNTIME_BLOCK map=0x19 x=11 y=10 key=11,10 dirs=east`
- Direct verifier result on the complained-about edge:
  - `probe_edge_verify:11,2,LEFT,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - reverse `probe_edge_verify:10,2,RIGHT,5`
    => `moved=6 blocked=0 classification=confirmed_passable`
  - promote only `(10,2).east`
- Runtime follow-up:
  - injected:
    - `add_blocked_edge:11,2,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=2`
    - `(10,2) dirs=east`
    - `(11,10) dirs=east`
- Immediate live reroute from the stair with that seam injected:
  - `auto_walk:1,10` replanned from `(11,2)` as
    `1 south, 10 west, 7 south`
  - first new route-only follow-up blocker was:
    - `(11,2)->DOWN` into `(11,3)`
    - `SEAM_OBSERVATION map=0x19 cell=(11,3) approach=north result=blocked`
      now up to blocked `3` / moved `0`
  - next repeated route-only follow-ups were the already suspicious top-right
    pocket faces:
    - `(12,2)->DOWN` into `(12,3)`
    - `(13,3)->LEFT` into `(12,3)`
  - none of those three received fresh direct verifiers yet because the route
    was interrupted by a `Warlock` battle at live `(7,11)`
- Code/data patch:
  - `map_reader.lua` now models B2 `0x19` `(10,2).east`
  - `test_map_reader.lua` flips the old “keep open” assertion into a positive
    regression and keeps `(11,3).north` explicitly unmodeled pending direct
    verification
- Current live stop:
  - battle started during the follow-up route at
    `map=0x19(Garin's Grave B2) x=7 y=11`
  - next best live check after the user clears the fight:
    - `probe_edge_verify:11,2,DOWN,5`
    - then, if still needed, revisit `(12,3).north` / `(12,3).east` from
      clean fresh-start probes
- Verification:
  - live `probe_edge_verify:11,2,LEFT,5`
  - live reverse `probe_edge_verify:10,2,RIGHT,5`
  - live reroute `auto_walk:1,10` with the runtime seam injected
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: lower southwest-stair detour promoted only `(11,10).east`; remaining reroute noise is timing-only (2026-06-05, uncommitted)

- User reported the next B2 route to the southwest B3 stairs was better and
  mainly interrupted by combat.
- Route-log review isolated the real new seam to the lower detour at
  `(12,10)->LEFT` into `(11,10)`:
  - repeated `probe_edge_verify:12,10,LEFT,5` stayed in the familiar
    teleport-artifact shape:
    - `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - stronger fresh-start tiebreaker:
    - three separate cycles of `teleport_to:12,10`, `report_position`,
      `probe_edge:LEFT` all blocked at `raw_hold_timeout`
    - reverse `probe_edge_verify:11,10,RIGHT,5`
      => `moved=6 blocked=0 classification=confirmed_passable`
    - promote only `(11,10).east`
- Follow-up runtime injection and route pass:
  - injected:
    - `add_blocked_edge:12,10,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=1`
    - `RUNTIME_BLOCK map=0x19 x=11 y=10 key=11,10 dirs=east`
  - live `auto_walk:1,10` from `(12,10)` then completed cleanly
  - the remaining noisy spots were timing-only, not geometry:
    - `(12,10)->DOWN` first timed out, then seam-retry moved immediately into
      `(12,11)` and cleared its temp block
    - `(2,11)->LEFT` still needed the familiar seam-retry/repress cycle, then
      completed into `(1,11)` and cleared its temp block
- Code/data patch:
  - `map_reader.lua` now models B2 `0x19` `(11,10).east`
  - `test_map_reader.lua` adds the regression asserting `(11,10).east`
- Current live stop:
  - `POSITION map=0x19(Garin's Grave B2) x=1 y=10`
- Verification:
  - live repeated `probe_edge_verify:12,10,LEFT,5`
  - live three-shot fresh-start `probe_edge:LEFT` tiebreaker from `(12,10)`
  - live reverse `probe_edge_verify:11,10,RIGHT,5`
  - live `auto_walk:1,10` completion with the runtime seam injected
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: noisy front-half reroute to southwest B3 stairs promoted only `(10,1).east`; `(12,3)` pocket stays mixed (2026-06-05, uncommitted)

- User reported the latest B2 route to the southwest B3 stairs completed, but
  the first/top-right segment was noisy.
- Route-log review isolated the noisy front-half candidates to the top-right
  hook and its immediate south pocket:
  - `(11,1)->LEFT` into `(10,1)`
  - `(12,2)->DOWN` into `(12,3)`
  - `(13,3)->LEFT` into `(12,3)`
- Fresh direct repeated verifiers on all three first came back in the same bad
  shape:
  - `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - so none were promoted from repeated verifier alone
- Stronger fresh-start tiebreaker results:
  - `(11,1)->LEFT`:
    - three separate cycles of `teleport_to:11,1`, `report_position`,
      `probe_edge:LEFT` all blocked at `raw_hold_timeout`
    - reverse `probe_edge_verify:10,1,RIGHT,5`
      => `moved=6 blocked=0 classification=confirmed_passable`
    - promote only `(10,1).east`
  - `(12,2)->DOWN`:
    - three separate fresh-start `probe_edge:DOWN` checks from `(12,2)` were
      `moved, blocked, blocked`
    - leave `(12,3).north` unmodeled
  - `(13,3)->LEFT`:
    - three separate fresh-start `probe_edge:LEFT` checks from `(13,3)` were
      `moved, blocked, blocked`
    - reverse `probe_edge_verify:12,3,RIGHT,5`
      => `moved=6 blocked=0 classification=confirmed_passable`
    - leave `(12,3).east` unmodeled
  - attempted reverse `probe_edge_verify:12,3,UP,5` for the north face was
    interrupted by battle after two moved attempts; still unresolved
- Code/data patch:
  - `map_reader.lua` now models B2 `0x19` `(10,1).east`
  - `test_map_reader.lua` flips the old “keep open” assertion and adds
    explicit absence assertions keeping `(12,3).north` and `(12,3).east`
    unmodeled pending cleaner evidence
- Live runtime sync for the current FCEUX session:
  - injected:
    - `add_blocked_edge:11,1,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=1`
    - `RUNTIME_BLOCK map=0x19 x=10 y=1 key=10,1 dirs=east`
  - current live stop:
    - `POSITION map=0x19(Garin's Grave B2) x=13 y=3`
- Verification:
  - live repeated `probe_edge_verify` on `(11,1)->LEFT`, `(12,2)->DOWN`, and
    `(13,3)->LEFT`
  - live three-shot fresh-start `probe_edge` tiebreakers for those same faces
  - live reverse `probe_edge_verify:10,1,RIGHT,5`
  - live reverse `probe_edge_verify:12,3,RIGHT,5`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: selected-object teleport hotkey now refreshes current-map object cache before reading focus (2026-06-05, uncommitted)

- Investigated the user-reported B2 selected-teleport glitch where trying to
  teleport to `Stairs Up to B1` sometimes landed back on center stairs.
- Live evidence from `dw_debug.log` in the broken state:
  - `ROUTE_PLAN_SNAPSHOT` from `(5,6)` targeted
    `target_id=stair_11_2 target_name=Stairs Up to B1 goal=(11,2)`
  - later in the same stop, the hotkey-side selected teleport logged
    `TELEPORT_SELECTED ... target_id=stair_5_6 target_name=Center Stairs Down to B3 target=(5,6)`
  - current live command-side readback still agreed with the planner:
    - `OBJECT: Stairs Up to B1: 4 north, 6 east (4 of 6) [player 5,6 obj 11,2]`
    - `POSITION: map=0x19(Garin's Grave B2) x=5 y=6`
- Root cause:
  - hotkey-side object browsing in `hotkeys.lua` was weaker than the command
    path in `object_commands.lua`
  - hotkeys were skipping `objects.check_refresh(map_id)` before reading the
    selected object
  - teleport hotkeys were also invoking the teleport handler without first
    refreshing browse context
- Patch:
  - `hotkeys.lua` now refreshes the current-map object cache before browse,
    route, and teleport reads
  - teleport hotkeys now also refresh live object positions before invoking
    the selected-teleport handler, matching pathfind/autowalk expectations
  - `test_hotkeys.lua` now asserts:
    - K/J/L browse hotkeys refresh current-map object cache
    - O/U route actions refresh current-map object cache before planning
    - teleport hotkeys refresh current-map object cache and live object
      positions before invoking the handler
- Verification:
  - `lua5.1 test_hotkeys.lua`
  - `lua5.1 test_object_commands.lua`
  - `luac5.1 -p hotkeys.lua test_hotkeys.lua`
  - `git diff --check -- hotkeys.lua test_hotkeys.lua`
- Live reload note:
  - FCEUX has not picked up this Lua patch yet; manual script reload is still
    required before re-testing `Shift+Enter` / selected teleport live
  - best live retest after reload: focus `Stairs Up to B1`, run path preview
    once for comparison if desired, then press `Shift+Enter` and confirm
    `TELEPORT_SELECTED` uses `target_id=stair_11_2`

## Latest: B2 northwest bridge trio promoted; pocket now collapses cleanly under planning (2026-06-05, uncommitted)

- Follow-up direct verification on the three unresolved bridge candidates from
  the northwest pocket:
  - `(2,2)->DOWN` into `(2,3)`:
    - initial `probe_edge_verify:DOWN,5` stayed mixed
      (`moved=1 blocked=4 classification=inconclusive_teleport_artifact`)
    - three separate fresh `probe_edge:DOWN` checks from `(2,2)` all blocked
    - reverse `teleport_to:2,3` then `probe_edge_verify:UP,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(2,3).north`
  - `(2,2)->LEFT` into `(1,2)`:
    - initial `probe_edge_verify:LEFT,5` stayed mixed
      (`moved=2 blocked=3 classification=inconclusive_teleport_artifact`)
    - three separate fresh `probe_edge:LEFT` checks from `(2,2)` all blocked
    - reverse `teleport_to:1,2` then `probe_edge_verify:RIGHT,5`
      => moved `6/6`
    - promote only `(1,2).east`
  - `(2,2)->UP` into `(2,1)`:
    - same-origin `probe_edge_verify:UP,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(2,1).south`
- Code/data patch:
  - `map_reader.lua` now also models B2 `0x19`:
    - `(1,2).east`
    - `(2,1).south`
    - `(2,3).north`
  - `test_map_reader.lua` now covers those three additions in the Garin's
    Grave B2 southwest-stair regression.
- Live runtime sync for the current FCEUX session:
  - newly injected this pass:
    - `add_blocked_edge:25,2,2,DOWN`
    - `add_blocked_edge:25,2,2,LEFT`
    - `add_blocked_edge:25,2,2,UP`
  - current `RUNTIME_BLOCKS map=0x19 count=9`
  - runtime northwest-pocket readback now includes:
    - `(2,1) dirs=east,south`
    - `(4,1) dirs=south,west`
    - `(5,1) dirs=south`
    - `(1,2) dirs=east`
    - `(2,2) dirs=east`
    - `(2,3) dirs=north`
    - `(3,3) dirs=north`
    - `(4,3) dirs=north`
    - `(5,3) dirs=north`
- Live planner status after the trio promotion:
  - from `POSITION map=0x19(Garin's Grave B2) x=2 y=2`:
    - `debug_pathfind_to:1,10`
      => `No path found [no_path] (visited=5 path=0)`
    - `debug_pathfind_to:6,2`
      => `No path found [goal_not_walkable]`
    - `debug_pathfind_to:5,2`
      => `Path: 3 east`
  - from live `teleport_to:5,2`:
    - `debug_pathfind_to:1,10`
      => `No path found [no_path] (visited=4 path=0)`
  - interpretation:
    - this northwest/top-row pocket is now modeled tightly enough that the
      planner treats it as a dead-end component rather than a bridge toward the
      southwest B3 stairs
    - next useful work is no longer the `(2,2)` trio; resume by probing the
      next outward seam beyond the reachable east-side lip of this component
- Current live stop:
  - `POSITION map=0x19(Garin's Grave B2) x=5 y=2`
- Verification:
  - live mixed verifier plus three-shot tiebreaker and reverse verifier for
    `(2,3).north`
  - live mixed verifier plus three-shot tiebreaker and reverse verifier for
    `(1,2).east`
  - live same-origin `probe_edge_verify:UP,5` from `(2,2)` for `(2,1).south`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 northwest lip and upper-row pocket promoted; top-hook false alarms mostly cleared (2026-06-05, uncommitted)

- Live cleanup of the earlier stopped autowalk near the B2 top hook:
  - `(10,2)->LEFT` into `(9,2)` was rechecked cleanly:
    `probe_edge_verify:LEFT,5` from `(10,2)` moved `6/6`, so keep
    `(9,2).east` open
  - the earlier route-shaped hits at `(11,2)->DOWN` and `(11,1)->LEFT`
    were also rechecked cleanly by fresh split probes:
    - `(11,2)->DOWN` moved into `(11,3)`, so keep `(11,3).north` open
    - `(11,1)->LEFT` moved into `(10,1)`, so keep `(10,1).east` open
  - `(10,2)<->(10,3)` stayed contradictory and is still not promoted:
    - interrupted verifier from `(10,2)->DOWN` moved `3/3` before battle
    - later split one-shots from `(10,2)->DOWN` were mixed (`1 moved, 2 blocked`)
    - reverse one-shots from `(10,3)->UP` blocked `3/3`
    - leave `(10,3).north` / `(10,2).south` unmodeled for now
- Fresh northwest-pocket autowalk from live `(10,1)` exposed a cleaner B2 band:
  - same-origin `probe_edge_verify:DOWN,5` from `(3,2)`, `(4,2)`, and `(5,2)`
    each confirmed the north lip into `(3,3)`, `(4,3)`, and `(5,3)` blocked
    `5/5`
  - same-origin `probe_edge_verify:UP,5` from `(4,2)` confirmed
    `(4,1).south` blocked `5/5`
  - `(5,1).south` stayed mixed on a full verifier (`moved=1 blocked=4`), but
    three separate fresh `probe_edge:UP` checks from `(5,2)` all blocked and
    reverse `probe_edge_verify:DOWN,5` from `(5,1)` moved `6/6`, so model it
    as a one-way seam
  - `(2,1).east` behaved the same way: full verifier from `(3,1)->LEFT`
    stayed mixed (`moved=1 blocked=4`), but three fresh `probe_edge:LEFT`
    checks from `(3,1)` all blocked and reverse
    `probe_edge_verify:RIGHT,5` from `(2,1)` moved `6/6`
  - same-origin `probe_edge_verify:LEFT,5` from `(3,2)` confirmed
    `(2,2).east` blocked `5/5`
  - a later resumed reseed route then surfaced the final upper-row face in that
    same pocket:
    - same-origin `probe_edge_verify:RIGHT,5` from `(3,1)` confirmed
      `(4,1).west` blocked `5/5`
- Code/data patch:
  - `map_reader.lua` now also models B2 `0x19`:
    - `(2,1).east`
    - `(2,2).east`
    - `(3,3).north`
    - `(4,1).west`
    - `(4,1).south`
    - `(4,3).north`
    - `(5,1).south`
    - `(5,3).north`
  - `test_map_reader.lua` now covers those eight additions in the Garin's
    Grave B2 southwest-stair regression.
- Live runtime sync for the current FCEUX session:
  - active runtime edges now include:
    - `(3,2)->DOWN`
    - `(4,2)->DOWN`
    - `(5,2)->DOWN`
    - `(3,1)->LEFT`
    - `(3,1)->RIGHT`
    - `(3,2)->LEFT`
    - `(4,2)->UP`
    - `(5,2)->UP`
  - current `RUNTIME_BLOCKS map=0x19 count=7`
- Live route follow-up after the reseed:
  - from `(2,2)`, `debug_pathfind_to:1,10`
    => `Path: 8 south, 1 west`
  - the next short autowalk did not invalidate the new blockers, but it exposed
    the next unresolved route-shaped trio in the same northwest pocket:
    - `(2,2)->DOWN` into `(2,3)` => candidate `(2,3).north`
    - `(2,2)->LEFT` into `(1,2)` => candidate `(1,2).east`
    - `(2,2)->UP` into `(2,1)` => candidate `(2,1).south`
  - after reseeding the later `(4,1).west` face, the planner from live
    `(3,1)` now collapses cleanly:
    - `debug_pathfind_to:1,10` => `No path found [no_path] (visited=4 path=0)`
    - the next bridge almost certainly lives in the unresolved trio above
  - current live stop:
    - `POSITION map=0x19(Garin's Grave B2) x=3 y=1`
- Verification:
  - live `probe_edge_verify:LEFT,5` from `(10,2)` clearing `(9,2).east`
  - live split one-shots from `(11,2)->DOWN` and `(11,1)->LEFT`
  - live same-origin `probe_edge_verify:DOWN,5` from `(3,2)`, `(4,2)`,
    and `(5,2)`
  - live same-origin `probe_edge_verify:UP,5` from `(4,2)`
  - live mixed verifier plus three-shot tiebreaker and reverse verifier for
    `(5,1).south`
  - live mixed verifier plus three-shot tiebreaker and reverse verifier for
    `(2,1).east`
  - live same-origin `probe_edge_verify:LEFT,5` from `(3,2)` for `(2,2).east`
  - live same-origin `probe_edge_verify:RIGHT,5` from `(3,1)` for `(4,1).west`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 west-strip continuation promoted through `(5,9)<->(8,9)` (2026-06-05, uncommitted)

- Live follow-up on the noisy `(8,9)->LEFT` probe:
  - repeated `probe_edge_verify:LEFT,5` from `(8,9)` stayed mixed
    (`moved=3 blocked=2 classification=inconclusive_teleport_artifact`)
  - fresh one-shot tiebreaker removed the ambiguity:
    - three separate `teleport_to:8,9` then `probe_edge:LEFT`
      all ended `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
  - reverse face then settled cleanly:
    - `teleport_to:7,9` then `probe_edge_verify:RIGHT,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
- West-strip continuation after that patch:
  - with `(7,9)<->(8,9)` active, `debug_pathfind_to:1,10` from `(7,9)` shrank
    to `Path: 6 west, 1 south`
  - follow-up autowalk still completed to `(1,10)`, but on the way it exposed
    the next two westward seams in the same row:
    - `(7,9)->LEFT` into `(6,9)` logged `blocked_only`
    - later direct work showed repeated verifier mixed, but three fresh
      `probe_edge:LEFT` checks from `(7,9)` all blocked and reverse
      `probe_edge_verify:RIGHT,5` from `(6,9)` blocked 5/5
    - after promoting that pair, the route from `(6,9)` shrank to
      `Path: 5 west, 1 south`
    - next autowalk again completed to `(1,10)` and exposed `(6,9)->LEFT`
      into `(5,9)` the same way
    - repeated verifier from `(6,9)` stayed mixed, but three fresh
      `probe_edge:LEFT` checks all blocked and reverse
      `probe_edge_verify:RIGHT,5` from `(5,9)` blocked 5/5
- Code/data patch:
  - `map_reader.lua` now also models B2 `0x19`:
    - `(7,9).east`
    - `(7,9).west`
    - `(8,9).west`
    - `(6,9).east`
    - `(6,9).west`
    - `(5,9).east`
  - `test_map_reader.lua` now covers those six additions in the Garin's Grave
    B2 southwest-stair regression.
  - during the patch, a duplicate-key overwrite bug surfaced: adding a later
    `(7,9)` entry initially shadowed the earlier `(7,9).north` face. The final
    model merges those faces correctly, and the focused test suite is green.
- Live runtime sync for the current FCEUX session:
  - newly injected this pass:
    - `add_blocked_edge:25,8,9,LEFT`
    - `add_blocked_edge:25,7,9,RIGHT`
    - `add_blocked_edge:25,7,9,LEFT`
    - `add_blocked_edge:25,6,9,RIGHT`
    - `add_blocked_edge:25,6,9,LEFT`
    - `add_blocked_edge:25,5,9,RIGHT`
  - current `RUNTIME_BLOCKS map=0x19 count=13`
  - notable live west strip now includes:
    - `(5,9).east`
    - `(6,9).east/west`
    - `(7,9).east/west`
    - `(8,9).north/west`
- Current live stop:
  - after the latest repeat autowalk, live state is back at
    `POSITION map=0x19(Garin's Grave B2) x=1 y=10`
  - the route still tightens from the west strip:
    - from `(5,9)`, `debug_pathfind_to:1,10` => `Path: 4 west, 1 south`
  - the most recent completion pass did not produce a new durable blocker:
    - `(4,10)->LEFT` into `(3,10)` hit timing retry, then moved on seam retry
    - `(2,11)->LEFT` into `(1,11)` hit timing retry, then moved on seam retry
    - do not promote `(3,10).east` or `(1,11).east`
- Verification:
  - live mixed `probe_edge_verify:LEFT,5` from `(8,9)`, `(7,9)`, and `(6,9)`
  - live three-shot `probe_edge:LEFT` tiebreakers from `(8,9)`, `(7,9)`,
    and `(6,9)`
  - live reverse `probe_edge_verify:RIGHT,5` from `(7,9)`, `(6,9)`, and `(5,9)`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 `(8,8)<->(8,9)` seam settled; next candidate is `(7,9).east` (2026-06-05, uncommitted)

- Live direct-verifier follow-up:
  - The planned `teleport_to:8,8` then `probe_edge_verify:DOWN,5` check did
    not settle cleanly by itself:
    - `EDGE_VERIFY_RESULT ... from=(8,8) dir=down dest=(8,9)`
      => `moved=2 blocked=3 classification=inconclusive_teleport_artifact`
  - The attempt-by-attempt log showed the typical mixed shape:
    - attempts 1-2 moved into `(8,9)`
    - attempts 3-5 hit `raw_hold_timeout` from the same fresh teleports
  - Fresh one-shot tiebreaker from the upper side then removed the ambiguity:
    - three separate `teleport_to:8,8` then `probe_edge:DOWN`
      all ended `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
  - Reverse face also settled cleanly:
    - `teleport_to:8,9` then `probe_edge_verify:UP,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
- Code/data patch:
  - `map_reader.lua` now also models B2 `0x19`:
    - `(8,8).south`
    - `(8,9).north`
  - `test_map_reader.lua` now covers both additions and removes the old
    “keep `(8,9)` unmodeled” expectation.
- Live runtime sync for the current FCEUX session:
  - injected:
    - `add_blocked_edge:25,8,8,DOWN`
    - `add_blocked_edge:25,8,9,UP`
  - current `RUNTIME_BLOCKS map=0x19 count=10`
- Live route follow-up:
  - from live `(8,9)`, `debug_pathfind_to:1,10`
    => `Path: 7 west, 1 south`
  - follow-up `auto_walk:1,10` then made useful progress through
    `(8,10) -> (8,11) -> (7,11) -> (6,11) -> (5,11) -> (4,11) -> (3,11)`
  - before a battle interrupted, it exposed one fresh unresolved candidate:
    - `(8,9)->LEFT` into `(7,9)` logged
      `SEAM_OBSERVATION ... cell=(7,9) approach=east result=blocked blocked=1 moved=0 classification=blocked_only`
    - do not promote `(7,9).east` yet; it only has route-shaped evidence
    - next best direct check after the battle: `teleport_to:8,9` then
      `probe_edge_verify:LEFT,5`
- Current live stop:
  - battle active after the interrupted autowalk
  - position snapshot at interruption:
    - `POSITION map=0x19(Garin's Grave B2) x=3 y=11`
- Verification:
  - live mixed `probe_edge_verify:DOWN,5` from `(8,8)`
  - live three-shot `probe_edge:DOWN` tiebreaker from `(8,8)`
  - live `probe_edge_verify:UP,5` from `(8,9)`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 center-right strip cleanup from live `(10,8)` and `(8,8)` (2026-06-05, uncommitted)

- Live direct-verifier batch:
  - Fresh same-origin verifiers from the row-8 center-right strip all settled
    cleanly with no drift, map changes, or teleport-artifact flags.
  - North lip from below:
    - `probe_edge_verify:UP,5` from `(9,8)` => `(9,7).south`
    - `probe_edge_verify:UP,5` from live `(10,8)` => `(10,7).south`
    - `probe_edge_verify:UP,5` from `(11,8)` => `(11,7).south`
    - `probe_edge_verify:UP,5` from `(12,8)` => `(12,7).south`
  - South lip from above:
    - `probe_edge_verify:DOWN,5` from `(9,8)` => `(9,9).north`
    - `probe_edge_verify:DOWN,5` from live `(10,8)` => `(10,9).north`
    - `probe_edge_verify:DOWN,5` from `(11,8)` => `(11,9).north`
    - `probe_edge_verify:DOWN,5` from `(12,8)` => `(12,9).north`
  - Reverse sanity check:
    - `teleport_to:10,7` then `probe_edge_verify:DOWN,5`
      => moved `6/6`, so `(10,7).south` is a directional seam, not a sealed
      two-way wall.
- Code/data patch:
  - `map_reader.lua` now also models B2 `0x19`:
    - `(9,7).south`
    - `(10,7).south`
    - `(11,7).south`
    - `(12,7).south`
    - `(9,9).north`
    - `(10,9).north`
    - `(11,9).north`
    - `(12,9).north`
  - `test_map_reader.lua` now covers all eight additions in the Garin's Grave
    B2 southwest-stair regression.
- Live runtime sync for the current FCEUX session:
  - injected:
    - `add_blocked_edge:25,9,8,UP`
    - `add_blocked_edge:25,10,8,UP`
    - `add_blocked_edge:25,11,8,UP`
    - `add_blocked_edge:25,12,8,UP`
    - `add_blocked_edge:25,9,8,DOWN`
    - `add_blocked_edge:25,10,8,DOWN`
    - `add_blocked_edge:25,11,8,DOWN`
    - `add_blocked_edge:25,12,8,DOWN`
  - current `RUNTIME_BLOCKS map=0x19 count=8`
- Live route follow-up:
  - from `(12,8)`, `debug_pathfind_to:1,10`
    => `Path: 4 west, 1 south, 7 west, 1 south`
  - a follow-up autowalk initially made `(9,8)->LEFT` into `(8,8)` look
    suspicious, but direct same-origin `probe_edge_verify:LEFT,5` from `(9,8)`
    then moved `6/6` with stability recheck. Do not promote `(8,8).east`.
  - from live `(8,8)`, `debug_pathfind_to:1,10`
    => `Path: 1 south, 7 west, 1 south`
  - the next autowalk from `(8,8)` then exposed one new unresolved candidate:
    - `(8,8)->DOWN` into `(8,9)` logged `blocked_only` on seam retry
    - battle interrupted later reroute progress at `(13,9)`, so there is still
      no direct verifier proof for `(8,9).north`
    - do not promote `(8,9).north` yet
- Verification:
  - live row-8 `probe_edge_verify` batch above
  - live `probe_edge_verify:LEFT,5` from `(9,8)` disproving `(8,8).east`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 southwest-stair route now completes on permanent model alone (2026-06-05, uncommitted)

- Live route outcome:
  - After the latest B2 west-strip promotions, the running Lua instance came
    back with `RUNTIME_BLOCKS map=0x19 none`, so the next checks effectively
    tested the permanent `map_reader.lua` model by itself.
  - Fresh direct check cleared the battle-interrupted false alarm at
    `(6,11)->LEFT`:
    - same-origin `probe_edge_verify:LEFT,5` from `(6,11)`
      => `moved=6 blocked=0 classification=confirmed_passable`
  - From live `(5,11)`, `debug_pathfind_to:1,10` tightened to
    `Path: 4 west, 1 north`.
  - A short autowalk from `(5,11)` then completed cleanly:
    - `(4,11)`, `(3,11)`, `(2,11)`, `(1,11)`, and `(1,10)` all logged
      `SEAM_OBSERVATION ... result=moved`
    - `AUTO_WALK_NPC_PARK_RESTORE ... reason=autowalk route complete`
  - Current shared state:
    - `POSITION map=0x19(Garin's Grave B2) x=1 y=10`
    - `RUNTIME_BLOCKS map=0x19 none`
- Interpretation:
  - The southwest B3 stair route now works live on the permanent B2 model
    alone; no runtime reinjection was needed for the final completion pass.
  - Do not promote the battle-interrupted `(5,11).east` route hit; direct
    verifier evidence disproved it.
- Verification:
  - live `probe_edge_verify:LEFT,5` from `(6,11)`
  - live `debug_pathfind_to:1,10` from `(5,11)`
  - live `auto_walk:1,10` completed to `(1,10)`

## Latest: B2 west-strip cleanup from `(9,6)` through `(6,8)` (2026-06-05, uncommitted)

- Live route follow-up:
  - The user-reported manual blocker at `(9,6)->LEFT` turned out to be real in
    the current engine state despite an older passable read:
    - fresh `probe_edge:LEFT` from `(9,6)` blocked immediately
    - same-origin `probe_edge_verify:LEFT,5` from `(9,6)` blocked 5/5 twice
    - reverse `probe_edge_verify:RIGHT,5` from `(8,6)` moved 6/6 with
      stability recheck
  - After promoting that seam, a rerouted southwest-stair pass exposed a new
    west strip on the `x=8` column:
    - `(7,6)->RIGHT` into `(8,6)` confirmed blocked 5/5
    - `(7,7)->RIGHT` into `(8,7)` confirmed blocked 5/5
    - `(7,8)->RIGHT` into `(8,8)` stayed teleport-artifact mixed under
      repeated verification, but three separate fresh-start `probe_edge:RIGHT`
      shots all blocked and reverse `probe_edge_verify:LEFT,5` from `(8,8)`
      moved 6/6
  - One more reroute then found an upper lip on `(6,8)->UP`:
    - repeated `probe_edge_verify:UP,5` from `(6,8)` was mixed
    - three fresh-start `probe_edge:UP` shots from `(6,8)` all blocked
    - reverse `probe_edge_verify:DOWN,5` from `(6,7)` moved 6/6
  - Nearby non-promoted noise from the same live passes:
    - `(10,6).west` stayed route-timing noise, not a blocker
    - `(7,8).north` was confirmed passable 6/6 after the Metal Scorpion fight
    - `(7,7).south` stayed noisy and should not be promoted
- Code/data patch:
  - `map_reader.lua` now also models B2 `0x19`:
    - `(8,6).east`
    - `(8,6).west`
    - `(8,7).west`
    - `(8,8).west`
    - `(6,7).south`
  - `test_map_reader.lua` now covers those additions in the Garin's Grave B2
    southwest-stair regression.
- Live runtime sync for the current FCEUX session:
  - injected:
    - `add_blocked_edge:25,9,6,LEFT`
    - `add_blocked_edge:25,7,6,RIGHT`
    - `add_blocked_edge:25,7,7,RIGHT`
    - `add_blocked_edge:25,7,8,RIGHT`
    - `add_blocked_edge:25,6,8,UP`
  - current `RUNTIME_BLOCKS map=0x19 count=22`
  - notable live cells now include:
    - `(6,7).south`
    - `(8,6).east/west`
    - `(8,7).west`
    - `(8,8).west`
  - current live baseline:
    - `POSITION map=0x19(Garin's Grave B2) x=6 y=8`
    - `debug_pathfind_to:1,10`
      => `Path: 1 east, 4 north, 2 east, 1 north, 8 west, 7 south`
- Verification:
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 east-pocket cleanup near `(10,4)` to `(12,6)` (2026-06-05, uncommitted)

- Live route follow-up:
  - A fresh B2 autowalk batch exposed a right-side pocket around `(11,5)` and
    `(11,6)` with repeated blocked-only seam hits on `(10,5)`, `(10,6)`,
    `(11,7)`, `(12,5)`, and `(12,6)`.
  - Split direct verifiers then confirmed five of them cleanly 5/5:
    - `teleport_to:11,6` then `probe_edge_verify:RIGHT,5`
      => `(12,6).west`
    - `teleport_to:11,6` then `probe_edge_verify:LEFT,5`
      => `(10,6).east`
    - `teleport_to:11,6` then `probe_edge_verify:DOWN,5`
      => `(11,7).north`
    - `teleport_to:11,5` then `probe_edge_verify:LEFT,5`
      => `(10,5).east`
    - `teleport_to:11,5` then `probe_edge_verify:RIGHT,5`
      => `(12,5).west`
  - The sixth face, `(10,5).north`, hit the known teleport-artifact signature
    under repeated verification:
    - `teleport_to:10,4` then `probe_edge_verify:DOWN,5`
      => `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - Independent fresh-start one-shot probes then settled it back to real engine
    blocking:
    - three separate `teleport_to:10,4` then `probe_edge:DOWN`
      all ended `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
- Code/data patch:
  - `map_reader.lua` now also models B2 `0x19`:
    - `(10,5).east`
    - `(10,5).north`
    - `(10,6).east`
    - `(11,7).north`
    - `(12,5).west`
    - `(12,6).west`
  - `test_map_reader.lua` now covers those six additions in the Garin's Grave
    B2 southwest-stair regression.
- Live runtime sync for the current FCEUX session:
  - injected:
    - `add_blocked_edge:25,11,6,RIGHT`
    - `add_blocked_edge:25,11,6,LEFT`
    - `add_blocked_edge:25,11,6,DOWN`
    - `add_blocked_edge:25,11,5,LEFT`
    - `add_blocked_edge:25,11,5,RIGHT`
    - `add_blocked_edge:25,10,4,DOWN`
  - current `RUNTIME_BLOCKS map=0x19 count=18`
  - notable live cells now include:
    - `(10,5).east/north/west`
    - `(12,5).west`
    - `(10,6).east`
    - `(12,6).west`
    - `(11,7).north`
  - current live baseline:
    - `POSITION map=0x19(Garin's Grave B2) x=10 y=4`
- Verification:
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 west-pocket and top-lip strip cleanup (2026-06-05, uncommitted)

- Live route follow-up:
  - After the prior B2 mid-pocket fixes were runtime-seeded, a fresh
    southwest-stair autowalk from `(8,4)` got farther before exposing the next
    real blocker band.
  - The first clean new seam was `(3,6)->LEFT` into `(2,6)`, confirmed blocked
    5/5 by same-origin `probe_edge_verify:LEFT,5`.
  - A subsequent route pass then exposed a wider upper-left strip:
    - `(3,5)->LEFT` into `(2,5)` confirmed blocked 5/5
    - `(3,4)->UP` into `(3,3)` confirmed blocked 5/5
    - `(4,4)->UP` into `(4,3)` confirmed blocked 5/5
    - `(5,4)->UP` into `(5,3)` confirmed blocked 5/5
    - `(6,4)->UP` into `(6,3)` confirmed blocked 5/5
    - `(7,4)->UP` into `(7,3)` confirmed blocked 5/5
  - The west/top faces around `(8,5)` also settled cleanly this pass:
    - `(7,5)->RIGHT` into `(8,5)` confirmed blocked 5/5
    - `(8,4)->DOWN` into `(8,5)` confirmed blocked 8/8 after one earlier
      teleport-artifact mixed read
    - `(8,4)->UP` into `(8,3)` confirmed blocked 5/5
- Code/data patch:
  - `map_reader.lua` now also models B2 `0x19`:
    - `(2,5).east`
    - `(2,6).east`
    - `(3,3).south`, `(4,3).south`, `(5,3).south`, `(6,3).south`, `(7,3).south`
    - `(8,3).south`
    - `(8,5).west`, `(8,5).north`
  - `test_map_reader.lua` now covers those additions in the Garin's Grave B2
    southwest-stair regression, while still keeping the disproven
    `(8,6).east`, `(10,6).west`, and `(9,3).south` approaches open.
- Live runtime sync for the current FCEUX session:
  - current `RUNTIME_BLOCKS map=0x19 count=14`
  - active runtime cells now include:
    - `(3,3).south` through `(8,3).south`
    - `(2,4).east`, `(2,5).east`, `(2,6).east`, `(2,7).east`, `(2,8).east`
    - `(8,5).east/north/west`
    - `(10,5).west`
    - `(9,7).north`
- Current live baseline:
  - `POSITION map=0x19(Garin's Grave B2) x=3 y=5`
  - `debug_pathfind_to:1,10` now returns
    `Path: 3 south, 5 east, 1 south, 7 west, 1 south`
  - route is still open; this pass cleaned a large blocker band but did not yet
    reach the southwest B3 stairs.
- Verification:
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B2 mid-pocket loop cleanup on the southwest-stair return (2026-06-05, uncommitted)

- Live root cause:
  - The noisy autowalk loop near Garin's Grave B2 `(9,4)` / `(9,5)` / `(9,6)`
    was a mixed cluster, not "all new blockers."
  - Same-origin direct verifiers split it cleanly:
    - real blockers:
      - `(9,6)->DOWN` into `(9,7)` confirmed blocked 5/5
      - `(9,5)->LEFT` into `(8,5)` confirmed blocked 5/5
      - `(9,5)->RIGHT` into `(10,5)` confirmed blocked 5/5
    - false positives:
      - `(9,6)->LEFT` into `(8,6)` moved 6/6
      - `(9,6)->RIGHT` into `(10,6)` moved 6/6
      - `(9,4)->UP` into `(9,3)` moved 6/6
  - The explicit-origin verifier for `(9,6)->DOWN` was mixed with
    `teleport_artifact_suspected=true`; the split `teleport_to:9,6` then
    same-origin `probe_edge_verify:DOWN,5` was the trustworthy proof.
- Code/data patch:
  - `map_reader.lua` now adds B2 `0x19` edges `(8,5).east`, `(9,7).north`, and
    `(10,5).west`.
  - `test_map_reader.lua` now asserts those three blockers and keeps
    `(8,6).east`, `(10,6).west`, and `(9,3).south` explicitly open on B2.
- Live runtime sync for the current FCEUX session:
  - injected `add_blocked_edge:25,9,6,DOWN`
  - injected `add_blocked_edge:25,9,5,LEFT`
  - injected `add_blocked_edge:25,9,5,RIGHT`
  - `RUNTIME_BLOCKS map=0x19 count=6`, including the older `(2,4).east`,
    `(2,7).east`, `(2,8).east` plus the new `(8,5).east`, `(10,5).west`,
    `(9,7).north`
  - hero restored to `POSITION map=0x19(Garin's Grave B2) x=9 y=4`
- Live planner sanity after reinjection:
  - `debug_pathfind_to:1,10` from `(9,4)` returned
    `Path: 6 west, 2 south, 2 west, 4 south`
- Verification:
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: route-turn movement reset stat corruption repro (2026-06-05, uncommitted)

- Live repro:
  - After the Silver Harp route, the user intentionally set
    `auto_step_reset_movement_on_route_turn_settle=true`.
  - On the next Garin's Grave B2 `0x19` autowalk pass, stats flipped from clean
    to bad in one frame:
    `PLAYER_STAT_FRAMEADVANCE_TRANSITION ... pre_frame=72173 post_frame=72174
    before_pos=(7,4) after_pos=(7,4) changed=C8,C9,CA,CB,CC,CD,CE`.
  - The flip happened immediately after
    `auto_step route turn settle prev=up next=right frames=16`.
  - The user won the resulting battle, changed the option back to `false`, and
    reloaded the script.
- Code/config safety patch:
  - `config.lua` now ships
    `auto_step_reset_movement_on_route_turn_settle=false`.
  - `auto_step.lua` now treats a missing config value as `false` too, so
    regenerated/incomplete configs cannot silently re-enable the risky reset.
  - `dw_access.ini` keeps the option false and its comment now warns that true
    reproduced stat corruption in FCEUX.
  - `test_config.lua` covers the shipped safe default.
  - `test_auto_step.lua` covers both the safe absent-setting fallback and the
    explicit opt-in reset behavior for controlled diagnostics.
- Live validation after reload with the option false:
  - `LAUNCHER_PROBE: after_false_reload`
  - `POSITION map=0x19 x=7 y=4`
  - `RUNTIME_BLOCKS map=0x19 none`
  - stats were clean again: `hp=70/70`, `mp=39/57`,
    `STR=0x34 AGI=0x2B ATK=0x48 DEF=0x39`, `spells=CE=0x7F CF=0x10`.
  - A cautious `auto_walk:1,10` ran through several route-turn/seam-retry
    events without a new stat-integrity warning before a Wolf battle interrupted
    at `map=0x19 x=3 y=6`; stats were still clean at battle start.
- Follow-up direct verifiers on the three left-edge B2 candidates all
  confirmed clean 5/5 blockers:
  - `probe_edge_verify:3,4,LEFT,5` confirmed `(2,4).east`
  - `probe_edge_verify:3,8,LEFT,5` confirmed `(2,8).east`
  - `probe_edge_verify:3,7,LEFT,5` confirmed `(2,7).east`
  - `MAP_DIRECTIONAL_BLOCKS[0x19]` now includes those east approaches, and
    `test_map_reader.lua` covers them in the Garin's Grave B2 southwest-stair
    route regression.
  - Live runtime also seeds them now:
    `RUNTIME_BLOCK map=0x19 x=2 y=4 dirs=east`,
    `RUNTIME_BLOCK map=0x19 x=2 y=7 dirs=east`,
    `RUNTIME_BLOCK map=0x19 x=2 y=8 dirs=east`.
  - Hero was restored after the verifier pass:
    `POSITION map=0x19(Garin's Grave B2) x=3 y=6`
- Verification:
  - `lua5.1 test_config.lua`
  - `lua5.1 test_auto_step.lua`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p config.lua auto_step.lua test_config.lua test_auto_step.lua`

## Latest: Garin's Grave B1 B2 Door dual-stand route fix (2026-06-05, uncommitted)

- Live root cause:
  - On Garin's Grave B1 `0x18`, selected object `B2 Door` remained present at
    `(17,17)`, with no NPC or runtime blockers.
  - The object was configured only for the previously proven lower/south stand
    `(17,18)` facing north. From the current north-side maze component,
    `debug_pathfind_to:17,18` returned `No path found`.
  - `debug_pathfind_adjacent:17,17` found a valid route to the north-side stand
    `(17,16)` and reported `Face south`.
- Code/data patch:
  - `objects.lua` keeps the original `(17,18)` stand as primary proof and adds
    `(17,16)` facing south as a second `interaction_points` entry.
  - `route_manager.lua` now tries alternate interaction points when the primary
    interaction goal has no path, and passes the selected stand into object
    readout so `current_object` can describe the reachable side.
  - `test_objects.lua` and `test_route_manager.lua` cover the dual-stand door
    metadata and reachable-stand route/readout selection.
- Live state:
  - FCEUX had not reloaded the patched Lua yet; live `current_object` still
    reported the old `(17,18)` stand and `pathfind` still returned no path.
  - Workaround route `auto_walk:17,16` was used. A Droll battle interrupted at
    `(9,14)`, then the resumed route completed to:
    `POSITION map=0x18(Garin's Grave B1) x=17 y=16`.
  - Current live `PATH_STATE target=nil map=0x18 runtime_count=0` and
    `RUNTIME_BLOCKS map=0x18 none`.
  - Immediate manual next step: face south from `(17,16)` and use `OPEN`.
    After a Lua reload/relaunch, selecting `B2 Door` should route to this stand
    automatically when approached from the north-side component.
- Verification:
  - `lua5.1 test_objects.lua`
  - `lua5.1 test_route_manager.lua`
  - `luac5.1 -p objects.lua route_manager.lua test_objects.lua test_route_manager.lua`
  - `git diff --check -- objects.lua route_manager.lua test_objects.lua test_route_manager.lua`
  - `python3 run_tests.py --allow-missing-speech-dep` passed, with the known
    `accessible_output2` warning and local `cmd: not found` speech-bridge noise.

## Latest: Garinham top-edge blocker and object browser cleanup (2026-06-05, uncommitted)

- Live blocker follow-up after the Silver Harp escape:
  - `probe_edge_verify:19,0,LEFT,5` confirmed `(19,0)->LEFT` into `(18,0)`
    is blocked 5/5 even though `(18,0)` remains a passthrough/exit cell.
    Promoted as Garinham `0x09` directional block `(18,0).east`.
  - `probe_edge_verify:18,1,UP,5` did **not** confirm a blocker: it moved
    onto `(18,0)` and then hit the world-map transition. Keep `(18,0).south`
    open.
- Object browser cleanup:
  - Reproduced the stale object-label bug live: `current_object` on Garinham
    `(19,0)` reported an old grave-floor stair at `(6,11)`.
  - `object_commands.lua` now calls `objects.check_refresh(current_map)` before
    describing or browsing objects, while avoiding forced NPC rebuilds when a
    map-entry refresh is still pending.
  - Added `test_object_commands.lua` and included `object_commands.lua` /
    `test_object_commands.lua` in `run_tests.py`.
  - Live sanity after the fix no longer reported the stale grave stair; after
    the transition settled, `current_object` reported a Garinham town object.
- Current live baseline:
  - `POSITION map=0x09(Garinham) x=0 y=14`
  - `PATH_STATE target=nil map=0x09 runtime_count=0`
  - `RUNTIME_BLOCKS map=0x09 none`
- Verification:
  - `lua5.1 test_map_reader.lua`
  - `lua5.1 test_object_commands.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua object_commands.lua test_object_commands.lua`
  - `python3 -m py_compile run_tests.py`
  - `python3 run_tests.py --allow-missing-speech-dep` passed, with the known
    `accessible_output2` warning
  - `git diff --check -- map_reader.lua test_map_reader.lua object_commands.lua test_object_commands.lua run_tests.py`

## Latest: Silver Harp recovered and escape reached Garinham (2026-06-05, uncommitted)

- Live outcome:
  - Garin's Grave B3 chest at `(13,6)` was reached and opened.
  - TAKE confirmation logged:
    `Fortune smiles upon thee, Bill. Thou hast found the Silver Harp.`
  - Return route then successfully crossed B4, B3, B2, and B1 back to
    Garinham.
  - Current live baseline after stopping a separate Garinham top-edge route:
    `POSITION map=0x09(Garinham) x=19 y=0`,
    `PATH_STATE target=nil map=0x09 runtime_count=0`, and
    `RUNTIME_BLOCKS map=0x09 none`.
- Permanent map/test sync from the successful route:
  - B3 `0x1A`: added confirmed blockers including `(10,6).east` and the
    hidden bridge passthrough `(4,14)`.
  - B4 `0x1B`: added west return stair passthrough `(0,4)`.
  - B1 `0x18`: added `(5,18).south` and `(6,18).south`, and removed stale
    `(4,17).west` after the live Silver Harp escape verifier moved
    `(3,17)->RIGHT` 6/6.
  - `test_map_reader.lua` has focused assertions for those corrections.
- Watch items:
  - FCEUX has not necessarily reloaded the edited Lua/data; permanent changes
    are verified by tests, but live FCEUX behavior still depends on manual Lua
    reload or relaunch.
  - Garinham `auto_walk:18,0` looped around `(19,0)/(19,1)/(18,1)` and
    repeatedly failed entering `(18,0)` from south/east. Treat that as a
    separate Garinham exit-model investigation, not as B1/B2/B3 route evidence.
  - Object-browser labels were stale across some map transitions during this
    pass, reporting old B3 stair labels while on B4/B2/B1. Future source fix
    should refresh object context before object command reporting after map
    changes.
  - One B3 southwest stair menu interaction had FCEUX/input-bridge funk where
    DOWN acted like field movement; user manually recovered to B2. Later B2
    and B1 stair menus behaved normally.
- Verification:
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## Latest: B3 lower-B4 route continuation (2026-06-05, uncommitted)

- Live context: user resumed Garin's Grave B3 after entering through the SW B2
  stairs, still targeting the lower stairs down to B4 at `(10,9)`.
- Baseline after fresh probe:
  - `POSITION map=0x1A x=4 y=10`
  - `RUNTIME_BLOCKS map=0x1A none`
  - planner still found a route to `(10,9)`: `3 south, 1 east, 1 north,
    9 east, 3 north, 4 west`
- Autowalk exposed two missing opposite approaches in the permanent B3 table:
  - `(4,13)->RIGHT` into `(5,13)` failed live; direct verifier
    `probe_edge_verify:4,13,RIGHT,5` confirmed blocked 5/5, promoted as
    `(5,13).west`
  - the reroute then climbed to `(6,4)` and failed `(6,4)->LEFT` into
    `(5,4)`; direct verifier `probe_edge_verify:6,4,LEFT,5` confirmed blocked
    5/5, promoted as `(5,4).east`
- Permanent data/test sync:
  - `map_reader.lua` now includes `(5,4).east` and `(5,13).west` in map `0x1A`
  - `test_map_reader.lua` adds focused B3 assertions for both approaches
  - TDD red check first failed on missing `5,4.east`; green check then passed
- After runtime-injecting those two edges in the live FCEUX session:
  - normal and skip-NPC `debug_pathfind_to:10,9` from `(6,4)` both returned
    `No path found`
  - `debug_route_frontier_skip_npcs:10,9` reported
    `reachable=25 target_reachable=false hidden_bridge_candidates=0`
  - top frontier exits were the two new runtime blocks plus existing static
    blockers around `(9,5)`
- Static frontier sanity check:
  - first `(9,5)->DOWN` verifier produced a contaminated-looking mixed result
    after stale `LeftAlt`/input focus noise, so `./recover_fceux_input.sh` was
    run before trusting it
  - clean rerun `probe_edge_verify:9,5,DOWN,8` confirmed blocked 8/8
  - `probe_edge_verify:9,5,RIGHT,5` confirmed blocked 5/5
- Current live state after the final baseline:
  - `POSITION map=0x1A x=9 y=5`
  - `RUNTIME_BLOCKS map=0x1A count=2`
  - runtime entries: `(5,4).east`, `(5,13).west`
  - `PATH_STATE target=nil map=0x1A runtime_count=2`
  - FCEUX has not reloaded `map_reader.lua`; keep those two runtime blocks
    seeded until reload/relaunch, after which they should be permanent.
- Current conclusion:
  - the newly attempted route is now sealed by two direct-confirmed blockers
    plus already-confirmed top frontier blockers
  - there is no obvious local seam from this component toward `(10,9)` after
    those confirmations; next work should pivot to a broader route/entry
    strategy, an external-map sanity check, or another start component rather
    than more blind seam hunting from `(6,4)` / `(9,5)`.
- Verification:
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check`

## Latest: permanent B3 blocker sync and clearer B4 stair labels (2026-06-02, uncommitted)

- Promoted the stable 49-edge Garin's Grave B3 runtime reseed into the
  permanent `map_reader.lua` directional model.
  - This keeps the old southwest-pocket seam set and adds the later
    model-consistent bridge-strip, top-pocket, and lower-B4-stair approach
    blockers that had previously only existed in runtime reseed commands.
  - The permanent B3 table now includes the proven directions on cells like
    `(7,7..9)`, `(5,10..12)`, `(6,10)`, `(7,10)`, `(9,3)`, `(9,6..10)`,
    `(10,4..5,10,12)`, `(11,10,12)`, `(12,10,12)`, `(13,9,12)`, and
    `(14,10..11)`.
- Clarified the ambiguous B4 return-stair names in `objects.lua`:
  - `(0,4)` is now `West Return Stairs to B3`
  - `(5,4)` is now `East Return Stairs to B3`
  - B3 `(9,5)` / `(10,9)` remain `Upper` / `Lower Stairs Down to B4`; the
    pairing itself was not swapped.
- Verification:
  - `lua5.1 test_objects.lua`
  - `lua5.1 test_map_reader.lua`
  - `luac5.1 -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`
  - `python3 run_tests.py --allow-missing-speech-dep`
  - `git diff --check -- objects.lua map_reader.lua test_objects.lua test_map_reader.lua`

## Latest: player-stat corruption fixes (2026-05-31, uncommitted)

Two safety fixes landed in the working tree (not committed) — see
`HANDOFF_2026-05-31_stat_corruption_fixes.md` for full detail:

- **Suspect #1 (latent):** unbounded NPC `slot` could make NPC park/freeze/hold
  writes land on the player-stat block (`0x00BA–0x00D0`). Added
  `valid_npc_slot()` and a guarded `write_npc_bytes_if_changed` chokepoint in
  `route_manager.lua` that refuses + logs out-of-range slots; both bypass sites
  (`is_destination_occupied_by_npc`, `add_live_npc_to_autowalk_parking`) now
  validate `npc.slot`. Watch `dw_debug.log` for `NPC write refused`.
- **Suspect #2 (recent trigger):** consolidated all `MOVEMENT_STATE/SUBPIXEL`
  (0x3C/0x3D) resets to a single write point. `auto_step.lua` exports
  `M.reset_movement_engine_state`; `main.lua`'s QOL reset + teleport guard now
  delegate to it. Zero raw movement writes remain in `main.lua`. Corruption
  stopped recurring once `auto_step_reset_movement_on_route_turn_settle=false`
  (`dw_access.ini:190`); the new single gate makes A/B testing this clean.
- `seam_retry` resets left firing unconditionally on purpose (test asserts it).
- Verified: `luac5.1 -p route_manager.lua auto_step.lua main.lua
  test_route_manager.lua test_auto_step.lua`; `lua5.1 test_auto_step.lua` →
  72/72; `lua5.1 test_route_manager.lua` → 94/94; `python3 run_tests.py` →
  477 PASS before the known speech-dep FAIL (`accessible_output2` missing).

Detailed wrap notes are preserved in:

- `handoff_archive/HANDOFF_2026-05-30_garins_grave_session_handoff_full.md`
- `work_notes/current_investigation.md`

## Latest: seam-retry combat cancel cleanup (2026-06-01, uncommitted)

- Fixed a live autowalk contamination bug in `auto_step.lua`:
  - when combat interrupted an active `seam_retry` or queued-route settle,
    `auto_step` only treated `route_steps ~= nil` as a cancellable route
    context
  - that missed queued-route-derived states where the route queue had already
    been cleared but `route_manager` still held active temp-block context
  - result: post-combat planner/debug calls could inherit stale
    `route_temp_blocks` and incorrectly report `No path found`
- Added `queued_route_cancel_source()` so `can_walk=false` now emits the normal
  `route_cancelled` signal for queued-route-derived contexts including
  `seam_retry`, pending repress from a queued route, and route-settle windows.
- Added regression `can_walk_false_cancels_seam_retry_route_context` in
  `test_auto_step.lua`.
- Verification:
  - `lua5.1 test_auto_step.lua`
  - `lua5.1 test_route_manager.lua`
  - `luac5.1 -p auto_step.lua test_auto_step.lua route_manager.lua`
  - `git diff --check`
  - `python3 run_tests.py --allow-missing-speech-dep`
    - passes aside from the expected `accessible_output2` warning
- Live proof of root cause:
  - from confirmed live `B3 (8,9)` with runtime count 20, both
    `debug_pathfind_to:10,9` and `debug_pathfind_to_skip_npcs:10,9` returned
    `No path found` with `route_temp_blocks=3`
  - after manual `stop_auto_walk`, `PATH_STATE` cleared to nil and the same
    `debug_pathfind_to:10,9` immediately recovered to
    `Path: 1 north, 2 east, 1 south` with `route_temp_blocks=0`
  - treat that as confirmed stale temp-block contamination, not fresh B3 map
    evidence
- FCEUX still needs a manual `main.lua` reload to pick up this fix. Until the
  reload happens, `stop_auto_walk` remains the safe manual workaround after any
  combat-interrupted seam-retry.

## End-Of-Night Resume

- The Garin's Grave southwest stair chain is now validated end to end:
  - B2 `(1,10)` -> B3 `(2,17)`
  - B3 `(10,9)` -> B4 `(5,4)`
  - B4 `(0,4)` -> B3 `(9,5)`
- That confirms the correct Silver Harp progress branch. The unresolved work is
  not stair identity anymore; it is stabilizing the B3 route from the southwest
  pocket to the lower B4 stair at `(10,9)`.
- No combat-stat corruption has recurred since:
  - `dw_access.ini` kept `auto_step_reset_movement_on_route_turn_settle=false`
  - `auto_step.lua` was patched so final-settle/final-complete resets finally
    honor that toggle too
- Working hypothesis for tomorrow: if corruption still does not return by the
  time the Silver Harp is recovered, the autowalk settle/reset path deserves a
  focused audit before re-enabling it.

## Current Live State

- Fresh late-night live pass after the permanent B3 sync changed the current
  picture materially:
  - post-reload baseline landed at `POSITION map=0x1A x=4 y=13` with
    `RUNTIME_BLOCKS map=0x1A none`
  - the user's `(4,13).south` report is now backed by two-way route evidence:
    `(4,14)->UP` had already moved into `(4,13)`, and the latest autowalk loop
    later moved back into `(4,13)` from the north as well
  - with only permanent blockers active, `debug_pathfind_to:10,9` from `(4,13)`
    now returns `Path: 1 east, 1 north, 9 east, 3 north, 4 west`
  - `debug_pathfind_to:2,17` from the same tile also returns a live return
    route, `Path: 3 east, 4 south, 5 west`
  - strongest current unresolved blockers from the new live component are:
    - `(5,13).west`, which rose to `blocked=2 moved=0 classification=blocked_only`
      under natural autowalk seam retries
    - `(5,4).east`, which currently sits at `blocked=1 moved=0`
  - latest interruption is a Wraith Knight battle at `POSITION map=0x1A x=4 y=10`
    while re-walking back to `(4,13)` for a direct seam verify
  - next exact resume after combat:
    - `report_position report_runtime_blocks report_path_state`
    - `auto_walk:4,13`
    - `probe_edge_verify:4,13,RIGHT,5`

- The hidden bridge on B3 is now live-confirmed from the southwest pocket:
  - `probe_edge_verify:3,14,RIGHT,5` finished
    `moved=6 blocked=0 classification=suspect_passable_model_mismatch`
  - immediate follow-up `probe_edge:UP` from `(4,14)` moved to `(4,13)`,
    proving the modeled-wall tile actually connects onward
- Once across that bridge, the bridged-side planner became live again:
  - from `(4,13)`, `debug_pathfind_to:10,9` returned `Path: 4 north, 6 east`
  - after seeding the `x=7` west-wall family, planner from `(6,7)` rerouted as
    `Path: 3 south, 4 east, 1 north`
- Clean direct verifiers above the bridge now support this runtime-only blocker
  family:
  - `(7,7).west` via `probe_edge_verify:6,7,RIGHT,5`
  - `(7,8).west` via `probe_edge_verify:6,8,RIGHT,5`
  - `(7,9).west` via `probe_edge_verify:6,9,RIGHT,5`
  - later direct confirms added:
    - `(5,11).west` via `probe_edge_verify:4,11,RIGHT,5`
    - `(5,11).north` via `probe_edge_verify:5,10,DOWN,5`
    - `(6,10).west` via `probe_edge_verify:5,10,RIGHT,5`
    - `(6,10).north` via `probe_edge_verify:6,9,DOWN,5`
  - the current in-session runtime set is:
    `(7,7).west`, `(7,8).west`, `(7,9).west`,
    `(5,11).north,west`, `(6,10).north,west`
- The latest live interruption moved the frontier far past the old `5,10`
  knot and then through the lower-right bypass family:
  - after sealing `5,11` and `6,10`, planner from `(6,9)` rerouted as
    `Path: 3 north, 4 east, 3 south`
  - later confirms sealed the lower-right approach family:
    `(10,4).west`, `(10,5).west`, `(9,6).north`, `(8,6).north`,
    `(7,5).east`, `(9,9).west`, `(9,10).west`, `(9,10).south`,
    `(10,10).south`,
    `(12,10).east,south`, and `(13,9).south`
  - the current in-session runtime set now counts 17 edges/cells, including
    those new lower-right confirmations plus the earlier bridge-side walls
  - the next reroute from `(9,11)` stayed alive, but exposed stronger new
    northeast pressure:
    - `(11,11).west` again stayed noisy/passable during seam retry
    - user follow-up `probe_edge_verify:11,11,UP,5` then cleanly confirmed
      `(11,10).south`
    - a later rerun cleaned up the two right-side siblings:
      - `(14,11).west` via `probe_edge_verify:13,11,RIGHT,5`
      - `(14,10).west` via rerun `probe_edge_verify:13,10,RIGHT,5`
    - once those were injected, the route bent back through the upper-left:
      `probe_edge_verify:8,7,RIGHT,5` then cleanly confirmed `(9,7).west`
    - the next direct cleanup pass then tightened the whole east side of the
      `x=7` strip:
      - `probe_edge_verify:8,7,LEFT,5` cleanly confirmed `(7,7).east`
      - `probe_edge_verify:8,8,LEFT,5` cleanly confirmed `(7,8).east`
      - `probe_edge_verify:8,9,LEFT,5` cleanly confirmed `(7,9).east`
      - the runtime set still counts 20 cells, but those three cells are now
        double-sided as `(7,7).east,west`, `(7,8).east,west`, and
        `(7,9).east,west`
    - even after sealing that strip, planner from `(8,9)` still stayed alive:
      `debug_pathfind_to:10,9` => `Path: 3 north, 2 east, 3 south`
    - repeated fresh autowalk from that cleaner state keeps treating
      `(8,6).south` as the main unresolved seam:
      - first harvest pushed it to
        `blocked=10 moved=0 classification=blocked_only`
      - second harvest pushed it further to
        `blocked=12 moved=0 classification=blocked_only`
      - but the direct verifier `probe_edge_verify:8,7,UP,5` still stayed mixed
        at `moved=2 blocked=3`, so it remains unpromoted
    - the newer lower-left detour also surfaced two more live leads:
      - `probe_edge_verify:8,10,LEFT,5` on `(7,10).east` stayed mixed at
        `moved=1 blocked=4`
      - autowalk moved cleanly `(8,11)->LEFT` to `(7,11)`, and the follow-up
        direct verifier `probe_edge_verify:7,11,UP,5` moved twice into `(7,10)`
        before a battle interrupted the run
  - the latest interruption is a Druinlord battle that began at
    `POSITION map=0x1A x=7 y=11`; by log inspection the fight later resolved,
    but no post-battle movement was queued

## B3 Model Status

- The permanent B3 directional model now matches the 14 confirmed live seams
  from the southwest-pocket dig.
- The strongest unresolved non-directional lead is the hidden-passable bridge
  tile `(4,14)`:
  - it now has two clean live through-movement results,
    `probe_edge_verify:4,15,UP,5` and `probe_edge_verify:3,14,RIGHT,5`
  - a live `probe_edge:UP` exit from `(4,14)` to `(4,13)` confirms it is not
    just a one-frame twitch
  - it still is not modeled because the verifier cannot directly stage onto
    `(4,14)` while the map reader marks it not walkable
- The sibling hidden candidate `(5,15)->UP` into `(5,14)` stayed mixed and
  should remain unmodeled for now.
- Above the bridge, the next unresolved wall family is no longer the `x=7`
  strip, and the `5,10/5,11/6,10` knot is now materially clearer:
  - `(5,11).north,west` are both confirmed blocked
  - `(6,10).north,west` are both confirmed blocked
  - `(5,10).west` is not a clean blocker lead; a direct verifier moved into
    `(5,10)` before battle interruption
- The active frontier is now no longer the old right-side family; it is the
  upper-left/lower-left seam cluster around `(8,6)`, `(7,10)`, and `(7,11)`:
  - the old `(10,4)` and `y=5/y=6` leads are now resolved
  - `(9,10).south` is now directly confirmed and runtime-injected via
    `probe_edge_verify:9,11,UP,5`
  - `(11,10).south` is now also directly confirmed and runtime-injected via
    `probe_edge_verify:11,11,UP,5`
  - the later reruns also directly confirmed and runtime-injected:
    - `(14,11).west` via `probe_edge_verify:13,11,RIGHT,5`
    - `(14,10).west` via rerun `probe_edge_verify:13,10,RIGHT,5`
    - `(9,7).west` via `probe_edge_verify:8,7,RIGHT,5`
    - `(7,7).east` via `probe_edge_verify:8,7,LEFT,5`
    - `(7,8).east` via `probe_edge_verify:8,8,LEFT,5`
    - `(7,9).east` via `probe_edge_verify:8,9,LEFT,5`
  - strongest remaining unresolved seam is still `(8,6).south`:
    - route evidence now has it at
      `blocked=12 moved=0 classification=blocked_only`
    - but the direct verifier from `(8,7)->UP` stayed mixed at
      `moved=2 blocked=3`, so it is still not safe to promote
  - `(7,10).east` is no longer mixed under the fresh reset baseline:
    - `probe_edge_verify:8,10,LEFT,5` now cleanly returned
      `moved=0 blocked=5 classification=confirmed_blocked`
    - it should be mirrored live with `add_blocked_edge:8,10,LEFT`
  - `(7,10).south` still looks like a likely-passable seam rather than a
    blocker:
    - fresh rerun `probe_edge_verify:7,11,UP,5` returned
      `moved=3 blocked=2 classification=inconclusive_teleport_artifact`
    - treat that as harness noise, not blocker evidence
  - with the full runtime reseed plus `(7,10).east`, the planner from live
    `(7,11)` found a new detour to the lower stair:
    - `debug_pathfind_to:10,9` => `Path: 3 north, 3 east, 1 south`
    - live `auto_walk:10,9` temp-blocked `(7,10).south`, rerouted through
      `(8,11) -> (8,10) -> (8,9)`, then exposed a fresh suspect seam at
      `(8,8).south` before combat
  - user follow-up on the nearby reverse seam cleaned up one concern:
    - `probe_edge_verify:8,10,DOWN,5` escalated to a stability recheck and
      finished `moved=6 blocked=0 classification=confirmed_passable`
    - so `(8,11).north` is confirmed open and should not be treated as a
      blocker lead
  - the direct rerun on the newer suspect seam still leans passable, but
    the later clean rerun fully settled it as open:
    - early retry `probe_edge_verify:8,9,UP,5` reached `(8,8)` on its first
      three attempts before a Specter interrupted
    - full rerun later escalated to stability recheck and finished
      `moved=6 blocked=0 classification=confirmed_passable`
    - so `(8,8).south` is confirmed open and should not be injected
  - fresh planner from live `(8,8)` then found the near-target short hop:
    - `debug_pathfind_to:10,9` => `Path: 2 east, 1 south`
    - live `auto_walk:10,9` did not finish that short route cleanly because
      the first step `(8,8)->RIGHT` into `(9,8)` hit a timing-retry temp block
      and the reroute spiraled back through the old upper-left family
  - user follow-up direct checks then settled the short-hop ambiguity:
    - `probe_edge_verify:8,8,RIGHT,5` finished
      `moved=6 blocked=0 classification=confirmed_passable`
    - `probe_edge_verify:6,11,UP,5` finished
      `moved=0 blocked=5 classification=confirmed_blocked`
    - so `(9,8).west` is confirmed open and `(6,10).south` is still a real
      runtime blocker; neither is the next frontier anymore
  - fresh re-baseline from the surviving battle stop:
    - `POSITION map=0x1A x=6 y=11`
    - `RUNTIME_BLOCKS map=0x1A count=20`
    - `PATH_STATE target=nil map=0x1A runtime_count=20`
  - planner from live `(6,11)` still stayed alive:
    - `debug_pathfind_to:10,9` => `Path: 2 east, 3 north, 2 east, 1 south`
  - live `auto_walk:10,9` then reproduced execution noise rather than a new
    stable map blocker:
    - `(7,11)->RIGHT` first logged as a timing-retry temp block/noisy seam,
      then the immediate seam retry moved cleanly into `(8,11)`
    - seam-retry follow-up from `(8,11)` shortened to
      `Path: 3 north, 2 east, 1 south`
    - `(8,11)->UP` then hit the same timing-retry pattern before a Wolflord
      battle interrupted at `POSITION map=0x1A x=8 y=11`
  - later continuation under the patched seam-memory behavior changed the
    picture again:
    - after a later Specter fight, the live script came back with
      `POSITION map=0x1A x=10 y=11`, `RUNTIME_BLOCKS map=0x1A none`,
      and `PATH_STATE target=Lower Stairs Down to B4 ... runtime_count=0`
    - re-seeding the current B3 runtime set (plus the user-confirmed
      `add_blocked_edge:6,11,UP`) restored `RUNTIME_BLOCKS map=0x1A count=20`
    - with that restored set, `debug_pathfind_to:10,9` from live `(10,11)`
      first gave `Path: 3 west, 5 north, 3 east, 3 south`, but the actual
      `auto_walk:10,9` immediately tightened back to the cleaner
      `Path: 2 west, 3 north, 2 east, 1 south`
    - that live route again reached the short-hop frontier:
      - seam-retry follow-up from `(8,8)` once more produced
        `Path: 2 east, 1 south`
    - but the natural arrival story for `(9,8).west` now directly contradicts
      the older teleported verifier result:
      - `probe_edge_verify:8,8,RIGHT,5` had earlier finished
        `moved=6 blocked=0 classification=confirmed_passable`
      - three separate live seam-retry runs from real autowalk now logged
        `SEAM_OBSERVATION map=0x1A cell=(9,8) approach=west result=blocked`
        up to `blocked=3 moved=0 classification=blocked_only`
    - treat `(9,8).west` as unresolved stateful/arrival-context evidence for
      now; do not promote it as either a blocker or a clean passable seam
      without a live non-teleport bracket
    - two nearby route-only lower-pocket siblings also strengthened under the
      same natural-route harvest:
      - `(5,11).east` reached `blocked=2 moved=0 classification=blocked_only`
      - `(6,12).north` reached `blocked=2 moved=0 classification=blocked_only`
  - latest interruption state:
    - a Specter battle started at `POSITION map=0x1A x=11 y=11`
    - HP at battle start was `69 / 70`
    - auto-walk was manually stopped during battle, so `PATH_STATE` is now nil
      even though the runtime blocker set stayed at `count=20`
  - one more live pass after that Specter resolved kept the same story:
    - fresh field baseline survived as
      `POSITION map=0x1A x=11 y=11`,
      `RUNTIME_BLOCKS map=0x1A count=20`,
      `PATH_STATE target=nil map=0x1A runtime_count=20`
    - planner from that live stop gave
      `debug_pathfind_to:10,9` => `Path: 3 west, 3 north, 2 east, 1 south`
    - live `auto_walk:10,9` followed that route back through
      `(10,11) -> (9,11) -> seam-retry (8,11) -> (8,10) -> (8,9) -> seam-retry (8,8)`
      and again produced the same short seam-retry follow-up:
      `Path: 2 east, 1 south`
    - the contradiction at `(9,8).west` then strengthened again:
      - a fourth natural seam-retry from `(8,8)->RIGHT` blocked
      - seam memory is now
        `SEAM_OBSERVATION map=0x1A cell=(9,8) approach=west result=blocked blocked=4 moved=0 classification=blocked_only source=seam_retry_block`
    - this strongly suggests the teleported verifier result there is not
      reflecting normal live-arrival context
  - latest interruption state:
    - a Drollmagi battle started at `POSITION map=0x1A x=10 y=11`
    - HP at battle start was `70 / 70`
    - unlike the earlier manual stop, `PATH_STATE` still targets
      `Lower Stairs Down to B4` during this combat because autowalk itself was
      interrupted by battle rather than cancelled by command
  - tooling note for the next Lua reload:
    - `route_manager` now defers blocked seam observations for
      timing-suspect queued-route timeouts until the direct seam retry also
      fails, so successful timing retries no longer pollute seam memory with
      bogus `classification=noisy`
  - tooling note for the next Lua reload:
    - repeated-start `probe_edge_verify` now distinguishes a teleport-artifact
      pattern from ordinary `mixed` results when attempt 1 moves from the live
      start tile and later teleported retries only block with
      `blocked_despite_open_preview`; treat that future
      `classification=inconclusive_teleport_artifact` output as harness noise,
      not blocker evidence
  - latest live cleanup after the Drollmagi interruption:
    - battle resolved cleanly by log inspection with `+22 EXP`, `+85 GOLD`
    - resumed field baseline came back as
      `POSITION map=0x1A x=8 y=9`,
      `RUNTIME_BLOCKS map=0x1A count=20`,
      `PATH_STATE target=Lower Stairs Down to B4 ... runtime_count=20`
    - from that live stop, stale route temp blocks had polluted the planner:
      `debug_pathfind_to:10,9` and `debug_pathfind_to_skip_npcs:10,9` both
      returned `No path found` with `route_temp_blocks=3`
    - manual `stop_auto_walk` cleared the stale route context, and the same
      live planner immediately recovered:
      `debug_pathfind_to:10,9` => `Path: 1 north, 2 east, 1 south`
      with `route_temp_blocks=0`
    - follow-up `auto_walk:10,9` did not get fresh command consumption before
      the log went idle again, so the safest next live step is:
      1. manually reload `main.lua` in FCEUX
      2. re-baseline with `report_position`, `report_runtime_blocks`,
         `report_path_state`
      3. if still at or near `(8,9)`, rerun `debug_pathfind_to:10,9` then
         `auto_walk:10,9`
      4. if a future battle interrupts before reload, use `stop_auto_walk`
         before trusting later planner results
  - 2026-06-02 morning reload continuation:
    - fresh field heartbeat proved the new reload was alive at
      `POSITION map=0x1A x=8 y=7`,
      `RUNTIME_BLOCKS map=0x1A none`,
      `PATH_STATE target=nil map=0x1A runtime_count=0`
    - fresh direct verifier evidence from that same reload cleanly confirmed
      both:
      - `probe_edge_verify:8,7,RIGHT,5` => `(9,7).west` blocked
      - `probe_edge_verify:8,7,UP,5` => `(8,6).south` blocked
    - reseeding the full B3 blocker set plus `add_blocked_edge:6,11,UP` and
      the newly promoted `add_blocked_edge:8,7,UP` still reported
      `RUNTIME_BLOCKS map=0x1A count=20`, because those extra edges merged into
      existing cells `(6,10)` and `(8,6)` instead of creating new cells
    - fresh planner from live `(8,7)` then tightened to
      `debug_pathfind_to:10,9` => `Path: 1 south, 2 east, 1 south`
    - live `auto_walk:10,9` did useful natural-route harvesting before the
      next fight:
      - `(8,7)->DOWN` seam retry moved into `(8,8)`
      - `(8,8)->RIGHT` into `(9,8)` again failed as `blocked_only`, so the
        long-running contradiction at `(9,8).west` still stands and should not
        be promoted either way from teleported verify alone
      - the detour then exposed three more route-context-only blocked seams:
        `(7,10).south`, `(5,11).east`, and `(6,12).north`
      - reroute after that crossed row 11 cleanly through
        `(7,11) -> (8,11) -> (9,11) -> (10,11) -> (11,11)`
      - the next untouched frontier became `(11,11)->RIGHT` into `(12,11)`,
        but battle interrupted before the seam-retry result settled
    - current stop condition:
      - a Drollmagi battle started at `POSITION map=0x1A x=11 y=11`
      - HP at battle start was `70 / 70`
      - no follow-up route commands were queued into combat
  - 2026-06-02 post-Drollmagi continuation:
    - the suggested direct check cleaned up well:
      - `probe_edge_verify:11,11,RIGHT,5` fully confirmed
        `(12,11).west` passable with `attempts=6 moved=6 blocked=0
        classification=confirmed_passable stability_recheck=true`
    - planner from live `(12,11)` still routed back through the known center:
      - `debug_pathfind_to:10,9` => `Path: 4 west, 3 north, 2 east, 1 south`
      - live `auto_walk:10,9` followed that family and again re-entered the
        old `(8,8)` contradiction rather than exposing a new east-side bridge
    - that bounce did not reveal a code bug, but it did sharpen the west/lower
      pocket:
      - `probe_edge_verify:7,11,UP,5` cleanly confirmed `(7,10).south`
      - `probe_edge_verify:6,11,LEFT,5` came back
        `classification=inconclusive_teleport_artifact`, so `(5,11).east`
        should stay treated as likely passable, not promoted blocked
      - `probe_edge_verify:6,11,DOWN,5` cleanly confirmed `(6,12).north`
    - after promoting those clean blockers, the live runtime set rose to
      `RUNTIME_BLOCKS map=0x1A count=21`
    - fresh planner from live `(6,11)` finally shifted into a new route
      family:
      - `debug_pathfind_to:10,9` => `Path: 2 east, 3 north, 2 east, 1 south`
    - live `auto_walk:10,9` from that same stop followed the new route cleanly
      through `(7,11) -> (8,11) -> (8,10)` before a Wraith Knight battle
      interrupted the next north step
    - current stop condition:
      - a Wraith Knight battle started at `POSITION map=0x1A x=8 y=10`
      - HP at battle start was `63 / 70`
      - no further route commands were queued into combat
  - 2026-06-02 late-morning breakthrough on the `(9,8).west` contradiction:
    - after the Wraith Knight and a later Druinlord resolved, the live state
      cleanly survived at `POSITION map=0x1A x=9 y=11` with the full
      `RUNTIME_BLOCKS map=0x1A count=21`
    - `probe_edge_verify:9,11,DOWN,5` then cleanly confirmed `(9,12).north`
      as blocked, raising the runtime set to `count=22`
    - the best planner from that live stop still wanted to revisit `(8,8)`, so
      I settled the long-running contradiction with a natural-arrival test:
      - used `auto_walk:8,8` to reach `(8,8)` without teleport verifier state
      - from that live tile, a one-step `probe_edge:RIGHT` into `(9,8)` also
        blocked despite the open preview
      - this is the first non-teleport direct confirmation of the same
        behavior that autowalk had been reporting
    - based on that natural probe plus the repeated seam-retry failures, I
      promoted `add_blocked_edge:8,8,RIGHT`, which raised the runtime set to
      `RUNTIME_BLOCKS map=0x1A count=23`
    - that promotion materially changed the route:
      - from live `(8,8)`, `debug_pathfind_to:10,9` no longer gives the old
        short contradictory family
      - it now gives `Path: 4 south, 6 east, 3 north, 4 west`
    - live `auto_walk:10,9` under the 23-edge set then exposed a stronger
      lower strip on row 12:
      - `(13,12).north` strengthened to `blocked=3 moved=0`
      - `(12,12).north` strengthened to `blocked=3 moved=0`
      - `(11,12).north` strengthened to `blocked=2 moved=0`
      - `(10,12).north` was being tested when combat interrupted
    - current stop condition:
      - a battle started at `POSITION map=0x1A x=10 y=11`
      - HP at battle start was `65 / 70`
      - no follow-up route commands were queued into combat
  - 2026-06-02 noon row-12 strip closure and upper-left reroute:
    - the interrupted `(10,12).north` verifier finished cleanly after the
      battle:
      - `probe_edge_verify:10,11,DOWN,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:10,11,DOWN`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=24`
    - direct cleanup then closed four more south-strip seams:
      - `probe_edge_verify:11,11,DOWN,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:11,11,DOWN`
      - runtime set rose to `count=25`
      - `probe_edge_verify:13,11,DOWN,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:13,11,DOWN`
      - runtime set rose to `count=26`
      - `probe_edge_verify:12,11,DOWN,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:12,11,DOWN`
      - runtime set rose to `count=27`
      - `probe_edge_verify:8,11,DOWN,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:8,11,DOWN`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=28`
    - planner progression while those strip cells were being promoted:
      - from live `(10,11)`, after adding `(10,12).north`:
        `debug_pathfind_to:10,9` => `Path: 3 east, 1 south, 1 east, 3 north, 4 west`
      - from live `(11,11)`, after adding `(11,12).north`:
        `debug_pathfind_to:10,9` => `Path: 2 east, 1 south, 1 east, 3 north, 4 west`
      - from live `(13,11)`, after adding `(13,12).north`:
        `debug_pathfind_to:10,9` => `Path: 1 west, 1 south, 2 east, 3 north, 4 west`
      - from live `(12,11)`, after adding `(12,12).north`:
        `debug_pathfind_to:10,9` => `Path: 4 west, 1 south, 6 east, 3 north, 4 west`
      - from live `(8,11)`, after adding `(8,12).north`:
        `debug_pathfind_to:10,9` => `Path: 3 west, 5 north, 5 east, 3 south`
    - interpretation:
      - the lower/right row-12 south strip is now much cleaner, and the route
        is no longer preferring that pocket once `(8,12).north` through
        `(13,12).north` are all present
      - however, the new planner path `3 west, 5 north, 5 east, 3 south`
        appears to run back through the old upper-left pocket even though the
        runtime set already includes `(5,11).north`
      - treat that as a planner-vs-runtime contradiction to validate live
        after combat before promoting any new blocker from that branch
    - live continuation under the 28-edge set:
      - `auto_walk:10,9` from live `(8,11)` began the new upper-left detour
        and moved cleanly `(8,11) -> (7,11)`
      - it then hit a timing retry on `(7,11)->LEFT` into `(6,11)`, but that
        seam has already moved repeatedly from natural arrival and should not
        be treated as fresh blocker evidence
      - battle interrupted before the route reached the suspicious
        `(5,11)` / upper-left transition
    - current stop condition:
      - a Druinlord battle started at `POSITION map=0x1A x=7 y=11`
      - HP at battle start was `66 / 70`
      - no follow-up route commands were queued into combat
  - 2026-06-02 afternoon top-strip breakthrough after fresh B3 reset:
    - after the user refreshed at the inn and returned to B3, the live script
      came back at `POSITION map=0x1A x=2 y=17` with
      `RUNTIME_BLOCKS map=0x1A none`
    - re-seeding the proven runtime set restored `count=28`, but
      `debug_pathfind_to:10,9` from that southwest-side start returned
      `No path found`
    - the known bridge re-entry still works from the southwest side:
      - `debug_pathfind_to:3,14` => `Path: 1 north, 1 east, 2 north`
      - `auto_walk:3,14` reached `(3,14)` cleanly
      - `probe_edge_verify:3,14,RIGHT,5` again finished
        `moved=6 blocked=0 classification=suspect_passable_model_mismatch`
      - immediate follow-up `probe_edge:UP` from `(4,14)` again moved to
        `(4,13)`
    - from live bridged-side `(4,13)`, the planner no longer said
      `3 west, 5 north, 5 east, 3 south`; it shifted to
      `Path: 7 north, 6 east, 3 south`
    - autowalk on that bridged-side family found a stronger top-strip frontier:
      - clean natural movement reached `(4,6)`, then `(6,6)`, then the upper
        strip around `(9,4)` and `(8,3)`
      - route-context-only blocked seams strengthened at:
        - `(7,6).west` from `(6,6)->RIGHT`
        - `(7,5).north` from `(7,4)->DOWN`
        - `(9,3).south` from `(9,4)->UP`
        - `(9,3).west` from `(8,3)->RIGHT`
        - `(6,2).south` from `(6,3)->UP`
        - `(5,3).east` from `(6,3)->LEFT`
    - the two top-left seams cleaned up under direct verification:
      - `probe_edge_verify:6,3,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:6,3,LEFT`
      - `probe_edge_verify:6,3,UP,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:6,3,UP`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=30`
    - those two promotions materially shortened the route:
      - from live `(6,3)`, `debug_pathfind_to:10,9` changed to
        `Path: 3 south, 4 east, 3 south`
    - live continuation under the 30-edge set:
      - `auto_walk:10,9` began following that shorter family cleanly
      - moved `(6,3) -> (6,4) -> (6,5)` before a Specter battle interrupted
        the next down-step seam into `(6,6)`
      - that interrupted `(6,5)->DOWN` retry should not be promoted as blocker
        evidence; earlier live route evidence already moved through `(6,6)`
    - current stop condition:
      - a Specter battle started at `POSITION map=0x1A x=6 y=5`
      - HP at battle start was `70 / 70`
      - no follow-up route commands were queued into combat
  - 2026-06-02 later-afternoon bridged-side cleanup near `(4,6)`:
    - the shorter bridged-side family from `(6,3)` remained valid, but the
      first new left/top-pocket candidate partially self-disproved:
      - `probe_edge_verify:4,6,UP,5` finished
        `moved=6 blocked=0 classification=confirmed_passable`
      - so `(4,5).south` should not be promoted; that earlier route-context
        seam was noise
    - the sibling west seam did hold:
      - `probe_edge_verify:4,6,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,6,LEFT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=31`
      - from live `(4,6)`, planner tightened to `Path: 6 east, 3 south`
    - live autowalk on that shorter route re-exposed two stronger top-strip
      seams:
      - `(6,6)->RIGHT` into `(7,6)` reached `blocked=6 moved=0`
      - `(7,4)->DOWN` into `(7,5)` reached `blocked=8 moved=0`
    - direct verifier cleanup confirmed one of that pair:
      - `probe_edge_verify:6,6,RIGHT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:6,6,RIGHT`
      - `probe_edge_verify:6,5,RIGHT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:6,5,RIGHT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=32`
    - route effect:
      - from live `(6,5)`, planner became
        `Path: 1 north, 1 east, 2 south, 3 east, 3 south`
      - the follow-up autowalk kept that family alive and reached the upper
        corner around `(8,3)` before battle
      - `probe_edge_verify:6,5,RIGHT,5` means `(7,5)` is now blocked from both
        east and west, but `(7,5).north` is still only route-context evidence
    - current strongest unresolved candidates:
      - `(7,5).north` from repeated `(7,4)->DOWN` seam retries
      - the two-sided `(9,3)` seam, which has route-context blocked evidence
        from both south and west but is not yet directly verified
    - no code patch was needed in this pass:
      - temp blocks kept clearing when seams moved, so this looked like map
        evidence rather than a stale-route or harness bug
    - current stop condition:
      - a Drollmagi battle started at `POSITION map=0x1A x=8 y=3`
      - no follow-up route commands were queued into combat
  - 2026-06-02 late-afternoon normalization retest at `(4,6)`:
    - the old `probe_edge_verify:4,6,UP,5 => confirmed_passable` result did
      not survive a fresh normalized control check after the full script reload
    - fresh live/raw A/B from `B3 (4,6)`:
      - direct `probe_edge:UP` returned
        `status=blocked ... kind=blocked_despite_open_preview`
      - rerun `probe_edge_verify:4,6,UP,5` returned
        `moved=0 blocked=5 classification=confirmed_blocked`
      - fresh `teleport_to:4,6` plus `simulate_raw_input:UP,90` still left the
        hero at `(4,6)`; `report_coords` showed
        `raw003C_0043=7F 90 04 CB 96 91 04 05`
    - interpretation:
      - treat the earlier passable result as stale-state contamination, not as
        durable B3 map truth
      - `(4,5).south` is now safe to promote under the current normalized raw
        control evidence
    - promotion:
      - injected with `add_blocked_edge:4,6,UP`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=33`
    - route effect:
      - from live `(4,6)`, `debug_pathfind_to:10,9` changed to
        `Path: 2 east, 2 north, 1 east, 2 south, 3 east, 3 south`
      - `auto_walk:10,9` followed that new family and moved cleanly
        `(4,6)->(5,6)->(6,6)`
      - the next queued step, `(6,6)->UP` into `(6,5)`, hit a timing retry,
        but battle interrupted before the seam retry could resolve
    - current stop condition:
      - a Wolflord battle started at `POSITION map=0x1A x=6 y=6`
      - HP at battle start was `66 / 70`
      - no follow-up route commands were queued into combat
  - 2026-06-02 late-afternoon lower-left continuation from `(4,11)`:
    - after the Wolflord, the live baseline held:
      - `POSITION map=0x1A(Garin's Grave B3) x=4 y=11`
      - `RUNTIME_BLOCKS map=0x1A count=33`
    - fresh planner from the battle-stop side:
      - `debug_pathfind_to:10,9` =>
        `Path: 1 south, 10 east, 3 north, 4 west`
    - live autowalk clarified the lower-left pocket:
      - `(4,11)->DOWN` into `(4,12)` succeeded on seam retry
      - `SEAM_OBSERVATION cell=(4,12) approach=north result=moved`
      - the straight row-12 east seam did not hold:
        - `(4,12)->RIGHT` into `(5,12)` failed on seam retry
        - strengthened to `blocked=3 moved=0 classification=blocked_only`
      - reroute then pushed one tile deeper:
        - `(4,12)->DOWN` into `(4,13)` succeeded on seam retry
        - `SEAM_OBSERVATION cell=(4,13) approach=north result=moved`
      - the sibling row-13 east seam also failed:
        - `(4,13)->RIGHT` into `(5,13)` failed on seam retry
        - strengthened to `blocked=3 moved=0 classification=blocked_only`
    - route effect:
      - after `(5,12).west` and `(5,13).west` strengthened, the planner pivoted
        to `Path: 7 north, 2 east, 2 north, 1 east, 2 south, 3 east, 3 south`
      - that reroute walked cleanly back up the left column
        `(4,13) -> (4,12) -> (4,11) -> (4,10) -> (4,9) -> (4,8) -> (4,7) -> (4,6)`
      - from live `(4,6)`, the route snapped back to the shorter family:
        `Path: 2 east, 2 north, 1 east, 2 south, 3 east, 3 south`
    - interpretation:
      - `(4,12)` and `(4,13)` are now cleanly live-passable from the north side
      - the strongest new unresolved seams are `(5,12).west` and `(5,13).west`
      - both are still route-context-only and should be directly verified before
        promotion
    - current stop condition:
      - a Specter battle started at `POSITION map=0x1A x=4 y=6`
      - HP at battle start was `70 / 70`
      - no follow-up route commands were queued into combat
  - 2026-06-02 late-afternoon verifier cleanup after the lower-left pocket:
    - direct cleanup of the two fresh lower-left seams split cleanly:
      - `probe_edge_verify:4,12,RIGHT,5` stayed mixed and is not safe to
        promote
      - final result was
        `moved=2 blocked=3 classification=inconclusive_teleport_artifact`
      - `probe_edge_verify:4,13,RIGHT,5` was clean
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,13,RIGHT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=34`
    - that promotion flushed the top-strip route-context family back into
      direct verifier cleanup:
      - `probe_edge_verify:7,4,DOWN,5` =>
        `moved=6 blocked=0 classification=confirmed_passable`
      - this disproves `(7,5).north` as a blocker despite the repeated live
        blocked-only route counts there
      - `probe_edge_verify:9,4,UP,5` =>
        `moved=6 blocked=0 classification=confirmed_passable`
      - this likewise disproves `(9,3).south` as a blocker; the old live
        blocked-only counts on `(9,3)` are route-context noise
      - `probe_edge_verify:6,4,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:6,4,LEFT`
      - runtime set rose to `count=35`
      - `probe_edge_verify:6,5,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:6,5,LEFT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=36`
    - route effect:
      - after `(5,4).east` was promoted, `debug_pathfind_to:10,9` from live
        `(6,4)` shortened to `Path: 1 east, 2 south, 3 east, 3 south`
      - after `(5,5).east` was promoted, `debug_pathfind_to:10,9` from live
        `(6,5)` became `Path: 1 north, 1 east, 2 south, 3 east, 3 south`
      - the follow-up autowalk immediately seam-retried back through `(6,4)`,
        so the active short family remains the 9-step route from live `(6,4)`
    - interpretation:
      - the current top-strip route-context family was partly misleading:
        `(7,5).north` and `(9,3).south` were false leads under direct verify
      - the real durable blockers in that family were the sibling west/east
        entries `(5,4).east` and `(5,5).east`
      - `(4,12)->RIGHT` remains unresolved and should stay unpromoted until it
        can be settled by a non-teleport/live method
    - current stop condition:
      - a Drollmagi battle started at `POSITION map=0x1A x=6 y=4`
      - HP at battle start was `70 / 70`
      - no follow-up route commands were queued into combat
  - 2026-06-02 evening live rechecks overturned two old false-passable reads:
    - first live contradiction cleanup around `(7,4)->DOWN`:
      - natural `probe_edge:DOWN` from live `(7,4)` blocked
      - `simulate_raw_input:DOWN,90` from live `(7,4)` also stayed put
      - fresh `probe_edge_verify:7,4,DOWN,5` then came back clean
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:7,4,DOWN`
      - this adds `(7,5).north` to the runtime set and overturns the older
        stale passable read from the earlier top-strip cleanup
      - runtime set stayed at `count=37` because `(7,5)` already existed with
        `east,west`
    - route effect after `(7,5).north` promotion:
      - `debug_pathfind_to:10,9` from live `(7,4)` changed to
        `Path: 2 east, 1 north, 1 east, 6 south`
      - the follow-up autowalk routed through `(9,4)` and exposed a fresh
        clean upper-right seam at `(8,3)->RIGHT` into `(9,3)`
    - lower-left natural seam cleanup also settled:
      - a live `probe_edge:DOWN` from `(4,10)` moved cleanly into `(4,11)`
      - this disproves the interrupted seam-retry there as blocker evidence
      - repeated natural route attempts then made `(4,12)->RIGHT` into
        `(5,12)` come back as a clean `blocked_only` seam twice
      - fresh `probe_edge_verify:4,12,RIGHT,5` finally settled it cleanly:
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,12,RIGHT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=38`
    - top-strip west-side seam then settled cleanly too:
      - natural autowalk repeatedly hit `(8,3)->RIGHT` into `(9,3)` as
        `blocked_only`
      - fresh `probe_edge_verify:8,3,RIGHT,5` returned
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:8,3,RIGHT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=39`
    - route effects after the new promotions:
      - after `(5,12).west`, the planner from live `(4,12)` changed to
        `Path: 6 north, 2 east, 3 north, 4 east, 6 south`
      - after `(9,3).west`, the planner from live `(8,3)` collapsed further
        to `Path: 1 south, 1 east, 1 north, 1 east, 6 south`
      - current active stubborn seam is again `(9,4)->UP` into `(9,3)`, but
        now only from the south approach; west approach is confirmed blocked
    - interpretation:
      - the old direct-passable reads on `(7,5).north` and `(5,12).west` were
        stale-state contamination, not durable truth
      - `(9,3)` is now asymmetric in a useful way:
        west approach is confirmed blocked, while south approach remains noisy
      - the runtime B3 set is now materially stronger at `count=39`
    - final clean-field baseline after the Drollmagi:
      - `POSITION: map=0x1A(Garin's Grave B3) x=8 y=4`
      - `RUNTIME_BLOCKS map=0x1A count=39`
      - `PATH_STATE target=nil map=0x1A runtime_count=39`
      - no follow-up movement was queued after the post-fight baseline
  - 2026-06-02 late-evening natural re-approach to `(9,4)` after mixed verifier:
    - the user-reported mixed result was the expected `probe_edge_verify:9,4,UP,5`
      teleport artifact:
      - `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
      - do not promote `(9,3).south` from that verifier
    - after stopping the bouncing route, the clean baseline was:
      - `POSITION: map=0x1A(Garin's Grave B3) x=4 y=12`
      - `RUNTIME_BLOCKS map=0x1A count=39`
      - `PATH_STATE target=nil map=0x1A runtime_count=39`
    - the huge left-column detour was temp-block noise, not new runtime truth:
      - `stop_auto_walk` dropped the route-temp pollution cleanly
      - fresh `debug_pathfind_to:10,9` from `(4,12)` recovered a stable
        no-temp route:
        `Path: 6 north, 2 east, 2 north, 3 east, 1 north, 1 east, 6 south`
    - most important new confirmation:
      - a natural non-teleport route to `(9,4)` is now proven clean
      - `debug_pathfind_to:9,4` from `(4,12)` =>
        `Path: 6 north, 2 east, 2 north, 3 east`
      - `auto_walk:9,4` then rebuilt that route cleanly through:
        `(4,12) -> (4,6) -> (6,6) -> (6,4) -> (8,4) -> (9,4)`
      - every seam retry on that approach cleared behind itself; no new durable
        blocker emerged during the re-approach
    - current stop condition:
      - a Specter battle started immediately after arrival at
        `POSITION map=0x1A x=9 y=4`
      - HP at battle start was `66 / 70`
      - MP at battle start was `27 / 57`
      - autowalk target was only `Tile 9,4`; no north probe was queued yet
  - 2026-06-02 late-evening natural south-approach cleanup plus left-column promotions:
    - after the Specter, the noisy south approach to `(9,3)` was settled with
      natural controls instead of another teleport-heavy verifier:
      - live `probe_edge:UP` from `(9,4)` blocked at `(9,4)`
      - live `simulate_raw_input:UP,90` from `(9,4)` also stayed at `(9,4)`
      - treat the older direct-passable read on `(9,4)->UP` as stale-state
        contamination under the current normalized control evidence
      - promoted with `add_blocked_edge:9,4,UP`
      - runtime set stayed at `RUNTIME_BLOCKS map=0x1A count=39` because
        `(9,3)` already existed with `west`
    - that promotion rerouted the planner into a tighter left-side knot around
      `(5,6)`:
      - route evidence there repeatedly hit `(5,6)->UP` into `(5,5)` and
        `(5,6)->DOWN` into `(5,7)` as `blocked_only`
      - live `probe_edge:UP` from `(5,6)` blocked and
        `simulate_raw_input:UP,90` also stayed at `(5,6)`
      - promoted with `add_blocked_edge:5,6,UP`
      - live `probe_edge:DOWN` from `(5,6)` blocked and
        `simulate_raw_input:DOWN,90` also stayed at `(5,6)`
      - promoted with `add_blocked_edge:5,6,DOWN`
      - runtime set still stayed at `count=39` because those additions merged
        into existing cells `(5,5)` and `(5,7)`
    - the strengthened `(5,6)` model exposed a new clean left-column sibling
      family:
      - natural autowalk strengthened `(4,8)->LEFT` into `(3,8)` and
        `(4,7)->LEFT` into `(3,7)` as `blocked_only`
      - `probe_edge_verify:4,8,LEFT,5` then returned
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,8,LEFT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=40`
      - `probe_edge_verify:4,7,LEFT,5` returned
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,7,LEFT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=41`
    - latest clean-field baseline:
      - `POSITION: map=0x1A(Garin's Grave B3) x=4 y=7`
      - `RUNTIME_BLOCKS map=0x1A count=41`
      - `PATH_STATE target=nil map=0x1A runtime_count=41`
    - latest planner snapshot from live `(4,7)`:
      - `debug_pathfind_to:10,9` =>
        `Path: 2 south, 1 west, 4 north, 2 east, 4 north, 5 east, 8 south`
      - this points to the next sibling check being the same left-column family
        one tile lower, not a return to the old `(9,4)->UP` ambiguity
  - 2026-06-02 late-evening left-column strip closure and hidden-bridge pivot:
    - the left-column sibling family kept confirming cleanly under direct
      verifier checks:
      - `probe_edge_verify:4,9,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,9,LEFT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=42`
      - `probe_edge_verify:4,10,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,10,LEFT`
      - runtime set rose to `count=43`
      - `probe_edge_verify:4,11,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,11,LEFT`
      - runtime set rose to `count=44`
      - `probe_edge_verify:4,12,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,12,LEFT`
      - runtime set rose to `count=45`
      - `probe_edge_verify:4,13,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,13,LEFT`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=46`
    - critical route effect:
      - after `(3,13).east` was added, the planner from live `(4,13)` finally
        collapsed:
        `debug_pathfind_to:10,9` => `No path found [no_path] (visited=33 path=0)`
      - `debug_pathfind_to_skip_npcs:10,9` matched exactly with
        `No path found`, and `npc_count=0`, so this is not an NPC-mode artifact
    - important follow-up interpretation:
      - the current entrance-side reachable component is now sealed under the
        46-edge runtime model
      - however, `debug_route_frontier_skip_npcs:10,9` still found useful
        bridge candidates instead of a dead-empty frontier:
        - rank 1 hidden bridge candidate:
          `(8,3)->UP` with `hidden_exit=up:(8,1)`
        - rank 2 hidden bridge candidate:
          `(7,3)->UP` with `hidden_exit=up:(7,1)`
      - the best non-hidden frontier after those remains the blocked-runtime
        family around `(9,5)`, `(8,5)`, `(9,4)`, and `(6,6..9)->RIGHT`, but
        the hidden-bridge pair is the cleaner pivot
    - live pivot toward the best hidden-bridge candidate:
      - `debug_pathfind_to:8,3` from `(4,13)` recovered a clean route:
        `Path: 7 north, 2 east, 3 north, 2 east`
      - `auto_walk:8,3` began following that route cleanly back up through
        `(4,12) -> (4,11) -> (4,10) -> (4,9) -> (4,8) -> (4,7)`
      - a timing retry on `(4,7)->UP` into `(4,6)` was interrupted by battle
        before seam retry could resolve
    - current stop condition:
      - a Wolflord battle started at
        `POSITION map=0x1A(Garin's Grave B3) x=4 y=7`
      - HP at battle start was `70 / 70`
      - MP at battle start was `23 / 57`
      - autowalk target was `Tile 8,3`
      - no follow-up movement was queued into combat
  - 2026-06-02 night pass after the hidden-bridge probes:
    - the first frontier-ranked hidden bridge at `(8,3)->UP` is now settled as
      a hard live block, not a viable bridge:
      - natural `probe_edge:UP` from live `(8,3)` blocked with
        `tile=1 base_walkable=false`
      - `simulate_raw_input:UP,90` from `(8,3)` stayed put
    - the sibling hidden-bridge family also failed under natural controls:
      - `probe_edge:LEFT` from `(8,3)` into `(7,3)` blocked despite an open
        preview (`blocked_despite_open_preview`)
      - `simulate_raw_input:LEFT,90` from `(8,3)` also stayed at `(8,3)`
      - natural route to `(7,4)` succeeded, but `probe_edge:UP` from `(7,4)`
        into `(7,3)` blocked with the same open-preview mismatch
      - `simulate_raw_input:UP,90` from `(7,4)` also stayed at `(7,4)`
      - promoted as runtime edges:
        - `add_blocked_edge:8,3,UP`
        - `add_blocked_edge:8,3,LEFT`
        - `add_blocked_edge:7,4,UP`
      - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=48`
    - important tooling note:
      - `debug_route_frontier_skip_npcs:10,9` still lists those two
        hidden-bridge candidates because they are frontier/not-walkable
        candidates rather than ordinary runtime-block edges
      - for current reasoning, treat `(8,3)->UP` and `(7,4)->UP` as known dead
        despite their continued presence in the frontier report
    - upper-right pocket sanity checks all matched the current runtime model:
      - live route to `(9,5)` remained clean
      - `probe_edge:DOWN` from `(9,5)` into `(9,6)` blocked exactly as modeled
      - `probe_edge:RIGHT` from `(9,5)` into `(10,5)` blocked exactly as modeled
      - route to `(8,5)` remained clean
      - `probe_edge:DOWN` from `(8,5)` into `(8,6)` blocked exactly as modeled
    - near-target left-family sanity checks also matched runtime:
      - route to `(6,6)` remained clean
      - `probe_edge:RIGHT` from `(6,6)` into `(7,6)` blocked exactly as modeled
      - route to `(6,9)` remained clean
      - `probe_edge:RIGHT` from `(6,9)` into `(7,9)` blocked exactly as modeled
      - `probe_edge:DOWN` from `(6,9)` into `(6,10)` blocked exactly as modeled
    - newest unresolved local lead:
      - route toward `(5,10)` stayed reachable from the west side
      - on the way there, seam retry produced the first live blocker evidence at
        `(5,9)->DOWN` into `(5,10)`:
        `SEAM_OBSERVATION cell=(5,10) approach=north result=blocked blocked=1 moved=0 classification=blocked_only`
      - battle interrupted before a direct natural cleanup could settle whether
        `(5,10).north` is a real blocker
    - current stop condition:
      - a battle started at
        `POSITION map=0x1A(Garin's Grave B3) x=4 y=9`
      - HP at battle start was `70 / 70`
      - MP at battle start was `23 / 57`
      - queued autowalk target was `Tile 5,10`
      - no follow-up movement was queued into combat
  - late-night continuation after the `5,10` cleanup:
    - `(5,10)` is now closed from both reachable sides under natural checks:
      - `probe_edge:DOWN` from `(5,9)` blocked despite an open preview, and
        `simulate_raw_input:DOWN,90` also stayed at `(5,9)`
      - promoted with `add_blocked_edge:5,9,DOWN`
      - reroute through `(4,9)->DOWN` succeeded cleanly, but the next step
        `(4,10)->RIGHT` into `(5,10)` failed
      - natural `probe_edge:RIGHT` from `(4,10)` also blocked with
        `runtime_directional_blocked=true`
      - `simulate_raw_input:RIGHT,90` from `(4,10)` stayed at `(4,10)`
      - promoted with `add_blocked_edge:4,10,RIGHT`
      - runtime set stayed at `RUNTIME_BLOCKS map=0x1A count=49` because both
        new edges merged into existing blocker cell `(5,10)`
    - the later pivot back toward `(7,3)->UP` exposed a better final seam one
      tile earlier:
      - post-battle baseline at `POSITION map=0x1A(Garin's Grave B3) x=5 y=6`
        still had `PATH_STATE target=nil map=0x1A runtime_count=49`
      - `debug_pathfind_to:7,3` then found `Path: 1 east, 3 north, 1 east`
      - autowalk reached `(6,3)` cleanly, but the final step
        `(6,3)->RIGHT` into `(7,3)` failed repeatedly
      - seam evidence there reached
        `blocked=5 moved=0 classification=blocked_only`
      - natural `probe_edge:RIGHT` from `(6,3)` also blocked with
        `directional_blocked=true`
      - `simulate_raw_input:RIGHT,90` from `(6,3)` stayed at `(6,3)`
      - promoted with `add_blocked_edge:6,3,RIGHT`
      - runtime set still stayed at `count=49` because `(7,3).west` merged
        into existing blocker cell `(7,3)` which already had `east,south`
    - planner/frontier state after the top-strip closure:
      - from live `(6,3)`, `debug_pathfind_to:10,9` still returned
        `No path found [no_path] (visited=25 path=0)`
      - `debug_route_frontier_skip_npcs:10,9` tightened to
        `reachable=25 target_reachable=false bridge_candidates=32 hidden_bridge_candidates=1`
      - the only remaining hidden-bridge candidate is now `(8,3)->UP`, even
        though that exact edge is already runtime-blocked and experimentally
        dead
    - tooling follow-up:
      - added `route_frontier_classifier.lua` plus
        `test_route_frontier_classifier.lua`
      - patched `run_debug_route_frontier` so a not-walkable candidate that is
        already blocked by runtime/directional evidence keeps that block reason
        and is no longer treated as a hidden-bridge candidate
      - FCEUX still needs a manual `main.lua` reload before the live frontier
        output will reflect that fix
  - post-reload live verification of the frontier patch:
    - manual FCEUX reload succeeded; fresh baseline from live `(6,3)` came back
      on `map=0x1A`
    - first reseed attempt exposed a handoff-list omission:
      - the documented reseed batch only rebuilt `runtime_count=47`
      - that incomplete runtime set falsely reopened the planner and brought
        back hidden-bridge-looking frontier entries around `(7,2)`
      - the missing directions were:
        - `(5,5).east` via `add_blocked_edge:6,5,LEFT`
        - `(5,7).west` via `add_blocked_edge:4,7,RIGHT`
      - after adding those two missing edges, the live runtime set returned to
        `RUNTIME_BLOCKS map=0x1A count=49`
    - with the full 49-edge set restored, the live frontier fix behaved as
      intended:
      - `debug_pathfind_to:10,9` from `(6,3)` again returned
        `No path found [no_path] (visited=25 path=0)`
      - `debug_route_frontier_skip_npcs:10,9` now reports
        `reachable=25 target_reachable=false bridge_candidates=31 hidden_bridge_candidates=0`
      - the old fake hidden-bridge `(8,3)->UP` no longer ranks as
        `hidden_bridge=true`
    - current top-ranked frontier family is now plain runtime-block evidence:
      - rank 1: `(9,5)->DOWN`
      - rank 2: `(9,5)->RIGHT`
      - rank 3: `(8,5)->DOWN`
    - live spot-checks after the reload all matched the current model exactly:
      - natural `probe_edge:DOWN` from `(9,5)` blocked cleanly with
        `directional_blocked=true approach_blocked=true effective_passable=false`
      - natural `probe_edge:RIGHT` from `(9,5)` blocked with the same clean
        runtime-backed shape
      - `auto_walk:8,5` moved cleanly from `(9,5)` to `(8,5)`
      - natural `probe_edge:DOWN` from `(8,5)` into `(8,6)` also blocked
        cleanly with `directional_blocked=true`
    - working conclusion after the reload:
      - the frontier-report ghost bridge issue is fixed live
      - B3 currently looks model-consistent under the full runtime set, and
        there is no obvious next local seam worth promoting from the present
        component

## Resume Plan

1. Keep `auto_step_reset_movement_on_route_turn_settle=false` for now.
2. If the session reset, re-establish the field baseline with `report_position`,
   `report_runtime_blocks`, and `report_path_state`.
3. If needed, re-cross the hidden bridge with `probe_edge_verify:3,14,RIGHT,5`
   and `probe_edge:UP`, because that is now the working entry into the upper
   pocket.
4. Re-seed the current runtime set above the bridge if the session reset:
   `add_blocked_edge:6,7,RIGHT`, `add_blocked_edge:6,8,RIGHT`,
   `add_blocked_edge:6,9,RIGHT`, `add_blocked_edge:4,11,RIGHT`,
   `add_blocked_edge:5,10,RIGHT`, `add_blocked_edge:5,10,DOWN`,
   `add_blocked_edge:6,9,DOWN`, `add_blocked_edge:9,4,RIGHT`,
   `add_blocked_edge:9,5,DOWN`, `add_blocked_edge:9,5,RIGHT`,
   `add_blocked_edge:8,5,DOWN`, `add_blocked_edge:8,5,LEFT`,
   `add_blocked_edge:8,10,RIGHT`, `add_blocked_edge:8,9,RIGHT`,
   `add_blocked_edge:8,7,LEFT`, `add_blocked_edge:8,8,LEFT`,
   `add_blocked_edge:8,9,LEFT`,
   `add_blocked_edge:8,10,LEFT`,
   `add_blocked_edge:9,11,UP`,
   `add_blocked_edge:10,11,UP`, `add_blocked_edge:11,11,UP`,
   `add_blocked_edge:12,11,UP`,
   `add_blocked_edge:13,10,UP`, `add_blocked_edge:13,10,LEFT`,
   `add_blocked_edge:13,10,RIGHT`, `add_blocked_edge:13,11,RIGHT`,
   `add_blocked_edge:8,7,RIGHT`, `add_blocked_edge:6,11,UP`,
   `add_blocked_edge:8,7,UP`, `add_blocked_edge:7,11,UP`,
   `add_blocked_edge:6,11,DOWN`, `add_blocked_edge:8,11,DOWN`,
   `add_blocked_edge:9,11,DOWN`, `add_blocked_edge:10,11,DOWN`,
   `add_blocked_edge:11,11,DOWN`, `add_blocked_edge:12,11,DOWN`,
   `add_blocked_edge:13,11,DOWN`, `add_blocked_edge:8,8,RIGHT`,
   `add_blocked_edge:6,3,LEFT`, `add_blocked_edge:6,3,UP`,
   `add_blocked_edge:8,3,RIGHT`,
   `add_blocked_edge:4,6,LEFT`, `add_blocked_edge:6,6,RIGHT`,
   `add_blocked_edge:6,5,RIGHT`, `add_blocked_edge:4,6,UP`,
   `add_blocked_edge:7,4,DOWN`, `add_blocked_edge:4,12,RIGHT`,
   `add_blocked_edge:9,4,UP`,
   `add_blocked_edge:5,6,UP`, `add_blocked_edge:5,6,DOWN`,
   `add_blocked_edge:4,8,LEFT`, `add_blocked_edge:4,7,LEFT`,
   `add_blocked_edge:4,9,LEFT`, `add_blocked_edge:4,10,LEFT`,
   `add_blocked_edge:4,11,LEFT`, `add_blocked_edge:4,12,LEFT`,
   `add_blocked_edge:4,13,LEFT`,
   `add_blocked_edge:8,3,UP`, `add_blocked_edge:8,3,LEFT`,
   `add_blocked_edge:7,4,UP`,
   `add_blocked_edge:5,9,DOWN`, `add_blocked_edge:4,10,RIGHT`,
   `add_blocked_edge:6,3,RIGHT`,
   `add_blocked_edge:6,5,LEFT`, `add_blocked_edge:4,7,RIGHT`.
5. After clearing the current fight, re-baseline immediately with
   `report_position`, `report_runtime_blocks`, and `report_path_state`.
6. If `RUNTIME_BLOCKS map=0x1A` comes back empty again, re-seed the current B3
   runtime set from step 4.
7. If the `count=49` runtime set survived, confirm the live stop before moving
   on:
   - expected battle-stop baseline is
     `POSITION: map=0x1A(Garin's Grave B3) x=6 y=3`
     `PATH_STATE target=nil map=0x1A runtime_count=49`
8. Do not return to `auto_walk:10,9` first; under the current 49-edge
   model both normal and skip-NPC planners already return `No path found`.
9. Treat `(8,3)->UP` as experimentally dead for current reasoning. If the
   live frontier report still ranks it after reload, that is tooling drift
   rather than fresh map evidence.
10. The frontier patch is now live-verified after reload, so do not spend more
    time challenging `(8,3)->UP`; it is no longer a valid ranked hidden bridge.
11. If you want one more local sanity pass from the current component, the top
    live runtime frontiers are:
    - `(9,5)->DOWN`
    - `(9,5)->RIGHT`
    - `(8,5)->DOWN`
    All three were re-checked after reload and blocked cleanly.
12. Treat B3 as effectively model-consistent under the current runtime set and
    pivot to a broader architectural/pathfinding rethink instead of more blind
    seam hunting from this side unless new contradictory live evidence appears.

## Verification Anchors

- `test_map_reader.lua` covers the current Garin's Grave B2/B3 directional seam
  model.
- `test_auto_step.lua` covers the final-settle toggle fix.
- `test_route_frontier_classifier.lua` covers the hidden-bridge frontier filter
  fix for already-blocked not-walkable edges.
- Latest relevant checks that were passing before wrap-up:
  - `lua5.1 test_map_reader.lua`
  - `lua5.1 test_auto_step.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `luac5.1 -p auto_step.lua test_auto_step.lua`
