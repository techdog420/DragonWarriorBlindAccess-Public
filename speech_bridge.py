"""
speech_bridge.py
Bridge between FCEUX Lua scripts and screen reader speech output.

This version writes startup status and runtime diagnostics to files so the
Lua side can distinguish "pipe opened" from "bridge initialized successfully".
"""

from __future__ import annotations

import datetime as _dt
from pathlib import Path
import queue
import sys
import threading
import traceback


def _append_log(log_path: Path, message: str) -> None:
    timestamp = _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(f"[{timestamp}] {message}\n")


def _write_status(status_path: Path, status: str) -> None:
    status_path.write_text(status + "\n", encoding="utf-8")


_STOP = object()


class SpeechDispatcher:
    """Keep stdin responsive even if the screen reader blocks."""

    def __init__(self, speaker, log, max_queue: int = 64):
        self._speaker = speaker
        self._log = log
        self._queue: queue.Queue = queue.Queue(maxsize=max_queue)
        self._thread = threading.Thread(target=self._run, name="speech-dispatch", daemon=True)
        self._thread.start()

    def submit(self, kind: str, text: str = "") -> None:
        if kind == "interrupt":
            self._drop_pending()
        try:
            self._queue.put_nowait((kind, text))
        except queue.Full:
            self._log(f"speech queue full; dropped {kind!r}")

    def close(self, wait: bool = True) -> None:
        try:
            self._queue.put_nowait(_STOP)
        except queue.Full:
            pass
        if wait:
            self._thread.join(timeout=1.0)

    def _drop_pending(self) -> None:
        while True:
            try:
                self._queue.get_nowait()
                self._queue.task_done()
            except queue.Empty:
                return

    def _run(self) -> None:
        while True:
            item = self._queue.get()
            try:
                if item is _STOP:
                    return
                kind, text = item
                if kind == "speak":
                    self._speaker.speak(text, interrupt=False)
                elif kind == "interrupt":
                    self._speaker.speak(text, interrupt=True)
                elif kind == "silence":
                    self._speaker.silence()
                else:
                    self._log(f"ignored unknown dispatch kind: {kind!r}")
            except Exception as exc:
                self._log(f"runtime failure: {exc}")
                self._log(traceback.format_exc().rstrip())
            finally:
                self._queue.task_done()


def run_command_loop(stdin, dispatcher: SpeechDispatcher, log) -> None:
    while True:
        line = stdin.readline()
        if not line:
            log("stdin closed; exiting")
            break

        line = line.strip()
        if not line:
            continue

        log(f"command={line!r}")

        if line.startswith("speak:"):
            dispatcher.submit("speak", line[6:])
        elif line.startswith("interrupt:"):
            dispatcher.submit("interrupt", line[10:])
        elif line == "silence":
            dispatcher.submit("silence")
        else:
            log(f"ignored unknown command: {line!r}")


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
        dispatcher = SpeechDispatcher(speaker, log)
        # Prime the audio pipeline without blocking stdin if the screen reader
        # backend stalls during startup.
        dispatcher.submit("interrupt", " ")
        log("audio pipeline prime queued")
        if status_path is not None:
            _write_status(status_path, "READY")
        print("bridge ready", flush=True)
    except Exception as exc:
        if status_path is not None:
            _write_status(status_path, f"ERROR:{exc}")
        log(f"startup failure: {exc}")
        log(traceback.format_exc().rstrip())
        return 1

    try:
        run_command_loop(sys.stdin, dispatcher, log)
    except KeyboardInterrupt:
        log("keyboard interrupt; exiting")
    finally:
        dispatcher.close(wait=False)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
