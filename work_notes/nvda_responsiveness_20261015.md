# NVDA responsiveness investigation - 2026-10-15

Status: bounded initial investigation complete; perceived NVDA-versus-JAWS
delay remains unresolved. No production code, reader settings, or package
artifacts changed. FCEUX stayed closed during these probes.

## Finding

The standalone mod bridge was fast in this run. Nine labeled samples used the
same portable Python, accessible-output2 backend, pinned controller DLL, and
production `speech_bridge.main` / `SpeechDispatcher` code as the candidate.
Diagnostic wrappers collected timing in the probe process only.

- Parent pipe write to backend call: median 0.516 ms, maximum 0.653 ms.
- Bridge worker queue wait: median 0.056 ms, maximum 0.075 ms.
- Backend dispatch, including cancel/speak for interrupt speech: median
  0.430 ms, maximum 0.574 ms.
- NVDA cancel RPC: median 0.336 ms; speak RPC: median 0.093 ms.
- All nine samples dispatched; all recorded controller return codes were zero.

These are API submission timings, not audible-onset measurements. The user
could not confidently judge whether these isolated samples felt delayed.

A separate supported SSML beginning-mark callback probe returned marks at
30.596, 53.363, and 51.357 ms (median 51.357 ms). All three valid calls returned
zero. This uses a different controller entry point from normal game speech
and is a proxy for downstream speech processing, not microphone/loopback
measurement of sound. Total synchronous call durations (285-303 ms) include
the spoken sample and must not be interpreted as startup latency.

An initial marker attempt was cancelled (1223) because the diagnostic queued
cancel immediately before registering synchronous speech. Those attempts
produced no marks and are excluded. A 150 ms settling interval after cancel
made the diagnostic valid; that interval is outside the measured mark time
and is not a proposed mod change.

## Source and environment checks

- NVDA and JAWS share the same flushed Lua pipe and bridge worker.
- Object browsing calls `tolk.output_interrupt`, bypassing duplicate-message
  debounce. Debounce suppresses repeated queued text; it does not sleep.
- NVDA's interrupt adapter calls cancel then speak; JAWS uses one `SayString`
  COM call. The measured NVDA pair is too small here to explain a substantial
  perceived pause by itself.
- Ordinary dialogue intentionally waits 30 unchanged frames (about 0.5 s at
  60 fps); battle dialogue uses a shorter threshold. Those rules do not vary
  by reader. They explain some absolute dialogue wait, not the reported
  reader difference on their own.
- Current NVDA log identifies version 2026.2 AMD64 and synth `sapi5`; saved
  speech config selects Eloquence, rate 80. Saved audio settings have ducking
  disabled, a 30-second keep-awake interval, and default output device.
  No live profile/setting was changed or exhaustively introspected.
- NVDA's version-matched controller implementation queues both speakText and
  cancelSpeech onto its own event queue before returning. A successful RPC
  return therefore does not establish speech onset.
- Recent NVDA warnings visible while Codex was foreground concerned Chromium
  accessibility objects. They are not evidence of a game-specific delay.

Primary references:

- [NVDA 2026.2 controller implementation](https://github.com/nvaccess/nvda/blob/release-2026.2/source/NVDAHelper/__init__.py)
- [NVDA 2026.2 SAPI5 driver](https://github.com/nvaccess/nvda/blob/release-2026.2/source/synthDrivers/sapi5.py)
- [NVDA 2026.2 audio and speech settings](https://download.nvaccess.org/releases/2026.2/documentation/en/userGuide.html#SpeechSettings)

## Limits and next useful check

This does not measure physical key-to-object handling, actual sound onset,
JAWS latency, or NVDA behavior under representative game load. It does not
establish a synth, add-on, or audio-driver fault, nor exclude an upstream
game-side issue. No speculative timeout, debounce, dialogue threshold, or
speech-backend change is justified from these measurements.

The next useful check is a controlled in-game input-to-audio comparison of the
same short phrases and object actions, with submission timestamps separated
from actual audio onset. If isolating the synth later, change one reader
setting/profile at a time with the player and retain a way back.

Structured results: `work_notes/nvda_responsiveness_20261015.json`.
Local probe scripts, raw timings, and logs:
`.test_tmp/speech_latency_20261015/` (`probe.py`, `mark_probe.py`, `result.json`,
`mark-result.json`, and `bridge.log`). The scripts are local diagnostic helpers,
not release inputs. Package ZIP hashes still match the qualified pair.
