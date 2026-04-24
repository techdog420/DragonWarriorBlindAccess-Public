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

function Wait-ForCommandPolling {
    param(
        [string] $CommandFile,
        [string] $LogPath,
        [string] $ProbeCommand,
        [string] $SuccessPattern,
        [int] $TimeoutSeconds = 12
    )

    $probeStartUtc = [datetime]::UtcNow
    [System.IO.File]::WriteAllText($CommandFile, $ProbeCommand + [Environment]::NewLine)
    Write-Host ("Queued readiness probe: {0}" -f $ProbeCommand)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $queueEmpty = $false
        if (Test-Path -LiteralPath $CommandFile -PathType Leaf) {
            try {
                $queueText = [System.IO.File]::ReadAllText($CommandFile)
                $queueEmpty = [string]::IsNullOrWhiteSpace($queueText)
            } catch {
                $queueEmpty = $false
            }
        }

        $probeSeen = $false
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            try {
                $item = Get-Item -LiteralPath $LogPath
                if ($item.Length -gt 0 -and $item.LastWriteTimeUtc -ge $probeStartUtc) {
                    $recentLines = Get-Content -LiteralPath $LogPath -Tail 200
                    foreach ($line in $recentLines) {
                        if ($line.Contains($SuccessPattern)) {
                            $probeSeen = $true
                            break
                        }
                    }
                }
            } catch {
                $probeSeen = $false
            }
        }

        if ($queueEmpty -and $probeSeen) {
            Write-Host ("Ready: command polling confirmed via {0}" -f $ProbeCommand)
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
    if ([System.IO.Path]::GetExtension($BatterySavePath).ToLowerInvariant() -ne ".sav") {
        throw "Battery save must use a .sav extension: $BatterySavePath"
    }
}

$emulatorDir = Split-Path -Parent $FceuxPath
$configPath = Join-Path $emulatorDir "fceux.cfg"
$romStem = [System.IO.Path]::GetFileNameWithoutExtension($RomPath)
$saveDir = Join-Path $emulatorDir "sav"
$batterySaveTarget = Join-Path $saveDir ($romStem + ".sav")
$commandFile = Join-Path $scriptDir "dw_commands.txt"
$processingFile = Join-Path $scriptDir "dw_commands.processing.txt"
$debugLog = Join-Path $scriptDir "dw_debug.log"
$startupLoopDiag = Join-Path $scriptDir "startup_loop_diag.txt"
$launchShim = Join-Path $scriptDir "launch_dw.cmd"

$loadStateEnabled = $StateSlot -ge 0
$autoResumeValue = Get-ConfigValue -ConfigPath $configPath -Key "SDL.AutoResume"

Assert-FileExists -PathValue $launchShim -Label "Launcher shim"

Write-Host "Dragon Warrior launcher"
Write-Host ("  Emulator: {0}" -f $FceuxPath)
Write-Host ("  ROM:      {0}" -f $RomPath)
Write-Host ("  Lua:      {0}" -f $LuaPath)
Write-Host ("  Save:     {0}" -f $(if ($BatterySavePath) { $BatterySavePath } else { "(none)" }))
Write-Host ("  Slot:     {0}" -f $(if ($loadStateEnabled) { $StateSlot } else { "(none)" }))
Write-Host ("  AutoResume: {0}" -f $(if ($null -ne $autoResumeValue) { $autoResumeValue } else { "(unknown)" }))
Write-Host ("  Wait:     {0}" -f (Format-Bool (-not $NoWait)))
Write-Host ("  Dry run:  {0}" -f (Format-Bool $DryRun))

if ($null -eq $autoResumeValue) {
    Write-Warning ("Could not read SDL.AutoResume from {0}" -f $configPath)
} elseif ($autoResumeValue -ne "1") {
    Write-Warning ("SDL.AutoResume = {0} in {1}. FCEUX may start paused, which prevents dw_commands.txt polling." -f $autoResumeValue, $configPath)
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

[System.IO.File]::WriteAllText($commandFile, "")
if (Test-Path -LiteralPath $startupLoopDiag) {
    Remove-Item -LiteralPath $startupLoopDiag -Force
    Write-Host ("Removed stale startup loop trace: {0}" -f $startupLoopDiag)
}
if (Test-Path -LiteralPath $processingFile) {
    Remove-Item -LiteralPath $processingFile -Force
    Write-Host ("Removed stale processing queue: {0}" -f $processingFile)
}
Write-Host ("Cleared command queue: {0}" -f $commandFile)

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
$launchArgs += ("--loadlua=" + $LuaPath)
$launchArgs += (Quote-Argument $RomPath)

$shimArgs = @($FceuxPath, $RomPath, $LuaPath)
if ($loadStateEnabled) {
    $shimArgs += [string] $StateSlot
}

$launchStartUtc = [datetime]::UtcNow
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

if ($NoWait) {
    Write-Host "Skipping readiness wait."
    exit 0
}

if (-not (Wait-ForDebugLog -LogPath $debugLog -LaunchStartUtc $launchStartUtc -TimeoutSeconds 20)) {
    throw "Timed out waiting for dw_debug.log to update after launch."
}

$probeTag = [guid]::NewGuid().ToString("N")
$probeCommand = "launcher_probe:" + $probeTag
$probeSuccessPattern = "LAUNCHER_PROBE: " + $probeTag

if (-not (Wait-ForCommandPolling -CommandFile $commandFile -LogPath $debugLog -ProbeCommand $probeCommand -SuccessPattern $probeSuccessPattern -TimeoutSeconds 12)) {
    $hint = "The emulator started but did not consume the readiness probe from dw_commands.txt."
    if ($autoResumeValue -eq "0") {
        $hint += (" Likely cause: FCEUX is paused because SDL.AutoResume = 0 in {0}. Set SDL.AutoResume = 1 and relaunch." -f $configPath)
    } else {
        $hint += " Check whether FCEUX is paused or otherwise not advancing frames."
    }
    $hint += (" Probe marker: {0}." -f $probeSuccessPattern)
    $hint += (" Inspect {0} for before/after frameadvance markers." -f $startupLoopDiag)
    throw $hint
}
