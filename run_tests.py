#!/usr/bin/env python3
"""
run_tests.py
Local test runner for the Dragon Warrior accessibility mod.

This is intentionally lightweight: it validates the pieces we can test
outside FCEUX so regressions are caught before doing emulator-driven checks.
"""

from __future__ import annotations

import argparse
import importlib
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parent

LUA_FILES = [
    "addresses.lua",
    "auto_step.lua",
    "chars.lua",
    "config.lua",
    "debug_tools.lua",
    "encoding.lua",
    "items.lua",
    "main.lua",
    "map_reader.lua",
    "maps.lua",
    "memory.lua",
    "menu.lua",
    "navigation.lua",
    "objects.lua",
    "pathfinder.lua",
    "state.lua",
    "test_env.lua",
    "test_screen.lua",
    "test_speech.lua",
    "text.lua",
    "tolk.lua",
]

PYTHON_FILES = [
    "speech_bridge.py",
    "test_tolk.py",
    "run_tests.py",
]


def parse_ini_value(text: str, key: str) -> str | None:
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        if "=" not in line:
            continue
        lhs, rhs = line.split("=", 1)
        if lhs.strip() == key:
            return rhs.strip()
    return None


def get_configured_python() -> Path | None:
    ini_path = ROOT / "dw_access.ini"
    if not ini_path.exists():
        return None
    text = ini_path.read_text(encoding="utf-8")
    python_cmd = parse_ini_value(text, "speech_python_cmd")
    if not python_cmd:
        return None
    normalized = python_cmd.replace("\\", os.sep)
    candidate = Path(normalized)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    return candidate


def run_command(label: str, cmd: list[str]) -> tuple[bool, str]:
    proc = subprocess.run(
        cmd,
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    output = (proc.stdout + proc.stderr).strip()
    if proc.returncode == 0:
        return True, output
    return False, output or f"command failed with exit code {proc.returncode}"


def check_lua_syntax() -> tuple[bool, str]:
    luac = shutil_which("luac")
    if not luac:
        return False, "luac not found on PATH"
    cmd = [luac, "-p", *LUA_FILES]
    return run_command("lua syntax", cmd)


def check_python_syntax() -> tuple[bool, str]:
    cmd = [sys.executable, "-m", "py_compile", *PYTHON_FILES]
    return run_command("python syntax", cmd)


def check_python_dependency() -> tuple[bool, str]:
    configured_python = get_configured_python()
    if configured_python is not None:
        if not configured_python.exists():
            return False, f"configured speech_python_cmd missing: {configured_python}"
        if os.name != "nt" and configured_python.suffix.lower() == ".exe":
            return True, (
                "configured speech_python_cmd is a Windows interpreter; "
                "dependency import must be verified from Windows/FCEUX"
            )
        ok, detail = run_command(
            "speech dependency",
            [
                str(configured_python),
                "-c",
                "import accessible_output2; print('accessible_output2 import OK')",
            ],
        )
        if ok:
            return True, f"{detail} via {configured_python}"
        return False, f"accessible_output2 missing for speech_python_cmd {configured_python}: {detail}"

    try:
        importlib.import_module("accessible_output2")
    except Exception as exc:
        return False, (
            "accessible_output2 missing: "
            f"{exc}. Create a project venv and install it there."
        )
    return True, "accessible_output2 import OK"


def check_bridge_config() -> tuple[bool, str]:
    configured_python = get_configured_python()
    if configured_python is None:
        ini_path = ROOT / "dw_access.ini"
        if not ini_path.exists():
            return True, "dw_access.ini not present; default speech_python_cmd will be used"
        text = ini_path.read_text(encoding="utf-8")
        python_cmd = parse_ini_value(text, "speech_python_cmd")
        if not python_cmd:
            return True, "speech_python_cmd not set; default interpreter will be used"
        return False, "speech_python_cmd set but could not be resolved"

    if configured_python.exists():
        return True, f"speech_python_cmd OK: {configured_python}"
    return False, f"speech_python_cmd missing target: {configured_python}"


def check_command_queue() -> tuple[bool, str]:
    cmd_file = ROOT / "dw_commands.txt"
    backup = None
    if cmd_file.exists():
        backup = cmd_file.read_text(encoding="utf-8")
    try:
        cmd_file.write_text("", encoding="utf-8")
        first = subprocess.run(
            ["bash", "dw_commands.sh", "alpha", "beta"],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        second = subprocess.run(
            ["bash", "dw_commands.sh", "gamma"],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        contents = cmd_file.read_text(encoding="utf-8").splitlines()
        ok = first.returncode == 0 and second.returncode == 0 and contents == ["alpha", "beta", "gamma"]
        if ok:
            return True, "dw_commands.sh append queue OK"
        detail = [
            f"first exit={first.returncode}",
            f"second exit={second.returncode}",
            f"contents={contents!r}",
        ]
        return False, "; ".join(detail)
    finally:
        if backup is None:
            try:
                cmd_file.unlink()
            except FileNotFoundError:
                pass
        else:
            cmd_file.write_text(backup, encoding="utf-8")


def shutil_which(name: str) -> str | None:
    for path_dir in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(path_dir) / name
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Run local smoke tests.")
    parser.add_argument(
        "--allow-missing-speech-dep",
        action="store_true",
        help="Do not fail the run if accessible_output2 is not installed.",
    )
    args = parser.parse_args()

    checks = [
        ("Lua syntax", check_lua_syntax),
        ("Python syntax", check_python_syntax),
        ("Bridge config", check_bridge_config),
        ("Speech dependency", check_python_dependency),
        ("Command queue", check_command_queue),
    ]

    failures = 0
    for name, fn in checks:
        ok, detail = fn()
        if name == "Speech dependency" and args.allow_missing_speech_dep and not ok:
            print(f"WARN  {name}: {detail}")
            continue
        status = "PASS" if ok else "FAIL"
        print(f"{status:<5} {name}: {detail or 'OK'}")
        if not ok:
            failures += 1

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
