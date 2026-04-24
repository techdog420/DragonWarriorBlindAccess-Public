[CmdletBinding()]
param(
    [int] $ProcessId,
    [string] $Keys,
    [switch] $SendCtrlL,
    [switch] $SendShiftL,
    [switch] $SendAltS,
    [switch] $SendR
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ws = New-Object -ComObject WScript.Shell

if ($ProcessId -gt 0) {
    $ok = $ws.AppActivate($ProcessId)
    Write-Output ("activate=" + $ok)
    $resolvedKeys = $Keys
    if ($SendCtrlL) {
        $resolvedKeys = '^l'
    } elseif ($SendShiftL) {
        $resolvedKeys = '+l'
    } elseif ($SendAltS) {
        $resolvedKeys = '%s'
    } elseif ($SendR) {
        $resolvedKeys = 'r'
    }

    if ($ok -and -not [string]::IsNullOrWhiteSpace($resolvedKeys)) {
        Start-Sleep -Milliseconds 300
        $ws.SendKeys($resolvedKeys)
        Write-Output ("keys=" + $resolvedKeys)
    }
} else {
    Write-Output "wscript-ok"
}
