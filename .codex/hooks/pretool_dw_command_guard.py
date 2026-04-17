#!/usr/bin/env python3

import json
import sys


FOLLOW_UP_TOKENS = (
    "probe_edge:",
    "survey_target:",
    "report_survey_start",
    "debug_pathfind_to:",
    "debug_pathfind_adjacent:",
)


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return

    command = payload.get("tool_input", {}).get("command", "")
    if "./dw_commands.sh" not in command:
        return

    if "teleport_to:" not in command:
        return

    if not any(token in command for token in FOLLOW_UP_TOKENS):
        return

    response = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                "Split state-sensitive dw_commands.sh batches: send teleport_to "
                "plus report_position first, wait for dw_debug.log confirmation, "
                "then send probe, survey, or path-debug commands separately."
            ),
        }
    }
    print(json.dumps(response))


if __name__ == "__main__":
    main()
