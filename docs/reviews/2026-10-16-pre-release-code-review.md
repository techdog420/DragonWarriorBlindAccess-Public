# Pre-release code review — 2026-10-16

Baseline: application source `b6261ba`, with existing packaging/acceptance
documentation changes in the working tree. Review fixes are local and uncommitted.

## Result

Focused reliability fixes are warranted. A broad refactor before alternate
hardware testing is not justified by the findings. The review found four
actionable reliability/test gaps and one lower-priority speech lifecycle issue;
all are fixed below with isolated reproductions. No map or movement algorithm
was changed. This is a risk-focused source review, not an exhaustive proof of
every module, game state, route, dependency, or hardware configuration.

The final host gate passes **43 Lua suites and 82 Python tests**. New player
acceptance has not been performed for these changes. The qualified
`2026.10.15-qualification1` ZIP pair still contains the original `b6261ba`
application payload and has not been replaced or published.

## Findings and fixes

### REVIEW-01 — P1: temporary sharing conflict permanently disables keyboard input

Location: `keyboard_bridge.ps1`, `Write-State` and its publication loop.

Reproduction: hold a read-only handle on the state file that denies writes,
then call the actual writer. Previously, `WriteAllText` raised an IOException
and the helper's stop-on-error policy terminated its infinite polling loop.
Once the Lua lease expired, manual keyboard input remained unavailable even
after the reader closed the file. This is the same failure class that the
earlier package diagnostic collector exposed; that historical collector fault
does not establish a natural gameplay failure.

Fix: defer publication only for Windows sharing/lock violations (32/33).
Leave the publication timer and last-published state unchanged on failure so
the next poll retries the current physical state. Other I/O failures still
propagate. A prolonged lock still expires Lua's existing lease and releases
input; the helper can recover when writing becomes possible again.

Validation: isolated Windows PowerShell test loads only the real writer through
the parser, reproduces a denied write, unlocks and verifies a fresh write, and
checks that an unrelated missing-directory error remains an error. It failed
before the change and passes afterward. The helper's 11 policy self-tests pass.

### REVIEW-02 — P2: valid dollar-sign installation paths corrupt Lua autoload

Locations: `release/install_player.ps1` and `release/play_player.ps1`,
`Set-PrivateFceuxConfigValue`; `launch_dw.ps1`, `Set-ConfigValue`.

Reproduction: validate a fixture package extracted to `DWA $& package` twice.
The initial missing settings are appended correctly. Updating existing
settings interprets `$&` as the previous whole regex match, corrupting both
Lua autoload paths while validation still reports success. `$1` and `$$` are
also replacement metacharacters. The same defect exists in all three writers.

Fix: use regex match evaluators so setting values are inserted literally.
Retain existing path alias handling and configuration-key matching.

Validation: repeated real player validation under the special-character path;
isolated execution of all three actual writers with `$&`, `$1`, `$$`, and
`${name}` in a value, preserving an unrelated setting. Both tests failed before
the change and pass afterward under Windows PowerShell 5.1. These fixtures
perform validation/config writes only and never start an emulator.

### REVIEW-03 — P2: failed Lua pipe I/O can remain reported as ready

Location: `tolk.lua`, `send_bridge`.

Reproduction: make either pipe `write` or `flush` return `nil, error`, the
normal Lua file-I/O failure convention. The enclosing `pcall` succeeds because
no exception was thrown, so the old code treated the message as delivered and
left the bridge marked ready.

Fix: check both return values inside the protected call. Reuse the existing
error logging, unavailable state, and fallback path. Later calls no longer
write to the known-broken pipe.

Validation: new `test_tolk.lua` checks successful transport, nil-returning
write/flush failures, and an exception. The failure test failed before the
change; both tests now pass. No Python process or real speech is involved.
This improves failure detection; it does not reconnect a dead screen reader.

### REVIEW-04 — P2: the normal gate silently skips speech-bridge tests

Locations: `test_speech_bridge.py`, Python unittest discovery.

The six existing speech tests were standalone functions. `unittest discover`
imported their module but collected zero tests; they ran only when that script
was invoked directly. Thus the historical 68-test count was accurate for
discovered tests but did not include those six speech tests.

Fix: add a standard `load_tests` hook and use `unittest.main()` for direct
execution. Add an inventory regression requiring each automated Python test
module to contribute at least one discovered case. The manual audible
`speech_smoke.py` remains outside automatic discovery.

Validation: discovery now runs ten speech tests (six restored, four new).
The complete Python gate increases from 68 to 82: six restored speech tests,
four new speech regressions, three input/path regressions, and the inventory
guard. The new transport suite increases the Lua-suite count from 42 to 43.

### REVIEW-05 — P3: speech cancellation and close fail at a full queue

Location: `speech_bridge.py`, `SpeechDispatcher`.

With a blocked fake speaker and a one-entry queue, a silence command was
dropped when the queue was full, allowing obsolete pending speech to continue.
The close sentinel could also be dropped, leaving the worker waiting forever
once the queue drained. Submission after close could remove a queued sentinel.
The installed JAWS backend also exposes `speak` without a `silence` method.

Fix: silence discards pending speech as interrupt already does; use a closing
event independent of queue capacity; reject submissions after close; use an
empty interrupt for a backend without `silence`. Accepted speech drains on
graceful close. Keep the existing bounded join and daemon worker behavior.

Validation: full-queue silence, full-queue close, post-close submission, and a
speak-only backend all pass. The first three failed before the fix. The
existing blocked-speaker test confirms stdin reading remains independent.
This is helper hardening: there is currently no bound player silence hotkey,
and process exit already ends the daemon. A call already blocked inside a
reader cannot be forcibly interrupted by this queue change.

## Other reviewed paths

- Entry/module loading and the frame loop: snapshot-before-consumer ordering,
  error reporting, settings capture, map transitions, dialogue/menu/battle
  checks, and the movement gate before frame advance.
- Movement: hotkey deferral until release, interruption and explicit resume,
  route cleanup, origin/drift handling, per-step darkness guards, hazard
  trimming/confirmation, and bounded recovery/corridor checks.
- Map/path planning: directional approaches, goal rejection, search bounds,
  mutable blocker overlays, open doors, passability snapshots, and the
  distinction between permanent map data and runtime observations.
- Narration/object state: warning ordering, low-health episodes, visibility
  filtering, selection preservation, title/ending and merchant text handling.
- Persistence: settings drafts, backup/replace/rollback, comment preservation,
  and refusal to claim saved changes after write failure.
- Release boundary: ROM fingerprint checks, private paths, required-file
  checks, player speech readiness, allowlisted package inputs, and separation
  of matching dependency source artifacts from player files.

No additional defect requiring a gameplay change was established in those
paths. Existing deterministic tests provide substantial model coverage; they
do not substitute for actual movement, audio, save/reload, or hardware testing.

## Refactor recommendation and remaining limits

- Keep this patch focused. `main.lua` and `route_manager.lua` carry substantial
  debug and map-specific complexity, but splitting them now would expand the
  acceptance surface without addressing the confirmed failures above. A later
  extraction of debug command registration from `main.lua` is reasonable if
  maintenance work requires it, with command/integration tests first.
- Lua's bridge `is_ready()` initially means a pipe opened; the player launcher
  separately checks a fresh Python `READY` status. Consolidating that lifecycle
  and diagnostics would improve maintenance, but is a separate change. The
  transport fix above does not turn readiness into proof of audible speech.
- The keyboard sidecar has no emulator-owned lifetime and normally survives
  closing FCEUX until a subsequent launcher cleans it up. Tying it to its
  owning emulator is a useful later lifecycle improvement; no CPU impact or
  player failure from that behavior was measured in this review.
- A silent SAPI property read succeeded across the existing worker handoff on
  this machine. No COM-thread rewrite is justified by that probe. It proves
  neither speech output nor behavior on other machines.
- `SPEECH-LATENCY-01`, dialogue-only onset, physical in-battle status speech,
  and the isolated western recovery carry retain their existing evidence
  status. No live emulator or reader settings were changed for this review.

## Verification and next handoff

Final validation:

- `python -u run_tests.py`: 43 host Lua suites; 82 Python tests; Lua/Python/shell
  syntax, speech dependency, and command queue checks pass.
- PowerShell parser: all 14 root/release scripts pass.
- `keyboard_bridge.ps1 -PolicySelfTest`: 11 cases pass.
- `git diff --check`: passes.
- Live-only `test_screen.lua` / `test_speech.lua`: explicitly skipped.

The sandbox again could not launch Lua (`WinError 623`) and could not use a
native fixture's temporary folder. The unmodified gate and native regressions
passed in normal host context. Raw before/after reproductions and gate logs
are preserved under `.test_tmp/code-review-20261016/`.

Both qualified archive hashes were rechecked unchanged:

- Player: `FC35731A8C3D9885D4089FF953DD919F7194AC9B564C0D7ADE6C2D3C6EA69C0A`.
- Corresponding source: `42DE81803D6586CA52E7149003189888D8AF9163A93E04BF89381A2E1376BA91`.

Before handing off a candidate containing these fixes, rebuild and qualify its
final bytes, then do a short local player smoke test of launch, manual arrows,
object speech, auto-walk interruption, and normal save/exit/Continue. Preserve
the old accepted package as a comparison baseline. Alternate hardware testing
should cover both supported readers, fallback speech if used, focus/menu and
screen-reader chords, launch/relaunch, and normal saves. Audible latency and
device-dependent behavior remain actual-player observations, not host-test claims.
