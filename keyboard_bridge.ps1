[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $OutputPath,

    [int] $PollMilliseconds = 16
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class KeyboardBridgeState {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
'@

function Test-KeyDown {
    param([int] $VirtualKey)
    return (([KeyboardBridgeState]::GetAsyncKeyState($VirtualKey) -band 0x8000) -ne 0)
}

function Test-EmulatorForeground {
    $hwnd = [KeyboardBridgeState]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) {
        return $false
    }

    $processId = [uint32] 0
    [void] [KeyboardBridgeState]::GetWindowThreadProcessId($hwnd, [ref] $processId)
    if ($processId -eq 0) {
        return $false
    }

    try {
        $process = Get-Process -Id ([int] $processId) -ErrorAction Stop
    } catch {
        return $false
    }

    return $process.ProcessName -eq "qfceux" -or $process.ProcessName -eq "fceux"
}

function Write-State {
    param([string[]] $Buttons)

    $line = if ($Buttons.Count -gt 0) { $Buttons -join "," } else { "-" }
    [System.IO.File]::WriteAllText($OutputPath, $line + [Environment]::NewLine)
}

$outputDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$lastLine = $null
while ($true) {
    $buttons = New-Object System.Collections.Generic.List[string]

    if (Test-EmulatorForeground) {
        if (Test-KeyDown 0x26) { $buttons.Add("up") }      # VK_UP
        if (Test-KeyDown 0x28) { $buttons.Add("down") }    # VK_DOWN
        if (Test-KeyDown 0x25) { $buttons.Add("left") }    # VK_LEFT
        if (Test-KeyDown 0x27) { $buttons.Add("right") }   # VK_RIGHT
        if (Test-KeyDown 0x46) { $buttons.Add("A") }       # F
        if (Test-KeyDown 0x44) { $buttons.Add("B") }       # D
        if (Test-KeyDown 0x0D) { $buttons.Add("start") }   # Enter
        if (Test-KeyDown 0x53) { $buttons.Add("select") }  # S
    }

    $line = if ($buttons.Count -gt 0) { $buttons -join "," } else { "-" }
    if ($line -ne $lastLine) {
        Write-State -Buttons $buttons.ToArray()
        $lastLine = $line
    }

    Start-Sleep -Milliseconds $PollMilliseconds
}
