#!/usr/bin/env python3

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def read_section(path: Path, heading: str) -> list[str]:
    if not path.exists():
        return []

    lines = path.read_text(encoding="utf-8").splitlines()
    marker = f"## {heading}"
    in_section = False
    collected: list[str] = []
    for line in lines:
        if line.strip() == marker:
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if in_section:
            collected.append(line.rstrip())
    return collected


def first_paragraph(lines: list[str]) -> str | None:
    paragraph: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            if paragraph:
                break
            continue
        if stripped.startswith("-") and not paragraph:
            continue
        paragraph.append(stripped)
    if not paragraph:
        return None
    return " ".join(paragraph)


def main() -> None:
    handoff_path = REPO_ROOT / "session_handoff.md"
    current_focus = first_paragraph(read_section(handoff_path, "Current Focus"))

    reminders = [
        "Read AGENTS.md and session_handoff.md first for active Dragon Warrior work.",
        "BizHawk is the primary runtime; keep FCEUX as an explicit fallback unless the task targets it.",
        "Use ./dw_commands.ps1 in PowerShell/Codex, or ./dw_commands.sh in bash, in short batches and verify dw_debug.log between state-sensitive steps.",
        "Use --replace plus --wait/--wait-ready for state-sensitive command batches; use --require-live when stale logs would mislead the result.",
        "Do not batch teleport_to with probe_edge, survey_target, report_survey_start, or path-debug follow-up commands when exact start state matters.",
        "Prefer runtime blocked-tile evidence before permanent map_reader.lua blocker changes.",
    ]

    if current_focus:
        reminders.insert(1, f"Current focus: {current_focus}")

    payload = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": " ".join(reminders),
        }
    }
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
