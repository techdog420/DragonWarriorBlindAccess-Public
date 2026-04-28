# Handoff 2026-04-24 — Movement A/B targeted checks

## What happened

After reloading the full FCEUX Lua script with the new `auto_step` timing
instrumentation, the targeted throne-room stairs survey was rerun from `(17,5)`.

Fresh log header:

```text
Started: 2026-04-24 16:29:08
```

Setup:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
```

Confirmed:

```text
POSITION: map=0x04(Tantegel Castle) x=17 y=5
```

Target:

```bash
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

## Baseline: inject limit 12

Planner still found the 19-step route:

```text
pathfind chosen adj=(2,1) path=2 north, 2 west, 1 north, 7 west, 1 north, 6 west
```

New timing logs showed normal route steps completing, while x=15 left-entry
attempts exhausted the full timeout/retry cycle:

```text
auto_step complete dir=up from=(17,5) to=(17,4) frames=19 timeout_retries=1 turn_represses=1 inject_limit=12 queued_route=true
auto_step complete dir=up from=(17,4) to=(17,3) frames=28 timeout_retries=1 turn_represses=1 inject_limit=12 queued_route=true
auto_step complete dir=left from=(17,3) to=(16,3) frames=18 timeout_retries=3 turn_represses=1 inject_limit=12 queued_route=true
auto_step blocked dir=left from=(16,3) frames=60 timeout_retries=3/3 turn_represses=1 inject_limit=12 queued_route=true timeout=60
auto_step blocked dir=left from=(16,2) frames=60 timeout_retries=3/3 turn_represses=1 inject_limit=12 queued_route=true timeout=60
auto_step blocked dir=left from=(16,1) frames=60 timeout_retries=3/3 turn_represses=1 inject_limit=12 queued_route=true timeout=60
```

Final baseline result:

```text
SURVEY_RESULT ... path_found=true path_length=19 movement_succeeded=false final=(16,3) failure_class=command_timing_or_state_issue blocked_events=9 suspected_tiles=15,3|15,2|15,1 ... reason=reroute_no_path
```

Interpretation:

- baseline confirms the issue is seam-specific, not a general failure to move
- normal route moves complete with the same timing settings
- x=15 left-entry seams exhaust every retry at `inject_limit=12`

## A/B: inject limit 24

Changed:

```ini
auto_step_inject_limit=24
```

Then ran:

```bash
./dw_commands.sh --replace reload_config freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

Result:

- longer injection did **not** solve x=15 left-entry blocks
- x=15 left entries still exhausted `frames=60 timeout_retries=3/3`
- the longer hold introduced overshoot/chaining risk

Key overshoot evidence:

```text
auto_step begin_step dir=up from=(17,5) ... inject_limit=24
auto_step complete dir=up from=(17,5) to=(17,4) frames=3 ...
auto_step begin_step dir=up from=(17,3) ... inject_limit=24
```

The second queued step began from `(17,3)` instead of `(17,4)`, meaning the
longer press carried through an extra tile before the queued route advanced.

The A/B survey was manually stopped after repeated x=15 failures:

```text
SURVEY_RESULT run=2 ... path_found=true path_length=19 movement_succeeded=false final=(16,3) failure_class=suspected_engine_blocked_tile blocked_events=15 suspected_tiles=15,2|15,1|15,3 ... reason=manual_stop
```

After the A/B:

- `auto_step_inject_limit` was restored to `12`
- `reload_config` succeeded
- runtime blocks and seam memory were cleared
- `report_path_state` showed `runtime_count=0`

## Interpretation

The simple "hold longer" hypothesis is not supported:

- raw `LEFT,90` from `(16,3)` previously failed
- `auto_step_inject_limit=24` failed x=15 and caused overshoot
- normal non-x=15 movements already complete under the default timing

The remaining likely causes are:

- x=15 east-entry is a real engine barrier in this state
- hidden state after teleport/direct probe previously made it appear passable
- path execution is missing hidden state that affects collision, such as facing,
  subtile offset, scroll/camera state, or room/zone state

## Recommended next step

Do not globally increase `auto_step_inject_limit`.

Next investigation should target hidden state around direct probes versus routed
movement:

1. Add/identify a diagnostic for player facing/subtile/movement state bytes.
2. Compare `report_coords`/raw RAM before a direct probe that moves and before
   a route/probe that blocks.
3. Consider whether `teleport_to` needs to normalize more movement-related RAM
   than just `PLAYER_X`/`PLAYER_Y`.
