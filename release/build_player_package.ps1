[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ReleaseVersion,
    [string] $OutputDirectory,
    [string] $OutputZip,
    [Parameter(Mandatory = $true)]
    [string] $FceuxDirectory,
    [string] $PythonDirectory,
    [Parameter(Mandatory = $true)]
    [string] $ReadmePath,
    [Parameter(Mandatory = $true)]
    [string] $KeyboardCommandsPath,
    [Parameter(Mandatory = $true)]
    [string] $ProjectLicensePath,
    [Parameter(Mandatory = $true)]
    [string] $FceuxLicensePath,
    [Parameter(Mandatory = $true)]
    [string] $FceuxSourceNoticePath,
    [switch] $SkipRuntimeExecution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$layoutPath = Join-Path $PSScriptRoot "package-layout.json"
$safeVersion = $ReleaseVersion.Trim()
if ([string]::IsNullOrWhiteSpace($safeVersion) -or $safeVersion -notmatch "^[0-9A-Za-z][0-9A-Za-z._-]*$") {
    throw "ReleaseVersion must contain only letters, numbers, periods, underscores, and hyphens."
}

if ([string]::IsNullOrWhiteSpace($PythonDirectory)) {
    $PythonDirectory = Join-Path $repoRoot ".tools\release-staging\python"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot (".tools\release-output\Dragon Warrior Accessibility " + $safeVersion)
}
if ([string]::IsNullOrWhiteSpace($OutputZip)) {
    $OutputZip = $OutputDirectory + ".zip"
}

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$OutputZip = [System.IO.Path]::GetFullPath($OutputZip)
$FceuxDirectory = [System.IO.Path]::GetFullPath($FceuxDirectory)
$PythonDirectory = [System.IO.Path]::GetFullPath($PythonDirectory)

function Assert-InputFile {
    param(
        [string] $Path,
        [string] $Label
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw ("{0} is required." -f $Label)
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw ("{0} not found: {1}" -f $Label, $fullPath)
    }
    return $fullPath
}

function Assert-InputDirectory {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw ("{0} not found: {1}" -f $Label, $Path)
    }
}

function Assert-ReleaseDocument {
    param(
        [string] $Path,
        [string] $Label,
        [string[]] $RequiredText = @()
    )

    $text = [System.IO.File]::ReadAllText($Path)
    foreach ($forbiddenText in @(
        "INTERNAL PACKAGE TEST ONLY",
        "NOT A LICENSE",
        "PLACEHOLDER",
        "LICENSE PENDING",
        "SOURCE OFFER PENDING"
    )) {
        if ($text.IndexOf($forbiddenText, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw ("{0} contains placeholder text: {1}" -f $Label, $forbiddenText)
        }
    }
    foreach ($required in $RequiredText) {
        if ($text.IndexOf($required, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw ("{0} is invalid: missing {1}" -f $Label, $required)
        }
    }
}

function Get-RelativePath {
    param(
        [string] $BasePath,
        [string] $ChildPath
    )

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\") + "\"
    $childFullPath = [System.IO.Path]::GetFullPath($ChildPath)
    $baseUri = New-Object System.Uri($baseFullPath)
    $childUri = New-Object System.Uri($childFullPath)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($childUri).ToString()).Replace("/", "\")
}

function Copy-PackageFile {
    param(
        [string] $Source,
        [string] $Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Required package source file not found: $Source"
    }
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination
}

function Copy-FilteredDirectory {
    param(
        [string] $SourceDirectory,
        [string] $DestinationDirectory,
        [switch] $ExcludePythonCaches
    )

    Assert-InputDirectory -Path $SourceDirectory -Label "Runtime directory"
    foreach ($sourceFile in @(Get-ChildItem -LiteralPath $SourceDirectory -Recurse -File | Sort-Object FullName)) {
        $relativePath = Get-RelativePath -BasePath $SourceDirectory -ChildPath $sourceFile.FullName
        if ($ExcludePythonCaches) {
            $segments = $relativePath -split "[\\/]"
            if ($segments -contains "__pycache__" -or
                $segments -contains "test" -or
                $segments -contains "tests" -or
                $segments -contains "demo" -or
                $segments -contains "demos" -or
                $segments -contains "sample" -or
                $segments -contains "samples" -or
                $sourceFile.Extension -ieq ".pyc" -or
                $sourceFile.Name -like "test_*.py") {
                continue
            }
        }
        Copy-PackageFile -Source $sourceFile.FullName -Destination (Join-Path $DestinationDirectory $relativePath)
    }
}

function Set-PlayerConfigValue {
    param(
        [string] $ConfigPath,
        [string] $Key,
        [string] $Value
    )

    $text = [System.IO.File]::ReadAllText($ConfigPath)
    $line = "{0}={1}" -f $Key, $Value
    $pattern = "(?m)^{0}=.*$" -f [regex]::Escape($Key)
    if ($text -notmatch $pattern) {
        throw "Player configuration key not found: $Key"
    }
    $text = [regex]::Replace($text, $pattern, $line)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ConfigPath, $text, $utf8NoBom)
}

function Get-Sha256 {
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

function Assert-DependencyLicense {
    param(
        [string] $SitePackages,
        [string] $DistributionName
    )

    $metadataDirectories = @(Get-ChildItem -LiteralPath $SitePackages -Directory -Filter ($DistributionName + "-*.dist-info"))
    if ($metadataDirectories.Count -ne 1) {
        throw ("Expected one {0} metadata directory; found {1}." -f $DistributionName, $metadataDirectories.Count)
    }
    $licenseFiles = @(Get-ChildItem -LiteralPath $metadataDirectories[0].FullName -Recurse -File | Where-Object { $_.Name -match "^(LICENSE|COPYING|NOTICE)" })
    if ($licenseFiles.Count -eq 0) {
        throw ("No bundled license file found for Python dependency {0}." -f $DistributionName)
    }
}

function Assert-PackagePolicy {
    param([string] $PackageRoot)

    $forbiddenExtensions = @(".nes", ".sav", ".fcs", ".state", ".saveram")
    $forbiddenNames = @(
        "dw_commands.txt",
        "dw_debug.log",
        "dw_keyboard_input.txt",
        "speech_bridge.log",
        "speech_bridge.status",
        "speech_bridge_launch.log"
    )
    foreach ($file in @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File)) {
        $relativePath = Get-RelativePath -BasePath $PackageRoot -ChildPath $file.FullName
        $segments = $relativePath -split "[\\/]"
        $containsNonRuntimePythonDirectory = @(
            $segments | Where-Object {
                $_ -in @("__pycache__", "test", "tests", "demo", "demos", "sample", "samples")
            }
        ).Count -gt 0
        if ($forbiddenExtensions -contains $file.Extension.ToLowerInvariant() -or
            $file.Extension -match "^\.fc[0-9]$" -or
            $forbiddenNames -contains $file.Name.ToLowerInvariant() -or
            $containsNonRuntimePythonDirectory -or
            $segments -contains ".git" -or
            $segments -contains ".tools" -or
            $segments -contains ".venv" -or
            $segments -contains "work_notes" -or
            $segments -contains "handoff_archive" -or
            $segments -contains "node_modules" -or
            $relativePath -match "(^|\\)test_[^\\]+$") {
            throw "Forbidden player-package file: $relativePath"
        }
    }
}

$ReadmePath = Assert-InputFile -Path $ReadmePath -Label "Player README"
$KeyboardCommandsPath = Assert-InputFile -Path $KeyboardCommandsPath -Label "Keyboard command reference"
$ProjectLicensePath = Assert-InputFile -Path $ProjectLicensePath -Label "Project license"
$FceuxLicensePath = Assert-InputFile -Path $FceuxLicensePath -Label "FCEUX license"
$FceuxSourceNoticePath = Assert-InputFile -Path $FceuxSourceNoticePath -Label "FCEUX corresponding-source notice"
$thirdPartyLicenseDirectory = Join-Path $repoRoot "licenses\third-party"
$thirdPartyNoticePath = Assert-InputFile `
    -Path (Join-Path $repoRoot "licenses\THIRD-PARTY-NOTICES.txt") `
    -Label "Third-party notices"
Assert-InputDirectory -Path $thirdPartyLicenseDirectory -Label "Third-party license directory"
Assert-ReleaseDocument -Path $ProjectLicensePath -Label "Project license" `
    -RequiredText @("MIT License", "Copyright (c) 2026 Bill Freeman")
Assert-ReleaseDocument -Path $FceuxLicensePath -Label "FCEUX license" `
    -RequiredText @("GNU GENERAL PUBLIC LICENSE", "Version 2, June 1991")
Assert-ReleaseDocument -Path $FceuxSourceNoticePath -Label "FCEUX corresponding-source notice" `
    -RequiredText @("corresponding source", "sibling release asset")
Assert-ReleaseDocument -Path $thirdPartyNoticePath -Label "Third-party notices" `
    -RequiredText @("Qt 5.15.2", "NVDA Controller Client 2026.1.1", "SDL2 2.24.1")
Assert-InputFile -Path $layoutPath -Label "Package layout" | Out-Null
Assert-InputDirectory -Path $FceuxDirectory -Label "FCEUX runtime"
Assert-InputDirectory -Path $PythonDirectory -Label "Portable Python runtime"
$fceuxBuildMarker = Assert-InputFile `
    -Path (Join-Path $FceuxDirectory "FCEUX-ACCESSIBILITY-BUILD.txt") `
    -Label "Patched FCEUX build marker"
$fceuxBuildMarkerText = Get-Content -LiteralPath $fceuxBuildMarker -Raw -Encoding UTF8
foreach ($requiredMarkerText in @(
    "Upstream commit: 34eb7601c415b81901fd02afbd5cfdc84b5047ac",
    "Patch: release/fceux-v2.6.6-deferred-startup-lua.patch"
)) {
    if ($fceuxBuildMarkerText -notlike ("*" + $requiredMarkerText + "*")) {
        throw "Patched FCEUX build marker is invalid: missing $requiredMarkerText"
    }
}

if (Test-Path -LiteralPath $OutputDirectory) {
    throw "Output directory already exists: $OutputDirectory"
}
if (Test-Path -LiteralPath $OutputZip) {
    throw "Output ZIP already exists: $OutputZip"
}

$layout = Get-Content -LiteralPath $layoutPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int] $layout.schemaVersion -ne 1) {
    throw "Unsupported package layout schema version: $($layout.schemaVersion)"
}

$pythonExecutable = Assert-InputFile -Path (Join-Path $PythonDirectory "python.exe") -Label "Portable Python executable"
$pythonLicense = Assert-InputFile -Path (Join-Path $PythonDirectory "LICENSE.txt") -Label "Python license"
$speechRequirements = Assert-InputFile -Path (Join-Path $PythonDirectory "SPEECH-DEPENDENCIES.txt") -Label "Speech dependency manifest"
$speechRequirementsText = [System.IO.File]::ReadAllText($speechRequirements)
foreach ($requiredSpeechText in @(
    "NVDA-Controller-Client==2026.1.1",
    "NVDA corresponding source commit: 5d92106f17e461dac62aa48257bbbf4183e033d0"
)) {
    if ($speechRequirementsText.IndexOf($requiredSpeechText, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Speech dependency manifest is invalid: missing $requiredSpeechText"
    }
}
$sitePackages = Join-Path $PythonDirectory "Lib\site-packages"
Assert-InputDirectory -Path $sitePackages -Label "Portable Python site-packages"
foreach ($distribution in @("accessible_output2", "libloader", "platform_utils", "platformdirs")) {
    Assert-DependencyLicense -SitePackages $sitePackages -DistributionName $distribution
}
Assert-InputFile -Path (Join-Path $sitePackages "win32\license.txt") -Label "pywin32 license" | Out-Null
$accessibleOutputLib = Join-Path $sitePackages "accessible_output2\lib"
Assert-InputDirectory -Path $accessibleOutputLib -Label "accessible-output2 runtime library directory"
$speechVendorDlls = @(Get-ChildItem -LiteralPath $accessibleOutputLib -File -Filter "*.dll")
if ($speechVendorDlls.Count -ne 1 -or $speechVendorDlls[0].Name -ne "nvdaControllerClient64.dll") {
    throw ("Unexpected bundled screen-reader DLL set: {0}" -f ($speechVendorDlls.Name -join ", "))
}
Assert-InputFile `
    -Path (Join-Path $accessibleOutputLib "NVDA Controller Client LICENSE.txt") `
    -Label "NVDA Controller Client license" | Out-Null

if (-not $SkipRuntimeExecution) {
    $verifyCode = @'
from accessible_output2.outputs.nvda import NVDA
from accessible_output2.outputs.sapi5 import SAPI5
import win32api
NVDA()
SAPI5()
print("speech-runtime=OK")
'@
    $verifyOutput = @(& $pythonExecutable -I -B -c $verifyCode 2>&1)
    if ($LASTEXITCODE -ne 0 -or $verifyOutput -notcontains "speech-runtime=OK") {
        throw ("Portable speech runtime verification failed: {0}" -f ($verifyOutput -join " | "))
    }
}

$createdOutput = $false
$createdZip = $false
try {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $createdOutput = $true

    foreach ($mapping in @($layout.rootFiles)) {
        Copy-PackageFile `
            -Source (Join-Path $repoRoot ([string] $mapping.source)) `
            -Destination (Join-Path $OutputDirectory ([string] $mapping.destination))
    }

    $appDirectory = Join-Path $OutputDirectory "app"
    foreach ($relativePath in @($layout.appFiles)) {
        Copy-PackageFile `
            -Source (Join-Path $repoRoot ([string] $relativePath)) `
            -Destination (Join-Path $appDirectory ([string] $relativePath))
    }
    foreach ($mapping in @($layout.releaseAppFiles)) {
        Copy-PackageFile `
            -Source (Join-Path $repoRoot ([string] $mapping.source)) `
            -Destination (Join-Path $appDirectory ([string] $mapping.destination))
    }

    $playerConfigPath = Join-Path $appDirectory "dw_access.ini"
    Set-PlayerConfigValue -ConfigPath $playerConfigPath -Key "speech_python_cmd" -Value "..\runtime\python\python.exe"
    Set-PlayerConfigValue -ConfigPath $playerConfigPath -Key "debug_mode" -Value "false"
    Set-PlayerConfigValue -ConfigPath $playerConfigPath -Key "debug_log_level" -Value "ERROR"
    Set-PlayerConfigValue -ConfigPath $playerConfigPath -Key "enable_bizhawk_diagnostic_hotkeys" -Value "false"

    $fceuxOutputDirectory = Join-Path $OutputDirectory "runtime\fceux"
    foreach ($relativePath in @($layout.fceuxRootFiles)) {
        Copy-PackageFile `
            -Source (Join-Path $FceuxDirectory ([string] $relativePath)) `
            -Destination (Join-Path $fceuxOutputDirectory ([string] $relativePath))
    }
    foreach ($relativeDirectory in @($layout.fceuxDirectories)) {
        Copy-FilteredDirectory `
            -SourceDirectory (Join-Path $FceuxDirectory ([string] $relativeDirectory)) `
            -DestinationDirectory (Join-Path $fceuxOutputDirectory ([string] $relativeDirectory))
    }

    $pythonOutputDirectory = Join-Path $OutputDirectory "runtime\python"
    Copy-FilteredDirectory -SourceDirectory $PythonDirectory -DestinationDirectory $pythonOutputDirectory -ExcludePythonCaches

    Copy-PackageFile -Source $ReadmePath -Destination (Join-Path $OutputDirectory "README.txt")
    Copy-PackageFile -Source $KeyboardCommandsPath -Destination (Join-Path $OutputDirectory "Keyboard Commands.txt")
    Copy-PackageFile -Source $ProjectLicensePath -Destination (Join-Path $OutputDirectory "licenses\Dragon Warrior Accessibility LICENSE.txt")
    Copy-PackageFile -Source $FceuxLicensePath -Destination (Join-Path $OutputDirectory "licenses\FCEUX COPYING.txt")
    Copy-PackageFile -Source $pythonLicense -Destination (Join-Path $OutputDirectory "licenses\Python LICENSE.txt")
    Copy-PackageFile -Source $speechRequirements -Destination (Join-Path $OutputDirectory "licenses\Python Speech Dependencies.txt")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $renderedSourceNotice = [System.IO.File]::ReadAllText($FceuxSourceNoticePath).Replace(
        "{{RELEASE_VERSION}}",
        $safeVersion
    )
    [System.IO.File]::WriteAllText(
        (Join-Path $OutputDirectory "licenses\FCEUX SOURCE.txt"),
        $renderedSourceNotice,
        $utf8NoBom
    )
    $renderedThirdPartyNotice = [System.IO.File]::ReadAllText($thirdPartyNoticePath).Replace(
        "{{RELEASE_VERSION}}",
        $safeVersion
    )
    [System.IO.File]::WriteAllText(
        (Join-Path $OutputDirectory "licenses\THIRD-PARTY-NOTICES.txt"),
        $renderedThirdPartyNotice,
        $utf8NoBom
    )
    foreach ($licenseFile in @(Get-ChildItem -LiteralPath $thirdPartyLicenseDirectory -File)) {
        if ($licenseFile.Name -eq "FCEUX COPYING.txt") {
            continue
        }
        Copy-PackageFile `
            -Source $licenseFile.FullName `
            -Destination (Join-Path $OutputDirectory ("licenses\" + $licenseFile.Name))
    }

    Assert-PackagePolicy -PackageRoot $OutputDirectory

    $manifestFiles = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $OutputDirectory -Recurse -File)) {
        $relativePath = (Get-RelativePath -BasePath $OutputDirectory -ChildPath $file.FullName).Replace("\", "/")
        $manifestFiles += [ordered]@{
            path = $relativePath
            size = [int64] $file.Length
            sha256 = Get-Sha256 -Path $file.FullName
        }
    }
    $manifestFileList = New-Object "System.Collections.Generic.List[object]"
    foreach ($manifestFile in $manifestFiles) {
        $manifestFileList.Add($manifestFile)
    }
    $manifestComparison = [System.Comparison[object]] {
        param($left, $right)
        $comparison = [System.StringComparer]::Ordinal.Compare(
            ([string] $left.path).ToLowerInvariant(),
            ([string] $right.path).ToLowerInvariant()
        )
        if ($comparison -ne 0) {
            return $comparison
        }
        return [System.StringComparer]::Ordinal.Compare(
            [string] $left.path,
            [string] $right.path
        )
    }
    $manifestFileList.Sort($manifestComparison)
    $manifestFiles = $manifestFileList.ToArray()
    $manifest = [ordered]@{
        schemaVersion = 1
        releaseVersion = $safeVersion
        hashAlgorithm = "SHA-256"
        manifestSelfExcluded = $true
        files = $manifestFiles
    }
    $manifestJson = $manifest | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText((Join-Path $OutputDirectory "PACKAGE-MANIFEST.json"), $manifestJson + [Environment]::NewLine, $utf8NoBom)

    $zipParent = Split-Path -Parent $OutputZip
    if (-not (Test-Path -LiteralPath $zipParent -PathType Container)) {
        New-Item -ItemType Directory -Path $zipParent -Force | Out-Null
    }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipStream = [System.IO.File]::Open($OutputZip, [System.IO.FileMode]::CreateNew)
    $createdZip = $true
    try {
        $archive = New-Object System.IO.Compression.ZipArchive(
            $zipStream,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            $zipRoot = "Dragon Warrior Accessibility " + $safeVersion
            foreach ($file in @(Get-ChildItem -LiteralPath $OutputDirectory -Recurse -File | Sort-Object FullName)) {
                $relativePath = (Get-RelativePath -BasePath $OutputDirectory -ChildPath $file.FullName).Replace("\", "/")
                $entry = $archive.CreateEntry(
                    $zipRoot + "/" + $relativePath,
                    [System.IO.Compression.CompressionLevel]::Optimal
                )
                $entry.LastWriteTime = New-Object System.DateTimeOffset(1980, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero)
                $sourceStream = [System.IO.File]::OpenRead($file.FullName)
                $entryStream = $entry.Open()
                try {
                    $sourceStream.CopyTo($entryStream)
                } finally {
                    $entryStream.Dispose()
                    $sourceStream.Dispose()
                }
            }
        } finally {
            $archive.Dispose()
        }
    } finally {
        $zipStream.Dispose()
    }

    Write-Output ("Player package directory: {0}" -f $OutputDirectory)
    Write-Output ("Player package ZIP: {0}" -f $OutputZip)
    Write-Output ("Payload files: {0}" -f $manifestFiles.Count)
    Write-Output ("ZIP SHA-256: {0}" -f (Get-Sha256 -Path $OutputZip))
    Write-Output "Deterministic player package build complete."
} catch {
    if ($createdZip -and (Test-Path -LiteralPath $OutputZip -PathType Leaf)) {
        Remove-Item -LiteralPath $OutputZip -Force
    }
    if ($createdOutput -and (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
    }
    throw
}
