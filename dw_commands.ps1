param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $CommandArgs
)

$scriptDir = Split-Path -Parent $PSCommandPath
$cmdFile = Join-Path $scriptDir "dw_commands.txt"
$logFile = Join-Path $scriptDir "dw_debug.log"

$mode = "append"
if ($CommandArgs.Count -gt 0 -and ($CommandArgs[0] -eq "--replace" -or $CommandArgs[0] -eq "-Replace")) {
    $mode = "replace"
    if ($CommandArgs.Count -eq 1) {
        $CommandArgs = @()
    } else {
        $CommandArgs = $CommandArgs[1..($CommandArgs.Count - 1)]
    }
}

if ($CommandArgs.Count -eq 0) {
    Write-Output "dw_commands.ps1 - Send commands to the Dragon Warrior accessibility mod"
    Write-Output ""
    Write-Output "Usage:"
    Write-Output "  ./dw_commands.ps1 [--replace] <command> [command2 command3 ...]"
    Write-Output ""
    Write-Output "Each argument is written as one command line to dw_commands.txt."
    Write-Output "Use ./dw_commands.sh for bash shells; use ./dw_commands.ps1 from PowerShell/Codex."
    exit 0
}

if ($mode -eq "replace") {
    Set-Content -LiteralPath $cmdFile -Value $CommandArgs -Encoding ascii
} else {
    Add-Content -LiteralPath $cmdFile -Value $CommandArgs -Encoding ascii
}

if (Test-Path -LiteralPath $logFile) {
    $ageSeconds = ((Get-Date) - (Get-Item -LiteralPath $logFile).LastWriteTime).TotalSeconds
    if ($ageSeconds -gt 60) {
        Write-Warning ("dw_debug.log was last updated {0}s ago - FCEUX may be idle or not running" -f [int]$ageSeconds)
    }
}

Write-Output ("Sent to mod: {0}" -f ($CommandArgs -join " "))
