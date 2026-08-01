[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $FceuxSourceDirectory,
    [Parameter(Mandatory = $true)]
    [string] $BuildToolsDirectory,
    [Parameter(Mandatory = $true)]
    [string] $BaseRuntimeDirectory,
    [string] $BuildDirectory,
    [string] $OutputDirectory,
    [string] $PatchPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $repoRoot ".tools\fceux-release-build"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ".tools\fceux-release-runtime"
}
if ([string]::IsNullOrWhiteSpace($PatchPath)) {
    $PatchPath = Join-Path $PSScriptRoot "fceux-v2.6.6-deferred-startup-lua.patch"
}

$FceuxSourceDirectory = [System.IO.Path]::GetFullPath($FceuxSourceDirectory)
$BuildToolsDirectory = [System.IO.Path]::GetFullPath($BuildToolsDirectory)
$BaseRuntimeDirectory = [System.IO.Path]::GetFullPath($BaseRuntimeDirectory)
$BuildDirectory = [System.IO.Path]::GetFullPath($BuildDirectory)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$PatchPath = [System.IO.Path]::GetFullPath($PatchPath)

$upstreamCommit = "34eb7601c415b81901fd02afbd5cfdc84b5047ac"
$cmake = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
$qtRoot = Join-Path $BuildToolsDirectory "Qt\5.15.2\msvc2019_64"
$dependencies = Join-Path $BuildToolsDirectory "deps"
$libarchiveInstall = Join-Path $dependencies "libarchive"
$buildTemp = Join-Path $BuildToolsDirectory "release-temp"

foreach ($requiredDirectory in @(
    $FceuxSourceDirectory,
    $BuildToolsDirectory,
    $BaseRuntimeDirectory,
    $qtRoot,
    (Join-Path $dependencies "SDL2")
)) {
    if (-not (Test-Path -LiteralPath $requiredDirectory -PathType Container)) {
        throw "Required directory not found: $requiredDirectory"
    }
}
foreach ($requiredFile in @(
    $cmake,
    $PatchPath,
    (Join-Path $FceuxSourceDirectory ".git\HEAD"),
    (Join-Path $libarchiveInstall "lib\archive.lib"),
    (Join-Path $libarchiveInstall "bin\archive.dll"),
    (Join-Path $BaseRuntimeDirectory "qfceux.exe")
)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required file not found: $requiredFile"
    }
}
if (Test-Path -LiteralPath $OutputDirectory) {
    throw "Output directory already exists: $OutputDirectory"
}

$actualCommit = (& git -C $FceuxSourceDirectory rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $upstreamCommit) {
    throw "FCEUX source must be the clean v2.6.6 commit $upstreamCommit; found $actualCommit"
}

$savedErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& git -C $FceuxSourceDirectory apply --check $PatchPath 2>$null
$patchAppliesCleanly = $LASTEXITCODE -eq 0
$ErrorActionPreference = $savedErrorActionPreference
if ($patchAppliesCleanly) {
    & git -C $FceuxSourceDirectory apply $PatchPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not apply the deferred-startup Lua patch."
    }
} else {
    $ErrorActionPreference = "SilentlyContinue"
    & git -C $FceuxSourceDirectory apply --reverse --check $PatchPath 2>$null
    $patchAlreadyApplied = $LASTEXITCODE -eq 0
    $ErrorActionPreference = $savedErrorActionPreference
    if (-not $patchAlreadyApplied) {
        throw "FCEUX source is neither clean nor patched exactly as expected."
    }
    Write-Output "FCEUX startup patch is already applied."
}

$changedPaths = @(& git -C $FceuxSourceDirectory diff --name-only)
$expectedPaths = @(
    "src/drivers/Qt/ConsoleWindow.cpp",
    "src/drivers/Qt/fceuWrapper.cpp",
    "src/drivers/Qt/fceuWrapper.h"
)
$unexpectedPathDifferences = @(Compare-Object $expectedPaths $changedPaths)
if ($unexpectedPathDifferences.Count -ne 0) {
    throw ("Unexpected FCEUX source changes: {0}" -f ($changedPaths -join ", "))
}
& git -C $FceuxSourceDirectory diff --check
if ($LASTEXITCODE -ne 0) {
    throw "Patched FCEUX source failed git diff --check."
}

New-Item -ItemType Directory -Path $BuildDirectory, $buildTemp -Force | Out-Null
$env:TEMP = $buildTemp
$env:TMP = $buildTemp
$env:GIT_DIR = Join-Path $FceuxSourceDirectory ".git"
$env:GIT_WORK_TREE = $FceuxSourceDirectory

& $cmake -S $FceuxSourceDirectory -B $BuildDirectory -G "Visual Studio 17 2022" -A x64 `
    -DQT6=0 `
    -DPUBLIC_RELEASE=0 `
    -DUSE_LIBAV=0 `
    "-DCMAKE_PREFIX_PATH=$qtRoot" `
    "-DQt5_DIR=$qtRoot\lib\cmake\Qt5" `
    "-DSDL_INSTALL_PREFIX=$dependencies" `
    "-DLIBARCHIVE_INSTALL_PREFIX=$dependencies"
if ($LASTEXITCODE -ne 0) {
    throw "FCEUX configure failed with exit code $LASTEXITCODE."
}

& $cmake --build $BuildDirectory --config Release --parallel 4
if ($LASTEXITCODE -ne 0) {
    throw "FCEUX build failed with exit code $LASTEXITCODE."
}

$builtExecutable = Join-Path $BuildDirectory "src\Release\fceux.exe"
if (-not (Test-Path -LiteralPath $builtExecutable -PathType Leaf)) {
    throw "Expected FCEUX executable not found: $builtExecutable"
}

New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
foreach ($sourceItem in @(Get-ChildItem -LiteralPath $BaseRuntimeDirectory -Force)) {
    Copy-Item -LiteralPath $sourceItem.FullName -Destination $OutputDirectory -Recurse
}
Copy-Item -LiteralPath $builtExecutable -Destination (Join-Path $OutputDirectory "qfceux.exe") -Force
Copy-Item -LiteralPath (Join-Path $FceuxSourceDirectory "src\auxlib.lua") -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $FceuxSourceDirectory "src\drivers\win\lua\x64\lua51.dll") -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $FceuxSourceDirectory "src\drivers\win\lua\x64\lua5.1.dll") -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $dependencies "SDL2\lib\x64\SDL2.dll") -Destination $OutputDirectory -Force
Copy-Item -LiteralPath (Join-Path $libarchiveInstall "bin\archive.dll") -Destination $OutputDirectory -Force

$windeployqt = Join-Path $qtRoot "bin\windeployqt.exe"
& $windeployqt --no-compiler-runtime (Join-Path $OutputDirectory "qfceux.exe")
if ($LASTEXITCODE -ne 0) {
    throw "windeployqt failed with exit code $LASTEXITCODE."
}

$executableHash = (Get-FileHash -LiteralPath (Join-Path $OutputDirectory "qfceux.exe") -Algorithm SHA256).Hash
$patchHash = (Get-FileHash -LiteralPath $PatchPath -Algorithm SHA256).Hash
$markerLines = @(
    "FCEUX 2.6.6 Dragon Warrior Accessibility runtime",
    "Upstream commit: $upstreamCommit",
    "Patch: release/fceux-v2.6.6-deferred-startup-lua.patch",
    "Patch SHA-256: $patchHash",
    "qfceux.exe SHA-256: $executableHash"
)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    (Join-Path $OutputDirectory "FCEUX-ACCESSIBILITY-BUILD.txt"),
    ($markerLines -join [Environment]::NewLine) + [Environment]::NewLine,
    $utf8NoBom
)

Write-Output ("FCEUX runtime: {0}" -f $OutputDirectory)
Write-Output ("qfceux.exe SHA-256: {0}" -f $executableHash)
Write-Output "Patched FCEUX runtime build complete."
