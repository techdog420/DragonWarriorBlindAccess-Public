# Blind-player installation plan

Date: 2026-07-31

Status: proposed player-release baseline

## Goal

A blind Windows gamer should be able to go from the downloaded release archive
to a speaking Dragon Warrior title screen without installing Python, locating
FCEUX settings, editing a configuration file, using a mouse, or running a
command manually.

The supported release target is 64-bit Windows 10 and Windows 11. Development
and automated-debug launch paths remain separate from the player package.

## Recommended distribution

Ship one portable ZIP containing the mod, the exact tested FCEUX 2.6.6 Qt/SDL
runtime with the repository's deferred-startup Lua patch, a portable Python
speech runtime with `accessible_output2`, and all required third-party license
notices. Do not include Dragon Warrior ROM data, battery saves, savestates,
playtest logs, developer tools, or map-reference images.

The player extracts the ZIP to a writable folder and runs one clearly named
file. The package does not require administrator access and does not write to
the registry, Program Files, or an existing FCEUX installation.

Bundling the tested runtimes is preferable to downloading them during setup:

- setup works offline and does not depend on a live URL;
- every player receives the emulator build used for release QA;
- no Python or `pip` knowledge is required;
- the mod uses a private FCEUX configuration and cannot damage an existing
  emulator setup;
- support reports can name one deterministic package version.

The size and third-party notice burden are acceptable release costs. The build
must include the licenses and corresponding-source arrangement required by the
bundled components before public distribution.

## Player experience

### First installation

1. Download and extract the release ZIP to a normal writable folder such as
   Documents or Games. Do not recommend Program Files.
2. Run `Install Dragon Warrior.cmd`.
3. The installer prints a short screen-reader-friendly introduction explaining
   that the original game is not included and that the supported image is the
   US Rev 1 NES release.
4. The installer first checks for exactly one supported `.nes` file beside the
   installer. If none is found, pressing Enter opens the standard Windows file
   picker. A ROM path may also be passed by dragging the file onto the installer
   or by supplying it as the first command-line argument.
5. Setup validates the selected file before copying it. The initial supported
   fingerprint is:
   - size: 81,936 bytes;
   - SHA-256: `676B89D76CF9E83EED76C0A67F81DA906916F0BCE321CF3A9A39AC78BC9C0845`.
6. On a mismatch, setup reports the selected filename, actual size and hash,
   expected revision, and warns that narration, navigation, game behavior, and
   save compatibility may be incorrect. The safe default is to cancel. A power
   user may proceed by typing the exact phrase `I ACCEPT`, or by passing
   `-AllowUnsupportedRom` to the PowerShell installer. Setup records the exact
   accepted size and SHA-256; changing the installed ROM invalidates that
   acknowledgement. It must not call the file "bad" or imply that the player
   should download a copyrighted copy.
7. On success, setup copies the ROM to `user\Dragon Warrior.nes`, creates the
   private FCEUX data directories, verifies the bundled speech runtime, and
   reports `Installation complete` in both console text and screen-reader
   speech.
8. Setup offers to launch the game immediately. Enter accepts; N exits.

Setup never modifies or deletes the player's source ROM.

### Normal play

The player runs `Play Dragon Warrior.cmd`. It uses only package-relative paths:

- emulator: `runtime\fceux\qfceux.exe`;
- emulator data and saves: `user\fceux\`;
- ROM copy: `user\Dragon Warrior.nes`;
- mod entry point: `app\main.lua`;
- speech Python: `runtime\python\python.exe`.

If setup is incomplete, the play launcher starts setup or explains the one
missing item. On a launch failure, the console remains open and gives a short
failure summary plus the path to a plain-text diagnostic log.

## Proposed archive layout

```text
Dragon Warrior Accessibility/
  Install Dragon Warrior.cmd
  Play Dragon Warrior.cmd
  [existing release README]
  Keyboard Commands.txt
  app/
    main.lua
    dw_access.ini
    launch_dw.ps1
    launch_dw.cmd
    keyboard_bridge.ps1
    speech_bridge.py
    [runtime Lua modules]
  runtime/
    fceux/
      qfceux.exe
      [official FCEUX runtime files]
    python/
      python.exe
      [portable Python and accessible_output2 files]
  licenses/
    [project and third-party license texts and notices]
  user/
    [created or populated by setup; preserved during updates]
```

`user\` is the only player-data area. The packaging build starts it empty apart
from a short README or placeholder if the archive format needs one.

The existing release README remains the single player-facing guide. Add the
final installation steps to that draft after setup behavior and filenames are
stable; do not create a competing quick-start document.

## Accessibility requirements

- Every essential action is keyboard accessible.
- Console prompts use one question at a time and always state the accepted
  keys. Enter chooses the safe default.
- Setup and launcher messages are short plain text; color, window position,
  progress bars, and screenshots are never the only source of information.
- The standard file picker is optional because same-folder detection,
  drag-and-drop, and a command-line path are also supported.
- Errors remain on screen until the player presses a key and are also written
  to `user\install.log` or `user\launch.log`.
- No success is claimed until the ROM, emulator, mod entry point, keyboard
  bridge, and speech runtime all pass their checks.
- First launch must produce screen-reader speech without asking the player to
  configure FCEUX menus.
- The package must not steal focus repeatedly after the game window is ready.

## Technical changes required

### Player setup and launcher

Add thin CMD entry points that invoke PowerShell with `-NoProfile` and
`-ExecutionPolicy Bypass`. Put all meaningful validation and logging in
PowerShell so quoting, Unicode paths, hashing, and error handling are reliable.

Qt FCEUX 2.6.6 cannot itself open non-ASCII ROM or Lua paths reliably. When the
package path contains non-ASCII characters, the player launcher therefore keeps
the original path in player-facing logs but supplies Windows 8.3 aliases for
FCEUX-facing executable, ROM, Lua, and private-config paths. If Windows cannot
provide an ASCII alias, setup must give a clear instruction to move the
extracted folder to an ASCII-only path rather than opening a silent emulator.

The player launcher sets `FCEUX_CONFIG_DIR` explicitly to the package's private
`user\fceux` directory. It passes explicit `-FceuxPath`, `-RomPath`, and
`-LuaPath` values to the existing launcher; it must not rely on the current
developer defaults or environment variables.

Because the Windows FCEUX 2.6.6 build does not reliably honor command-line Lua
loading, setup also writes `SDL.LuaScript` and `SDL.LastLoadLua` into the
private FCEUX configuration. These point to the current packaged `app\main.lua`.
The player launcher refreshes both paths before every launch so moving the
package does not leave stale absolute paths. The shipped archive itself remains
path-independent; the absolute path exists only in generated private player
data.

The launch code needs a release-safe path for creating a minimal clean
`fceux.cfg` when the private data directory is new. Existing developer behavior
and command-line options should remain compatible.

Do not pass `-bginput` to Qt `qfceux.exe`. FCEUX 2.6.6 registers that option
only in its separate Windows-native driver. The Qt argument parser rejects it
and then silently skips ROM startup. The launcher handles menu and focus risks
through its private configuration, blanked Alt hotkeys, and bounded input
recovery instead.

The bundled FCEUX executable is built from upstream tag `v2.6.6`, commit
`34eb7601c415b81901fd02afbd5cfdc84b5047ac`, plus
`release\fceux-v2.6.6-deferred-startup-lua.patch`. That patch defers configured
Lua startup until the first completed emulation frame so `main.lua` can call
`emu.frameadvance()` without blocking the emulator worker before it starts.
`release\build_fceux_runtime.ps1` produces the runtime and its required
`FCEUX-ACCESSIBILITY-BUILD.txt` marker. The player package builder refuses an
unmarked stock runtime.

### Speech runtime

Do not copy the current `.venv`; Python virtual environments contain machine-
specific paths and are not a portable distribution format. Build a clean
64-bit embedded Python runtime, install only pinned runtime dependencies into
it, enable its local site-packages path, and set `speech_python_cmd` to that
relative executable in the release configuration.

FCEUX 2.6.6 does not expose LuaJIT FFI, so the Python bridge is the required
player speech path. The release build should not treat the optional BizHawk
Tolk DLL path as a player prerequisite.

### ROM validation

Keep ROM fingerprints in a small data file or single setup function covered by
tests. Hash the complete file, including its iNES header. Reject unknown hashes
before starting FCEUX because RAM addresses and decoded map data are revision
specific.

### Packaging

Create a deterministic packaging script with an explicit runtime manifest.
Fail the build if any of these are present in the player archive:

- ROMs, battery saves, or savestates;
- `.git`, `.env`, `.venv`, `node_modules`, `.tools`, or assistant directories;
- test files, handoffs, work notes, map-reference images, or diagnostic dumps;
- nonempty command queues or logs containing developer paths or play data.

Fail the build if a required Lua module, launcher, runtime binary, clean config,
README, keyboard reference, license, or source-compliance artifact is absent.
Generate a manifest containing release version, relative path, byte size, and
SHA-256 for every packaged file.

## Verification matrix

The installation is not release-ready until all of these pass from a newly
extracted package, not the development checkout:

1. Windows 11, JAWS, path containing spaces, no system Python, no prior FCEUX
   config.
2. Windows 11, NVDA, non-ASCII Windows username or extraction path. NVDA and a
   non-ASCII extraction path have passed; a non-ASCII Windows username remains
   untested.
3. Supported ROM selected through the file picker.
4. Supported ROM placed beside the installer and detected automatically.
5. Wrong revision: clear rejection with actual size and hash; no emulator
   launch.
6. Hacked ROM override: warning and safe cancellation by default; exact
   acknowledgement permits only the accepted size and SHA-256.
7. Missing or broken speech runtime: clear failure before play, with a readable
   log.
8. Second launch: no setup prompts, existing battery save preserved.
9. Package moved to a different writable folder after setup: paths remain
   relative and play still works.
10. Existing unrelated FCEUX process/configuration: no settings are overwritten.
11. Full play smoke: title, name entry, King dialogue, movement, object
    selection, one battle, save, close, relaunch, and save reload all speak.

The first release candidate should also be tested from a standard downloaded
ZIP so Windows attachment/SmartScreen behavior is observed rather than assumed.

## Verification evidence

### 2026-07-31 real-ROM clean-folder test

The ROM-installation layer passed from a temporary package under `C:\tmp` using
the actual supported US Rev 1 ROM:

- source before and after: 81,936 bytes, SHA-256
  `676B89D76CF9E83EED76C0A67F81DA906916F0BCE321CF3A9A39AC78BC9C0845`;
- installed `user\Dragon Warrior.nes`: the same size and SHA-256;
- first setup exit: 0, with `Supported ROM: Dragon Warrior (USA) (Rev 1)` and
  `ROM installation complete`;
- repeat setup exit: 0, with `The supported ROM is already installed`;
- the already-running FCEUX process remained PID 7852 before and after;
- the temporary package and its copied ROM were removed after verification.

This proves only ROM selection, fingerprinting, safe copying, and repeat-setup
behavior. It does not yet validate the complete FCEUX runtime, private FCEUX
configuration, portable Python runtime, speech output, or player launch path.

### 2026-07-31 private-config and player-isolation tests

The next clean-folder layer passed with the real supported ROM while the
developer FCEUX remained running:

- all nine private FCEUX safety keys were present exactly once;
- a deliberately changed `SDL.ToggleMenu = 0` was repaired to `1` on repeat
  setup;
- an unrelated `SDL.Sound.Volume = 128` preference was preserved;
- the config contained no absolute drive paths;
- the bridge-only keyboard profile and private `sav` directory matched the
  expected package data;
- source and installed ROM hashes remained the supported Rev 1 hash;
- the player launcher's isolated dry run found zero target processes, issued no
  close request, and left the unrelated developer FCEUX at PID 7852;
- both temporary test packages were removed.

This validates private data creation, repeat-setup repair, preservation of
unrelated config values, package-relative path selection, and process
isolation. Actual packaged FCEUX startup and speech remain unverified.

### 2026-07-31 portable speech-runtime test

The pinned speech runtime was built from the official Python 3.14.6 embedded
x64 archive and its downloaded SHA-256 matched the pinned value. All five
binary runtime dependencies installed offline into the staged runtime, and
imports reported `accessible-output2=0.17` and `pywin32=311`.

Live backend probing found a compatibility problem before packaging: the
library's JAWS activity check returned false on the installed JAWS version and
selected SAPI5 in the system Python, development virtual environment, and
portable runtime. Direct JAWS COM speech succeeded. The bridge now detects a
running `jfw.exe` through the Windows process snapshot API and selects the JAWS
backend directly only after automatic selection falls through to SAPI5. NVDA-
only and JAWS-only operation are the required release configurations. If both
screen readers happen to be running, automatic NVDA selection wins as a
defensive fallback; simultaneous operation is not part of the normal player
workflow. The staged portable runtime then reported:

- `speaker=accessible_output2.outputs.jaws.Jaws`;
- `selected_backend=Jaws reason=jfw-process`;
- five focused bridge-selection/dispatch tests passed, including the defensive
  simultaneous-reader case;
- all 15 installer, launcher, and speech-package tests passed;
- the developer FCEUX remained responsive at PID 7852.

This validates the portable runtime build and JAWS-only backend selection on
the development machine. The later clean package tests also validated JAWS
startup from the packaged runtime.

### 2026-07-31 unsupported-ROM opt-in test

The power-user path passed with a temporary ROM made by changing one byte in a
copy of the real supported Rev 1 image:

- the supported source ROM remained unchanged at SHA-256
  `676B89D76CF9E83EED76C0A67F81DA906916F0BCE321CF3A9A39AC78BC9C0845`;
- the modified source, installed copy, and acknowledgement record all matched
  SHA-256
  `A765774F4897D3D97F8658CC9D796E582DA4CC3F8DEAE8112D78842A3ED90653`;
- setup displayed the unsupported-ROM risk warning and accepted the explicit
  `-AllowUnsupportedRom` opt-in;
- player validation displayed the warning and accepted only that exact file;
- automated coverage verifies safe rejection by default, interactive/scripted
  opt-in state, repeat setup, exact-hash launch, and invalidation after a ROM
  change;
- all 17 player installer/launcher tests passed, and the temporary package was
  removed.

### 2026-07-31 deterministic package and Lua-autoload test

The package builder now uses explicit app/FCEUX allowlists, strips Python
bytecode and test caches, rewrites player configuration, requires player docs
and compliance files, generates sorted SHA-256 payload metadata, and writes ZIP
entries in deterministic order with fixed timestamps. Two independent fixture
builds were byte-for-byte identical. Missing project-license input failed
before creating an output directory or ZIP.

An internal real-runtime package built successfully with 694 payload files:

- unpacked payload: 243,171,214 bytes;
- ZIP: 106,393,004 bytes;
- forbidden ROM/save/test/log files: zero;
- real embedded-Python speech verification: passed;
- real Rev 1 install and validation-only launch: passed with matching source
  and installed SHA-256.

Live isolation found that the silent ROM failure was not argument order: the
Qt build rejected the Windows-only `-bginput 0` option and then skipped ROM
loading. Removing it immediately restored title music with stock FCEUX. The
launcher now omits that option in every branch and uses split `--loadlua PATH`
syntax where CLI Lua loading is requested.

Stock Qt FCEUX then loaded configured Lua too early for a frame-advancing
script. A narrow three-file FCEUX patch now defers configured Lua until the
first completed emulation frame. The patch reverse-checks against upstream
tag `v2.6.6`; a fresh reproducible runtime build completed with qfceux SHA-256
`AB8C668B6DFA87352B3911312ACFBE5BB928E36B49CB597AACD8685FDA75EEE1`.

A clean internal package built from that runtime with 695 allowlisted payload
files and ZIP SHA-256
`A606B24C804972F123F5ED9E358E1AE54F41643A94667BE94FFC029B31F0AEDC`.
Its real supported-ROM installation passed. On clean launch, qfceux remained
responsive; package-local `speech_bridge.status` became `READY`; packaged
Python selected JAWS; and the bridge queued the mod-loaded announcement,
`Title screen.`, and the title text. Release debug mode was off and the clean
package contained no diagnostic/bootstrap artifacts before launch.

Two follow-up input/restart failures were found and fixed iteratively. Windows
PowerShell joins `Start-Process -ArgumentList` elements without automatically
quoting spaced paths, so the package keyboard bridge originally exited at the
first space in its script path. Both bridge paths are now explicitly quoted.
On repeat launch, graceful shutdown of the old FCEUX could also overwrite the
already-refreshed `SDL.LuaScript` with a blank value. The launcher now refreshes
both Lua autoload keys after old-process shutdown and before replacement
startup.

The rebuilt package then passed first launch and repeat launch. Each run left
exactly one responsive package qfceux process, one package keyboard bridge with
an advancing heartbeat, populated Lua autoload keys, and speech status
`READY`. The user manually confirmed keyboard input, physical controller input,
and pause-on-main-menu behavior. The ZIP contained zero ROM, save, state,
command-queue, bridge-state, or runtime-log files before test installation.

### 2026-07-31 NVDA-only packaged launch

The rebuilt internal package passed an NVDA-only repeat launch. Process
inspection found `nvda.exe` PID 33080 and no JAWS process. The fresh packaged
speech log recorded `selected_backend=NVDA reason=auto`, then status `READY`
and the mod-loaded, title-screen, and title-text speech commands. The user
manually confirmed that the script came up speaking. qfceux PID 32604 remained
  responsive and the package keyboard heartbeat continued advancing. This
  completed the NVDA backend/startup portion of the matrix before the separate
  non-ASCII extraction-path pass below.

### 2026-07-31 non-ASCII extraction-path package

The first long-path diagnostic opened qfceux but loaded neither the ROM nor Lua.
Passing a Windows 8.3 alias started the ROM, but Windows PowerShell 5.1 then
expanded the Lua alias back to the incompatible Unicode form while refreshing
the private config. The player launcher now creates ASCII aliases for all
FCEUX-facing paths and the developer launcher preserves an already-rooted alias
when writing `SDL.LuaScript` and `SDL.LastLoadLua`.

The clean rebuilt ROM-free ZIP was extracted to
`C:\tmp\DWA Rebuilt 20260731 – naïve тест 日本語`. Setup installed the supported
ROM, and first/repeat launch produced responsive qfceux PIDs 38776 then 27476.
Both runs selected NVDA automatically, wrote `READY`, narrated the title,
retained `C:/tmp/DWAREB~1/DRAGON~1/app/main.lua` in both Lua config keys, and
kept an advancing keyboard heartbeat. The user manually confirmed object
navigation and ordinary keyboard input with the same corrected source. The
rebuilt ZIP has 695 payload files and SHA-256
`4137169FB1A27E8E26E6CDAA157C19C56BF8AE3E1AA46F7967EACBCB99D9A56A`.
This closes non-ASCII extraction-path coverage but does not test a non-ASCII
Windows username.

### 2026-07-31 licensing, source, and runtime-pruning checkpoint

The licensing and source-compliance inputs are now real rather than test
fixtures. Original project work uses the MIT License under Bill Freeman's
name. The package contains FCEUX, Qt, SDL2, libarchive, Lua, NVDA Controller
Client, Python, Python-package, ANGLE, Mesa llvmpipe, and Microsoft runtime
notices as applicable. The strict builder rejects placeholder project,
FCEUX-license, or source-notice inputs.

The modified FCEUX, Qt, and NVDA corresponding source is a same-version sibling
release asset. Two builds of the internal-license1 source ZIP were identical at
SHA-256
`53243A90C3798CD0C95917B22C3A8C94824926D9A471BCEAAD85D22B20059EC7`.

Eight unused FFmpeg DLLs were removed. Qt ANGLE and Mesa `opengl32sw.dll`
remain intentionally as graphics-compatibility fallbacks. Speech packaging now
uses the official pinned 64-bit NVDA Controller Client DLL, no Tolk or JAWS
binaries, and explicit NVDA, installed-JAWS, then SAPI5 selection. Two player
builds were identical at SHA-256
`246086C1CCEFC486EA9B78354324FC31CA0E9D14CB974EEF436882B0B5CA785A`.
The ZIP contains 689 payload files, zero ROM/save or FFmpeg files, one
screen-reader DLL, 17 license entries, and no placeholder license text. Its
size is 47,777,459 bytes, 58,279,624 bytes smaller than the earlier internal
ZIP. The full local smoke suite, 37 release tests, and `git diff --check` pass.

The current internal build still uses temporary README and keyboard-guide
fixtures. Release-ready documents now exist at `README.md` and
`release\Keyboard Commands.txt`, with focused checks against the runtime,
installer, and `dw_access.ini`. The public build is blocked only on choosing
the jam version and filename, rebuilding both same-version assets, and
running separate final NVDA and JAWS acceptance passes plus save/relaunch QA.

## Implementation sequence

1. Completed: ROM validation, setup, and unknown-ROM opt-in.
2. Completed: player launch, private configuration, and failure logging.
3. Completed: pinned portable speech runtime and initial JAWS/NVDA acceptance.
4. Completed: explicit package allowlist, deterministic archives, licenses,
   notices, corresponding source, and archive-policy tests.
5. Completed: use root `README.md` and `release\Keyboard Commands.txt` as the
   player documents.
6. Build the same-version jam player/source assets and complete separate final
   NVDA, JAWS, clean-folder, gameplay, save, exit, and relaunch acceptance.

## Open release decisions

These do not block the first setup implementation:

- final game-jam version number and archive filename;
- whether setup offers an optional desktop shortcut;
- whether Windows 10 remains an explicitly tested target or a best-effort
  target if only Windows 11 test machines are available.
