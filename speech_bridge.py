"""
speech_bridge.py
Bridge between FCEUX Lua scripts and screen reader speech output.

This version writes startup status and runtime diagnostics to files so the
Lua side can distinguish "pipe opened" from "bridge initialized successfully".
"""

from __future__ import annotations

import datetime as _dt
from pathlib import Path
import sys
import traceback


def _append_log(log_path: Path, message: str) -> None:
    timestamp = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(f"[{timestamp}] {message}\n")


def _write_status(status_path: Path, status: str) -> None:
    status_path.write_text(status + "\n", encoding="utf-8")


def main() -> int:
    # Status and log file paths are optional.
    # Old tolk.lua (pre-FFI-rewrite) passed them as argv[1] and argv[2].
    # New tolk.lua launches the bridge without arguments and communicates
    # purely via stdin/stdout. When omitted, status/log file writing is skipped.
    status_path = Path(sys.argv[1]) if len(sys.argv) >= 2 else None
    log_path = Path(sys.argv[2]) if len(sys.argv) >= 3 else None

    def log(message: str) -> None:
        if log_path is not None:
            _append_log(log_path, message)

    if log_path is not None:
        log_path.write_text("=== speech_bridge session start ===\n", encoding="utf-8")
    log(f"python={sys.executable}")
    log(f"argv={sys.argv!r}")

    try:
        from accessible_output2.outputs.auto import Auto

        log("imported accessible_output2")
        speaker = Auto()
        log(f"speaker={speaker!r}")

        # Prime the audio pipeline. Sound cards and Bluetooth devices often
        # clip the first utterance after silence unless the speech stack is
        # already awake.
        speaker.speak(" ", interrupt=True)
        log("audio pipeline primed")
        if status_path is not None:
            _write_status(status_path, "READY")
        print("bridge ready", flush=True)
    except Exception as exc:
        if status_path is not None:
            _write_status(status_path, f"ERROR:{exc}")
        log(f"startup failure: {exc}")
        log(traceback.format_exc().rstrip())
        return 1

    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                log("stdin closed; exiting")
                break

            line = line.strip()
            if not line:
                continue

            log(f"command={line!r}")

            if line.startswith("speak:"):
                speaker.speak(line[6:], interrupt=False)
            elif line.startswith("interrupt:"):
                speaker.speak(line[10:], interrupt=True)
            elif line == "silence":
                speaker.silence()
            else:
                log(f"ignored unknown command: {line!r}")
        except KeyboardInterrupt:
            log("keyboard interrupt; exiting")
            break
        except Exception as exc:
            log(f"runtime failure: {exc}")
            log(traceback.format_exc().rstrip())

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
