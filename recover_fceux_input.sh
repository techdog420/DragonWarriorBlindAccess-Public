#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ps_script="$script_dir/recover_fceux_input.ps1"

if ! command -v wslpath >/dev/null 2>&1; then
    echo "wslpath is required to run the Windows FCEUX recovery helper from WSL." >&2
    exit 1
fi

exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w "$ps_script")" "$@"
