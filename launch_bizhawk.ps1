[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $BizhawkPath,

    [Parameter(Mandatory=$true)]
    [string] $LuaPath,

    [Parameter(Mandatory=$true)]
    [string] $RomPath,

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

Write-Host "BizHawk launcher"
Write-Host ("  Emulator: {0}" -f $BizhawkPath)
Write-Host ("  ROM:      {0}" -f $RomPath)
Write-Host ("  Lua:      {0}" -f $LuaPath)
$waitLabel = "yes"
if ($NoWait) {
    $waitLabel = "no"
}
Write-Host ("  Wait:     {0}" -f $waitLabel)

$arguments = @(
    "--lua=$LuaPath",
    $RomPath
)

if ($DryRun) {
    Write-Host ("  Argument: --lua={0}" -f $LuaPath)
    return
}

if ($NoWait) {
    Start-Process -FilePath $BizhawkPath -ArgumentList $arguments | Out-Null
    return
}

& $BizhawkPath @arguments
