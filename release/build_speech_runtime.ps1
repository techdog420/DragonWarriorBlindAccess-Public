[CmdletBinding()]
param(
    [string] $OutputDirectory,
    [string] $CacheDirectory,
    [string] $BuilderPython
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ".tools\release-staging\python"
}
if ([string]::IsNullOrWhiteSpace($CacheDirectory)) {
    $CacheDirectory = Join-Path $repoRoot ".tools\release-cache\speech"
}
if ([string]::IsNullOrWhiteSpace($BuilderPython)) {
    $BuilderPython = Join-Path $repoRoot ".venv\Scripts\python.exe"
}

$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$CacheDirectory = [System.IO.Path]::GetFullPath($CacheDirectory)
$BuilderPython = [System.IO.Path]::GetFullPath($BuilderPython)
$requirementsPath = Join-Path $PSScriptRoot "speech-requirements.txt"

$pythonUrl = "https://www.python.org/ftp/python/3.14.6/python-3.14.6-embed-amd64.zip"
$pythonArchiveName = "python-3.14.6-embed-amd64.zip"
$pythonArchiveSha256 = "DF901E84A896FF1EE720AD03377E0C8D8C2244FDA79808AEEAFF6316DF1CB75C"
$pythonArchivePath = Join-Path $CacheDirectory $pythonArchiveName
$nvdaControllerUrl = "https://download.nvaccess.org/releases/2026.1.1/nvda_2026.1.1_controllerClient.zip"
$nvdaControllerArchiveName = "nvda_2026.1.1_controllerClient.zip"
$nvdaControllerArchiveSha256 = "2A3A70F729BE0C48120C5F24A81653202827C40A7986E289FFE2275A2B45011F"
$nvdaControllerDllSha256 = "2FE60CF00BE929AAE32E95C1E1507A20ADA4902C8FEC273B3CC2D3BF5472932A"
$nvdaSourceCommit = "5d92106f17e461dac62aa48257bbbf4183e033d0"
$nvdaControllerArchivePath = Join-Path $CacheDirectory $nvdaControllerArchiveName
$wheelDirectory = Join-Path $CacheDirectory "wheels"

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

if (-not (Test-Path -LiteralPath $BuilderPython -PathType Leaf)) {
    throw "Builder Python not found: $BuilderPython"
}
if (-not (Test-Path -LiteralPath $requirementsPath -PathType Leaf)) {
    throw "Pinned speech requirements not found: $requirementsPath"
}
if (Test-Path -LiteralPath $OutputDirectory) {
    throw "Speech runtime output already exists; choose a new empty path: $OutputDirectory"
}

New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $wheelDirectory -Force | Out-Null

$downloadRequired = $true
if (Test-Path -LiteralPath $pythonArchivePath -PathType Leaf) {
    $cachedHash = Get-Sha256 -Path $pythonArchivePath
    if ($cachedHash -eq $pythonArchiveSha256) {
        $downloadRequired = $false
        Write-Output "Using verified cached Python archive."
    } else {
        Remove-Item -LiteralPath $pythonArchivePath -Force
        Write-Output ("Removed cached Python archive with unexpected SHA-256: {0}" -f $cachedHash)
    }
}

if ($downloadRequired) {
    Write-Output ("Downloading official embedded Python: {0}" -f $pythonUrl)
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonArchivePath -UseBasicParsing
}

$actualPythonHash = Get-Sha256 -Path $pythonArchivePath
if ($actualPythonHash -ne $pythonArchiveSha256) {
    throw ("Embedded Python SHA-256 mismatch. Expected {0}; actual {1}" -f $pythonArchiveSha256, $actualPythonHash)
}
Write-Output ("Embedded Python SHA-256 verified: {0}" -f $actualPythonHash)

$nvdaDownloadRequired = $true
if (Test-Path -LiteralPath $nvdaControllerArchivePath -PathType Leaf) {
    $cachedNvdaHash = Get-Sha256 -Path $nvdaControllerArchivePath
    if ($cachedNvdaHash -eq $nvdaControllerArchiveSha256) {
        $nvdaDownloadRequired = $false
        Write-Output "Using verified cached NVDA Controller Client archive."
    } else {
        Remove-Item -LiteralPath $nvdaControllerArchivePath -Force
        Write-Output ("Removed cached NVDA archive with unexpected SHA-256: {0}" -f $cachedNvdaHash)
    }
}

if ($nvdaDownloadRequired) {
    Write-Output ("Downloading official NVDA Controller Client: {0}" -f $nvdaControllerUrl)
    Invoke-WebRequest -Uri $nvdaControllerUrl -OutFile $nvdaControllerArchivePath -UseBasicParsing
}

$actualNvdaArchiveHash = Get-Sha256 -Path $nvdaControllerArchivePath
if ($actualNvdaArchiveHash -ne $nvdaControllerArchiveSha256) {
    throw ("NVDA Controller Client SHA-256 mismatch. Expected {0}; actual {1}" -f $nvdaControllerArchiveSha256, $actualNvdaArchiveHash)
}
Write-Output ("NVDA Controller Client SHA-256 verified: {0}" -f $actualNvdaArchiveHash)

Write-Output "Downloading pinned binary dependency wheels."
& $BuilderPython -m pip download `
    --disable-pip-version-check `
    --only-binary=:all: `
    --dest $wheelDirectory `
    --requirement $requirementsPath
if ($LASTEXITCODE -ne 0) {
    throw ("Dependency wheel download failed with exit code {0}" -f $LASTEXITCODE)
}

$createdOutput = $false
try {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $createdOutput = $true
    Expand-Archive -LiteralPath $pythonArchivePath -DestinationPath $OutputDirectory

    $sitePackages = Join-Path $OutputDirectory "Lib\site-packages"
    New-Item -ItemType Directory -Path $sitePackages -Force | Out-Null

    Write-Output "Installing pinned speech dependencies into the portable runtime."
    & $BuilderPython -m pip install `
        --disable-pip-version-check `
        --no-compile `
        --no-index `
        --only-binary=:all: `
        --find-links $wheelDirectory `
        --target $sitePackages `
        --requirement $requirementsPath
    if ($LASTEXITCODE -ne 0) {
        throw ("Portable dependency installation failed with exit code {0}" -f $LASTEXITCODE)
    }

    # accessible-output2's wheel includes vendor DLLs for screen readers that
    # this release does not support. Keep only the official, pinned x64 NVDA
    # client; JAWS uses the screen reader's installed COM API and SAPI uses
    # Windows' installed speech API.
    $accessibleOutputLib = Join-Path $sitePackages "accessible_output2\lib"
    $unusedVendorDlls = @(
        "dolapi.dll",
        "nvdaControllerClient32.dll",
        "nvdaControllerClient64.dll",
        "PCTKUSR.dll",
        "PCTKUSR64.dll",
        "SAAPI32.dll",
        "ZDSRAPI.dll",
        "ZDSRAPI_x64.dll"
    )
    foreach ($unusedVendorDll in $unusedVendorDlls) {
        $unusedPath = Join-Path $accessibleOutputLib $unusedVendorDll
        if (Test-Path -LiteralPath $unusedPath -PathType Leaf) {
            Remove-Item -LiteralPath $unusedPath -Force
        }
    }

    $nvdaExtractDirectory = Join-Path $OutputDirectory "_nvda-controller-client"
    Expand-Archive -LiteralPath $nvdaControllerArchivePath -DestinationPath $nvdaExtractDirectory
    $officialNvdaDll = Join-Path $nvdaExtractDirectory "x64\nvdaControllerClient.dll"
    $officialNvdaLicense = Join-Path $nvdaExtractDirectory "license.txt"
    if ((Get-Sha256 -Path $officialNvdaDll) -ne $nvdaControllerDllSha256) {
        throw "Official NVDA Controller Client DLL failed its pinned SHA-256 check."
    }
    Copy-Item `
        -LiteralPath $officialNvdaDll `
        -Destination (Join-Path $accessibleOutputLib "nvdaControllerClient64.dll")
    Copy-Item `
        -LiteralPath $officialNvdaLicense `
        -Destination (Join-Path $accessibleOutputLib "NVDA Controller Client LICENSE.txt")
    Remove-Item -LiteralPath $nvdaExtractDirectory -Recurse -Force

    $remainingVendorDlls = @(Get-ChildItem -LiteralPath $accessibleOutputLib -File -Filter "*.dll")
    if ($remainingVendorDlls.Count -ne 1 -or $remainingVendorDlls[0].Name -ne "nvdaControllerClient64.dll") {
        throw ("Unexpected accessible-output2 vendor DLL set: {0}" -f ($remainingVendorDlls.Name -join ", "))
    }

    $pthFiles = @(Get-ChildItem -LiteralPath $OutputDirectory -File -Filter "python*._pth")
    if ($pthFiles.Count -ne 1) {
        throw ("Expected one embedded-Python _pth file; found {0}" -f $pthFiles.Count)
    }
    $pthText = @(
        "python314.zip",
        ".",
        "Lib\site-packages",
        "import site"
    ) -join [Environment]::NewLine
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($pthFiles[0].FullName, $pthText + [Environment]::NewLine, $utf8NoBom)

    $dependencyLines = @(
        [System.IO.File]::ReadAllText($requirementsPath).TrimEnd(),
        "",
        "NVDA-Controller-Client==2026.1.1",
        "NVDA controller archive SHA-256: $nvdaControllerArchiveSha256",
        "NVDA controller DLL SHA-256: $nvdaControllerDllSha256",
        "NVDA corresponding source commit: $nvdaSourceCommit",
        "NVDA source is included in the sibling corresponding-source release asset."
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText(
        (Join-Path $OutputDirectory "SPEECH-DEPENDENCIES.txt"),
        $dependencyLines + [Environment]::NewLine,
        $utf8NoBom
    )

    $runtimePython = Join-Path $OutputDirectory "python.exe"
    $verifyCode = @'
import importlib.metadata as metadata
from accessible_output2.outputs.nvda import NVDA
from accessible_output2.outputs.sapi5 import SAPI5

nvda = NVDA()
sapi = SAPI5()
print("python-runtime=OK")
print("accessible-output2=" + metadata.version("accessible-output2"))
print("pywin32=" + metadata.version("pywin32"))
print("nvda=" + nvda.__class__.__module__ + "." + nvda.__class__.__name__)
print("sapi=" + sapi.__class__.__module__ + "." + sapi.__class__.__name__)
'@
    $previousNoBytecode = [Environment]::GetEnvironmentVariable("PYTHONDONTWRITEBYTECODE")
    $env:PYTHONDONTWRITEBYTECODE = "1"
    try {
        $verifyOutput = @(& $runtimePython -c $verifyCode 2>&1)
        $verifyExitCode = $LASTEXITCODE
    } finally {
        $env:PYTHONDONTWRITEBYTECODE = $previousNoBytecode
    }
    $verifyOutput | ForEach-Object { Write-Output $_ }
    if ($verifyExitCode -ne 0) {
        throw ("Portable speech runtime verification failed with exit code {0}" -f $verifyExitCode)
    }

    Write-Output ("Portable speech runtime ready: {0}" -f $OutputDirectory)
} catch {
    if ($createdOutput -and (Test-Path -LiteralPath $OutputDirectory)) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
    }
    throw
}
