#!/usr/bin/env bash
# dw_commands.sh — Send commands to the Dragon Warrior accessibility mod
#
# Usage:
#   ./dw_commands.sh [--replace] [--wait PATTERN] [--timeout SECONDS] <command> [command2 command3 ...]
#
# Each argument is written as one command line to dw_commands.txt.
# The mod polls this file every ~1 second (60 frames) and clears it
# after processing. Requires debug_mode=true in dw_access.ini.
# By default commands are APPENDED so separate invocations don't clobber
# each other. Use --replace to overwrite the queue intentionally.
# Use --wait PATTERN to wait for a fresh dw_debug.log line containing PATTERN.
# Use --timeout SECONDS to override the default 10 second wait timeout.
#
# ── Built-in commands ────────────────────────────────────────────────
#   log_state              Full game-state snapshot to dw_debug.log
#   report_position        Map/coordinates to dw_debug.log
#   report_door_state      Magic-key count and opened-door RAM slots
#   toggle_debug           Toggle debug_mode on/off at runtime
#   dump_grid              Dump walkability grid for current map
#   reload_config          Re-read dw_access.ini (picks up setting changes)
#   simulate_input:BTN     Inject one-frame input (UP/DOWN/LEFT/RIGHT/A/B/START/SELECT)
#   export_blocks          Format all recorded blocked moves as MAP_BLOCKED_CELLS Lua
#                          entries; output appears in dw_debug.log
#   speech_status          Report speech backend, readiness, and last error
#   sweep_map              Systematic engine-collision sweep: teleports player to every
#                          walkable-looking tile, probes all 4 directions, outputs
#                          MAP_BLOCKED_CELLS entries for hidden engine walls
#   stop_sweep             Cancel an active sweep
#   report_blockers        Log current NPC blockers and runtime-discovered blocks
#   report_runtime_blocks  Log current map's runtime_blocked cells
#   report_upper_dialogue_state  Dump upper-window dialogue state variables to log
#   clear_runtime_blocks   Clear runtime_blocked cells for current map
#   clear_runtime_blocks:all  Clear runtime_blocked cells for all maps
#   add_blocked_tile:X,Y   Inject a runtime blocked tile on the current map
#   add_blocked_tile:MAP_ID,X,Y  Inject a runtime blocked tile on an explicit map
#   list_blocked_tiles     List runtime blocked tiles for the current map
#   list_blocked_tiles:MAP_ID  List runtime blocked tiles for an explicit map
#   clear_blocked_tiles    Clear runtime blocked tiles for the current map
#   clear_blocked_tiles:MAP_ID  Clear runtime blocked tiles for an explicit map
#   clear_blocked_tiles:all  Clear runtime blocked tiles for all maps
#   is_blocked_tile:X,Y    Inspect runtime blocked status for the current map
#   is_blocked_tile:MAP_ID,X,Y  Inspect runtime blocked status for an explicit map
#   dump_blocked_tiles     Dump current map runtime blocked tiles as Lua table lines
#   dump_blocked_tiles:MAP_ID  Dump explicit map runtime blocked tiles as Lua table lines
#   inspect_tile:X,Y       Log tile type, base walkability, permanent/runtime overrides,
#                          and final effective path passability
#   inspect_move:DIR       Inspect a move from current position (UP/DOWN/LEFT/RIGHT)
#   inspect_move:X,Y,DIR   Inspect a move from an explicit origin
#   pathfind_to:X,Y        Run direct pathfinding to explicit coordinates
#   pathfind_adjacent:X,Y  Run adjacent pathfinding to explicit coordinates
#   report_path_state      Log current path target, blockers, and runtime blocks
#   auto_walk              Auto-walk to the current selected object using pathfinder
#
# ── Navigation commands ──────────────────────────────────────────────
#   next_object            Next object in list (like L key)
#   prev_object            Previous object in list (like J key)
#   current_object         Describe current object (like K key)
#   next_filter            Cycle object filter: All/NPCs/Exits/Chests/Stairs/Doors
#   pathfind               Pathfind to current object (like O key)
#   auto_walk              Auto-walk to current object (like U key)
#   freeze_npcs            Lock NPC positions in RAM
#   unfreeze_npcs          Unlock NPC positions
#
# ── Path debug commands ─────────────────────────────────────────────
#   debug_pathfind_to:X,Y       Pathfind with full A* search logging
#   debug_pathfind_adjacent:X,Y Adjacent pathfind with full A* search logging
#   trace_path                  Output last computed path (coords + directions)
#   dump_search_log             Output per-node A* visit/reject log (verbose!)
#   start_step_mode             Load last path into step buffer
#   step_path                   Execute one step from step buffer
#   stop_step_mode              Cancel step-by-step mode
#   validate_path               Auto-walk last path, check each step position
#   stop_validate               Cancel active path validation
#   test_path                   Run all test scenarios for current map
#   test_path:NAME              Run named test scenario (e.g. test_path:spawn_to_king)
#   list_tests                  List available test scenarios for current map
#   dump_path_grid              Dump tile grid with path overlay
#
# ── Edge probe commands ──────────────────────────────────────────────
#   probe_edge:DIR              Probe one step in DIR from current position;
#                               records whether the engine allows movement and logs result
#                               DIR: UP/DOWN/LEFT/RIGHT
#   probe_edge:X,Y,DIR          Same but from explicit coordinates (must be standing there)
#   stop_probe_edge             Cancel an active edge probe
#
# ── Teleport (debug) ─────────────────────────────────────────────────
#   teleport_to:X,Y             Same-map teleport; refuses if target not walkable
#   teleport_to:X,Y,near        Teleport to target, or first walkable cardinal/diagonal
#                               neighbor if target is blocked
#   teleport_to:X,Y,force       Skip walkability check (unstick/debug; risk of strand)
#                               Refused during menus, dialogue, battle, sweeps, active
#                               routes, or edge probes.
#
# ── Map survey commands ──────────────────────────────────────────────
#   survey_objects              Auto-walk to every object on the current map to probe
#                               adjacency. Freezes NPCs during the run. Results appear
#                               in dw_debug.log and are retained for export.
#   survey_objects:retry_failed Re-run only the targets that failed in the last survey
#   survey_objects:park_npcs    Survey with non-target NPCs parked off-screen
#                               for the run
#   survey_objects:retry_failed,park_npcs  Retry failed targets with parked-NPC mode
#   survey_map                  Alias for survey_objects
#   survey_target:NAME          Survey a single named target (partial name match)
#   survey_target:NAME,park_npcs  Single-target survey with parked-NPC mode
#   stop_survey                 Cancel an active survey run
#   report_survey_start         Preflight check: reports reachable area, exit count, and
#                               whether the current start position is isolated; does NOT
#                               launch a survey. Use before survey_objects to verify.
#   report_survey_start:retry_failed  Same preflight using the failed-target set
#   report_survey_start:park_npcs  Same preflight, annotated for parked-NPC mode
#   report_survey_findings      Summary of failed targets + strong reroute candidates
#   report_survey_findings:MAP_ID  Same for an explicit map
#   report_failed_targets       Log targets that failed in the last survey run
#   report_failed_targets:MAP_ID  Same for an explicit map
#   report_strong_candidates    Log high-confidence directional-block candidates
#   report_strong_candidates:MAP_ID  Same for an explicit map
#   report_candidate_suggestions  Log suggested MAP_DIRECTIONAL_BLOCKS entries to try
#   report_candidate_suggestions:MAP_ID  Same for an explicit map
#   list_blocked_candidates     List all recorded blocked-candidate cells with counts
#   list_blocked_candidates:MAP_ID  Same for an explicit map
#   dump_survey_report          Full per-target survey report for current map
#   dump_survey_report:MAP_ID   Same for an explicit map
#   export_blocked_candidates   Export strong candidates as MAP_BLOCKED_CELLS Lua lines
#   export_blocked_candidates:MAP_ID  Same for an explicit map
#   export_directional_candidates  Export strong candidates as MAP_DIRECTIONAL_BLOCKS
#                               Lua lines (directional block format)
#   export_directional_candidates:MAP_ID  Same for an explicit map
#   reset_survey_candidates     Clear all candidate data for the current map
#   reset_survey_candidates:MAP_ID  Clear candidate data for an explicit map
#
# ── TTS test ─────────────────────────────────────────────────────────
#   speak:TEXT             Speak TEXT via Tolk, e.g.: speak:Hello world
#
# ── Script restart ───────────────────────────────────────────────────
#   Full restart: relaunch with ./launch_dw.sh, or use the emulator's Lua reload UI.
#   Use reload_config to pick up dw_access.ini changes without restarting.
#
# ── Examples ─────────────────────────────────────────────────────────
#   ./dw_commands.sh log_state
#   ./dw_commands.sh next_object
#   ./dw_commands.sh next_object next_object next_object
#   ./dw_commands.sh pathfind
#   ./dw_commands.sh speak:Testing speech output
#   ./dw_commands.sh simulate_input:UP
#   ./dw_commands.sh next_filter current_object
#   ./dw_commands.sh inspect_move:RIGHT
#   ./dw_commands.sh inspect_tile:14,2 pathfind_to:27,6
#   ./dw_commands.sh debug_pathfind_to:3,3 trace_path
#   ./dw_commands.sh test_path:spawn_to_king dump_path_grid
#   ./dw_commands.sh report_survey_start
#   ./dw_commands.sh survey_objects
#   ./dw_commands.sh survey_objects:retry_failed
#   ./dw_commands.sh stop_survey
#   ./dw_commands.sh report_survey_findings
#   ./dw_commands.sh dump_survey_report export_directional_candidates
#   ./dw_commands.sh probe_edge:RIGHT
#   ./dw_commands.sh probe_edge:14,2,UP
#   ./dw_commands.sh --replace --wait "POSITION:" report_position

BASE_DIR="$(dirname "$0")"
CMD_FILE="$BASE_DIR/dw_commands.txt"
LOG_FILE="$BASE_DIR/dw_debug.log"

if [ $# -eq 0 ]; then
    sed -n 's/^# \?//p' "$0" | head -50
    exit 0
fi

mode="append"
wait_pattern=""
timeout_seconds=10

while [ $# -gt 0 ]; do
    case "$1" in
        --replace)
            mode="replace"
            shift
            ;;
        --wait)
            shift
            if [ $# -eq 0 ]; then
                echo "--wait requires a log pattern."
                exit 1
            fi
            wait_pattern="$1"
            shift
            ;;
        --timeout)
            shift
            if [ $# -eq 0 ]; then
                echo "--timeout requires a positive integer seconds value."
                exit 1
            fi
            case "$1" in
                ''|*[!0-9]*)
                    echo "--timeout requires a positive integer seconds value."
                    exit 1
                    ;;
            esac
            if [ "$1" -eq 0 ]; then
                echo "--timeout requires a positive integer seconds value."
                exit 1
            fi
            timeout_seconds="$1"
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -eq 0 ]; then
    echo "No commands provided."
    exit 1
fi

wait_start_line=0
if [ -n "$wait_pattern" ] && [ -f "$LOG_FILE" ]; then
    wait_start_line=$(wc -l < "$LOG_FILE")
fi

# Write each argument as one command line.
# Using printf ensures each arg gets its own line with no trailing newline issues.
if [ "$mode" = "replace" ]; then
    printf '%s\n' "$@" > "$CMD_FILE"
else
    printf '%s\n' "$@" >> "$CMD_FILE"
fi

# Warn only after a longer idle period so a live-but-idle emulator doesn't
# trigger false positives during normal testing.
if [ -f "$LOG_FILE" ]; then
    last_mod=$(date -r "$LOG_FILE" +%s 2>/dev/null)
    now=$(date +%s)
    age=$(( now - last_mod ))
    if [ "$age" -gt 60 ]; then
        echo "WARNING: dw_debug.log was last updated ${age}s ago - emulator may be idle or not running"
    fi
fi

echo "Sent to mod: $*"

if [ -n "$wait_pattern" ]; then
    echo "Waiting up to ${timeout_seconds}s for log pattern: $wait_pattern"
    start_time=$(date +%s)
    while true; do
        now=$(date +%s)
        if [ $(( now - start_time )) -ge "$timeout_seconds" ]; then
            echo "Timed out waiting for log pattern: $wait_pattern" >&2
            exit 2
        fi

        if [ -f "$LOG_FILE" ]; then
            current_lines=$(wc -l < "$LOG_FILE")
            if [ "$current_lines" -lt "$wait_start_line" ]; then
                wait_start_line=0
            fi
            match=$(tail -n +"$((wait_start_line + 1))" "$LOG_FILE" | grep -F "$wait_pattern" | tail -n 1)
            if [ -n "$match" ]; then
                echo "Matched log: $match"
                exit 0
            fi
        fi

        sleep 0.2
    done
fi
