#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

default_emulator="${DW_EMULATOR:-fceux}"
default_bizhawk_path="${DW_BIZHAWK_PATH:-/mnt/d/emulation/bizhawk/EmuHawk.exe}"
default_fceux_path="${DW_FCEUX_PATH:-/mnt/d/emulation/fceux/bin/qfceux.exe}"
default_rom_path="${DW_ROM_PATH:-/mnt/d/emulation/nes/Dragon Warrior (USA) (Rev 1).nes}"
default_lua_path="${DW_LUA_PATH:-$script_dir/main.lua}"

emulator="$default_emulator"
bizhawk_path="$default_bizhawk_path"
fceux_path="$default_fceux_path"
rom_path="$default_rom_path"
lua_path="$default_lua_path"
battery_save=""
state_slot="${DW_STATE_SLOT:-}"
state_slot_cli=0
wait_for_ready=1
dry_run=0

usage() {
    cat <<'EOF'
launch_dw.sh - Launch Dragon Warrior with the accessibility mod

Usage:
  ./launch_dw.sh [options]

Options:
  --emulator NAME       Emulator backend: fceux (default) or bizhawk
  --bizhawk-path PATH   Override the Windows EmuHawk executable path
  --fceux-path PATH     Override the Windows FCEUX executable path
  --rom-path PATH       Override the Dragon Warrior ROM path
  --lua-path PATH       Override the Lua script path
  --battery-save PATH   Copy raw battery data to the emulator's save path before launch
  --state-slot N        Load savestate slot N on startup (0-9)
  --no-wait             Return immediately after launching the emulator
  --dry-run             Print resolved actions without killing or launching
  --help                Show this help text

Environment overrides:
  DW_EMULATOR, DW_BIZHAWK_PATH, DW_FCEUX_PATH, DW_ROM_PATH, DW_LUA_PATH, DW_STATE_SLOT
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
        --emulator)
            [ $# -ge 2 ] || { echo "Missing value for --emulator" >&2; exit 1; }
            emulator="$2"
            shift 2
            ;;
        --emulator=*)
            emulator="${1#*=}"
            shift
            ;;
        --bizhawk-path)
            [ $# -ge 2 ] || { echo "Missing value for --bizhawk-path" >&2; exit 1; }
            bizhawk_path="$2"
            shift 2
            ;;
        --fceux-path)
            [ $# -ge 2 ] || { echo "Missing value for --fceux-path" >&2; exit 1; }
            fceux_path="$2"
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
        --battery-save)
            [ $# -ge 2 ] || { echo "Missing value for --battery-save" >&2; exit 1; }
            battery_save="$2"
            shift 2
            ;;
        --state-slot)
            [ $# -ge 2 ] || { echo "Missing value for --state-slot" >&2; exit 1; }
            state_slot="$2"
            state_slot_cli=1
            shift 2
            ;;
        --no-wait)
            wait_for_ready=0
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
    echo "wslpath is required to launch Windows emulators from WSL." >&2
    exit 1
fi

emulator="$(printf '%s' "$emulator" | tr '[:upper:]' '[:lower:]')"
case "$emulator" in
    bizhawk|fceux)
        ;;
    *)
        echo "--emulator must be 'bizhawk' or 'fceux'." >&2
        exit 1
        ;;
esac

rom_path="$(resolve_posix_path "$rom_path")"
lua_path="$(resolve_posix_path "$lua_path")"

if [ -n "$battery_save" ]; then
    battery_save="$(resolve_posix_path "$battery_save")"
fi

if { [ "$emulator" = "fceux" ] || [ "$state_slot_cli" -eq 1 ]; } \
    && [ -n "$state_slot" ] && ! [[ "$state_slot" =~ ^[0-9]$ ]]; then
    echo "--state-slot must be a single digit from 0 to 9." >&2
    exit 1
fi

if [ -n "$battery_save" ]; then
    case "${battery_save##*.}" in
        [sS][aA][vV]|[sS][aA][vV][eE][rR][aA][mM])
            ;;
        *)
            echo "--battery-save must point to a .sav or .SaveRAM file." >&2
            exit 1
            ;;
    esac
    if ! is_windows_path "$battery_save" && [ ! -f "$battery_save" ]; then
        echo "Battery save data file not found: $battery_save" >&2
        exit 1
    fi
fi

if [ "$emulator" = "bizhawk" ]; then
    bizhawk_path="$(resolve_posix_path "$bizhawk_path")"
    for required_path in "$bizhawk_path" "$rom_path" "$lua_path"; do
        if ! is_windows_path "$required_path" && [ ! -f "$required_path" ]; then
            echo "Required file not found: $required_path" >&2
            exit 1
        fi
    done

    ps_script="$script_dir/launch_bizhawk.ps1"
    if [ ! -f "$ps_script" ]; then
        echo "PowerShell BizHawk launcher not found: $ps_script" >&2
        exit 1
    fi

    ps_script_win="$(to_windows_path "$ps_script")"
    bizhawk_path_win="$(to_windows_path "$bizhawk_path")"
    rom_path_win="$(to_windows_path "$rom_path")"
    lua_path_win="$(to_windows_path "$lua_path")"
    battery_save_win=""
    if [ -n "$battery_save" ]; then
        battery_save_win="$(to_windows_path "$battery_save")"
    fi

    if [ "$dry_run" -eq 1 ]; then
        echo "Dragon Warrior launcher"
        echo "  Emulator: BizHawk"
        echo "  Executable: $bizhawk_path_win"
        echo "  ROM:        $rom_path_win"
        echo "  Lua:        $lua_path_win"
        if [ -n "$battery_save_win" ]; then
            echo "  Battery:    $battery_save_win"
            echo "  SaveRAM:    resolved by launch_bizhawk.ps1"
        fi
        if [ -n "$state_slot" ]; then
            echo "  State:      slot $state_slot"
        fi
        if [ "$wait_for_ready" -eq 0 ]; then
            echo "  Wait:       no"
        else
            echo "  Wait:       yes"
        fi
        echo "  Argument:   --lua=$lua_path_win"
        if [ -n "$state_slot" ]; then
            echo "  Argument:   --load-slot $state_slot"
        fi
        exit 0
    fi

    ps_args=(
        -NoProfile
        -ExecutionPolicy Bypass
        -File "$ps_script_win"
        -BizhawkPath "$bizhawk_path_win"
        -RomPath "$rom_path_win"
        -LuaPath "$lua_path_win"
    )

    if [ -n "$state_slot" ]; then
        ps_args+=(-StateSlot "$state_slot")
    fi

    if [ -n "$battery_save" ]; then
        ps_args+=(-BatterySavePath "$battery_save_win")
    fi

    if [ "$wait_for_ready" -eq 0 ]; then
        ps_args+=(-NoWait)
    fi

    exec powershell.exe "${ps_args[@]}"
fi

fceux_path="$(resolve_posix_path "$fceux_path")"

for required_path in "$fceux_path" "$rom_path" "$lua_path"; do
    if ! is_windows_path "$required_path" && [ ! -f "$required_path" ]; then
        echo "Required file not found: $required_path" >&2
        exit 1
    fi
done

ps_script="$script_dir/launch_dw.ps1"
if [ ! -f "$ps_script" ]; then
    echo "PowerShell launcher not found: $ps_script" >&2
    exit 1
fi

ps_script_win="$(to_windows_path "$ps_script")"
fceux_path_win="$(to_windows_path "$fceux_path")"
rom_path_win="$(to_windows_path "$rom_path")"
lua_path_win="$(to_windows_path "$lua_path")"
battery_save_win=""
if [ -n "$battery_save" ]; then
    battery_save_win="$(to_windows_path "$battery_save")"
fi

if [ "$dry_run" -eq 1 ]; then
    echo "Dragon Warrior launcher"
    echo "  Emulator: FCEUX"
    echo "  Executable: $fceux_path_win"
    echo "  ROM:        $rom_path_win"
    echo "  Lua:        $lua_path_win"
    if [ -n "$battery_save_win" ]; then
        echo "  Battery:    $battery_save_win"
    fi
    if [ -n "$state_slot" ]; then
        echo "  State slot: $state_slot"
    fi
    if [ "$wait_for_ready" -eq 0 ]; then
        echo "  Wait:       no"
    else
        echo "  Wait:       yes"
    fi
    exit 0
fi

ps_args=(
    -NoProfile
    -ExecutionPolicy Bypass
    -File "$ps_script_win"
    -FceuxPath "$fceux_path_win"
    -RomPath "$rom_path_win"
    -LuaPath "$lua_path_win"
)

if [ -n "$battery_save" ]; then
    ps_args+=(-BatterySavePath "$battery_save_win")
fi

if [ -n "$state_slot" ]; then
    ps_args+=(-StateSlot "$state_slot")
fi

if [ "$wait_for_ready" -eq 0 ]; then
    ps_args+=(-NoWait)
fi

exec powershell.exe "${ps_args[@]}"
