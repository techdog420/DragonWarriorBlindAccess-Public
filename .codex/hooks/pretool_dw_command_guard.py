#!/usr/bin/env python3

import json
import os
import re
import shlex
import sys
from pathlib import PurePosixPath

PROTECTED_BASENAMES = {"dw_commands.txt", "dw_debug.log"}
WRITE_REDIRECTS = {">", ">>", "1>", "1>>", "2>", "2>>", "&>", "&>>"}
DESTRUCTIVE_COMMANDS = {"rm", "truncate", "tee", "cp", "mv", "dd"}
POWERSHELL_WRITE_COMMANDS = {
    "set-content",
    "add-content",
    "out-file",
    "clear-content",
    "remove-item",
    "copy-item",
    "move-item",
}
CONTROL_TOKENS = {";", "&&", "||", "|"}
FOLLOW_UP_PREFIXES = (
    "probe_edge:",
    "survey_target:",
    "report_survey_start",
    "debug_pathfind_to:",
    "debug_pathfind_adjacent:",
)
STATE_SENSITIVE_EXACT = {
    "auto_walk",
    "pathfind",
    "survey_objects",
    "survey_map",
    "report_survey_start",
    "validate_path",
    "start_step_mode",
    "step_path",
    "reload_config",
    "simulate_input",
    "simulate_raw_input",
}
STATE_SENSITIVE_PREFIXES = (
    "teleport_to:",
    "probe_edge:",
    "survey_target:",
    "survey_objects:",
    "survey_map:",
    "report_survey_start:",
    "pathfind_to:",
    "pathfind_adjacent:",
    "debug_pathfind_to:",
    "debug_pathfind_adjacent:",
    "test_path:",
    "simulate_input:",
    "simulate_raw_input:",
)
OPTION_TAKES_VALUE = {
    "--wait",
    "-wait",
    "--timeout",
    "-timeout",
    "--require-live",
    "-requirelive",
    "--wait-ready",
    "-waitready",
}
FLAG_OPTIONS = {"--replace", "-replace", "--json", "-json"}


def deny(reason: str) -> None:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )


def tokenize(command: str) -> list[str]:
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        return list(lexer)
    except ValueError:
        return []


def basename_token(token: str) -> str:
    normalized = token.replace("\\", "/").rstrip("/")
    return PurePosixPath(normalized).name.lower()


def is_protected_path(token: str) -> bool:
    cleaned = token.strip('"\'').replace("\\", "/").lower()
    return any(cleaned == name or cleaned.endswith(f"/{name}") for name in PROTECTED_BASENAMES)


def has_bypass(tokens: list[str]) -> bool:
    if os.environ.get("DW_COMMAND_GUARD_ALLOW_RAW") == "1":
        return True
    return any(token == "DW_COMMAND_GUARD_ALLOW_RAW=1" for token in tokens)


def split_segments(tokens: list[str]) -> list[list[str]]:
    segments: list[list[str]] = []
    current: list[str] = []
    for token in tokens:
        if token in CONTROL_TOKENS:
            if current:
                segments.append(current)
                current = []
            continue
        current.append(token)
    if current:
        segments.append(current)
    return segments


def is_env_assignment(token: str) -> bool:
    return bool(re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", token))


def first_command_index(segment: list[str]) -> int | None:
    i = 0
    while i < len(segment) and is_env_assignment(segment[i]):
        i += 1
    if i < len(segment) and basename_token(segment[i]) == "env":
        i += 1
        while i < len(segment) and is_env_assignment(segment[i]):
            i += 1
    if i >= len(segment):
        return None
    return i


def is_dw_command_token(token: str) -> bool:
    return basename_token(token) in {"dw_commands.sh", "dw_commands.ps1"}


def nested_command_strings(command: str, depth: int = 0) -> list[str]:
    if depth > 2:
        return []
    tokens = tokenize(command)
    found: list[str] = []
    for i, token in enumerate(tokens[:-1]):
        name = basename_token(token)
        lower = token.lower()
        if name in {"bash", "sh", "zsh"}:
            for j in range(i + 1, len(tokens) - 1):
                if tokens[j] in {"-c", "-lc", "-cl"}:
                    found.append(tokens[j + 1])
                    found.extend(nested_command_strings(tokens[j + 1], depth + 1))
                    break
        if "powershell" in name or name == "pwsh":
            for j in range(i + 1, len(tokens) - 1):
                if tokens[j].lower() in {"-command", "-c"}:
                    found.append(tokens[j + 1])
                    found.extend(nested_command_strings(tokens[j + 1], depth + 1))
                    break
        if lower in {"cmd", "cmd.exe"}:
            for j in range(i + 1, len(tokens) - 1):
                if tokens[j].lower() in {"/c", "-c"}:
                    found.append(" ".join(tokens[j + 1 :]))
                    break
    return found


def command_sources(command: str) -> list[tuple[str, list[str]]]:
    sources = [command]
    sources.extend(nested_command_strings(command))
    return [(source, tokenize(source)) for source in sources]


def command_name(segment: list[str]) -> str | None:
    idx = first_command_index(segment)
    if idx is None:
        return None
    return basename_token(segment[idx])


def check_protected_file_writes(tokens: list[str]) -> str | None:
    if has_bypass(tokens):
        return None

    for i, token in enumerate(tokens[:-1]):
        if token in WRITE_REDIRECTS and is_protected_path(tokens[i + 1]):
            return "Do not write or truncate dw_commands.txt/dw_debug.log directly; use dw_commands helpers or inspect logs read-only."
        if re.fullmatch(r"\d*>{1,2}", token) and is_protected_path(tokens[i + 1]):
            return "Do not write or truncate dw_commands.txt/dw_debug.log directly; use dw_commands helpers or inspect logs read-only."

    for segment in split_segments(tokens):
        name = command_name(segment)
        if not name:
            continue
        lower_tokens = {token.lower() for token in segment}
        if name in DESTRUCTIVE_COMMANDS and any(is_protected_path(token) for token in segment[1:]):
            return "Do not use raw file operations on dw_commands.txt or dw_debug.log unless explicitly debugging the harness with DW_COMMAND_GUARD_ALLOW_RAW=1."
        if lower_tokens & POWERSHELL_WRITE_COMMANDS and any(is_protected_path(token) for token in segment):
            return "Do not use raw PowerShell file operations on dw_commands.txt or dw_debug.log unless explicitly debugging the harness."
        if name in {"sed", "perl"} and any(token == "-i" or token.startswith("-i") for token in segment[1:]) and any(is_protected_path(token) for token in segment[1:]):
            return "Do not edit dw_commands.txt or dw_debug.log in place."
        if name == "dd" and any(token.lower().startswith("of=") and is_protected_path(token[3:]) for token in segment[1:]):
            return "Do not write dw_commands.txt or dw_debug.log through dd."
    return None


def has_reload_confirmation(tokens: list[str]) -> bool:
    lowered = [token.lower() for token in tokens]
    return any(
        token in {"--wait", "-wait", "--wait-ready", "-waitready"}
        or token.startswith("launcher_probe:")
        for token in lowered
    )


def check_reload_trigger(tokens: list[str]) -> str | None:
    for segment in split_segments(tokens):
        name = command_name(segment)
        if name == "touch" and any(basename_token(token) == "main.lua" for token in segment[1:]):
            if not has_reload_confirmation(tokens):
                return "After touching main.lua for a Lua reload, include --wait-ready/--wait or a launcher_probe follow-up so stale loops are detected."
    return None


def parse_dw_invocation(segment: list[str], command_index: int) -> tuple[bool, list[str]]:
    has_replace = False
    queued: list[str] = []
    i = command_index + 1
    while i < len(segment):
        token = segment[i]
        lower = token.lower()
        if token == "--":
            queued.extend(segment[i + 1 :])
            break
        if lower in FLAG_OPTIONS:
            if lower in {"--replace", "-replace"}:
                has_replace = True
            i += 1
            continue
        if lower in OPTION_TAKES_VALUE:
            i += 2
            continue
        if token.startswith("-"):
            i += 1
            continue
        queued.extend(segment[i:])
        break
    return has_replace, queued


def is_state_sensitive(command: str) -> bool:
    lower = command.lower()
    base = lower.split(":", 1)[0]
    return (
        lower in STATE_SENSITIVE_EXACT
        or base in STATE_SENSITIVE_EXACT
        or any(lower.startswith(prefix) for prefix in STATE_SENSITIVE_PREFIXES)
    )


def command_categories(commands: list[str]) -> set[str]:
    categories: set[str] = set()
    for command in commands:
        lower = command.lower()
        if lower.startswith("teleport_to:"):
            categories.add("teleport")
        if lower.startswith(("probe_edge:", "auto_walk", "simulate_input:", "simulate_raw_input:")):
            categories.add("movement")
        if lower.startswith(("survey_", "report_survey_")):
            categories.add("survey")
        if lower.startswith(("report_", "log_state", "speech_status", "input_status")):
            categories.add("log")
    return categories


def check_dw_invocation(tokens: list[str]) -> str | None:
    if has_bypass(tokens):
        return None

    for segment in split_segments(tokens):
        for idx, token in enumerate(segment):
            if not is_dw_command_token(token):
                continue
            has_replace, queued = parse_dw_invocation(segment, idx)
            lowered = [command.lower() for command in queued]

            if "teleport_to:" in " ".join(lowered) and any(
                any(command.startswith(prefix) for prefix in FOLLOW_UP_PREFIXES) for command in lowered
            ):
                return (
                    "Split state-sensitive dw_commands batches: send teleport_to plus report_position first, "
                    "wait for dw_debug.log confirmation, then send probe, survey, or path-debug commands separately."
                )

            if any(is_state_sensitive(command) for command in queued) and not has_replace:
                return "Use --replace for state-sensitive dw_commands batches so stale queued commands do not contaminate the next observation."

            categories = command_categories(queued)
            if len(queued) > 4 and len(categories) > 1:
                return "Split large mixed dw_commands batches into short command groups with log verification between state-sensitive steps."
    return None


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return

    tool_input = payload.get("tool_input", {})
    command = tool_input.get("command") or tool_input.get("cmd") or ""
    if not isinstance(command, str) or not command:
        return

    for _source, tokens in command_sources(command):
        if not tokens:
            continue
        for check in (check_protected_file_writes, check_reload_trigger, check_dw_invocation):
            reason = check(tokens)
            if reason:
                deny(reason)
                return


if __name__ == "__main__":
    main()
