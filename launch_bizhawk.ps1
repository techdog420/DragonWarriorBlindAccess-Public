[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $BizhawkPath,

    [Parameter(Mandatory=$true)]
    [string] $LuaPath,

    [Parameter(Mandatory=$true)]
    [string] $RomPath,

    [string] $StateSlot = "",

    [string] $BatterySavePath = "",

    [switch] $NoWait,
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BizhawkPath -PathType Leaf)) {
    throw "BizHawk executable not found: $BizhawkPath"
}
if (-not (Test-Path -LiteralPath $LuaPath -PathType Leaf)) {
    throw "Lua script not found: $LuaPath"
}
if (-not (Test-Path -LiteralPath $RomPath -PathType Leaf)) {
    throw "ROM not found: $RomPath"
}
if (-not [string]::IsNullOrWhiteSpace($BatterySavePath)) {
    if (-not (Test-Path -LiteralPath $BatterySavePath -PathType Leaf)) {
        throw "Battery save data not found: $BatterySavePath"
    }
    $saveExt = [System.IO.Path]::GetExtension($BatterySavePath).ToLowerInvariant()
    if ($saveExt -ne ".sav" -and $saveExt -ne ".saveram") {
        throw "Battery save data must use .sav or .SaveRAM extension: $BatterySavePath"
    }
}

function Get-BizhawkSaveRamTarget {
    param(
        [string] $EmulatorPath,
        [string] $LoadedRomPath
    )

    $emulatorDir = Split-Path -Parent $EmulatorPath
    $saveRamDir = Join-Path $emulatorDir "NES\SaveRAM"
    $romStem = [System.IO.Path]::GetFileNameWithoutExtension($LoadedRomPath)
    $cleanStem = [regex]::Replace($romStem, "\s*\([^)]*\)", "").Trim()
    if ([string]::IsNullOrWhiteSpace($cleanStem)) {
        $cleanStem = $romStem
    }

    $candidateNames = @(
        ($cleanStem + ".SaveRAM"),
        ($romStem + ".SaveRAM")
    ) | Select-Object -Unique

    foreach ($name in $candidateNames) {
        $candidate = Join-Path $saveRamDir $name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    if (Test-Path -LiteralPath $saveRamDir -PathType Container) {
        $matches = @(Get-ChildItem -LiteralPath $saveRamDir -Filter ($cleanStem + "*.SaveRAM") -File -ErrorAction SilentlyContinue)
        if ($matches.Count -eq 1) {
            return $matches[0].FullName
        }
    }

    return (Join-Path $saveRamDir ($cleanStem + ".SaveRAM"))
}

$saveRamTarget = ""
if (-not [string]::IsNullOrWhiteSpace($BatterySavePath)) {
    $saveRamTarget = Get-BizhawkSaveRamTarget -EmulatorPath $BizhawkPath -LoadedRomPath $RomPath
}

Write-Host "BizHawk launcher"
Write-Host ("  Emulator: {0}" -f $BizhawkPath)
Write-Host ("  ROM:      {0}" -f $RomPath)
Write-Host ("  Lua:      {0}" -f $LuaPath)
if (-not [string]::IsNullOrWhiteSpace($BatterySavePath)) {
    Write-Host ("  Battery:  {0}" -f $BatterySavePath)
    Write-Host ("  SaveRAM:  {0}" -f $saveRamTarget)
}
$waitLabel = "yes"
if ($NoWait) {
    $waitLabel = "no"
}
Write-Host ("  Wait:     {0}" -f $waitLabel)
if ($StateSlot -ne "") {
    Write-Host ("  State:    slot {0}" -f $StateSlot)
}

function Quote-ProcessArgument {
    param([string] $Value)
    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    return '"' + ($Value -replace '"', '\"') + '"'
}

$arguments = @(
    "--lua=$LuaPath"
)
if ($StateSlot -ne "") {
    $arguments += @("--load-slot", $StateSlot)
}
$arguments += $RomPath

if ($DryRun) {
    Write-Host ("  Argument: --lua={0}" -f $LuaPath)
    if ($StateSlot -ne "") {
        Write-Host ("  Argument: --load-slot {0}" -f $StateSlot)
    }
    if (-not [string]::IsNullOrWhiteSpace($BatterySavePath)) {
        $existingProcesses = @(Get-Process -Name EmuHawk -ErrorAction SilentlyContinue)
        if ($existingProcesses.Count -gt 0) {
            Write-Host "  Battery:  would require BizHawk to be closed before copying."
        } else {
            Write-Host ("  Battery:  would copy to {0}" -f $saveRamTarget)
        }
    }
    return
}

if (-not [string]::IsNullOrWhiteSpace($BatterySavePath)) {
    $existingProcesses = @(Get-Process -Name EmuHawk -ErrorAction SilentlyContinue)
    if ($existingProcesses.Count -gt 0) {
        throw "Close BizHawk before seeding battery save data; running EmuHawk can ignore or overwrite copied SaveRAM."
    }

    $saveRamDir = Split-Path -Parent $saveRamTarget
    New-Item -ItemType Directory -Path $saveRamDir -Force | Out-Null
    $sameSavePath = [System.StringComparer]::OrdinalIgnoreCase.Equals(
        [System.IO.Path]::GetFullPath($BatterySavePath),
        [System.IO.Path]::GetFullPath($saveRamTarget)
    )
    if ($sameSavePath) {
        Write-Host ("Battery save data already in place: {0}" -f $saveRamTarget)
    } else {
        Copy-Item -LiteralPath $BatterySavePath -Destination $saveRamTarget -Force
        Write-Host ("Copied battery save data to: {0}" -f $saveRamTarget)
    }
}

if ($NoWait) {
    $startArguments = @($arguments | ForEach-Object { Quote-ProcessArgument $_ })
    Start-Process -FilePath $BizhawkPath -ArgumentList $startArguments | Out-Null
    return
}

& $BizhawkPath @arguments
