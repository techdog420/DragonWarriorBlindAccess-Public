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
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent

LUA_FILES = [
    "addresses.lua",
    "auto_step.lua",
    "battle.lua",
    "chars.lua",
    "config.lua",
    "debug_tools.lua",
    "edge_flow_guard.lua",
    "edge_verify_classifier.lua",
    "emulator_compat.lua",
    "encoding.lua",
    "field_action_guard.lua",
    "hotkey_filter.lua",
    "items.lua",
    "main.lua",
    "map_survey.lua",
    "map_reader.lua",
    "maps.lua",
    "memory.lua",
    "merchant.lua",
    "menu.lua",
    "navigation.lua",
    "object_commands.lua",
    "objects.lua",
    "path_debug.lua",
    "pathfinder.lua",
    "route_manager.lua",
    "route_frontier_classifier.lua",
    "scan_profiler.lua",
    "state.lua",
    "test_auto_step.lua",
    "test_battle.lua",
    "test_config.lua",
    "test_edge_flow_guard.lua",
    "test_edge_verify_classifier.lua",
    "test_emulator_compat.lua",
    "test_field_action_guard.lua",
    "test_env.lua",
    "test_game_snapshot.lua",
    "test_key_combo.lua",
    "test_hotkeys.lua",
    "test_hotkey_filter.lua",
    "test_items.lua",
    "test_maps.lua",
    "test_map_survey.lua",
    "test_map_reader.lua",
    "test_object_commands.lua",
    "test_path_debug.lua",
    "test_merchant.lua",
    "test_menu.lua",
    "test_objects.lua",
    "test_pathfinder.lua",
    "test_route_manager.lua",
    "test_route_frontier_classifier.lua",
    "test_screen.lua",
    "test_state.lua",
    "test_speech.lua",
    "text.lua",
    "tolk.lua",
]

LUA_TEST_FILES = [
    "test_pathfinder.lua",
    "test_auto_step.lua",
    "test_battle.lua",
    "test_config.lua",
    "test_edge_flow_guard.lua",
    "test_edge_verify_classifier.lua",
    "test_emulator_compat.lua",
    "test_field_action_guard.lua",
    "test_game_snapshot.lua",
    "test_key_combo.lua",
    "test_hotkeys.lua",
    "test_hotkey_filter.lua",
    "test_items.lua",
    "test_maps.lua",
    "test_map_survey.lua",
    "test_map_reader.lua",
    "test_object_commands.lua",
    "test_path_debug.lua",
    "test_merchant.lua",
    "test_menu.lua",
    "test_objects.lua",
    "test_route_manager.lua",
    "test_route_frontier_classifier.lua",
    "test_state.lua",
]

PYTHON_FILES = [
    "speech_bridge.py",
    "test_player_install.py",
    "test_player_launch.py",
    "test_player_package.py",
    "test_release_keyboard_guide.py",
    "test_release_licenses.py",
    "test_release_readme.py",
    "test_speech_bridge.py",
    "test_speech_runtime_package.py",
    "test_tolk.py",
    "run_tests.py",
]

SHELL_FILES = [
    "dw_commands.sh",
    "launch_dw.sh",
    "launch_bizhawk.sh",
    "launch_fceux.sh",
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


def get_configured_python() -> Path | str | None:
    ini_path = ROOT / "dw_access.ini"
    if not ini_path.exists():
        return None
    text = ini_path.read_text(encoding="utf-8")
    python_cmd = parse_ini_value(text, "speech_python_cmd")
    if not python_cmd:
        return None

    if "/" not in python_cmd and "\\" not in python_cmd:
        resolved = shutil_which(python_cmd)
        return resolved or python_cmd

    normalized = python_cmd.replace("\\", os.sep)
    candidate = Path(normalized)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    return candidate


def run_command(label: str, cmd: list[str]) -> tuple[bool, str]:
    try:
        proc = subprocess.run(
            cmd,
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
    except FileNotFoundError as exc:
        return False, f"{cmd[0]} not found: {exc}"
    output = (proc.stdout + proc.stderr).strip()
    if proc.returncode == 0:
        return True, output
    return False, output or f"command failed with exit code {proc.returncode}"


def get_lua_runtime() -> str | None:
    return shutil_which("lua") or shutil_which("luajit")


def check_lua_syntax() -> tuple[bool, str]:
    luac = shutil_which("luac")
    if luac:
        cmd = [luac, "-p", *LUA_FILES]
        return run_command("lua syntax", cmd)

    lua = get_lua_runtime()
    if not lua:
        return False, "luac not found on PATH and no lua/luajit runtime is available"

    # LuaJIT can syntax-check by compiling bytecode to a temp file.
    # os.devnull is not reliable here: on Linux LuaJIT treats "nul" as a
    # literal filename and writes a file in cwd instead of discarding output.
    if Path(lua).name.lower().startswith("luajit"):
        outputs: list[str] = []
        tmp_fd, tmp_path = tempfile.mkstemp(suffix=".luac")
        os.close(tmp_fd)
        try:
            for lua_file in LUA_FILES:
                ok, detail = run_command("luajit syntax", [lua, "-b", lua_file, tmp_path])
                if not ok:
                    return False, f"{lua_file}: {detail}"
                outputs.append(detail)
        finally:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
        return True, "\n".join(outputs)

    return False, "luac not found on PATH"


def check_python_syntax() -> tuple[bool, str]:
    cmd = [sys.executable, "-m", "py_compile", *PYTHON_FILES]
    return run_command("python syntax", cmd)


def check_shell_syntax() -> tuple[bool, str]:
    bash = get_bash_runtime()
    if not bash:
        return False, "bash not found on PATH"
    return run_command("shell syntax", [bash, "-n", *SHELL_FILES])


def check_lua_unit_tests() -> tuple[bool, str]:
    lua = get_lua_runtime()
    if not lua:
        return False, "lua/luajit not found on PATH"
    outputs: list[str] = []
    for test_file in LUA_TEST_FILES:
        ok, detail = run_command("lua unit tests", [lua, test_file])
        if not ok:
            return False, f"{test_file}: {detail}"
        outputs.append(detail)
    return True, "\n".join(outputs)


def check_python_dependency() -> tuple[bool, str]:
    configured_python = get_configured_python()
    if configured_python is not None:
        if isinstance(configured_python, Path) and not configured_python.exists():
            return False, f"configured speech_python_cmd missing: {configured_python}"
        if isinstance(configured_python, Path) and os.name != "nt" and configured_python.suffix.lower() == ".exe":
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

    if isinstance(configured_python, Path):
        if configured_python.exists():
            return True, f"speech_python_cmd OK: {configured_python}"
        return False, f"speech_python_cmd missing target: {configured_python}"

    return True, f"speech_python_cmd OK (command): {configured_python}"


def check_command_queue() -> tuple[bool, str]:
    bash = get_bash_runtime()
    if not bash:
        return False, "bash not found on PATH"

    bash_dir = Path(bash).parent
    if bash_dir.parent.name.casefold() == "usr":
        git_root = bash_dir.parent.parent
    else:
        git_root = bash_dir.parent
    helper_dir = git_root / "usr" / "bin"

    path_prefixes = []
    if helper_dir.is_dir() and helper_dir != bash_dir:
        path_prefixes.append(str(helper_dir))
    path_prefixes.append(str(bash_dir))

    child_env = os.environ.copy()
    original_path = child_env.get("PATH", "")
    if original_path:
        path_prefixes.append(original_path)
    child_env["PATH"] = os.pathsep.join(path_prefixes)

    with tempfile.TemporaryDirectory(prefix="dw_commands_test_") as tmp:
        tmp_path = Path(tmp)
        script_path = tmp_path / "dw_commands.sh"
        cmd_file = tmp_path / "dw_commands.txt"
        shutil.copy2(ROOT / "dw_commands.sh", script_path)
        cmd_file.write_text("", encoding="utf-8")
        first = subprocess.run(
            [bash, str(script_path), "freeze_npcs", "debug_pathfind_to:3,3"],
            cwd=tmp_path,
            text=True,
            capture_output=True,
            env=child_env,
        )
        second = subprocess.run(
            [bash, str(script_path), "validate_path"],
            cwd=tmp_path,
            text=True,
            capture_output=True,
            env=child_env,
        )
        contents = cmd_file.read_text(encoding="utf-8").splitlines()
        ok = (
            first.returncode == 0
            and second.returncode == 0
            and contents == ["freeze_npcs", "debug_pathfind_to:3,3", "validate_path"]
        )
        if ok:
            return True, "dw_commands.sh append queue OK"
        detail = [
            f"first exit={first.returncode}",
            f"second exit={second.returncode}",
            f"contents={contents!r}",
        ]
        return False, "; ".join(detail)


def shutil_which(name: str) -> str | None:
    return shutil.which(name)


def get_bash_runtime() -> str | None:
    if os.name == "nt":
        git_bash = Path(r"C:\Program Files\Git\bin\bash.exe")
        if git_bash.is_file():
            return str(git_bash)
    return shutil_which("bash")


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
        ("Lua unit tests", check_lua_unit_tests),
        ("Shell syntax", check_shell_syntax),
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
