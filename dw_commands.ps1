param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $CommandArgs
)

$scriptDir = Split-Path -Parent $PSCommandPath
$cmdFile = Join-Path $scriptDir "dw_commands.txt"
$logFile = Join-Path $scriptDir "dw_debug.log"

$mode = "append"
$waitPattern = $null
$timeoutSeconds = 10
$i = 0

while ($i -lt $CommandArgs.Count) {
    $arg = $CommandArgs[$i]
    if ($arg -eq "--replace" -or $arg -eq "-Replace") {
        $mode = "replace"
        $i += 1
    } elseif ($arg -eq "--wait" -or $arg -eq "-Wait") {
        $i += 1
        if ($i -ge $CommandArgs.Count) {
            Write-Error "--wait requires a log pattern."
            exit 1
        }
        $waitPattern = $CommandArgs[$i]
        $i += 1
    } elseif ($arg -eq "--timeout" -or $arg -eq "-Timeout") {
        $i += 1
        if ($i -ge $CommandArgs.Count) {
            Write-Error "--timeout requires a positive integer seconds value."
            exit 1
        }
        $parsedTimeout = 0
        if (-not [int]::TryParse($CommandArgs[$i], [ref]$parsedTimeout) -or $parsedTimeout -le 0) {
            Write-Error "--timeout requires a positive integer seconds value."
            exit 1
        }
        $timeoutSeconds = $parsedTimeout
        $i += 1
    } elseif ($arg -eq "--") {
        $i += 1
        break
    } elseif ($arg.StartsWith("-")) {
        Write-Error ("Unknown option: {0}" -f $arg)
        exit 1
    } else {
        break
    }
}

if ($i -lt $CommandArgs.Count) {
    $CommandArgs = @($CommandArgs[$i..($CommandArgs.Count - 1)])
} else {
    $CommandArgs = @()
}

if ($CommandArgs.Count -eq 0) {
    Write-Output "dw_commands.ps1 - Send commands to the Dragon Warrior accessibility mod"
    Write-Output ""
    Write-Output "Usage:"
    Write-Output "  ./dw_commands.ps1 [--replace] [--wait PATTERN] [--timeout SECONDS] <command> [command2 command3 ...]"
    Write-Output ""
    Write-Output "Each argument is written as one command line to dw_commands.txt."
    Write-Output "--wait PATTERN waits for a fresh dw_debug.log line containing PATTERN."
    Write-Output "--timeout SECONDS overrides the default 10 second wait timeout."
    Write-Output "Use ./dw_commands.sh for bash shells; use ./dw_commands.ps1 from PowerShell/Codex."
    exit 0
}

$waitStartLine = 0
if ($waitPattern -and (Test-Path -LiteralPath $logFile)) {
    $waitStartLine = @(Get-Content -LiteralPath $logFile).Count
}

if ($mode -eq "replace") {
    Set-Content -LiteralPath $cmdFile -Value $CommandArgs -Encoding ascii
} else {
    Add-Content -LiteralPath $cmdFile -Value $CommandArgs -Encoding ascii
}

if (Test-Path -LiteralPath $logFile) {
    $ageSeconds = ((Get-Date) - (Get-Item -LiteralPath $logFile).LastWriteTime).TotalSeconds
    if ($ageSeconds -gt 60) {
        Write-Warning ("dw_debug.log was last updated {0}s ago - emulator may be idle or not running" -f [int]$ageSeconds)
    }
}

Write-Output ("Sent to mod: {0}" -f ($CommandArgs -join " "))

if ($waitPattern) {
    Write-Output ("Waiting up to {0}s for log pattern: {1}" -f $timeoutSeconds, $waitPattern)
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $logFile) {
            $lines = @(Get-Content -LiteralPath $logFile)
            if ($lines.Count -lt $waitStartLine) {
                $waitStartLine = 0
            }
            if ($lines.Count -gt $waitStartLine) {
                $newLines = $lines[$waitStartLine..($lines.Count - 1)]
                $match = $newLines | Where-Object { $_.Contains($waitPattern) } | Select-Object -Last 1
                if ($match) {
                    Write-Output ("Matched log: {0}" -f $match)
                    exit 0
                }
            }
        }

        Start-Sleep -Milliseconds 200
    }

    Write-Error ("Timed out waiting for log pattern: {0}" -f $waitPattern)
    exit 2
}
