[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ReleaseVersion,
    [string] $FceuxSourceDirectory,
    [string] $CacheDirectory,
    [string] $OutputDirectory,
    [string] $OutputZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$safeVersion = $ReleaseVersion.Trim()
if ([string]::IsNullOrWhiteSpace($safeVersion) -or $safeVersion -notmatch "^[0-9A-Za-z][0-9A-Za-z._-]*$") {
    throw "ReleaseVersion must contain only letters, numbers, periods, underscores, and hyphens."
}

if ([string]::IsNullOrWhiteSpace($FceuxSourceDirectory)) {
    $FceuxSourceDirectory = Join-Path $repoRoot ".tools\fceux-release-src"
}
if ([string]::IsNullOrWhiteSpace($CacheDirectory)) {
    $CacheDirectory = Join-Path $repoRoot ".tools\release-cache\source"
}
$assetBaseName = "Dragon-Warrior-Accessibility-$safeVersion-Corresponding-Source"
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot (".tools\release-output\" + $assetBaseName)
}
if ([string]::IsNullOrWhiteSpace($OutputZip)) {
    $OutputZip = Join-Path $repoRoot (".tools\release-output\" + $assetBaseName + ".zip")
}

$FceuxSourceDirectory = [System.IO.Path]::GetFullPath($FceuxSourceDirectory)
$CacheDirectory = [System.IO.Path]::GetFullPath($CacheDirectory)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$OutputZip = [System.IO.Path]::GetFullPath($OutputZip)

$fceuxCommit = "34eb7601c415b81901fd02afbd5cfdc84b5047ac"
$nvdaCommit = "5d92106f17e461dac62aa48257bbbf4183e033d0"
$patchPath = Join-Path $PSScriptRoot "fceux-v2.6.6-deferred-startup-lua.patch"
$sourceInputs = @(
    [ordered]@{
        Name = "qtbase-everywhere-src-5.15.2.zip"
        Url = "https://download.qt.io/archive/qt/5.15/5.15.2/submodules/qtbase-everywhere-src-5.15.2.zip"
        Sha256 = "6BC369D0A9D24F185ABCD718EE0F003B8DA09DDEEF4F90B35088BD46152B7507"
        Destination = "Qt\qtbase-everywhere-src-5.15.2.zip"
    },
    [ordered]@{
        Name = "qtsvg-everywhere-src-5.15.2.zip"
        Url = "https://download.qt.io/archive/qt/5.15/5.15.2/submodules/qtsvg-everywhere-src-5.15.2.zip"
        Sha256 = "0466848C82F09BFB867E018CEFFE5C717B4AE0FA02B5F8531D0008659FD482AA"
        Destination = "Qt\qtsvg-everywhere-src-5.15.2.zip"
    },
    [ordered]@{
        Name = "nvda-$nvdaCommit.zip"
        Url = "https://codeload.github.com/nvaccess/nvda/zip/$nvdaCommit"
        Sha256 = "3C44AC5BB35188E0B2CB9339E8AC78D5D9F74EAA10E14565572E7FD41D8CFB64"
        Destination = "NVDA\nvda-$nvdaCommit.zip"
    }
)

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

function Get-RelativePath {
    param([string] $BasePath, [string] $ChildPath)

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\") + "\"
    $childFullPath = [System.IO.Path]::GetFullPath($ChildPath)
    $baseUri = New-Object System.Uri($baseFullPath)
    $childUri = New-Object System.Uri($childFullPath)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($childUri).ToString()).Replace("/", "\")
}

function Copy-SourceFile {
    param([string] $Source, [string] $Destination)

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

if (-not (Test-Path -LiteralPath $FceuxSourceDirectory -PathType Container)) {
    throw "FCEUX source directory not found: $FceuxSourceDirectory"
}
if (-not (Test-Path -LiteralPath $patchPath -PathType Leaf)) {
    throw "FCEUX patch not found: $patchPath"
}
if (Test-Path -LiteralPath $OutputDirectory) {
    throw "Corresponding-source output directory already exists: $OutputDirectory"
}
if (Test-Path -LiteralPath $OutputZip) {
    throw "Corresponding-source ZIP already exists: $OutputZip"
}

$actualFceuxCommit = (& git -C $FceuxSourceDirectory rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualFceuxCommit -ne $fceuxCommit) {
    throw "FCEUX source is not at pinned commit $fceuxCommit."
}
$changedPaths = @(& git -C $FceuxSourceDirectory diff --name-only)
$expectedChangedPaths = @(
    "src/drivers/Qt/ConsoleWindow.cpp",
    "src/drivers/Qt/fceuWrapper.cpp",
    "src/drivers/Qt/fceuWrapper.h"
)
if (@(Compare-Object $expectedChangedPaths $changedPaths).Count -ne 0) {
    throw ("Unexpected FCEUX source changes: {0}" -f ($changedPaths -join ", "))
}
& git -C $FceuxSourceDirectory apply --reverse --check $patchPath
if ($LASTEXITCODE -ne 0) {
    throw "Pinned FCEUX accessibility patch is not applied exactly."
}
& git -C $FceuxSourceDirectory diff --check
if ($LASTEXITCODE -ne 0) {
    throw "Patched FCEUX source failed git diff --check."
}

New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
foreach ($sourceInput in $sourceInputs) {
    $cachePath = Join-Path $CacheDirectory $sourceInput.Name
    $downloadRequired = $true
    if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
        if ((Get-Sha256 -Path $cachePath) -eq $sourceInput.Sha256) {
            $downloadRequired = $false
        } else {
            Remove-Item -LiteralPath $cachePath -Force
        }
    }
    if ($downloadRequired) {
        Write-Output ("Downloading corresponding source: {0}" -f $sourceInput.Url)
        Invoke-WebRequest -Uri $sourceInput.Url -OutFile $cachePath -UseBasicParsing
    }
    $actualHash = Get-Sha256 -Path $cachePath
    if ($actualHash -ne $sourceInput.Sha256) {
        throw ("Corresponding-source SHA-256 mismatch for {0}. Expected {1}; actual {2}" -f $sourceInput.Name, $sourceInput.Sha256, $actualHash)
    }
}

$createdOutput = $false
$createdZip = $false
try {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $createdOutput = $true

    $fceuxOutput = Join-Path $OutputDirectory "FCEUX\source"
    $trackedFceuxPaths = @(& git -C $FceuxSourceDirectory ls-files)
    if ($LASTEXITCODE -ne 0 -or $trackedFceuxPaths.Count -eq 0) {
        throw "Unable to enumerate tracked FCEUX source files."
    }
    foreach ($relativePath in $trackedFceuxPaths) {
        $sourcePath = Join-Path $FceuxSourceDirectory $relativePath
        if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
            Copy-SourceFile -Source $sourcePath -Destination (Join-Path $fceuxOutput $relativePath)
        }
    }
    Copy-SourceFile -Source $patchPath `
        -Destination (Join-Path $OutputDirectory "FCEUX\fceux-v2.6.6-deferred-startup-lua.patch")
    Copy-SourceFile -Source (Join-Path $PSScriptRoot "build_fceux_runtime.ps1") `
        -Destination (Join-Path $OutputDirectory "FCEUX\build_fceux_runtime.ps1")

    foreach ($sourceInput in $sourceInputs) {
        Copy-SourceFile `
            -Source (Join-Path $CacheDirectory $sourceInput.Name) `
            -Destination (Join-Path $OutputDirectory $sourceInput.Destination)
    }

    $readmeLines = @(
        "Dragon Warrior Accessibility $safeVersion corresponding source",
        "============================================================",
        "",
        "This archive accompanies the player package with the same release version.",
        "It contains the preferred source and build-control materials for the modified",
        "FCEUX executable, plus the exact Qt and NVDA source archives corresponding to",
        "the LGPL-covered DLLs in the player package.",
        "",
        "FCEUX",
        "-----",
        "Pinned upstream commit: $fceuxCommit",
        "The source tree under FCEUX\source already has the accessibility patch applied.",
        "The original patch and release build script are included beside that tree.",
        "The build used Visual Studio 2022, Qt 5.15.2 msvc2019_64, SDL2 2.24.1,",
        "libarchive 3.6.2, and the CMake settings recorded in build_fceux_runtime.ps1.",
        "No FCEUX source changes are omitted.",
        "",
        "Qt",
        "--",
        "Qt\qtbase-everywhere-src-5.15.2.zip and",
        "Qt\qtsvg-everywhere-src-5.15.2.zip are the verified official source modules",
        "for every Qt module shipped in the player package. The Qt DLLs are unmodified.",
        "",
        "NVDA Controller Client",
        "----------------------",
        "Pinned source commit: $nvdaCommit",
        "NVDA\nvda-$nvdaCommit.zip is the official repository snapshot corresponding",
        "to the unmodified NVDA Controller Client 2026.1.1 DLL.",
        "",
        "Checksums for every file in this archive are in SOURCE-MANIFEST.json."
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $OutputDirectory "README.txt"),
        ($readmeLines -join [Environment]::NewLine) + [Environment]::NewLine,
        $utf8NoBom
    )

    $manifestFiles = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $OutputDirectory -Recurse -File)) {
        $relativePath = (Get-RelativePath -BasePath $OutputDirectory -ChildPath $file.FullName).Replace("\", "/")
        $manifestFiles += [ordered]@{
            path = $relativePath
            size = [int64] $file.Length
            sha256 = Get-Sha256 -Path $file.FullName
        }
    }
    $manifestFiles = @($manifestFiles | Sort-Object { $_.path.ToLowerInvariant() }, { $_.path })
    $manifest = [ordered]@{
        schemaVersion = 1
        releaseVersion = $safeVersion
        fceuxCommit = $fceuxCommit
        nvdaCommit = $nvdaCommit
        hashAlgorithm = "SHA-256"
        manifestSelfExcluded = $true
        files = $manifestFiles
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $OutputDirectory "SOURCE-MANIFEST.json"),
        ($manifest | ConvertTo-Json -Depth 5) + [Environment]::NewLine,
        $utf8NoBom
    )

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
            foreach ($file in @(Get-ChildItem -LiteralPath $OutputDirectory -Recurse -File | Sort-Object FullName)) {
                $relativePath = (Get-RelativePath -BasePath $OutputDirectory -ChildPath $file.FullName).Replace("\", "/")
                $entry = $archive.CreateEntry(
                    $assetBaseName + "/" + $relativePath,
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

    Write-Output ("Corresponding-source directory: {0}" -f $OutputDirectory)
    Write-Output ("Corresponding-source ZIP: {0}" -f $OutputZip)
    Write-Output ("Source files: {0}" -f $manifestFiles.Count)
    Write-Output ("ZIP SHA-256: {0}" -f (Get-Sha256 -Path $OutputZip))
    Write-Output "Deterministic corresponding-source build complete."
} catch {
    if ($createdZip -and (Test-Path -LiteralPath $OutputZip -PathType Leaf)) {
        Remove-Item -LiteralPath $OutputZip -Force
    }
    if ($createdOutput -and (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
    }
    throw
}
