[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]] $RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$fceuxLauncher = Join-Path $scriptDir "launch_dw.ps1"

& $fceuxLauncher @RemainingArgs
if ($null -ne $LASTEXITCODE) {
    exit $LASTEXITCODE
}
exit 0
