"""
speech_bridge.py
Bridge between FCEUX Lua scripts and screen reader speech output.

This version writes startup status and runtime diagnostics to files so the
Lua side can distinguish "pipe opened" from "bridge initialized successfully".
"""

from __future__ import annotations

import datetime as _dt
import ctypes
from ctypes import wintypes
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


def _running_process_names() -> set[str]:
    """Return Windows process image names without elevated access or a console."""

    if sys.platform != "win32":
        return set()

    class ProcessEntry(ctypes.Structure):
        _fields_ = [
            ("dwSize", wintypes.DWORD),
            ("cntUsage", wintypes.DWORD),
            ("th32ProcessID", wintypes.DWORD),
            ("th32DefaultHeapID", ctypes.c_size_t),
            ("th32ModuleID", wintypes.DWORD),
            ("cntThreads", wintypes.DWORD),
            ("th32ParentProcessID", wintypes.DWORD),
            ("pcPriClassBase", wintypes.LONG),
            ("dwFlags", wintypes.DWORD),
            ("szExeFile", wintypes.WCHAR * 260),
        ]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel32.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(ProcessEntry)]
    kernel32.Process32FirstW.restype = wintypes.BOOL
    kernel32.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(ProcessEntry)]
    kernel32.Process32NextW.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

    snapshot = kernel32.CreateToolhelp32Snapshot(0x00000002, 0)
    invalid_handle = ctypes.c_void_p(-1).value
    if snapshot == invalid_handle:
        return set()

    names = set()
    try:
        entry = ProcessEntry()
        entry.dwSize = ctypes.sizeof(entry)
        if kernel32.Process32FirstW(snapshot, ctypes.byref(entry)):
            while True:
                names.add(entry.szExeFile.casefold())
                if not kernel32.Process32NextW(snapshot, ctypes.byref(entry)):
                    break
    finally:
        kernel32.CloseHandle(snapshot)
    return names


def create_speaker(
    log,
    process_names=None,
    nvda_factory=None,
    jaws_factory=None,
    sapi_factory=None,
):
    """Select only release-supported speech outputs: NVDA, JAWS, or SAPI."""

    if process_names is None:
        process_names = _running_process_names()
    normalized_names = {name.casefold() for name in process_names}

    try:
        if nvda_factory is None:
            from accessible_output2.outputs.nvda import NVDA

            nvda_factory = NVDA
        nvda_speaker = nvda_factory()
        if nvda_speaker.is_active():
            log("selected_backend=NVDA reason=active")
            return nvda_speaker
    except Exception as exc:
        log(f"NVDA backend unavailable: {exc}")

    if "jfw.exe" in normalized_names or "jfw" in normalized_names:
        try:
            if jaws_factory is None:
                from accessible_output2.outputs.jaws import Jaws

                jaws_factory = Jaws
            speaker = jaws_factory()
            log("selected_backend=Jaws reason=jfw-process")
            return speaker
        except Exception as exc:
            log(f"JAWS direct backend failed; falling back to SAPI: {exc}")

    if sapi_factory is None:
        from accessible_output2.outputs.sapi5 import SAPI5

        sapi_factory = SAPI5
    speaker = sapi_factory()
    log("selected_backend=SAPI5 reason=fallback")
    return speaker


class SpeechDispatcher:
    """Keep stdin responsive even if the screen reader blocks."""

    def __init__(self, speaker, log, max_queue: int = 64):
        self._speaker = speaker
        self._log = log
        self._queue: queue.Queue = queue.Queue(maxsize=max_queue)
        self._closing = threading.Event()
        self._thread = threading.Thread(target=self._run, name="speech-dispatch", daemon=True)
        self._thread.start()

    def submit(self, kind: str, text: str = "") -> None:
        if self._closing.is_set():
            return
        if kind in {"interrupt", "silence"}:
            self._drop_pending()
        try:
            self._queue.put_nowait((kind, text))
        except queue.Full:
            self._log(f"speech queue full; dropped {kind!r}")

    def close(self, wait: bool = True) -> None:
        # A sentinel can be lost when the bounded queue is full. A separate
        # event lets the worker drain accepted commands and then always exit.
        self._closing.set()
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
            if self._closing.is_set() and self._queue.empty():
                return
            try:
                item = self._queue.get(timeout=0.1)
            except queue.Empty:
                continue
            try:
                kind, text = item
                if kind == "speak":
                    self._speaker.speak(text, interrupt=False)
                elif kind == "interrupt":
                    self._speaker.speak(text, interrupt=True)
                elif kind == "silence":
                    silence = getattr(self._speaker, "silence", None)
                    if callable(silence):
                        silence()
                    else:
                        # accessible-output2's JAWS backend exposes only speak.
                        self._speaker.speak("", interrupt=True)
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
        log("imported accessible_output2")
        speaker = create_speaker(log)
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
