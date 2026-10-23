[CmdletBinding()]
param(
    [string] $PackageRoot,
    [string] $RomManifestPath,
    [switch] $ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
    $PackageRoot = Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($RomManifestPath)) {
    $RomManifestPath = Join-Path $PSScriptRoot "roms.json"
}

$PackageRoot = [System.IO.Path]::GetFullPath($PackageRoot)
$userDirectory = Join-Path $PackageRoot "user"
$script:launchLogPath = Join-Path $userDirectory "launch.log"
$script:unsupportedRomAcknowledgementPath = Join-Path $userDirectory "unsupported-rom-acknowledgement.json"

function Write-LaunchMessage {
    param([string] $Message)

    Write-Output $Message
    if (Test-Path -LiteralPath $userDirectory -PathType Container) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $script:launchLogPath -Encoding UTF8 -Value ("[{0}] {1}" -f $timestamp, $Message)
    }
}

function Get-FileSha256 {
    param([string] $Path)

    $stream = $null
    $sha256 = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($stream)
        return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToUpperInvariant()
    } finally {
        if ($null -ne $sha256) { $sha256.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Ensure-FceuxPathCompatibilityType {
    if (-not ("DragonWarrior.FceuxPathCompatibility" -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace DragonWarrior {
    public static class FceuxPathCompatibility {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern uint GetShortPathName(
            string longPath,
            StringBuilder shortPath,
            uint bufferLength
        );
    }
}
'@
    }
}

function Get-FceuxCompatiblePath {
    param(
        [string] $PathValue,
        [string] $Label,
        [switch] $Directory
    )

    $fullPath = [System.IO.Path]::GetFullPath($PathValue)
    if ($fullPath -notmatch '[^\x00-\x7F]') {
        return $fullPath
    }

    $aliasTarget = if ($Directory) {
        $fullPath
    } else {
        Split-Path -Parent $fullPath
    }

    Ensure-FceuxPathCompatibilityType
    $buffer = New-Object System.Text.StringBuilder 32768
    $length = [DragonWarrior.FceuxPathCompatibility]::GetShortPathName(
        $aliasTarget,
        $buffer,
        [uint32] $buffer.Capacity
    )
    if ($length -eq 0) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw ("{0} is under a non-ASCII path, and Windows could not create a compatibility alias (error {1}). Move the extracted Dragon Warrior Accessibility folder to a path using only English letters, numbers, spaces, hyphens, and underscores." -f $Label, $errorCode)
    }

    $compatiblePath = if ($Directory) {
        $buffer.ToString()
    } else {
        Join-Path $buffer.ToString() ([System.IO.Path]::GetFileName($fullPath))
    }
    if ($compatiblePath -match '[^\x00-\x7F]') {
        throw ("{0} is under a non-ASCII path that this FCEUX build cannot open safely. Move the extracted Dragon Warrior Accessibility folder to a path using only English letters, numbers, spaces, hyphens, and underscores." -f $Label)
    }

    return $compatiblePath
}

function Test-UnsupportedRomAcknowledgement {
    param(
        [int64] $Size,
        [string] $Sha256
    )

    if (-not (Test-Path -LiteralPath $script:unsupportedRomAcknowledgementPath -PathType Leaf)) {
        return $false
    }

    try {
        $record = Get-Content -LiteralPath $script:unsupportedRomAcknowledgementPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $requiredProperties = @("schemaVersion", "acknowledged", "size", "sha256")
        foreach ($propertyName in $requiredProperties) {
            if ($record.PSObject.Properties.Name -notcontains $propertyName) {
                return $false
            }
        }
        return (
            [int] $record.schemaVersion -eq 1 -and
            [bool] $record.acknowledged -and
            [int64] $record.size -eq $Size -and
            ([string] $record.sha256).ToUpperInvariant() -eq $Sha256
        )
    } catch {
        return $false
    }
}

function Set-PrivateFceuxConfigValue {
    param(
        [string] $ConfigPath,
        [string] $Key,
        [string] $Value
    )

    $text = [System.IO.File]::ReadAllText($ConfigPath)
    $line = "{0} = {1}" -f $Key, $Value
    $pattern = "(?m)^{0}\s*=.*$" -f [regex]::Escape($Key)
    if ($text -match $pattern) {
        # Paths may contain dollar signs; a string replacement interprets $&,
        # $1, and $$ as regex substitutions instead of literal path characters.
        $text = [regex]::Replace($text, $pattern, [System.Text.RegularExpressions.MatchEvaluator] {
            param($match)
            return $line
        })
    } else {
        if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) {
            $text += [Environment]::NewLine
        }
        $text += $line + [Environment]::NewLine
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ConfigPath, $text, $utf8NoBom)
}

if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    Write-Output ("Player package folder not found: {0}" -f $PackageRoot)
    exit 4
}

New-Item -ItemType Directory -Path $userDirectory -Force | Out-Null
Set-Content -LiteralPath $script:launchLogPath -Encoding UTF8 -Value ("=== Dragon Warrior player launch {0:u} ===" -f [datetime]::UtcNow)
Write-LaunchMessage "Dragon Warrior Accessibility player launcher"

$romPath = Join-Path $userDirectory "Dragon Warrior.nes"
if (-not (Test-Path -LiteralPath $romPath -PathType Leaf)) {
    Write-LaunchMessage "Dragon Warrior is not installed yet."
    Write-LaunchMessage "Run Install Dragon Warrior.cmd, then run Play Dragon Warrior.cmd again."
    exit 2
}

if (-not (Test-Path -LiteralPath $RomManifestPath -PathType Leaf)) {
    Write-LaunchMessage ("Player package is incomplete. ROM manifest not found: {0}" -f $RomManifestPath)
    exit 4
}

try {
    $manifest = Get-Content -LiteralPath $RomManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $supportedRoms = @($manifest.roms)
    $romItem = Get-Item -LiteralPath $romPath
    $romHash = Get-FileSha256 -Path $romPath
    $romMatch = $null
    foreach ($supported in $supportedRoms) {
        if ($romItem.Length -eq [int64] $supported.size -and
            $romHash -eq ([string] $supported.sha256).ToUpperInvariant()) {
            $romMatch = $supported
            break
        }
    }
} catch {
    Write-LaunchMessage ("The installed ROM could not be verified: {0}" -f $_.Exception.Message)
    Write-LaunchMessage "No emulator was started."
    exit 3
}

$unsupportedRomOverride = $false
if ($null -eq $romMatch) {
    $unsupportedRomOverride = Test-UnsupportedRomAcknowledgement -Size $romItem.Length -Sha256 $romHash
}

if ($null -eq $romMatch -and -not $unsupportedRomOverride) {
    Write-LaunchMessage "The installed ROM is not the supported revision."
    Write-LaunchMessage ("Actual size: {0} bytes" -f $romItem.Length)
    Write-LaunchMessage ("Actual SHA-256: {0}" -f $romHash)
    Write-LaunchMessage "Run Install Dragon Warrior.cmd with your US Rev 1 ROM. No emulator was started."
    exit 3
}

if ($unsupportedRomOverride) {
    Write-LaunchMessage "WARNING: Running an unsupported ROM by prior user acknowledgement."
    Write-LaunchMessage ("Accepted SHA-256: {0}" -f $romHash)
    Write-LaunchMessage "Accessibility narration, navigation, game behavior, and save compatibility may be incorrect."
}

$relativeRequiredFiles = @(
    "app\main.lua",
    "app\launch_dw.ps1",
    "app\launch_dw.cmd",
    "app\keyboard_bridge.ps1",
    "app\speech_bridge.py",
    "app\dw_access.ini",
    "runtime\fceux\qfceux.exe",
    "runtime\python\python.exe",
    "user\fceux\fceux.cfg"
)
$missingFiles = @()
foreach ($relativePath in $relativeRequiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot $relativePath) -PathType Leaf)) {
        $missingFiles += $relativePath
    }
}
if ($missingFiles.Count -gt 0) {
    Write-LaunchMessage "Player package is incomplete. Missing required file(s):"
    foreach ($relativePath in $missingFiles) {
        Write-LaunchMessage ("  {0}" -f $relativePath)
    }
    Write-LaunchMessage "Extract the complete release ZIP and run setup again. No emulator was started."
    exit 4
}

$fceuxPath = Join-Path $PackageRoot "runtime\fceux\qfceux.exe"
$fceuxDataDirectory = Join-Path $userDirectory "fceux"
$luaPath = Join-Path $PackageRoot "app\main.lua"
$launcherPath = Join-Path $PackageRoot "app\launch_dw.ps1"
$fceuxConfigPath = Join-Path $fceuxDataDirectory "fceux.cfg"
$fceuxLaunchPath = Get-FceuxCompatiblePath -PathValue $fceuxPath -Label "Packaged FCEUX"
$romLaunchPath = Get-FceuxCompatiblePath -PathValue $romPath -Label "Installed ROM"
$luaLaunchPath = Get-FceuxCompatiblePath -PathValue $luaPath -Label "Accessibility script"
$fceuxDataLaunchDirectory = Get-FceuxCompatiblePath -PathValue $fceuxDataDirectory -Label "Private FCEUX data" -Directory
$usesCompatibilityAliases = @(@(
        $fceuxLaunchPath,
        $romLaunchPath,
        $luaLaunchPath,
        $fceuxDataLaunchDirectory
    ) | Where-Object { $_ -match '~' })
$normalizedLuaPath = $luaLaunchPath.Replace("\", "/")
Set-PrivateFceuxConfigValue -ConfigPath $fceuxConfigPath -Key "SDL.LastLoadLua" -Value $normalizedLuaPath
Set-PrivateFceuxConfigValue -ConfigPath $fceuxConfigPath -Key "SDL.LuaScript" -Value $normalizedLuaPath

if ($unsupportedRomOverride) {
    Write-LaunchMessage "Unsupported ROM override active for this exact file."
} else {
    Write-LaunchMessage ("Supported ROM: {0}" -f $romMatch.name)
}
Write-LaunchMessage ("Emulator: {0}" -f $fceuxPath)
Write-LaunchMessage ("Private FCEUX data: {0}" -f $fceuxDataDirectory)
Write-LaunchMessage ("ROM: {0}" -f $romPath)
Write-LaunchMessage ("Mod: {0}" -f $luaPath)
if ($usesCompatibilityAliases.Count -gt 0) {
    Write-LaunchMessage "Non-ASCII installation path detected; using Windows compatibility aliases for FCEUX."
}
Write-LaunchMessage "Private FCEUX Lua autoload path refreshed."
Write-LaunchMessage "Player package validation passed."

if ($ValidateOnly) {
    Write-LaunchMessage "Validation only: no emulator was started."
    exit 0
}

$env:FCEUX_CONFIG_DIR = $fceuxDataLaunchDirectory
$previousConfigLuaOnly = [Environment]::GetEnvironmentVariable("DW_LAUNCH_CONFIG_LUA_ONLY")
$env:DW_LAUNCH_CONFIG_LUA_ONLY = "1"
try {
    & $launcherPath `
        -FceuxPath $fceuxLaunchPath `
        -RomPath $romLaunchPath `
        -LuaPath $luaLaunchPath `
        -IsolatedProcessScope `
        -PlayerReadiness
    if (-not $?) {
        throw "The FCEUX launcher returned a failure status."
    }
} catch {
    Write-LaunchMessage ("Player launch failed: {0}" -f $_.Exception.Message)
    Write-LaunchMessage ("Diagnostic log: {0}" -f $script:launchLogPath)
    exit 5
} finally {
    $env:DW_LAUNCH_CONFIG_LUA_ONLY = $previousConfigLuaOnly
}

Write-LaunchMessage "Dragon Warrior started successfully."
exit 0
