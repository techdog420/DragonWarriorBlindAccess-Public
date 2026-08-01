[CmdletBinding()]
param(
    [string] $PackageRoot,
    [string] $RomPath,
    [string] $RomManifestPath,
    [switch] $NonInteractive,
    [switch] $AllowUnsupportedRom
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
$installedRomPath = Join-Path $PackageRoot "user\Dragon Warrior.nes"
$userDirectory = Join-Path $PackageRoot "user"
$fceuxDataDirectory = Join-Path $userDirectory "fceux"
$script:installLogPath = Join-Path $userDirectory "install.log"
$script:unsupportedRomAcknowledgementPath = Join-Path $userDirectory "unsupported-rom-acknowledgement.json"

function Write-InstallMessage {
    param([string] $Message)

    Write-Output $Message
    if (Test-Path -LiteralPath $userDirectory -PathType Container) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -LiteralPath $script:installLogPath -Encoding UTF8 -Value ("[{0}] {1}" -f $timestamp, $Message)
    }
}

function Get-RomFingerprint {
    param([string] $Path)

    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    $stream = $null
    $sha256 = $null
    try {
        $stream = [System.IO.File]::OpenRead($item.FullName)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($stream)
        $hashText = ([System.BitConverter]::ToString($hashBytes)).Replace("-", "")
    } finally {
        if ($null -ne $sha256) {
            $sha256.Dispose()
        }
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
    return [pscustomobject]@{
        Path = $item.FullName
        Size = [int64] $item.Length
        Sha256 = $hashText.ToUpperInvariant()
    }
}

function Get-SupportedRom {
    param(
        [object] $Fingerprint,
        [object[]] $SupportedRoms
    )

    foreach ($supported in $SupportedRoms) {
        $supportedSize = [int64] $supported.size
        $supportedHash = ([string] $supported.sha256).ToUpperInvariant()
        if ($Fingerprint.Size -eq $supportedSize -and $Fingerprint.Sha256 -eq $supportedHash) {
            return $supported
        }
    }
    return $null
}

function Test-UnsupportedRomAcknowledgement {
    param([object] $Fingerprint)

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
            [int64] $record.size -eq [int64] $Fingerprint.Size -and
            ([string] $record.sha256).ToUpperInvariant() -eq $Fingerprint.Sha256
        )
    } catch {
        return $false
    }
}

function Write-UnsupportedRomAcknowledgement {
    param([object] $Fingerprint)

    $record = [ordered]@{
        schemaVersion = 1
        acknowledged = $true
        size = [int64] $Fingerprint.Size
        sha256 = $Fingerprint.Sha256
        sourceFile = [System.IO.Path]::GetFileName($Fingerprint.Path)
    }
    $temporaryPath = $script:unsupportedRomAcknowledgementPath + ".installing"
    $json = $record | ConvertTo-Json
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($temporaryPath, $json + [Environment]::NewLine, $utf8NoBom)
    Move-Item -LiteralPath $temporaryPath -Destination $script:unsupportedRomAcknowledgementPath -Force
}

function Clear-UnsupportedRomAcknowledgement {
    if (Test-Path -LiteralPath $script:unsupportedRomAcknowledgementPath -PathType Leaf) {
        Remove-Item -LiteralPath $script:unsupportedRomAcknowledgementPath -Force
    }
}

function Select-RomFile {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select Dragon Warrior US Rev 1 ROM"
    $dialog.Filter = "NES ROM files (*.nes)|*.nes|All files (*.*)|*.*"
    $dialog.CheckFileExists = $true
    $dialog.Multiselect = $false
    $dialog.RestoreDirectory = $true

    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }
    return $null
}

function Set-PrivateFceuxConfigValue {
    param(
        [string] $ConfigPath,
        [string] $Key,
        [string] $Value
    )

    $text = if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
        [System.IO.File]::ReadAllText($ConfigPath)
    } else {
        "# Dragon Warrior Accessibility private FCEUX configuration" + [Environment]::NewLine
    }

    $line = "{0} = {1}" -f $Key, $Value
    $pattern = "(?m)^{0}\s*=.*$" -f [regex]::Escape($Key)
    if ($text -match $pattern) {
        $text = [regex]::Replace($text, $pattern, $line)
    } else {
        if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) {
            $text += [Environment]::NewLine
        }
        $text += $line + [Environment]::NewLine
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ConfigPath, $text, $utf8NoBom)
}

function Initialize-PrivateFceuxData {
    param(
        [string] $DataDirectory,
        [string] $LuaScriptPath
    )

    $profileName = "dragonwarrior-bridge-only"
    $profileDirectory = Join-Path $DataDirectory "input\keyboard"
    $profilePath = Join-Path $profileDirectory ($profileName + ".txt")
    $saveDirectory = Join-Path $DataDirectory "sav"
    $configPath = Join-Path $DataDirectory "fceux.cfg"
    $normalizedLuaScriptPath = [System.IO.Path]::GetFullPath($LuaScriptPath).Replace("\", "/")

    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $saveDirectory -Force | Out-Null

    $profileText = "keyboard,$profileName,config:0,a:,b:,back:,start:,dpup:,dpdown:,dpleft:,dpright:,turboA:,turboB:,"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($profilePath, $profileText, $utf8NoBom)

    $requiredValues = [ordered]@{
        "SDL.AutoResume" = "0"
        "SDL.ToggleMenu" = "1"
        "SDL.PauseOnMainMenuAccess" = "1"
        "SDL.Hotkeys.MainMenuHide" = ""
        "SDL.Hotkeys.FullScreen" = ""
        "SDL.Input.0" = "GamePad.0"
        "SDL.Input.GamePad.0.DeviceGUID" = ""
        "SDL.Input.GamePad.0.DeviceType" = "None"
        "SDL.Input.GamePad.0.Profile" = $profileName
        "SDL.LastLoadLua" = $normalizedLuaScriptPath
        "SDL.LuaScript" = $normalizedLuaScriptPath
    }
    foreach ($entry in $requiredValues.GetEnumerator()) {
        Set-PrivateFceuxConfigValue -ConfigPath $configPath -Key $entry.Key -Value $entry.Value
    }
}

if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    Write-Output ("Installation folder not found: {0}" -f $PackageRoot)
    exit 4
}

New-Item -ItemType Directory -Path $userDirectory -Force | Out-Null
Set-Content -LiteralPath $script:installLogPath -Encoding UTF8 -Value ("=== Dragon Warrior installation {0:u} ===" -f [datetime]::UtcNow)

Write-InstallMessage "Dragon Warrior Accessibility setup"
Write-InstallMessage ("Installation folder: {0}" -f $PackageRoot)

$requiredFiles = @(
    "app\main.lua",
    "app\launch_dw.ps1",
    "app\keyboard_bridge.ps1",
    "app\speech_bridge.py",
    "runtime\fceux\qfceux.exe",
    "runtime\python\python.exe"
)
$missingFiles = @()
foreach ($relativePath in $requiredFiles) {
    $candidate = Join-Path $PackageRoot $relativePath
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $missingFiles += $relativePath
    }
}
if ($missingFiles.Count -gt 0) {
    Write-InstallMessage "The release package is incomplete. Missing required file(s):"
    foreach ($relativePath in $missingFiles) {
        Write-InstallMessage ("  {0}" -f $relativePath)
    }
    Write-InstallMessage "Extract the complete release ZIP to a writable folder and run setup again."
    exit 4
}

if (-not (Test-Path -LiteralPath $RomManifestPath -PathType Leaf)) {
    Write-InstallMessage ("The release package is incomplete. ROM manifest not found: {0}" -f $RomManifestPath)
    exit 4
}

try {
    $manifest = Get-Content -LiteralPath $RomManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $supportedRoms = @($manifest.roms)
    if ($supportedRoms.Count -eq 0) {
        throw "No supported ROM fingerprints are listed."
    }
} catch {
    Write-InstallMessage ("The ROM manifest could not be read: {0}" -f $_.Exception.Message)
    exit 4
}

try {
    Initialize-PrivateFceuxData `
        -DataDirectory $fceuxDataDirectory `
        -LuaScriptPath (Join-Path $PackageRoot "app\main.lua")
    Write-InstallMessage "Private FCEUX configuration prepared: user\fceux\fceux.cfg"
} catch {
    Write-InstallMessage ("The private FCEUX configuration could not be prepared: {0}" -f $_.Exception.Message)
    exit 5
}

if (Test-Path -LiteralPath $installedRomPath -PathType Leaf) {
    try {
        $installedFingerprint = Get-RomFingerprint -Path $installedRomPath
        $installedMatch = Get-SupportedRom -Fingerprint $installedFingerprint -SupportedRoms $supportedRoms
        if ($null -ne $installedMatch) {
            Clear-UnsupportedRomAcknowledgement
            Write-InstallMessage ("Supported ROM: {0}" -f $installedMatch.name)
            Write-InstallMessage "The supported ROM is already installed."
            exit 0
        }
        if (Test-UnsupportedRomAcknowledgement -Fingerprint $installedFingerprint) {
            Write-InstallMessage "WARNING: The installed ROM has an unsupported checksum."
            Write-InstallMessage ("Previously accepted SHA-256: {0}" -f $installedFingerprint.Sha256)
            Write-InstallMessage "Accessibility narration, navigation, game behavior, and save compatibility may be incorrect."
            Write-InstallMessage "The previously accepted unsupported ROM is already installed."
            exit 0
        }
        Write-InstallMessage "The installed ROM copy is not a supported revision; setup will leave it unchanged until a supported source is selected."
    } catch {
        Write-InstallMessage ("The installed ROM copy could not be checked: {0}" -f $_.Exception.Message)
    }
}

$selectedRomPath = $RomPath
if ([string]::IsNullOrWhiteSpace($selectedRomPath)) {
    $supportedCandidates = @()
    $rootCandidates = @(Get-ChildItem -LiteralPath $PackageRoot -File -Filter "*.nes" -ErrorAction SilentlyContinue | Sort-Object Name)
    foreach ($candidate in $rootCandidates) {
        try {
            $fingerprint = Get-RomFingerprint -Path $candidate.FullName
            $match = Get-SupportedRom -Fingerprint $fingerprint -SupportedRoms $supportedRoms
            if ($null -ne $match) {
                $supportedCandidates += [pscustomobject]@{
                    Path = $candidate.FullName
                    Match = $match
                }
            }
        } catch {
            Write-InstallMessage ("Could not inspect ROM candidate {0}: {1}" -f $candidate.Name, $_.Exception.Message)
        }
    }

    if ($supportedCandidates.Count -gt 0) {
        $selectedRomPath = $supportedCandidates[0].Path
        Write-InstallMessage ("Found a supported ROM beside the installer: {0}" -f ([System.IO.Path]::GetFileName($selectedRomPath)))
    } elseif ($NonInteractive) {
        Write-InstallMessage "No supported ROM was supplied or found beside the installer."
        exit 2
    } else {
        Write-InstallMessage "The original game is not included. Setup needs your own Dragon Warrior US Rev 1 NES ROM."
        $answer = Read-Host "Press Enter to open the file picker, or type N to cancel"
        if ($answer -match "^[Nn]") {
            Write-InstallMessage "Setup cancelled. No ROM was copied."
            exit 2
        }
        $selectedRomPath = Select-RomFile
        if ([string]::IsNullOrWhiteSpace($selectedRomPath)) {
            Write-InstallMessage "No ROM was selected. Setup cancelled."
            exit 2
        }
    }
}

if (-not (Test-Path -LiteralPath $selectedRomPath -PathType Leaf)) {
    Write-InstallMessage ("Selected ROM file not found: {0}" -f $selectedRomPath)
    exit 2
}

try {
    $selectedFingerprint = Get-RomFingerprint -Path $selectedRomPath
} catch {
    Write-InstallMessage ("The selected ROM could not be read: {0}" -f $_.Exception.Message)
    exit 2
}

$selectedMatch = Get-SupportedRom -Fingerprint $selectedFingerprint -SupportedRoms $supportedRoms
$unsupportedRomAccepted = $false
if ($null -eq $selectedMatch) {
    Write-InstallMessage "Unsupported Dragon Warrior ROM revision."
    Write-InstallMessage ("Selected file: {0}" -f $selectedFingerprint.Path)
    Write-InstallMessage ("Actual size: {0} bytes" -f $selectedFingerprint.Size)
    Write-InstallMessage ("Actual SHA-256: {0}" -f $selectedFingerprint.Sha256)
    foreach ($supported in $supportedRoms) {
        Write-InstallMessage ("Expected: {0}, {1} bytes, SHA-256 {2}" -f $supported.name, $supported.size, ([string] $supported.sha256).ToUpperInvariant())
    }
    Write-InstallMessage "WARNING: This mod was built and tested only with the supported US Rev 1 ROM."
    Write-InstallMessage "A hacked or otherwise modified ROM may cause incorrect speech, navigation, game behavior, or save compatibility."
    Write-InstallMessage "Compatibility and support are not guaranteed."

    if ($AllowUnsupportedRom) {
        $unsupportedRomAccepted = $true
        Write-InstallMessage "Unsupported ROM override accepted from the command line."
    } elseif ($NonInteractive) {
        Write-InstallMessage "No file was copied. Run setup interactively and type I ACCEPT, or use -AllowUnsupportedRom."
        exit 3
    } else {
        $answer = Read-Host "Type I ACCEPT to install this ROM at your own risk, or press Enter to cancel"
        if ($answer -cne "I ACCEPT") {
            Write-InstallMessage "Unsupported ROM installation cancelled. No file was copied."
            exit 3
        }
        $unsupportedRomAccepted = $true
        Write-InstallMessage "Unsupported ROM risk acknowledgement accepted."
    }
} else {
    Write-InstallMessage ("Supported ROM: {0}" -f $selectedMatch.name)
    Write-InstallMessage ("Verified SHA-256: {0}" -f $selectedFingerprint.Sha256)
}

try {
    $sourceFullPath = [System.IO.Path]::GetFullPath($selectedFingerprint.Path)
    $targetFullPath = [System.IO.Path]::GetFullPath($installedRomPath)
    if (-not $sourceFullPath.Equals($targetFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $temporaryTarget = $installedRomPath + ".installing"
        Copy-Item -LiteralPath $sourceFullPath -Destination $temporaryTarget -Force
        Move-Item -LiteralPath $temporaryTarget -Destination $installedRomPath -Force
    }
} catch {
    Write-InstallMessage ("The ROM could not be copied into the release folder: {0}" -f $_.Exception.Message)
    exit 5
}

$copiedFingerprint = Get-RomFingerprint -Path $installedRomPath
$copiedMatch = Get-SupportedRom -Fingerprint $copiedFingerprint -SupportedRoms $supportedRoms
if ($unsupportedRomAccepted) {
    if ($copiedFingerprint.Size -ne $selectedFingerprint.Size -or
        $copiedFingerprint.Sha256 -ne $selectedFingerprint.Sha256) {
        Write-InstallMessage "The copied unsupported ROM does not match the accepted file. Setup stopped."
        exit 5
    }
    try {
        Write-UnsupportedRomAcknowledgement -Fingerprint $copiedFingerprint
    } catch {
        Write-InstallMessage ("The unsupported ROM acknowledgement could not be saved: {0}" -f $_.Exception.Message)
        Write-InstallMessage "The launcher will not run this ROM until setup completes successfully."
        exit 5
    }
    Write-InstallMessage "Unsupported ROM override recorded for this exact size and SHA-256."
} else {
    if ($null -eq $copiedMatch) {
        Write-InstallMessage "The copied ROM did not pass verification. Setup stopped."
        exit 5
    }
    Clear-UnsupportedRomAcknowledgement
}

Write-InstallMessage ("Installed ROM: {0}" -f $installedRomPath)
Write-InstallMessage "ROM installation complete."
exit 0
