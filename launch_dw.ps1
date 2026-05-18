[CmdletBinding()]
param(
    [string] $FceuxPath,
    [string] $RomPath,
    [string] $LuaPath,
    [string] $BatterySavePath,
    [ValidateRange(-1, 9)]
    [int] $StateSlot = -1,
    [switch] $NoWait,
    [switch] $DryRun
)

# FCEUX fallback launcher. The WSL entry point `launch_dw.sh` now defaults to
# BizHawk and calls this script only when `--emulator fceux` is requested.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath

function Resolve-LauncherPath {
    param(
        [string] $CliValue,
        [string] $EnvName,
        [string] $DefaultValue
    )

    if (-not [string]::IsNullOrWhiteSpace($CliValue)) {
        return $CliValue
    }

    $envValue = [Environment]::GetEnvironmentVariable($EnvName)
    if (-not [string]::IsNullOrWhiteSpace($envValue)) {
        return $envValue
    }

    return $DefaultValue
}

function Assert-FileExists {
    param(
        [string] $PathValue,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
        throw "$Label not found: $PathValue"
    }
}

function Format-Bool {
    param([bool] $Value)
    if ($Value) { return "yes" }
    return "no"
}

function Quote-Argument {
    param([string] $Value)

    if ($null -eq $Value) {
        return '""'
    }

    if ($Value.Contains('"')) {
        throw "Argument values containing double quotes are not supported: $Value"
    }

    if ($Value -match '\s') {
        return '"' + $Value + '"'
    }

    return $Value
}

function Wait-ForProcessExit {
    param(
        [int[]] $Ids,
        [int] $TimeoutSeconds = 5
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $remaining = @()
        foreach ($id in $Ids) {
            if (Get-Process -Id $id -ErrorAction SilentlyContinue) {
                $remaining += $id
            }
        }

        if ($remaining.Count -eq 0) {
            return
        }

        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
}

function Wait-ForDebugLog {
    param(
        [string] $LogPath,
        [datetime] $LaunchStartUtc,
        [int] $TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            $item = Get-Item -LiteralPath $LogPath
            if ($item.Length -gt 0 -and $item.LastWriteTimeUtc -ge $LaunchStartUtc) {
                Write-Host ("Startup log detected: dw_debug.log updated at {0:u}" -f $item.LastWriteTimeUtc)
                return $true
            }
        }

        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    return $false
}

$script:lastReadinessProbeDiagnostics = ""

function Get-ReadinessDiagnostics {
    param(
        [string] $CommandFile,
        [string] $LogPath,
        [string] $StartupLoopDiag,
        [string] $ProbeCommand,
        [string] $SuccessPattern,
        [datetime] $LaunchStartUtc,
        [datetime] $ProbeStartUtc,
        [System.Diagnostics.Process] $Process
    )

    $commandConsumed = $false
    $queueState = "missing"
    if (Test-Path -LiteralPath $CommandFile -PathType Leaf) {
        try {
            $queueText = [System.IO.File]::ReadAllText($CommandFile)
            if ([string]::IsNullOrWhiteSpace($queueText)) {
                $commandConsumed = $true
                $queueState = "empty"
            } elseif ($queueText.Contains($ProbeCommand)) {
                $queueState = "probe_pending"
            } else {
                $queueState = "other_pending"
            }
        } catch {
            $queueState = "unreadable"
        }
    }

    $debugFreshSinceProbe = $false
    $debugFreshSinceLaunch = $false
    $debugStamp = "missing"
    $probeSeen = $false
    if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
        try {
            $item = Get-Item -LiteralPath $LogPath
            $debugStamp = $item.LastWriteTimeUtc.ToString("u")
            $debugFreshSinceProbe = $item.Length -gt 0 -and $item.LastWriteTimeUtc -ge $ProbeStartUtc
            $debugFreshSinceLaunch = $item.Length -gt 0 -and $item.LastWriteTimeUtc -ge $LaunchStartUtc
            if ($debugFreshSinceLaunch) {
                $recentLines = Get-Content -LiteralPath $LogPath -Tail 200
                foreach ($line in $recentLines) {
                    if ($line.Contains($SuccessPattern)) {
                        $probeSeen = $true
                        break
                    }
                }
            }
        } catch {
            $debugStamp = "unreadable"
        }
    }

    $loopFresh = "missing"
    $loopAdvanced = "unknown"
    $loopLastFrame = "n/a"
    if (Test-Path -LiteralPath $StartupLoopDiag -PathType Leaf) {
        try {
            $item = Get-Item -LiteralPath $StartupLoopDiag
            $loopFresh = if ($item.LastWriteTimeUtc -ge $LaunchStartUtc) { "yes" } else { "stale" }
            $loopLines = Get-Content -LiteralPath $StartupLoopDiag -Tail 80
            $sawAfterFrameadvance = $false
            foreach ($line in $loopLines) {
                if ($line -match "frame=(\d+)") {
                    $loopLastFrame = $Matches[1]
                }
                if ($line.Contains("event=after_frameadvance")) {
                    $sawAfterFrameadvance = $true
                }
            }
            if ($sawAfterFrameadvance) {
                $loopAdvanced = "yes"
            } elseif ($loopFresh -eq "yes") {
                $loopAdvanced = "no"
            }
        } catch {
            $loopFresh = "unreadable"
        }
    }

    $processRunning = "no"
    $processResponding = "unknown"
    if ($Process) {
        try {
            $Process.Refresh()
            if (-not $Process.HasExited) {
                $processRunning = "yes"
                try {
                    $processResponding = if ($Process.Responding) { "yes" } else { "no" }
                } catch {
                    $processResponding = "unknown"
                }
            }
        } catch {
            $processRunning = "unknown"
        }
    }

    $paused = "unknown"
    if ($loopAdvanced -eq "yes" -or $debugFreshSinceProbe -or $probeSeen) {
        $paused = "not_indicated"
    } elseif (-not $commandConsumed -and -not $debugFreshSinceProbe -and ($loopAdvanced -eq "no" -or $loopFresh -eq "stale" -or $loopFresh -eq "missing")) {
        $paused = "possible"
    }

    return [pscustomobject]@{
        ProcessRunning = $processRunning
        ProcessResponding = $processResponding
        Paused = $paused
        StartupLoopFresh = $loopFresh
        StartupLoopAfterFrameadvance = $loopAdvanced
        StartupLoopLastFrame = $loopLastFrame
        DebugLogFreshSinceProbe = if ($debugFreshSinceProbe) { "yes" } else { "no" }
        DebugLogFreshSinceLaunch = if ($debugFreshSinceLaunch) { "yes" } else { "no" }
        DebugLogStamp = $debugStamp
        CommandConsumed = if ($commandConsumed) { "yes" } else { "no" }
        ProbeSeen = if ($probeSeen) { "yes" } else { "no" }
        QueueState = $queueState
    }
}

function Format-ReadinessDiagnostics {
    param([pscustomobject] $Diagnostics)

    return ("process_running={0} responding={1} paused={2} startup_loop_fresh={3} startup_loop_after_frameadvance={4} startup_loop_last_frame={5} debug_log_fresh_since_probe={6} debug_log_fresh_since_launch={7} debug_log_stamp={8} command_consumed={9} probe_seen={10} queue_state={11}" -f
        $Diagnostics.ProcessRunning,
        $Diagnostics.ProcessResponding,
        $Diagnostics.Paused,
        $Diagnostics.StartupLoopFresh,
        $Diagnostics.StartupLoopAfterFrameadvance,
        $Diagnostics.StartupLoopLastFrame,
        $Diagnostics.DebugLogFreshSinceProbe,
        $Diagnostics.DebugLogFreshSinceLaunch,
        $Diagnostics.DebugLogStamp,
        $Diagnostics.CommandConsumed,
        $Diagnostics.ProbeSeen,
        $Diagnostics.QueueState)
}

function Wait-ForNewEmulatorProcess {
    param(
        [datetime] $LaunchStartUtc,
        [int] $TimeoutSeconds = 5
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $process = Get-Process -Name qfceux, fceux -ErrorAction SilentlyContinue |
            Sort-Object StartTime -Descending |
            Select-Object -First 1

        if ($process) {
            try {
                if ($process.StartTime.ToUniversalTime() -ge $LaunchStartUtc.AddSeconds(-1)) {
                    return $process
                }
            } catch {
                # Process metadata can disappear if the process exits mid-poll.
            }
        }

        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    return $null
}

function Ensure-InputRecoveryType {
    if (-not ("DragonWarrior.InputRecovery" -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace DragonWarrior {
    public static class InputRecovery {
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

function Send-VirtualKeyUp {
    param(
        [Parameter(Mandatory=$true)]
        [byte] $VirtualKey
    )

    Ensure-InputRecoveryType
    $KEYEVENTF_KEYUP = 0x0002
    [DragonWarrior.InputRecovery]::keybd_event($VirtualKey, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
}

function Send-VirtualKeyTap {
    param(
        [Parameter(Mandatory=$true)]
        [byte] $VirtualKey
    )

    Ensure-InputRecoveryType
    $KEYEVENTF_KEYUP = 0x0002
    [DragonWarrior.InputRecovery]::keybd_event($VirtualKey, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 50
    [DragonWarrior.InputRecovery]::keybd_event($VirtualKey, 0, $KEYEVENTF_KEYUP, [UIntPtr]::Zero)
}

function Invoke-AltReleasePulse {
    # Release every Alt flavor before and after Escape. The repeated key-up
    # pulses are deliberately harmless if Alt is already up, and they help when
    # FCEUX/SDL missed one side of an Alt+Tab focus transition.
    Send-VirtualKeyUp -VirtualKey 0xA4  # VK_LMENU / Left Alt
    Send-VirtualKeyUp -VirtualKey 0xA5  # VK_RMENU / Right Alt
    Send-VirtualKeyUp -VirtualKey 0x12  # VK_MENU / generic Alt
    Start-Sleep -Milliseconds 60
    Send-VirtualKeyTap -VirtualKey 0x1B # VK_ESCAPE / dismiss menu focus
    Start-Sleep -Milliseconds 60
    Send-VirtualKeyUp -VirtualKey 0xA4
    Send-VirtualKeyUp -VirtualKey 0xA5
    Send-VirtualKeyUp -VirtualKey 0x12
    Start-Sleep -Milliseconds 60
    Send-VirtualKeyUp -VirtualKey 0xA4
    Send-VirtualKeyUp -VirtualKey 0xA5
    Send-VirtualKeyUp -VirtualKey 0x12
}

function Focus-EmulatorWindow {
    param(
        [System.Diagnostics.Process] $Process
    )

    if (-not $Process) {
        Write-Warning "Startup input recovery: no emulator process available to focus."
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
        Start-Sleep -Milliseconds 250
    }

    if ($hwnd -eq [IntPtr]::Zero) {
        Write-Warning "Startup input recovery: emulator window handle was not ready."
        return $false
    }

    [void] [DragonWarrior.InputRecovery]::ShowWindow($hwnd, 9) # SW_RESTORE
    Start-Sleep -Milliseconds 100
    $focused = [DragonWarrior.InputRecovery]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 150
    Write-Host ("Startup input recovery: foregrounded emulator window: {0}" -f $focused)
    return $focused
}

function Invoke-StartupInputRecovery {
    param(
        [System.Diagnostics.Process] $Process,
        [string] $Phase = "startup",
        [string] $KeyboardBridgePath,
        [string] $CommandFile,
        [switch] $QueueStatus
    )

    # FCEUX/SDL can occasionally report LeftAlt as still held after script/ROM
    # startup. A key-up only event is intentionally conservative: it clears a
    # stale modifier without opening menus or injecting gameplay input. If the
    # Alt key has already activated FCEUX's menu accelerator focus, Escape
    # dismisses that UI mode so keyboard input returns to the game canvas.
    try {
        [void] (Focus-EmulatorWindow -Process $Process)
        Invoke-AltReleasePulse
        if (-not [string]::IsNullOrWhiteSpace($KeyboardBridgePath)) {
            [System.IO.File]::WriteAllText($KeyboardBridgePath, "-" + [Environment]::NewLine)
            Write-Host ("Startup input recovery ({0}): reset keyboard bridge state." -f $Phase)
        }
        if ($QueueStatus -and -not [string]::IsNullOrWhiteSpace($CommandFile)) {
            Add-Content -LiteralPath $CommandFile -Value "input_status:fceux_recovery"
            Write-Host ("Startup input recovery ({0}): queued input_status:fceux_recovery." -f $Phase)
        }
        Write-Host ("Startup input recovery ({0}): sent repeated LeftAlt/RightAlt/generic Alt key-up pulse and Escape tap." -f $Phase)
    } catch {
        Write-Warning ("Startup input recovery failed: {0}" -f $_.Exception.Message)
    }
}

function Get-ConfigValue {
    param(
        [string] $ConfigPath,
        [string] $Key
    )

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        return $null
    }

    $match = Select-String -LiteralPath $ConfigPath -Pattern ("^{0}\s*=\s*(.+)$" -f [regex]::Escape($Key)) | Select-Object -First 1
    if (-not $match) {
        return $null
    }

    return $match.Matches[0].Groups[1].Value.Trim()
}

function Set-ConfigValue {
    param(
        [string] $ConfigPath,
        [string] $Key,
        [string] $Value
    )

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Config file not found: $ConfigPath"
    }

    $text = Get-Content -LiteralPath $ConfigPath -Raw
    $pattern = ("(?m)^{0}\s*=.*$" -f [regex]::Escape($Key))
    $line = "{0} = {1}" -f $Key, $Value
    if ($text -match $pattern) {
        $text = $text -replace $pattern, $line
    } else {
        if (-not $text.EndsWith("`n")) {
            $text += [Environment]::NewLine
        }
        $text += $line + [Environment]::NewLine
    }
    Set-Content -LiteralPath $ConfigPath -Value $text -NoNewline
}

function Disable-FceuxNativeKeyboardGamepad {
    param([string] $ConfigPath)

    # qfceux/SDL can leave keyboard-backed GamePad.0 state stuck (for example
    # native joy1=left while Windows reports no key down). Lua joypad.set()
    # cannot clear that native state because FCEUX ORs the sources together.
    # Disable the native keyboard gamepad and let keyboard_bridge.ps1 provide
    # the project-owned keyboard-to-NES-pad path instead.
    Set-ConfigValue -ConfigPath $ConfigPath -Key "SDL.Input.GamePad.0.DeviceGUID" -Value ""
    Set-ConfigValue -ConfigPath $ConfigPath -Key "SDL.Input.GamePad.0.DeviceType" -Value "None"
    Set-ConfigValue -ConfigPath $ConfigPath -Key "SDL.Input.GamePad.0.Profile" -Value ""
    Write-Host "Configured FCEUX GamePad.0 native keyboard input: disabled; using project keyboard bridge."
}

function Enable-FceuxHideMenu {
    param([string] $ConfigPath)

    $current = Get-ConfigValue -ConfigPath $ConfigPath -Key "SDL.ToggleMenu"
    if ($current -eq "1") {
        Write-Host "FCEUX Hide Menu already enabled: SDL.ToggleMenu = 1."
        return
    }

    Set-ConfigValue -ConfigPath $ConfigPath -Key "SDL.ToggleMenu" -Value "1"
    Write-Host ("Configured FCEUX Hide Menu: SDL.ToggleMenu {0} -> 1. Escape restores the menu if needed." -f $(if ($null -ne $current) { $current } else { "(missing)" }))
}

function Disable-FceuxAltHotkeys {
    param([string] $ConfigPath)

    $altHotkeys = @(
        "SDL.Hotkeys.MainMenuHide",
        "SDL.Hotkeys.FullScreen"
    )

    foreach ($key in $altHotkeys) {
        $current = Get-ConfigValue -ConfigPath $ConfigPath -Key $key
        if ([string]::IsNullOrWhiteSpace($current)) {
            Write-Host ("FCEUX Alt hotkey already blank: {0}" -f $key)
        } else {
            Set-ConfigValue -ConfigPath $ConfigPath -Key $key -Value ""
            Write-Host ("Blanked FCEUX Alt hotkey: {0} was '{1}'" -f $key, $current)
        }
    }
}

function Wait-ForCommandPolling {
    param(
        [string] $CommandFile,
        [string] $LogPath,
        [string] $ProbeCommand,
        [string] $SuccessPattern,
        [string] $StartupLoopDiag,
        [datetime] $LaunchStartUtc,
        [System.Diagnostics.Process] $Process,
        [int] $TimeoutSeconds = 12
    )

    $probeStartUtc = [datetime]::UtcNow
    [System.IO.File]::WriteAllText($CommandFile, $ProbeCommand + [Environment]::NewLine)
    Write-Host ("Queued readiness probe: {0}" -f $ProbeCommand)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $diagnostics = Get-ReadinessDiagnostics `
            -CommandFile $CommandFile `
            -LogPath $LogPath `
            -StartupLoopDiag $StartupLoopDiag `
            -ProbeCommand $ProbeCommand `
            -SuccessPattern $SuccessPattern `
            -LaunchStartUtc $LaunchStartUtc `
            -ProbeStartUtc $probeStartUtc `
            -Process $Process
        $script:lastReadinessProbeDiagnostics = Format-ReadinessDiagnostics -Diagnostics $diagnostics

        if ($diagnostics.CommandConsumed -eq "yes" -and $diagnostics.ProbeSeen -eq "yes") {
            Write-Host ("Ready: command polling confirmed via {0}" -f $ProbeCommand)
            Write-Host ("Readiness diagnostics: {0}" -f $script:lastReadinessProbeDiagnostics)
            return $true
        }

        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    return $false
}

$FceuxPath = Resolve-LauncherPath -CliValue $FceuxPath -EnvName "DW_FCEUX_PATH" -DefaultValue "D:\emulation\fceux\bin\qfceux.exe"
$RomPath = Resolve-LauncherPath -CliValue $RomPath -EnvName "DW_ROM_PATH" -DefaultValue "D:\emulation\nes\Dragon Warrior (USA) (Rev 1).nes"
$LuaPath = Resolve-LauncherPath -CliValue $LuaPath -EnvName "DW_LUA_PATH" -DefaultValue (Join-Path $scriptDir "main.lua")

Assert-FileExists -PathValue $FceuxPath -Label "FCEUX executable"
Assert-FileExists -PathValue $RomPath -Label "ROM"
Assert-FileExists -PathValue $LuaPath -Label "Lua script"

if (-not [string]::IsNullOrWhiteSpace($BatterySavePath)) {
    Assert-FileExists -PathValue $BatterySavePath -Label "Battery save"
    $saveExt = [System.IO.Path]::GetExtension($BatterySavePath).ToLowerInvariant()
    if ($saveExt -ne ".sav" -and $saveExt -ne ".saveram") {
        throw "Battery save data must use .sav or .SaveRAM extension: $BatterySavePath"
    }
}

$emulatorDir = Split-Path -Parent $FceuxPath
$configPath = Join-Path $emulatorDir "fceux.cfg"
$romStem = [System.IO.Path]::GetFileNameWithoutExtension($RomPath)
$saveDir = Join-Path $emulatorDir "sav"
$batterySaveTarget = Join-Path $saveDir ($romStem + ".sav")
$commandFile = Join-Path $scriptDir "dw_commands.txt"
$processingFile = Join-Path $scriptDir "dw_commands.processing.txt"
$keyboardBridgeScript = Join-Path $scriptDir "keyboard_bridge.ps1"
$keyboardBridgeFile = Join-Path $scriptDir "dw_keyboard_input.txt"
$debugLog = Join-Path $scriptDir "dw_debug.log"
$startupLoopDiag = Join-Path $scriptDir "startup_loop_diag.txt"
$launchShim = Join-Path $scriptDir "launch_dw.cmd"

$loadStateEnabled = $StateSlot -ge 0
$autoResumeValue = Get-ConfigValue -ConfigPath $configPath -Key "SDL.AutoResume"
$hideMenuValue = Get-ConfigValue -ConfigPath $configPath -Key "SDL.ToggleMenu"
$mainMenuHotkeyValue = Get-ConfigValue -ConfigPath $configPath -Key "SDL.Hotkeys.MainMenuHide"
$fullscreenHotkeyValue = Get-ConfigValue -ConfigPath $configPath -Key "SDL.Hotkeys.FullScreen"

Assert-FileExists -PathValue $launchShim -Label "Launcher shim"
Assert-FileExists -PathValue $keyboardBridgeScript -Label "Keyboard bridge script"

Write-Host "Dragon Warrior launcher"
Write-Host ("  Emulator: {0}" -f $FceuxPath)
Write-Host ("  ROM:      {0}" -f $RomPath)
Write-Host ("  Lua:      {0}" -f $LuaPath)
Write-Host ("  Save:     {0}" -f $(if ($BatterySavePath) { $BatterySavePath } else { "(none)" }))
Write-Host ("  Slot:     {0}" -f $(if ($loadStateEnabled) { $StateSlot } else { "(none)" }))
Write-Host ("  AutoResume: {0} (old-session restore; not used for command polling)" -f $(if ($null -ne $autoResumeValue) { $autoResumeValue } else { "(unknown)" }))
Write-Host ("  Hide menu: {0}" -f $(if ($null -ne $hideMenuValue) { $hideMenuValue } else { "(unknown)" }))
Write-Host ("  Alt menu hotkey: {0}" -f $(if ($null -ne $mainMenuHotkeyValue -and $mainMenuHotkeyValue -ne "") { $mainMenuHotkeyValue } else { "(blank)" }))
Write-Host ("  Alt fullscreen hotkey: {0}" -f $(if ($null -ne $fullscreenHotkeyValue -and $fullscreenHotkeyValue -ne "") { $fullscreenHotkeyValue } else { "(blank)" }))
Write-Host "  Background input: disabled via -bginput 0"
Write-Host ("  Wait:     {0}" -f (Format-Bool (-not $NoWait)))
Write-Host ("  Dry run:  {0}" -f (Format-Bool $DryRun))

if ($null -eq $autoResumeValue) {
    Write-Warning ("Could not read SDL.AutoResume from {0}; launcher will leave it unchanged." -f $configPath)
}

$existingProcesses = @(Get-Process -Name qfceux, fceux -ErrorAction SilentlyContinue)
if ($existingProcesses.Count -gt 0) {
    foreach ($process in $existingProcesses) {
        Write-Host ("Found running emulator: {0} (PID {1})" -f $process.ProcessName, $process.Id)
    }
} else {
    Write-Host "No running emulator found."
}

if ($DryRun) {
    if ($existingProcesses.Count -gt 0) {
        Write-Host "Dry run: would close the running emulator process(es)."
    }
    Write-Host ("Dry run: would clear {0}" -f $commandFile)
    if (Test-Path -LiteralPath $startupLoopDiag) {
        Write-Host ("Dry run: would remove {0}" -f $startupLoopDiag)
    }
    if (Test-Path -LiteralPath $processingFile) {
        Write-Host ("Dry run: would remove {0}" -f $processingFile)
    }
    if ($BatterySavePath) {
        $sameSavePath = [System.StringComparer]::OrdinalIgnoreCase.Equals(
            [System.IO.Path]::GetFullPath($BatterySavePath),
            [System.IO.Path]::GetFullPath($batterySaveTarget)
        )
        if ($sameSavePath) {
            Write-Host "Dry run: battery save already matches the target path; copy would be skipped."
        } else {
            Write-Host ("Dry run: would copy battery save to {0}" -f $batterySaveTarget)
        }
    }

    $previewArgs = @()
    if ($loadStateEnabled) {
        $previewArgs += "--loadstate"
        $previewArgs += [string] $StateSlot
    }
    $previewArgs += "-bginput"
    $previewArgs += "0"
    $previewArgs += ("--loadlua=" + $LuaPath)
    $previewArgs += (Quote-Argument $RomPath)
    $shimPreviewArgs = @(
        (Quote-Argument $FceuxPath),
        (Quote-Argument $RomPath),
        (Quote-Argument $LuaPath)
    )
    if ($loadStateEnabled) {
        $shimPreviewArgs += [string] $StateSlot
    }

    Write-Host ("Dry run: would invoke launcher shim {0}" -f $launchShim)
    Write-Host ("  Shim args: {0}" -f ($shimPreviewArgs -join " "))
    Write-Host ("Dry run: would launch {0}" -f $FceuxPath)
    Write-Host ("  Args: {0}" -f ($previewArgs -join " "))
    exit 0
}

if ($existingProcesses.Count -gt 0) {
    $processIds = @($existingProcesses | ForEach-Object { $_.Id })
    foreach ($process in $existingProcesses) {
        if ($process.MainWindowHandle -ne 0) {
            Write-Host ("Requesting graceful close for PID {0}..." -f $process.Id)
            [void] $process.CloseMainWindow()
        }
    }

    Wait-ForProcessExit -Ids $processIds -TimeoutSeconds 5

    $stillRunning = @(Get-Process -Id $processIds -ErrorAction SilentlyContinue)
    if ($stillRunning.Count -gt 0) {
        foreach ($process in $stillRunning) {
            Write-Host ("Force stopping PID {0}..." -f $process.Id)
            Stop-Process -Id $process.Id -Force
        }
        Wait-ForProcessExit -Ids $processIds -TimeoutSeconds 5
    }

    $afterStop = @(Get-Process -Id $processIds -ErrorAction SilentlyContinue)
    if ($afterStop.Count -gt 0) {
        $ids = ($afterStop | ForEach-Object { $_.Id }) -join ", "
        throw "Failed to stop emulator process(es): $ids"
    }
}

Disable-FceuxNativeKeyboardGamepad -ConfigPath $configPath
Enable-FceuxHideMenu -ConfigPath $configPath
Disable-FceuxAltHotkeys -ConfigPath $configPath

$existingBridgeProcesses = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*keyboard_bridge.ps1*" })
foreach ($bridgeProcess in $existingBridgeProcesses) {
    Write-Host ("Stopping stale keyboard bridge PID {0}..." -f $bridgeProcess.ProcessId)
    Stop-Process -Id $bridgeProcess.ProcessId -Force -ErrorAction SilentlyContinue
}

[System.IO.File]::WriteAllText($commandFile, "")
[System.IO.File]::WriteAllText($keyboardBridgeFile, "-" + [Environment]::NewLine)
if (Test-Path -LiteralPath $startupLoopDiag) {
    Remove-Item -LiteralPath $startupLoopDiag -Force
    Write-Host ("Removed stale startup loop trace: {0}" -f $startupLoopDiag)
}
if (Test-Path -LiteralPath $processingFile) {
    Remove-Item -LiteralPath $processingFile -Force
    Write-Host ("Removed stale processing queue: {0}" -f $processingFile)
}
Write-Host ("Cleared command queue: {0}" -f $commandFile)
Write-Host ("Cleared keyboard bridge state: {0}" -f $keyboardBridgeFile)

if ($BatterySavePath) {
    New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
    $sameSavePath = [System.StringComparer]::OrdinalIgnoreCase.Equals(
        [System.IO.Path]::GetFullPath($BatterySavePath),
        [System.IO.Path]::GetFullPath($batterySaveTarget)
    )
    if ($sameSavePath) {
        Write-Host ("Battery save already in place: {0}" -f $batterySaveTarget)
    } else {
        Copy-Item -LiteralPath $BatterySavePath -Destination $batterySaveTarget -Force
        Write-Host ("Copied battery save to: {0}" -f $batterySaveTarget)
    }
}

$launchArgs = @()
if ($loadStateEnabled) {
    $launchArgs += "--loadstate"
    $launchArgs += [string] $StateSlot
}
$launchArgs += "-bginput"
$launchArgs += "0"
$launchArgs += ("--loadlua=" + $LuaPath)
$launchArgs += (Quote-Argument $RomPath)

$shimArgs = @($FceuxPath, $RomPath, $LuaPath)
if ($loadStateEnabled) {
    $shimArgs += [string] $StateSlot
}

$launchStartUtc = [datetime]::UtcNow
$bridgeProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $keyboardBridgeScript,
    "-OutputPath", $keyboardBridgeFile
) -WindowStyle Hidden -PassThru
Write-Host ("Started keyboard bridge PID {0}" -f $bridgeProcess.Id)
& $launchShim @shimArgs
$shimExitCode = $LASTEXITCODE
if ($shimExitCode -ne 0) {
    throw ("Launcher shim failed with exit code {0}" -f $shimExitCode)
}

$process = Wait-ForNewEmulatorProcess -LaunchStartUtc $launchStartUtc -TimeoutSeconds 5
if (-not $process) {
    throw "Launcher shim returned success, but no new qfceux process appeared."
}

Write-Host ("Started emulator PID {0}" -f $process.Id)
Write-Host ("Launch args: {0}" -f ($launchArgs -join " "))
Invoke-StartupInputRecovery -Process $process -Phase "post-start" -KeyboardBridgePath $keyboardBridgeFile

if ($NoWait) {
    Write-Host "Skipping readiness wait."
    exit 0
}

if (-not (Wait-ForDebugLog -LogPath $debugLog -LaunchStartUtc $launchStartUtc -TimeoutSeconds 20)) {
    $diagnostics = Get-ReadinessDiagnostics `
        -CommandFile $commandFile `
        -LogPath $debugLog `
        -StartupLoopDiag $startupLoopDiag `
        -ProbeCommand "__startup_log_probe_not_sent__" `
        -SuccessPattern "__startup_log_probe_not_sent__" `
        -LaunchStartUtc $launchStartUtc `
        -ProbeStartUtc $launchStartUtc `
        -Process $process
    $script:lastReadinessProbeDiagnostics = Format-ReadinessDiagnostics -Diagnostics $diagnostics
    $hint = "Timed out waiting for dw_debug.log to update after launch."
    $hint += (" Readiness diagnostics: {0}." -f $script:lastReadinessProbeDiagnostics)
    $hint += " FCEUX command-line ROM/Lua startup is unreliable on this machine; if qfceux is open, manually load the ROM and main.lua, then verify command polling with input_status."
    $hint += " BizHawk remains the dependable automated startup path."
    throw $hint
}

$probeTag = [guid]::NewGuid().ToString("N")
$probeCommand = "launcher_probe:" + $probeTag
$probeSuccessPattern = "LAUNCHER_PROBE: " + $probeTag

if (-not (Wait-ForCommandPolling -CommandFile $commandFile -LogPath $debugLog -ProbeCommand $probeCommand -SuccessPattern $probeSuccessPattern -StartupLoopDiag $startupLoopDiag -LaunchStartUtc $launchStartUtc -Process $process -TimeoutSeconds 12)) {
    $hint = "The emulator started but did not consume the readiness probe from dw_commands.txt."
    $hint += (" Readiness diagnostics: {0}." -f $script:lastReadinessProbeDiagnostics)
    $hint += " AutoResume is only old-session restore; this launcher leaves it unchanged and uses explicit --loadstate when requested."
    $hint += (" Probe marker: {0}." -f $probeSuccessPattern)
    $hint += (" Inspect {0} for before/after frameadvance markers." -f $startupLoopDiag)
    throw $hint
}

Invoke-StartupInputRecovery -Process $process -Phase "post-ready" -KeyboardBridgePath $keyboardBridgeFile -CommandFile $commandFile -QueueStatus
