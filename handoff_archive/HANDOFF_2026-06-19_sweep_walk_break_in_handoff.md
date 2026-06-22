# Sweep Walk Break-In Handoff

Created: 2026-06-19
Archived: 2026-06-21

Status: historical evidence. The break-in continued after this note. Current
state is summarized in `session_handoff.md` and
`work_notes/current_investigation.md`. The original resume plan below was
deferred after field validation: random encounters now stop `sweep_walk`
gracefully, and a new sweep should be started manually after battle control
returns unless future play proves resume support is needed.

## Why This Exists

The teleport-backed `sweep_map` path produced misleading evidence because it
classified edges from teleported setup states. The current task replaced that
workflow with `sweep_walk`, a normal-movement sweep backed by
`crawl_map_frontier`. The next CLI session should hammer the live command on
larger reachable areas, then add resume support after the command has been
broken in.

## Current Implementation State

Completed:

- Legacy `sweep_map` is quarantined as unsafe/review-only.
- `sweep_teleport_legacy` is the explicit alias for the old teleport sweep.
- Legacy output logs `trusted=false`, `teleport_used=true`, and
  `persistence=skipped`; it should not write trusted blocker data.
- New command `sweep_walk` starts from the current live player tile and uses
  normal movement through the map crawler.
- `sweep_walk` writes `sweep_status.txt` while active.
- On finish, `sweep_walk` writes:
  - `sweep_walk_MM_runNNN.json`
  - `sweep_walk_MM_runNNN_summary.txt`
  - existing `dw_crawl_MM.txt` review snippets
- The JSON includes explicit top-level buckets:
  - `unknowns`
  - `dynamic_blockers`
  - `transitions`
  - `unsafe_aborts`
- `main.lua` was scoped to stay under Lua's 200-local limit.
- Command docs include `sweep_walk`, `sweep_teleport_legacy`, and the
  legacy warning.

Partially proven:

- The crawler already has frontier/backtracking behavior, but it still needs a
  longer live run to prove the `sweep_walk` command uses that behavior safely
  outside tiny test cases.
- Safe stop is unit-tested, but still needs one live stop check during a longer
  run.

Not implemented yet:

- Resume-from-JSON or pause/resume support. The design treated resume as a
  future enhancement after safe stop.

## Live Validation Already Done

Runtime:

- FCEUX was the live runtime.
- User manually reloaded `main.lua` before validation.
- Reload was confirmed with:
  `LAUNCHER_PROBE: codex_taxonomy_reload`
- Position before validation:
  `map=0x09(Garinham) x=4 y=5`
- Menu was initially open, then closed with:
  `simulate_input:B,8`
- Final menu state after testing:
  `MENU_STATE raw_open=false cached_open=false`

Tiny live sweep command:

```bash
./dw_commands.sh --json --replace --timeout 45 --wait "MAP_CRAWL_FINISH" "sweep_walk:attempts=1,max_edges=1"
```

Observed finish:

```text
MAP_CRAWL_FINISH run=1 map=0x09 completed=false reason=max_edges edges=1 passthrough_candidates=0 directional_candidates=0 stationary_npc_cells=0 transitions=0
```

The one live edge was:

- From `(4,5)` direction `up`
- Destination `(4,4)`
- Classification `modeled_blocked`
- JSON status `blocked`
- Confidence `modeled`
- Note `approach_already_modeled`

Generated files validated:

- `sweep_status.txt`
- `sweep_walk_09_run001.json`
- `sweep_walk_09_run001_summary.txt`
- `dw_crawl_09.txt`

Important validation results:

- `sweep_status.txt` ended `active=false`.
- `sweep_status.txt` recorded `method=normal_movement`.
- `sweep_status.txt` recorded `teleport_used=false`.
- `sweep_walk_09_run001.json` parsed as valid JSON.
- JSON contained top-level `unknowns`, `dynamic_blockers`, `transitions`, and
  `unsafe_aborts` arrays.
- `rg '^0x09:' dw_blocks.log` found no matches, so the tiny run did not add
  permanent block data.
- `dw_script_error.log` only had old May errors; no new reload/runtime crash
  was observed.
- Final live state after validation:
  `map=0x09(Garinham) x=4 y=5`, menu closed.

Known benign live noise:

- FCEUX still reports the known stale `LeftAlt` latch in `dw_debug.log`.
- Treat idle `LeftAlt` with no bridge buttons as benign FCEUX/SDL latch noise,
  not map evidence.

## Tests Already Run

Focused tests:

```bash
lua test_map_crawler.lua
lua test_debug_tools.lua
lua test_sweep_walk_command_surface.lua
luac -p main.lua map_crawler.lua debug_tools.lua test_map_crawler.lua test_debug_tools.lua test_sweep_walk_command_surface.lua
git diff --check
```

Results:

- `test_map_crawler.lua`: 35 tests passed.
- `test_debug_tools.lua`: 16 tests passed.
- `test_sweep_walk_command_surface.lua`: passed.
- `luac -p ...`: passed.
- `git diff --check`: passed.

Broad test:

```bash
python3 run_tests.py --allow-missing-speech-dep
```

Result:

- Exit code 0.
- Known WSL speech warnings appeared:
  - `accessible_output2` missing for `/usr/bin/python`
  - `sh: 1: cmd: not found`
- The runner still reported PASS.

## Recommended Next CLI Loop

Start with a fresh baseline:

```bash
./dw_commands.sh --json --replace --timeout 15 --wait-ready sweep_breakin_baseline report_position report_menu_state
```

If a menu is open, close it and recheck:

```bash
./dw_commands.sh --json --replace --timeout 10 --wait "CMD: simulate_input:B,8" "simulate_input:B,8"
./dw_commands.sh --json --replace --timeout 10 --wait "MENU_STATE" report_menu_state report_position
```

Run a slightly larger sweep:

```bash
./dw_commands.sh --json --replace --timeout 180 --wait "MAP_CRAWL_FINISH" "sweep_walk:attempts=2,max_edges=25"
```

If that is clean, increase cautiously:

```bash
./dw_commands.sh --json --replace --timeout 300 --wait "MAP_CRAWL_FINISH" "sweep_walk:attempts=2,max_edges=50"
```

While a longer sweep is running, inspect status:

```bash
sed -n '1,120p' sweep_status.txt
tail -n 120 dw_debug.log
```

Validate the newest JSON:

```bash
python3 -c 'import json, glob; p=sorted(glob.glob("sweep_walk_*.json"))[-1]; json.load(open(p, encoding="utf-8")); print("json ok:", p)'
```

Check that permanent blocker data was not written for the test map:

```bash
rg -n '^0x09:' dw_blocks.log
```

Note: exit code 1 from the `rg` command means no matches, which is the desired
result for the Garinham tiny test.

## What To Hammer Next

Priority 1: Multi-cell live sweep.

- Goal: prove passable edges enqueue destination cells and the sweep continues
  over reachable graph edges.
- Evidence to collect:
  - at least one `status=passable` edge in JSON
  - `cells_visited > 1`
  - `edges_tested > 1`
  - no teleport logs in the sweep path

Priority 2: Frontier/backtracking.

- Goal: prove the command can route back to a known reachable frontier cell
  using confirmed passable edges only.
- Evidence to collect:
  - `MAP_CRAWL_PROBE` lines from more than one source cell
  - successful return/backtrack or return-to-frontier behavior
  - final `sweep_status.txt` ends `active=false`

Priority 3: Live taxonomy examples.

- Static tests cover all buckets, but live evidence is still thin.
- Try to capture at least:
  - one `passable` edge
  - one `transition` edge, if a safe stairs/door boundary is nearby
  - one safe stop or unsafe-abort style interruption without poisoning output

Priority 4: Safe stop live check.

Start a longer run, then stop it:

```bash
./dw_commands.sh --replace "sweep_walk:attempts=2,max_edges=100"
./dw_commands.sh --replace stop_map_crawl
```

Then verify:

```bash
sed -n '1,120p' sweep_status.txt
tail -n 160 dw_debug.log
./dw_commands.sh --json --replace --timeout 15 --wait "POSITION:" report_position report_menu_state
```

Expected:

- `sweep_status.txt` ends `active=false`.
- Log includes `MAP_CRAWL_NPC_PARK_RESTORE` if NPCs were parked.
- Final position is sensible.
- Menu is closed or explicitly understood.

## Resume Logic Plan After Break-In

Add resume only after larger live runs expose the shape of real output.

Suggested first resume feature:

- Command: `sweep_walk_resume:PATH` or `sweep_walk:resume=PATH`
- Read prior JSON.
- Restore visited cells and edge observations.
- Rebuild frontier from passable edges and untested directions.
- Require the live player position to be on a known reachable cell from that
  JSON before resuming.
- If live position is not in the known reachable component, refuse with a clear
  message instead of teleporting.

Important resume rules:

- Never teleport to resume.
- Never trust old `unknown`, `dynamic_blocked`, `transition`, or `unsafe_abort`
  as blockers.
- Include prior output path and resume generation in the new JSON.
- Keep old JSON immutable; write a new run file.

## Cleanup To Do After Break-In

Generated artifacts currently present from validation:

- `sweep_status.txt`
- `sweep_walk_09_run001.json`
- `sweep_walk_09_run001_summary.txt`
- `dw_crawl_09.txt`

Other untracked/non-task artifacts seen in `git status`:

- `.coderabbit.yaml`
- `C:/`

Be careful with `dw_access.ini`; it is modified in the worktree and may be a
local runtime/debug setting rather than source work. Do not normalize it unless
the user asks.

Expected source/test files from the sweep work:

- `debug_hooks.txt`
- `debug_tools.lua`
- `dw_commands.sh`
- `main.lua`
- `map_crawler.lua`
- `session_handoff.md`
- `test_debug_tools.lua`
- `test_map_crawler.lua`
- `test_sweep_walk_command_surface.lua`

Before committing or packaging, run:

```bash
lua test_map_crawler.lua
lua test_debug_tools.lua
lua test_sweep_walk_command_surface.lua
luac -p main.lua map_crawler.lua debug_tools.lua test_map_crawler.lua test_debug_tools.lua test_sweep_walk_command_surface.lua
git diff --check
python3 run_tests.py --allow-missing-speech-dep
```

## Stop Conditions For The Next Session

Stop and inspect instead of queueing more commands if:

- commands stop being consumed
- `dw_debug.log` stops updating
- `dw_script_error.log` gets a new current-date stack trace
- menu/dialogue/battle state appears during a sweep
- the player position drifts from expected source/destination
- JSON fails to parse
- a run writes trusted permanent blocker data unexpectedly
