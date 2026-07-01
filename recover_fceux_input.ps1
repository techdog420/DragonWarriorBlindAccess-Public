[CmdletBinding()]
param(
    [string] $KeyboardBridgePath,
    [string] $BridgeHotkeyPath,
    [string] $CommandFile,
    [string] $Tag = "fceux_recovery",
    [int] $ProcessId = 0,
    [switch] $NoQueue,
    [switch] $NoBridgeStart,
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
if ([string]::IsNullOrWhiteSpace($KeyboardBridgePath)) {
    $KeyboardBridgePath = Join-Path $scriptDir "dw_keyboard_input.txt"
}
if ([string]::IsNullOrWhiteSpace($BridgeHotkeyPath)) {
    $BridgeHotkeyPath = Join-Path $scriptDir "dw_bridge_hotkeys.txt"
}
if ([string]::IsNullOrWhiteSpace($CommandFile)) {
    $CommandFile = Join-Path $scriptDir "dw_commands.txt"
}
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "fceux_recovery"
}
$KeyboardBridgeScript = Join-Path $scriptDir "keyboard_bridge.ps1"

function Ensure-InputRecoveryType {
    if (-not ("DragonWarrior.FceuxInputRecovery" -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace DragonWarrior {
    public static class FceuxInputRecovery {
        [DllImport("user32.dll")]
        public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    }
}
'@
    }
}

function Get-FceuxProcess {
    if ($ProcessId -gt 0) {
        return Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    }

    return Get-Process -Name qfceux, fceux -ErrorAction SilentlyContinue |
        Sort-Object StartTime -Descending |
        Select-Object -First 1
}

function Focus-EmulatorWindow {
    param([System.Diagnostics.Process] $Process)

    if (-not $Process) {
        Write-Warning "FCEUX input recovery: no qfceux/fceux process found."
        return $false
    }

    Ensure-InputRecoveryType
    $hwnd = [IntPtr]::Zero
    for ($i = 0; $i -lt 20; $i++) {
        try {
            $Process.Refresh()
            $hwnd = $Process.MainWindowHandle
            if ($hwnd -ne [IntPtr]::Zero) {
                break
            }
        } catch {
            break
        }
        Start-Sleep -Milliseconds 100
    }

    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Warning "FCEUX input recovery: emulator window handle was not ready."
        return $false
    }

    [void] [DragonWarrior.FceuxInputRecovery]::ShowWindow($hwnd, 9) # SW_RESTORE
    Start-Sleep -Milliseconds 100
    $focused = [DragonWarrior.FceuxInputRecovery]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 150
    Write-Host ("FCEUX input recovery: foregrounded emulator window: {0}" -f $focused)
    return $focused
}

function Send-VirtualKeyUp {
    param([Parameter(Mandatory=$true)][byte] $VirtualKey)

    Ensure-InputRecoveryType
    $KEYEVENTF_KEYUP = 0x0002
    [DragonWarrior.FceuxInputRecovery]::keybd_event($VirtualKey, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
}

function Send-VirtualKeyTap {
    param([Parameter(Mandatory=$true)][byte] $VirtualKey)

    Ensure-InputRecoveryType
    $KEYEVENTF_KEYUP = 0x0002
    [DragonWarrior.FceuxInputRecovery]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [DragonWarrior.FceuxInputRecovery]::keybd_event($VirtualKey, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
}

function Invoke-AltReleasePulse {
    # Repeat Alt key-up around Escape to clear the common Alt+Tab case where
    # FCEUX/SDL saw Alt-down but missed Alt-up during a focus transition.
    Send-VirtualKeyUp -VirtualKey 0x0D  # VK_RETURN / clear Alt+Enter latch
    Send-VirtualKeyUp -VirtualKey 0xA4  # VK_LMENU / Left Alt
    Send-VirtualKeyUp -VirtualKey 0xA5  # VK_RMENU / Right Alt
    Send-VirtualKeyUp -VirtualKey 0x12  # VK_MENU / generic Alt
    Start-Sleep -Milliseconds 60
    Send-VirtualKeyTap -VirtualKey 0x1B # VK_ESCAPE / dismiss menu focus
    Start-Sleep -Milliseconds 60
    Send-VirtualKeyUp -VirtualKey 0x0D
    Send-VirtualKeyUp -VirtualKey 0xA4
    Send-VirtualKeyUp -VirtualKey 0xA5
    Send-VirtualKeyUp -VirtualKey 0x12
    Start-Sleep -Milliseconds 60
    Send-VirtualKeyUp -VirtualKey 0x0D
    Send-VirtualKeyUp -VirtualKey 0xA4
    Send-VirtualKeyUp -VirtualKey 0xA5
    Send-VirtualKeyUp -VirtualKey 0x12
}

function Test-CommandLineContains {
    param(
        [string] $CommandLine,
        [string] $Needle
    )

    if ([string]::IsNullOrWhiteSpace($CommandLine) -or [string]::IsNullOrWhiteSpace($Needle)) {
        return $false
    }
    return $CommandLine.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-KeyboardBridgeProcess {
    param(
        [string] $BridgeScript,
        [string] $OutputPath
    )

    if (-not (Test-Path -LiteralPath $BridgeScript -PathType Leaf)) {
        return @()
    }

    $scriptFullPath = [System.IO.Path]::GetFullPath($BridgeScript)
    $outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)

    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like "powershell*" -and
            (Test-CommandLineContains -CommandLine $_.CommandLine -Needle $scriptFullPath) -and
            (Test-CommandLineContains -CommandLine $_.CommandLine -Needle $outputFullPath)
        })
}

function Ensure-KeyboardBridgeRunning {
    param(
        [string] $BridgeScript,
        [string] $OutputPath,
        [string] $HotkeyOutputPath
    )

    if ($NoBridgeStart) {
        Write-Host "FCEUX input recovery: keyboard bridge start skipped by -NoBridgeStart."
        return
    }

    if (-not (Test-Path -LiteralPath $BridgeScript -PathType Leaf)) {
        Write-Warning ("FCEUX input recovery: keyboard bridge script not found: {0}" -f $BridgeScript)
        return
    }

    $existing = @(Get-KeyboardBridgeProcess -BridgeScript $BridgeScript -OutputPath $OutputPath)
    $withHotkeyOutput = @($existing | Where-Object {
        Test-CommandLineContains -CommandLine $_.CommandLine -Needle ([System.IO.Path]::GetFullPath($HotkeyOutputPath))
    })
    if ($withHotkeyOutput.Count -gt 0) {
        $ids = ($withHotkeyOutput | ForEach-Object { $_.ProcessId }) -join ","
        Write-Host ("FCEUX input recovery: keyboard bridge already running: PID {0}" -f $ids)
        return
    }
    foreach ($oldBridge in $existing) {
        Write-Host ("FCEUX input recovery: stopping stale keyboard bridge PID {0} without mod-hotkey output..." -f $oldBridge.ProcessId)
        Stop-Process -Id $oldBridge.ProcessId -Force -ErrorAction SilentlyContinue
    }

    $bridgeProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $BridgeScript,
        "-OutputPath", $OutputPath,
        "-HotkeyOutputPath", $HotkeyOutputPath
    ) -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 150
    Write-Host ("FCEUX input recovery: started keyboard bridge PID {0}" -f $bridgeProcess.Id)
}

$process = Get-FceuxProcess
if ($DryRun) {
    Write-Host "FCEUX input recovery dry run"
    Write-Host ("  Process:   {0}" -f $(if ($process) { "$($process.ProcessName) PID $($process.Id)" } else { "(none)" }))
    Write-Host "  Key-up:    repeated Return, LeftAlt, RightAlt, generic Alt"
    Write-Host "  Tap:       Escape"
    Write-Host ("  Bridge:    reset {0} to '-'" -f $KeyboardBridgePath)
    Write-Host ("  ModBridge: reset {0} to '-'" -f $BridgeHotkeyPath)
    if ($NoBridgeStart) {
        Write-Host "  Sidecar:   start skipped"
    } else {
        Write-Host ("  Sidecar:   ensure {0} is running" -f $KeyboardBridgeScript)
    }
    if ($NoQueue) {
        Write-Host "  Queue:     skipped"
    } else {
        Write-Host ("  Queue:     input_status:{0} -> {1}" -f $Tag, $CommandFile)
    }
    exit 0
}

if (-not $process) {
    throw "FCEUX input recovery needs a running qfceux/fceux process; none was found."
}

[void] (Focus-EmulatorWindow -Process $process)
Invoke-AltReleasePulse

[System.IO.File]::WriteAllText($KeyboardBridgePath, "-" + [Environment]::NewLine)
Write-Host ("FCEUX input recovery: reset keyboard bridge state: {0}" -f $KeyboardBridgePath)
[System.IO.File]::WriteAllText($BridgeHotkeyPath, "-" + [Environment]::NewLine)
Write-Host ("FCEUX input recovery: reset bridge hotkey state: {0}" -f $BridgeHotkeyPath)
Ensure-KeyboardBridgeRunning -BridgeScript $KeyboardBridgeScript -OutputPath $KeyboardBridgePath -HotkeyOutputPath $BridgeHotkeyPath

if (-not $NoQueue) {
    Add-Content -LiteralPath $CommandFile -Value ("input_status:{0}" -f $Tag)
    Write-Host ("FCEUX input recovery: queued input_status:{0}" -f $Tag)
}

Write-Host "FCEUX input recovery: sent repeated Return/LeftAlt/RightAlt/generic Alt key-up pulse and Escape tap."
