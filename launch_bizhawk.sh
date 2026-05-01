#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

default_bizhawk_path="${DW_BIZHAWK_PATH:-/mnt/d/emulation/bizhawk/EmuHawk.exe}"
default_rom_path="${DW_ROM_PATH:-/mnt/d/emulation/nes/Dragon Warrior (USA) (Rev 1).nes}"
default_lua_path="${DW_LUA_PATH:-$script_dir/main.lua}"

bizhawk_path="$default_bizhawk_path"
rom_path="$default_rom_path"
lua_path="$default_lua_path"
state_slot="${DW_STATE_SLOT:-}"
wait_for_exit=1
dry_run=0

usage() {
    cat <<'EOF'
launch_bizhawk.sh - Launch Dragon Warrior with the accessibility mod in BizHawk

Usage:
  ./launch_bizhawk.sh [options]

Options:
  --bizhawk-path PATH   Override the Windows EmuHawk executable path
  --rom-path PATH       Override the Dragon Warrior ROM path
  --lua-path PATH       Override the Lua script path
  --state-slot N        Load BizHawk savestate slot N on startup (0-9)
  --no-wait             Return immediately after launching BizHawk
  --dry-run             Print resolved launch values without launching
  --help                Show this help text

Environment overrides:
  DW_BIZHAWK_PATH, DW_ROM_PATH, DW_LUA_PATH, DW_STATE_SLOT
EOF
}

is_windows_path() {
    [[ "$1" =~ ^([A-Za-z]:[\\/]|\\\\) ]]
}

resolve_posix_path() {
    local path="$1"
    if is_windows_path "$path"; then
        printf '%s\n' "$path"
        return
    fi

    if command -v realpath >/dev/null 2>&1; then
        realpath "$path"
        return
    fi

    local dir base
    dir="$(cd "$(dirname "$path")" && pwd -P)"
    base="$(basename "$path")"
    printf '%s/%s\n' "$dir" "$base"
}

to_windows_path() {
    local path="$1"
    if is_windows_path "$path"; then
        printf '%s\n' "$path"
    else
        wslpath -w "$path"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bizhawk-path)
            [ $# -ge 2 ] || { echo "Missing value for --bizhawk-path" >&2; exit 1; }
            bizhawk_path="$2"
            shift 2
            ;;
        --rom-path)
            [ $# -ge 2 ] || { echo "Missing value for --rom-path" >&2; exit 1; }
            rom_path="$2"
            shift 2
            ;;
        --lua-path)
            [ $# -ge 2 ] || { echo "Missing value for --lua-path" >&2; exit 1; }
            lua_path="$2"
            shift 2
            ;;
        --state-slot)
            [ $# -ge 2 ] || { echo "Missing value for --state-slot" >&2; exit 1; }
            state_slot="$2"
            shift 2
            ;;
        --no-wait)
            wait_for_exit=0
            shift
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if ! command -v wslpath >/dev/null 2>&1; then
    echo "wslpath is required to launch Windows BizHawk from WSL." >&2
    exit 1
fi

bizhawk_path="$(resolve_posix_path "$bizhawk_path")"
rom_path="$(resolve_posix_path "$rom_path")"
lua_path="$(resolve_posix_path "$lua_path")"

if [ -n "$state_slot" ] && ! [[ "$state_slot" =~ ^[0-9]$ ]]; then
    echo "--state-slot must be a single digit from 0 to 9." >&2
    exit 1
fi

for required_path in "$bizhawk_path" "$rom_path" "$lua_path"; do
    if ! is_windows_path "$required_path" && [ ! -f "$required_path" ]; then
        echo "Required file not found: $required_path" >&2
        exit 1
    fi
done

bizhawk_path_win="$(to_windows_path "$bizhawk_path")"
rom_path_win="$(to_windows_path "$rom_path")"
lua_path_win="$(to_windows_path "$lua_path")"

if [ "$dry_run" -eq 1 ]; then
    echo "BizHawk launcher"
    echo "  Emulator: $bizhawk_path_win"
    echo "  ROM:      $rom_path_win"
    echo "  Lua:      $lua_path_win"
    if [ "$wait_for_exit" -eq 1 ]; then
        echo "  Wait:     yes"
    else
        echo "  Wait:     no"
    fi
    if [ -n "$state_slot" ]; then
        echo "  State:    slot $state_slot"
    fi
    echo "  Argument: --lua=$lua_path_win"
    if [ -n "$state_slot" ]; then
        echo "  Argument: --load-slot $state_slot"
    fi
    exit 0
fi

ps_script="$script_dir/launch_bizhawk.ps1"
if [ ! -f "$ps_script" ]; then
    echo "PowerShell BizHawk launcher not found: $ps_script" >&2
    exit 1
fi

ps_script_win="$(to_windows_path "$ps_script")"

ps_args=(
    -NoProfile
    -ExecutionPolicy Bypass
    -File "$ps_script_win"
    -BizhawkPath "$bizhawk_path_win"
    -LuaPath "$lua_path_win"
    -RomPath "$rom_path_win"
)

if [ -n "$state_slot" ]; then
    ps_args+=(-StateSlot "$state_slot")
fi

if [ "$wait_for_exit" -eq 0 ]; then
    ps_args+=(-NoWait)
fi

exec powershell.exe "${ps_args[@]}"
