# Non-ASCII account qualification - 2026-10-15

Status: actual non-ASCII account qualification complete and player-accepted.
The corrected diagnostic collector allows sustained manual input. The qualified
package is unchanged.

## Actual account and first run

The helper recorded Windows identity `TEST-PC\DWTest-é`, SID ending `1021`,
session 2, real and environment profile `C:\Users\DWTest-é`, and temporary
directory under that profile. NVDA PID 16144 was in the same session. The
player ZIP hash is the original qualified
`FC35731A8C3D9885D4089FF953DD919F7194AC9B564C0D7ADE6C2D3C6EA69C0A`.

Installation accepted the supported ROM. The launcher used ASCII 8.3 aliases
for FCEUX-facing paths while keeping private data under the real profile.
Packaged Python selected NVDA and reported READY. The player confirmed emulator
and script behavior, created LOKI, and saved normally through the King.
Fresh speech confirms the Imperial Scrolls save with 5 experience needed to
level. Preserved 8 KB battery SHA-256:
`5D5325A17F69F7211CA083B05F41EEE096BD924B0558A8BF6B63407705ECB48C`.

Manual movement did not work according to the player. The launcher recorded
keyboard helper PID 5056, so it did start. Its final file was
`v2:1274:1792104626:suspended`, written around 22:50:26 UTC; game speech
continued until exit at 22:55:06 UTC. The v2 suspended line is the helper's
finally/cleanup output, not proof of a missing initial launch. No first-run
helper stderr was captured, so its exact exception is unavailable.

Raw first-run evidence: `.test_tmp/non_ascii_account_20261015/evidence/run-001/`.

## CAPTURE-LOCK-01

- Severity: P1 test-harness defect; diagnostic collection can terminate input.
- Reproduction: launch the unchanged keyboard helper on a scratch output file,
  then repeatedly sample it with the collector's original `Copy-Item` call.
- Observed: the helper exits with `IOException`, reporting that another process
  is using the file. `WriteAllText` cannot obtain write access while the copy's
  source reader denies write sharing. Two independent reproductions failed
  after 241 and 368 copies; one reproduced the same v2 cleanup marker.
- Expected: observational snapshots must permit the producer to keep writing.
- Correction: the account-test harness now reads live source files with an
  explicit FileStream using `FileShare.ReadWrite | FileShare.Delete`, closes
  that reader, then writes the snapshot separately. It records heartbeat samples
  so a started PID is not mistaken for sustained readiness. The bootstrap
  refreshes only helper files in the test profile, preserving app/save data.
- Verification: the shared reader survived 14,664 snapshots in the first test.
  Retesting the exact extracted helper function survived 12,828 snapshots over
  8 seconds with heartbeat advancing from 1 to 29 and no stderr. The old reader
  again killed the helper during that same comparison.
- Evidence: `.test_tmp/non_ascii_account_20261015/capture-check-20261015-225955/`
  and `capture-check-20261015-230132/`, including results JSON and stderr.

This reproduced collector failure is the likely explanation for the first
account run's early helper exit. It does not prove a Unicode defect or establish
the original exception without stderr. No production keyboard helper, launcher,
Lua, or player ZIP was changed. Do not alter the package to compensate for an
observer that denies its writes.

## Accepted second run

Run 002 started at 23:05:28 UTC under the same actual identity, SID, session,
profile and Unicode temporary path. The unchanged package selected NVDA and
reported READY. Continue restored LOKI; fresh King dialogue at 18:05:58 local
reports 5 points needed to level. The player confirmed successful battery load
and normal manual keyboard movement. Speech positions changed from `(6,4)` to
`(6,6)`, corroborating that report.

The launcher started keyboard PID 46736 and FCEUX PID 37812. Fresh v3 heartbeat
samples advanced from sequence 3 at 23:05:32 UTC to 1017 at 23:10:03 UTC while
the corrected observer was running. The old v2 line at the beginning of capture
is prelaunch residue and excluded. Later `suspended` samples reflect the test
account being in the background while the player returns to Codex; continued
sequence advancement confirms the helper remains alive.

This closes supported ROM installation, two launches, automatic NVDA speech,
normal King save/reload, manual input and private config/log/keyboard paths under
the real `C:\Users\DWTest-é` profile. FCEUX was left running as requested.
Raw evidence: `.test_tmp/non_ascii_account_20261015/evidence/run-002/`;
preserved acceptance snapshot: `accepted-run-002/` under the same test root.
Broader hardware/player testing and public release decisions remain open.
