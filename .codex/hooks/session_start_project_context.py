#!/usr/bin/env python3

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def find_active_handoff(repo_root: Path) -> str | None:
    handoff_path = repo_root / "session_handoff.md"
    if not handoff_path.exists():
        return None

    for line in handoff_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("- `") and stripped.endswith("`"):
            return stripped[3:-1]
        if stripped.startswith("- "):
            return stripped[2:]
    return None


def main() -> None:
    active_handoff = find_active_handoff(REPO_ROOT)

    reminders = [
        "Read session_handoff.md first for the active handoff set.",
        "Use ./dw_commands.sh in short batches and verify dw_debug.log between state-sensitive steps.",
        "Do not batch teleport_to with probe_edge, survey_target, or similar follow-up commands when exact start state matters.",
        "Prefer runtime blocked-tile evidence before permanent map_reader.lua blocker changes."
    ]

    if active_handoff:
        reminders.insert(1, f"Current active handoff: {active_handoff}.")

    payload = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": " ".join(reminders),
        }
    }
    print(json.dumps(payload))


if __name__ == "__main__":
    main()
