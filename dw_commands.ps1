param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $CommandArgs
)

$scriptDir = Split-Path -Parent $PSCommandPath
$cmdFile = Join-Path $scriptDir "dw_commands.txt"
$logFile = Join-Path $scriptDir "dw_debug.log"

$mode = "append"
$waitPattern = $null
$waitReadyTag = $null
$timeoutSeconds = 10
$requireLiveSeconds = $null
$jsonOutput = $false
$sent = $false
$matchedLine = $null
$warningMessage = $null
$logAgeSeconds = $null
$timedOut = $false
$finalCommands = @()
$i = 0

function Write-StatusAndExit {
    param(
        [string] $Status,
        [int] $ExitCode,
        [string] $Message = $null
    )

    if ($script:jsonOutput) {
        [ordered]@{
            status = $Status
            exit_code = $ExitCode
            mode = $script:mode
            commands = @($script:finalCommands)
            wait_pattern = $script:waitPattern
            wait_ready_tag = $script:waitReadyTag
            timeout_seconds = $script:timeoutSeconds
            require_live_seconds = $script:requireLiveSeconds
            log_age_seconds = $script:logAgeSeconds
            sent = $script:sent
            matched_line = $script:matchedLine
            timed_out = $script:timedOut
            warning = $script:warningMessage
            message = $Message
        } | ConvertTo-Json -Compress
    } elseif ($Message) {
        Write-Error $Message
    }

    exit $ExitCode
}

function Require-PositiveSeconds {
    param(
        [string] $OptionName,
        [string] $Value
    )

    $parsed = 0
    if (-not [int]::TryParse($Value, [ref]$parsed) -or $parsed -le 0) {
        Write-StatusAndExit "error" 1 ("{0} requires a positive integer seconds value." -f $OptionName)
    }
    return $parsed
}

function Update-LogAge {
    $script:logAgeSeconds = $null
    if (Test-Path -LiteralPath $script:logFile) {
        $script:logAgeSeconds = [int](((Get-Date) - (Get-Item -LiteralPath $script:logFile).LastWriteTime).TotalSeconds)
    }
}

while ($i -lt $CommandArgs.Count) {
    $arg = $CommandArgs[$i]
    if ($arg -eq "--replace" -or $arg -eq "-Replace") {
        $mode = "replace"
        $i += 1
    } elseif ($arg -eq "--wait" -or $arg -eq "-Wait") {
        $i += 1
        if ($i -ge $CommandArgs.Count) {
            Write-StatusAndExit "error" 1 "--wait requires a log pattern."
        }
        $waitPattern = $CommandArgs[$i]
        $i += 1
    } elseif ($arg -eq "--wait-ready" -or $arg -eq "-WaitReady") {
        $i += 1
        if ($i -ge $CommandArgs.Count) {
            Write-StatusAndExit "error" 1 "--wait-ready requires a tag."
        }
        $waitReadyTag = $CommandArgs[$i]
        $i += 1
    } elseif ($arg -eq "--timeout" -or $arg -eq "-Timeout") {
        $i += 1
        if ($i -ge $CommandArgs.Count) {
            Write-StatusAndExit "error" 1 "--timeout requires a positive integer seconds value."
        }
        $timeoutSeconds = Require-PositiveSeconds "--timeout" $CommandArgs[$i]
        $i += 1
    } elseif ($arg -eq "--require-live" -or $arg -eq "-RequireLive") {
        $i += 1
        if ($i -ge $CommandArgs.Count) {
            Write-StatusAndExit "error" 1 "--require-live requires a positive integer seconds value."
        }
        $requireLiveSeconds = Require-PositiveSeconds "--require-live" $CommandArgs[$i]
        $i += 1
    } elseif ($arg -eq "--json" -or $arg -eq "-Json") {
        $jsonOutput = $true
        $i += 1
    } elseif ($arg -eq "--") {
        $i += 1
        break
    } elseif ($arg.StartsWith("-")) {
        Write-StatusAndExit "error" 1 ("Unknown option: {0}" -f $arg)
    } else {
        break
    }
}

if ($i -lt $CommandArgs.Count) {
    $CommandArgs = @($CommandArgs[$i..($CommandArgs.Count - 1)])
} else {
    $CommandArgs = @()
}

if ($waitPattern -and $waitReadyTag) {
    Write-StatusAndExit "error" 1 "--wait and --wait-ready cannot be used together."
}

$finalCommands = @($CommandArgs)
if ($waitReadyTag) {
    $waitPattern = "LAUNCHER_PROBE: {0}" -f $waitReadyTag
    $finalCommands = @("launcher_probe:{0}" -f $waitReadyTag) + $finalCommands
}

if ($finalCommands.Count -eq 0) {
    if ($jsonOutput) {
        Write-StatusAndExit "error" 1 "No commands provided."
    }

    Write-Output "dw_commands.ps1 - Send commands to the Dragon Warrior accessibility mod"
    Write-Output ""
    Write-Output "Usage:"
    Write-Output "  ./dw_commands.ps1 [--replace] [--wait PATTERN] [--wait-ready TAG] [--timeout SECONDS]"
    Write-Output "                    [--require-live SECONDS] [--json] <command> [command2 command3 ...]"
    Write-Output ""
    Write-Output "Each argument is written as one command line to dw_commands.txt."
    Write-Output "--wait PATTERN waits for a fresh dw_debug.log line containing PATTERN."
    Write-Output "--wait-ready TAG queues launcher_probe:TAG and waits for the fresh marker."
    Write-Output "--timeout SECONDS overrides the default 10 second wait timeout."
    Write-Output "--require-live SECONDS fails before queueing if dw_debug.log is stale."
    Write-Output "--json prints machine-readable status for automated harnesses."
    Write-Output "Use ./dw_commands.sh for bash shells; use ./dw_commands.ps1 from PowerShell/Codex."
    exit 0
}

Update-LogAge
if ($requireLiveSeconds) {
    if ($null -eq $logAgeSeconds) {
        Write-StatusAndExit "not_live" 3 "dw_debug.log is missing; refusing to queue commands without live proof."
    }
    if ($logAgeSeconds -gt $requireLiveSeconds) {
        Write-StatusAndExit "not_live" 3 ("dw_debug.log is {0}s old, exceeding --require-live {1}s; refusing to queue commands." -f $logAgeSeconds, $requireLiveSeconds)
    }
}

$waitStartLine = 0
if ($waitPattern -and (Test-Path -LiteralPath $logFile)) {
    $waitStartLine = @(Get-Content -LiteralPath $logFile).Count
}

if ($mode -eq "replace") {
    Set-Content -LiteralPath $cmdFile -Value $finalCommands -Encoding ascii
} else {
    Add-Content -LiteralPath $cmdFile -Value $finalCommands -Encoding ascii
}
$sent = $true

if ($null -ne $logAgeSeconds -and $logAgeSeconds -gt 60) {
    $warningMessage = "dw_debug.log was last updated {0}s ago - emulator may be idle or not running" -f $logAgeSeconds
    if (-not $jsonOutput) {
        Write-Warning $warningMessage
    }
}

if (-not $jsonOutput) {
    Write-Output ("Sent to mod: {0}" -f ($finalCommands -join " "))
}

if ($waitPattern) {
    if (-not $jsonOutput) {
        Write-Output ("Waiting up to {0}s for log pattern: {1}" -f $timeoutSeconds, $waitPattern)
    }
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
                    $matchedLine = $match
                    if ($jsonOutput) {
                        Write-StatusAndExit "matched" 0
                    } else {
                        Write-Output ("Matched log: {0}" -f $match)
                        exit 0
                    }
                }
            }
        }

        Start-Sleep -Milliseconds 200
    }

    $timedOut = $true
    Write-StatusAndExit "timeout" 2 ("Timed out waiting for log pattern: {0}" -f $waitPattern)
}

if ($jsonOutput) {
    Write-StatusAndExit "sent" 0
}
