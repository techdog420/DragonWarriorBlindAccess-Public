# Current-source player package qualification

Prepared: 2026-10-15 against clean `b6261ba` on `main`.
Status: local artifact qualification and separate NVDA/JAWS player acceptance
complete on 2026-10-15, including actual non-ASCII account acceptance.
Broader hardware/player coverage and publication remain open.

## Candidate and scope

Internal version: `2026.10.15-qualification1`. This is a local qualification
label, not a published release version. The app payload is the source at
`b6261ba`; later roadmap/handoff edits do not change that payload.

Both artifacts are under `D:\modding\DragonWarrior1\.tools\release-output\`:

- `Dragon Warrior Accessibility 2026.10.15-qualification1.zip`
  (47,565,986 bytes, 525 payload files plus its manifest).
  SHA-256: `FC35731A8C3D9885D4089FF953DD919F7194AC9B564C0D7ADE6C2D3C6EA69C0A`.
- `Dragon-Warrior-Accessibility-2026.10.15-qualification1-Corresponding-Source.zip`
  (157,355,170 bytes, 2,608 payload files plus its manifest).
  SHA-256: `42DE81803D6586CA52E7149003189888D8AF9163A93E04BF89381A2E1376BA91`.

The distributable ZIPs and their original build directories remain pristine.
ROM installation and launch tests use separate extracted copies under ignored
`.test_tmp\packaging-20261015-baseline\`. Do not zip those test copies: they
contain a user-installed ROM, private configuration, logs, and eventually saves.

## Completed automated qualification

- [x] Preserve prior live logs before running the host gate.
- [x] `python -u run_tests.py`: 42 host-runnable Lua suites, 68 Python tests,
  syntax, speech dependency, and command queue pass. Live-only `test_screen.lua`
  and `test_speech.lua` remain explicitly skipped.
- [x] Build player and corresponding-source artifacts twice using PowerShell 7.6.6.
  Both pairs have identical archive SHA-256 values. Repeat outputs are under
  `.tools\release-output\qualification-repro-20261015\`.
- [x] Read both ZIPs independently: every manifest size/hash matches, manifest
  coverage is exact, paths are unique and safe, timestamps are fixed, and
  release versions match. No ROM, battery save, or emulator savestate entries.
- [x] Compare all allowlisted app/root files and player documents with the
  checkout. The only config changes are the four prescribed player defaults.
  No development logs, queues, tests, caches, or personal data in the player ZIP.
- [x] Verify patched emulator executable and patch hashes against its build
  marker; verify pinned Qt/NVDA source archive hashes; verify the sole shipped
  screen-reader DLL is the pinned official NVDA Controller Client. No FFmpeg.
  Versioned notices reference the matching source asset.
- [x] Fresh extraction with spaces: missing-ROM launch returns 2 with setup
  guidance; actual `.cmd` installer accepts the supported ROM; repeat setup
  preserves it; two `-ValidateOnly` checks pass with private config and Lua paths.
  Source ROM hash remains unchanged.
- [x] Unicode extraction on this D: volume: installation succeeds; launch safely
  refuses because the returned compatibility path still contains non-ASCII
  characters. The error instructs relocation to an ASCII-only folder before
  any emulator starts. This exercises the documented fallback, not successful
  Unicode gameplay or a non-ASCII Windows account.
- [x] Real first launch through packaged `Play Dragon Warrior.cmd` with active
  NVDA: package-local Python selected `NVDA reason=active`, status `READY`, mod
  announcement/title/new-game/slot/name-entry speech logged. Keyboard heartbeat
  advanced. No app/config edits were required for this launch.
- [x] After the player closed FCEUX and switched readers, relaunch the same
  extraction with JAWS alone. Host inspection found `jfw` and no NVDA/FCEUX;
  the fresh speech log selected `Jaws reason=jfw-process`, reported `READY`,
  and recorded the mod announcement and title narration. JAWS player acceptance
  and save loading were separate checks; the player later accepted the initial
  JAWS slice below.
- [x] Second JAWS launch after the player reported saving and exiting:
  `Jaws reason=jfw-process`, `READY`, mod announcement and title narration.
  Pre-relaunch logs, battery data, and slot 0 savestate were preserved before
  testing. This was an intermediate emulator-slot check; the normal battery
  save and reload checks below subsequently completed.

The restricted gate could not start Lua (`WinError 623`); the unmodified gate
passed in normal host context. Restricted player builds could not create the
SAPI5 COM cache (`WinError 5`); both normal-host builds passed runtime execution
without `-SkipRuntimeExecution`. FCEUX source ownership required a process-local
`safe.directory` entry; no global Git settings were changed.

Local raw evidence, including both build logs, gate output, independent archive
audit, extracted checks, and live launch log, is under
`.test_tmp\packaging-20261015-baseline\`. Durable artifact/check results are in
`work_notes/packaging_qualification_20261015.json`.

## Build recipe

From the repo root in PowerShell 7, choose fresh output paths; builders refuse
to overwrite existing outputs. Use normal host context for the speech COM check.

```powershell
$playerInputs = @{
    ReleaseVersion = '2026.10.15-qualification1'
    FceuxDirectory = "$PWD\.tools\fceux-release-runtime-verified"
    PythonDirectory = "$PWD\.tools\release-staging\python-license1"
    ReadmePath = "$PWD\README.md"
    KeyboardCommandsPath = "$PWD\release\Keyboard Commands.txt"
    ProjectLicensePath = "$PWD\LICENSE"
    FceuxLicensePath = "$PWD\licenses\third-party\FCEUX COPYING.txt"
    FceuxSourceNoticePath = "$PWD\licenses\FCEUX-SOURCE.txt"
}
.\release\build_player_package.ps1 @playerInputs
.\release\build_corresponding_source.ps1 -ReleaseVersion $playerInputs.ReleaseVersion
```

Source inputs remain the existing pinned patched FCEUX checkout, portable speech
runtime, and hash-checked source cache. A new version or changed payload produces
different artifacts and needs qualification of those final bytes.

## Local player acceptance and remaining release checks

- [x] NVDA initial gameplay, player-confirmed: automatic backend selection,
  audible prompts, new character creation, King dialogue, opening a chest,
  movement, and closing FCEUX. The log also records a completed 12-step chest
  auto-walk. This closes the reported initial slice, not save/relaunch coverage.
- [x] Normal NVDA King save: player loaded the prior battery save, fought
  battles, and returned to save with 4 experience needed to level (previously
  5). Fresh speech confirms both the 4-point marker and Imperial Scrolls save;
  FCEUX exited. Logs and the 8 KB battery file are preserved under
  `nvda-king-save-before-final-reload/` in the evidence root. Battery SHA-256:
  `A0E7FA77E524DB0C5F7E21FA6444CD561C5B1325AAF93EBA3F6DF3D0C013558D`.
- [x] Final NVDA battery reload: automatic NVDA selection and `READY`; Continue,
  Slot 1, and game start logged. Fresh King dialogue and player confirmation
  both report 4 experience needed to level. The updated save loaded as expected.
  NVDA normal save/relaunch acceptance is complete.
- [x] JAWS initial launch/speech/gameplay, player-confirmed. The player reports
  the game works as expected and left the emulator running with JAWS active.
- [x] Player reports saving and exiting the first JAWS session. Both an 8 KB
  battery file and `Dragon Warrior.fc0` exist. The player later clarified that
  this first save used FCEUX's slot system.
  Battery SHA-256 before relaunch:
  `24850A61133BAEF88ADF226B637C3E830A80EFA1E85183D3FBD93A83E4FD8004`.
- [x] Normal JAWS battery save: after leaving the castle and fighting battles,
  the player returned to the King. Fresh speech records the deeds prompt,
  `Thy deeds have been recorded on the Imperial Scrolls of Honor.`, refusal to
  continue, and the RESET/power-off instruction. FCEUX exited. The preserved
  8 KB battery SHA-256 is
  `F248B24BA50F528A8C200DCC6F25F3C74ACA2F2FB18BB63BD9921E5923578F30`.
- [x] Confirm restored progress and JAWS narration after this King save.
  Third JAWS startup passes and fresh speech records Continue/Slot 1/game
  start. The packaged launch supplied no savestate argument and AutoResume
  remains disabled. The player confirmed the character restored with the same
  experience needed for the next level, then closed FCEUX and switched to NVDA.
  A savestate reload and a normal in-game save are recorded separately.
  Coordinate any reader switch with the player; do not interrupt their reader.
  First JAWS launch logs `CONTINUE A QUEST`, Slot 1, game start, and the King
  addressing Loki, supporting loading the NVDA session's initial character.
  Audible/gameplay confirmation is now accepted. This is cross-reader
  continuity evidence, not confirmation of the later saved progress or NVDA
  relaunch acceptance. The second JAWS startup has now passed independently.
  The later King-save backup is under
  `.test_tmp\packaging-20261015-baseline\jaws-king-save-before-battery-reload\`;
  its relaunch log is `jaws-battery-relaunch.txt` in the evidence root.
  Accepted JAWS logs and battery data were preserved under
  `jaws-battery-accepted-before-nvda/` before the NVDA save-check launch.
  JAWS launch/gameplay/normal battery save/relaunch acceptance is complete.
- [x] Actual non-ASCII Windows profile: supported ROM installation, two NVDA
  launches, create/reload a save, private config, speech log, and keyboard paths.
  The user created `DWTest-é` and signed in. Live Windows profile inspection
  confirms `C:\Users\DWTest-é`, SID ending `1021`, loaded in session 2 with
  NVDA running there. Codex remains in `developer` session 1. Actual application
  testing must run from the new account; changing USERPROFILE alone is not proof.
  Run `D:\modding\DragonWarrior1\.test_tmp\account-test.cmd` while signed into
  the new account. It prepares a fresh verified extraction in that account's
  Downloads, checks the real Windows SID/profile, installs the supported ROM,
  and starts the unchanged player launcher. Run twice for King save/exit and
  Continue/reload. Package-owned context/logs are mirrored back to
  `.test_tmp/non_ascii_account_20261015/evidence/` for inspection; no ROM is
  mirrored as evidence. Acceptance completed on run 002.
  Direct staging from developer was denied by Windows profile permissions. The
  helper stages under the actual account instead; no account/folder ACL changes.
  Run 001 confirmed actual identity/profile, install, NVDA READY, gameplay and
  normal King save (LOKI, 5 experience to level). Manual movement failed; the
  keyboard helper started but stopped early. The capture harness's Copy-Item
  source reader twice reproduced a fatal write-sharing conflict in a scratch
  helper. The harness now uses shared-read snapshots and passed the stress
  comparison. This is a likely test artifact, not proven Unicode breakage.
  Run 002 with the corrected collector restored LOKI's 5-XP save; the player
  confirmed battery load and manual arrows. Fresh position speech and v3
  heartbeat advancement from 3 to 1017 over more than four minutes corroborate
  sustained input readiness. Account qualification is complete; the package
  remains unchanged. See `work_notes/non_ascii_account_20261015.md`.
- [ ] Broader hardware/player coverage before a broader release.
- [ ] Choose the final public version and publication destination with the user,
  qualify any rebuilt artifacts, and publish the paired player/source assets
  only when authorized. Nothing was uploaded or published in this pass.

Live test extraction:
`D:\modding\DragonWarrior1\.test_tmp\packaging-20261015-baseline\clean extracted package\Dragon Warrior Accessibility 2026.10.15-qualification1`.
It starts without development saves; keep its new saves with that test copy.
The first NVDA session's speech/status/launch logs and battery file are preserved
under `.test_tmp\packaging-20261015-baseline\nvda-complete-before-jaws\`.

## Follow-up after packaging

The player reports NVDA has a detectable delay compared with JAWS in object
browsing and arriving dialogue, particularly apparent during the quick reader
switch. Track this as `SPEECH-LATENCY-01` in `PLAYTESTING.md`; investigate after
the remaining package work. This is a comparative usability report without
measured latency or an established cause. No speech settings or code were changed.
