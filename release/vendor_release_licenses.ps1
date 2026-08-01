[CmdletBinding()]
param(
    [string] $FceuxSourceDirectory,
    [string] $DependencyDirectory,
    [string] $QtBaseSourceArchive,
    [string] $QtSvgSourceArchive,
    [string] $NvdaControllerArchive,
    [string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($FceuxSourceDirectory)) {
    $FceuxSourceDirectory = Join-Path $repoRoot ".tools\fceux-release-src"
}
if ([string]::IsNullOrWhiteSpace($DependencyDirectory)) {
    $DependencyDirectory = Join-Path $repoRoot ".tools\fceux-build-tools\deps"
}
if ([string]::IsNullOrWhiteSpace($QtBaseSourceArchive)) {
    $QtBaseSourceArchive = Join-Path $repoRoot ".tools\release-cache\source\qtbase-everywhere-src-5.15.2.zip"
}
if ([string]::IsNullOrWhiteSpace($QtSvgSourceArchive)) {
    $QtSvgSourceArchive = Join-Path $repoRoot ".tools\release-cache\source\qtsvg-everywhere-src-5.15.2.zip"
}
if ([string]::IsNullOrWhiteSpace($NvdaControllerArchive)) {
    $NvdaControllerArchive = Join-Path $repoRoot ".tools\release-cache\speech\nvda_2026.1.1_controllerClient.zip"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "licenses\third-party"
}

$expectedHashes = @{
    $QtBaseSourceArchive = "6BC369D0A9D24F185ABCD718EE0F003B8DA09DDEEF4F90B35088BD46152B7507"
    $QtSvgSourceArchive = "0466848C82F09BFB867E018CEFFE5C717B4AE0FA02B5F8531D0008659FD482AA"
    $NvdaControllerArchive = "2A3A70F729BE0C48120C5F24A81653202827C40A7986E289FFE2275A2B45011F"
}

foreach ($archivePath in $expectedHashes.Keys) {
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "Required verified source archive not found: $archivePath"
    }
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHashes[$archivePath]) {
        throw "Source archive SHA-256 mismatch: $archivePath"
    }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $FceuxSourceDirectory "COPYING") `
    -Destination (Join-Path $OutputDirectory "FCEUX COPYING.txt") -Force
Copy-Item -LiteralPath (Join-Path $DependencyDirectory "SDL2\COPYING.txt") `
    -Destination (Join-Path $OutputDirectory "SDL2 LICENSE.txt") -Force
Copy-Item -LiteralPath (Join-Path $DependencyDirectory "libarchive-3.6.2-src\COPYING") `
    -Destination (Join-Path $OutputDirectory "libarchive COPYING.txt") -Force

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Copy-ZipEntry {
    param(
        [string] $ArchivePath,
        [string] $EntryName,
        [string] $DestinationPath
    )

    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $entry = $archive.GetEntry($EntryName)
        if ($null -eq $entry) {
            throw "Archive entry not found: $EntryName"
        }
        $source = $entry.Open()
        $destination = [System.IO.File]::Open(
            $DestinationPath,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        try {
            $source.CopyTo($destination)
        } finally {
            $destination.Dispose()
            $source.Dispose()
        }
    } finally {
        $archive.Dispose()
    }
}

Copy-ZipEntry -ArchivePath $QtBaseSourceArchive `
    -EntryName "qtbase-everywhere-src-5.15.2/LICENSE.LGPL3" `
    -DestinationPath (Join-Path $OutputDirectory "Qt LGPL v3.txt")
Copy-ZipEntry -ArchivePath $QtBaseSourceArchive `
    -EntryName "qtbase-everywhere-src-5.15.2/LICENSE.GPL3" `
    -DestinationPath (Join-Path $OutputDirectory "Qt GPL v3.txt")
Copy-ZipEntry -ArchivePath $NvdaControllerArchive `
    -EntryName "license.txt" `
    -DestinationPath (Join-Path $OutputDirectory "NVDA Controller Client LGPL 2.1.txt")

$qtMaterialsPath = Join-Path $OutputDirectory "Qt 5.15.2 Third-Party License Materials.zip"
$qtMaterialsStream = [System.IO.File]::Open($qtMaterialsPath, [System.IO.FileMode]::Create)
try {
    $qtMaterials = New-Object System.IO.Compression.ZipArchive(
        $qtMaterialsStream,
        [System.IO.Compression.ZipArchiveMode]::Create,
        $false
    )
    try {
        foreach ($sourceArchivePath in @($QtBaseSourceArchive, $QtSvgSourceArchive)) {
            $sourceArchive = [System.IO.Compression.ZipFile]::OpenRead($sourceArchivePath)
            try {
                $selectedEntries = @($sourceArchive.Entries | Where-Object {
                    $_.Length -gt 0 -and (
                        $_.FullName -match "(^|/)LICENSE[^/]*$" -or
                        $_.FullName -match "(^|/)COPYING[^/]*$" -or
                        $_.FullName -match "(^|/)NOTICE[^/]*$" -or
                        $_.FullName -match "(^|/)[^/]*_LICENSE[^/]*$" -or
                        $_.FullName -match "/qt_attribution\.json$"
                    )
                } | Sort-Object FullName)
                foreach ($sourceEntry in $selectedEntries) {
                    $targetEntry = $qtMaterials.CreateEntry(
                        $sourceEntry.FullName,
                        [System.IO.Compression.CompressionLevel]::Optimal
                    )
                    $targetEntry.LastWriteTime = New-Object System.DateTimeOffset(
                        1980, 1, 1, 0, 0, 0, [System.TimeSpan]::Zero
                    )
                    $sourceStream = $sourceEntry.Open()
                    $targetStream = $targetEntry.Open()
                    try {
                        $sourceStream.CopyTo($targetStream)
                    } finally {
                        $targetStream.Dispose()
                        $sourceStream.Dispose()
                    }
                }
            } finally {
                $sourceArchive.Dispose()
            }
        }
    } finally {
        $qtMaterials.Dispose()
    }
} finally {
    $qtMaterialsStream.Dispose()
}

Write-Output "Release license files refreshed from verified upstream sources."
Write-Output ("Output directory: {0}" -f $OutputDirectory)
