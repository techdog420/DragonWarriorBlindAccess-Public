# Darkness fixes and hardware-test candidate

Date: 2026-10-23. Local package qualification; release artifacts unpublished.

## Bugs and fixes

- DARK-SPEECH-01: Radiant generated interrupting messages at frames 1207,
  1215, and 1223, reporting one, two, and three visible tiles. Automatic
  expansion speech now waits for 12 unchanged frames and reports the final
  radius once. The pre-cast context preserves balanced navigation's restoration
  notice. Torchlight still reports its smaller radius; dimming and light loss
  remain immediate. Visibility/navigation and explicit reports use current RAM.
- DARK-SPEECH-02: exit spoke `World Map. Radiant light...` at 11:23:00.
  `darkness.context` now excludes map 0x01 even if terrain still says dungeon.
  Pending expansion speech is cancelled across maps/non-field states.
  The existing entry notice is preserved when dungeon terrain arrives after
  the map-change frame, with its own focused regression.

Changed code: `darkness.lua`, `main.lua`, `test_darkness.lua`.

## Verification

- Focused Lua suite: 21 tests pass; Lua syntax passes.
- Final `python -u run_tests.py`: 43 host-runnable Lua suites, 82 Python tests,
  syntax, speech dependency and command queue pass. Live-only screen/speech
  diagnostics remain outside this host gate.
- Initial fresh command polling: `darkness_fix_20261023`, frame 60600.
- The player initially tested the old loaded script, then manually reloaded at
  11:36:11. The reloaded NVDA session queued one final-radius warning at frame
  2654 and delivered it at 2655 (11:36:55):
  `The light expands. Radiant light. 3 tiles are visible in every direction.
  Navigation assistance is restored while the light lasts`.
- Exit at frame 3529 (11:37:10) spoke only `World Map`. The player confirmed
  both issues resolved after reload. Subsequent preservation of the existing
  late-terrain entry notice has host regression coverage and does not alter
  these cast/exit cases.
- Raw before/accepted logs and build/gate/audit outputs are under ignored
  `.test_tmp/darkness-20261023/`, using shared-read snapshots for live logs.

## Candidate

Version: `2026.10.23-qualification1`, built from the current working-tree app
payload, including October 16 release hardening. Artifacts were built before
the source commit; no release assets were published. October 15 qualification
ZIPs are preserved. Final archive hashes
and checks: `work_notes/packaging_qualification_20261023.json`.

Both player/source repeat builds are byte-identical. Independent audits pass
all manifest hashes, current app matching, safe paths, pinned dependencies,
source notices, and ROM/save exclusion. Clean install/validation and the
Unicode-path safe-refusal fallback pass.

Development-source cast/exit checks and the fresh packaged launch smoke are
player-accepted. The player installed into
`C:\tmp1\Dragon Warrior Accessibility 2026.10.23-qualification1`, confirmed ROM
discovery, launch, character creation and quest start, and reported expected
behavior. Install/launch logs confirm the supported ROM and successful startup;
the package-local Python selected NVDA. Speech logs show object browsing,
completed auto-walks, door use and arrival in Tantegel Castle. All 525 installed
payload files match the manifest. Read-only log snapshots are preserved under
`.test_tmp/darkness-20261023/package-smoke-c-tmp1/`.

The candidate is ready for alternate-hardware validation. Earlier broader
reader/save/non-ASCII account acceptance belongs to the October 15 bytes;
this check establishes the new candidate's fresh-install smoke scope.
Alternate-hardware testing and publication remain open.
