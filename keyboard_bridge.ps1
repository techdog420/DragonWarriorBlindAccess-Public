[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $OutputPath,

    [int] $PollMilliseconds = 16,

    [int] $HeartbeatMilliseconds = 250,

    [switch] $PolicySelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class KeyboardBridgeState {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct GUITHREADINFO {
        public int cbSize;
        public int flags;
        public IntPtr hwndActive;
        public IntPtr hwndFocus;
        public IntPtr hwndCapture;
        public IntPtr hwndMenuOwner;
        public IntPtr hwndMoveSize;
        public IntPtr hwndCaret;
        public RECT rcCaret;
    }

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    public static bool IsWarningActivityKey(int key) {
        return key >= 8 && key <= 254 && key != 16 && key != 17 && key != 18
            && key != 91 && key != 92 && !(key >= 160 && key <= 165);
    }

    public static bool HasWarningKeyboardActivity() {
        for (int key = 8; key <= 254; key++) {
            if (IsWarningActivityKey(key) && (GetAsyncKeyState(key) & 0x8000) != 0)
                return true;
        }
        return false;
    }

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetGUIThreadInfo(uint idThread, ref GUITHREADINFO lpgui);
}
'@

$GUI_INMENUMODE = [uint32] 0x00000004
$GUI_SYSTEMMENUMODE = [uint32] 0x00000008
$GUI_POPUPMENUMODE = [uint32] 0x00000010
$GUI_MENU_MODE_MASK = $GUI_INMENUMODE -bor $GUI_SYSTEMMENUMODE -bor $GUI_POPUPMENUMODE
$GW_OWNER = [uint32] 4

function Test-KeyDown {
    param([int] $VirtualKey)
    return (([KeyboardBridgeState]::GetAsyncKeyState($VirtualKey) -band 0x8000) -ne 0)
}

function Test-BridgePolicy {
    param(
        [bool] $EmulatorForeground,
        [bool] $OwnedWindow,
        [uint32] $GuiThreadFlags,
        [bool] $ModifierDown
    )

    if (-not $EmulatorForeground -or $OwnedWindow -or $ModifierDown) {
        return $false
    }

    return (($GuiThreadFlags -band $GUI_MENU_MODE_MASK) -eq 0)
}

function Test-BridgeModifierDown {
    # Shift/Ctrl/Alt/Windows cover emulator and mod hotkeys. Insert and Caps
    # Lock cover the common JAWS/NVDA modifier keys so screen-reader commands
    # using arrows cannot move the hero underneath the spoken UI.
    foreach ($virtualKey in @(0x10, 0x11, 0x12, 0x5B, 0x5C, 0x2D, 0x14)) {
        if (Test-KeyDown $virtualKey) {
            return $true
        }
    }
    return $false
}

function Get-BridgeButtons {
    $buttons = New-Object System.Collections.Generic.List[string]
    if (Test-KeyDown 0x26) { $buttons.Add("up") }      # VK_UP
    if (Test-KeyDown 0x28) { $buttons.Add("down") }    # VK_DOWN
    if (Test-KeyDown 0x25) { $buttons.Add("left") }    # VK_LEFT
    if (Test-KeyDown 0x27) { $buttons.Add("right") }   # VK_RIGHT
    if (Test-KeyDown 0x46) { $buttons.Add("A") }       # F
    if (Test-KeyDown 0x44) { $buttons.Add("B") }       # D
    if (Test-KeyDown 0x0D) { $buttons.Add("start") }   # Enter
    if (Test-KeyDown 0x53) { $buttons.Add("select") }  # S
    return $buttons.ToArray()
}

function Get-BridgeSuppressionState {
    param(
        [bool] $BasePolicyAllowsInput,
        [bool] $MappedButtonDown,
        [bool] $WasSuppressed
    )

    if (-not $BasePolicyAllowsInput) {
        return $true
    }

    # Do not let the tail of Alt+F, Shift+Enter, a screen-reader arrow chord,
    # or a dialog-selection key reach the ROM if its modifier/window state
    # clears first. Resume only after every mapped game key is physically up.
    return $WasSuppressed -and $MappedButtonDown
}

function Test-EmulatorGameplayInput {
    param([bool] $ModifierDown)

    $hwnd = [KeyboardBridgeState]::GetForegroundWindow()
    if ($hwnd -eq [IntPtr]::Zero) {
        return $false
    }

    $processId = [uint32] 0
    $threadId = [KeyboardBridgeState]::GetWindowThreadProcessId($hwnd, [ref] $processId)
    if ($processId -eq 0 -or $threadId -eq 0) {
        return $false
    }

    try {
        $process = Get-Process -Id ([int] $processId) -ErrorAction Stop
    } catch {
        return $false
    }

    $emulatorForeground = $process.ProcessName -eq "qfceux" -or $process.ProcessName -eq "fceux"
    if (-not $emulatorForeground) {
        return $false
    }

    # QFileDialog/Lua Script Control and other modal windows are owned by the
    # main qfceux window. Never translate their arrows or Enter into NES input.
    $ownedWindow = [KeyboardBridgeState]::GetWindow($hwnd, $GW_OWNER) -ne [IntPtr]::Zero

    # The File menu normally remains part of the main qfceux top-level window,
    # so ownership alone is insufficient. GUITHREADINFO exposes native/menu
    # popup modes even while the foreground HWND itself does not change.
    $guiFlags = [uint32] 0
    $guiInfo = New-Object KeyboardBridgeState+GUITHREADINFO
    $guiInfo.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($guiInfo)
    if ([KeyboardBridgeState]::GetGUIThreadInfo($threadId, [ref] $guiInfo)) {
        $guiFlags = [uint32] $guiInfo.flags

        # Qt popups may expose an active or menu-owner HWND even when Windows
        # keeps the main qfceux HWND foreground. Treat any owned active popup
        # or explicit menu owner as emulator UI rather than gameplay.
        if ($guiInfo.hwndMenuOwner -ne [IntPtr]::Zero) {
            $ownedWindow = $true
        }
        foreach ($uiHwnd in @($guiInfo.hwndActive, $guiInfo.hwndFocus, $guiInfo.hwndCapture)) {
            if ($uiHwnd -ne [IntPtr]::Zero -and
                $uiHwnd -ne $hwnd -and
                [KeyboardBridgeState]::GetWindow($uiHwnd, $GW_OWNER) -ne [IntPtr]::Zero) {
                $ownedWindow = $true
            }
        }
    }

    return Test-BridgePolicy `
        -EmulatorForeground $emulatorForeground `
        -OwnedWindow $ownedWindow `
        -GuiThreadFlags $guiFlags `
        -ModifierDown $ModifierDown
}

if ($PolicySelfTest) {
    foreach ($key in @(16,17,18,91,92,160,161,162,163,164,165)) {
        if ([KeyboardBridgeState]::IsWarningActivityKey($key)) { throw "Modifier counted as activity: $key" }
    }
    foreach ($key in @(13,32,38,70,112,45,20)) {
        if (-not [KeyboardBridgeState]::IsWarningActivityKey($key)) { throw "Keyboard activity ignored: $key" }
    }
    $cases = @(
        @{Name="gameplay"; Emulator=$true; Owned=$false; Flags=0; Modifier=$false; Expected=$true},
        @{Name="other_process"; Emulator=$false; Owned=$false; Flags=0; Modifier=$false; Expected=$false},
        @{Name="owned_dialog"; Emulator=$true; Owned=$true; Flags=0; Modifier=$false; Expected=$false},
        @{Name="modifier_chord"; Emulator=$true; Owned=$false; Flags=0; Modifier=$true; Expected=$false},
        @{Name="menu_mode"; Emulator=$true; Owned=$false; Flags=$GUI_INMENUMODE; Modifier=$false; Expected=$false},
        @{Name="system_menu"; Emulator=$true; Owned=$false; Flags=$GUI_SYSTEMMENUMODE; Modifier=$false; Expected=$false},
        @{Name="popup_menu"; Emulator=$true; Owned=$false; Flags=$GUI_POPUPMENUMODE; Modifier=$false; Expected=$false}
    )
    foreach ($case in $cases) {
        $actual = Test-BridgePolicy `
            -EmulatorForeground $case.Emulator `
            -OwnedWindow $case.Owned `
            -GuiThreadFlags $case.Flags `
            -ModifierDown $case.Modifier
        if ($actual -ne $case.Expected) {
            throw ("Keyboard bridge policy test failed: {0}; expected={1} actual={2}" -f $case.Name, $case.Expected, $actual)
        }
    }
    $suppressionCases = @(
        @{Name="menu_begins"; Base=$false; Mapped=$false; Prior=$false; Expected=$true},
        @{Name="modifier_tail_held"; Base=$true; Mapped=$true; Prior=$true; Expected=$true},
        @{Name="neutral_resume"; Base=$true; Mapped=$false; Prior=$true; Expected=$false},
        @{Name="normal_gameplay"; Base=$true; Mapped=$true; Prior=$false; Expected=$false}
    )
    foreach ($case in $suppressionCases) {
        $actual = Get-BridgeSuppressionState `
            -BasePolicyAllowsInput $case.Base `
            -MappedButtonDown $case.Mapped `
            -WasSuppressed $case.Prior
        if ($actual -ne $case.Expected) {
            throw ("Keyboard bridge suppression test failed: {0}; expected={1} actual={2}" -f $case.Name, $case.Expected, $actual)
        }
    }
    Write-Output ("Keyboard bridge policy tests passed: {0}" -f ($cases.Count + $suppressionCases.Count))
    return
}

function Write-State {
    param([string] $Line)

    try {
        [System.IO.File]::WriteAllText($OutputPath, $Line + [Environment]::NewLine)
        return $true
    } catch [System.IO.IOException] {
        $errorCode = $_.Exception.HResult -band 0xFFFF
        if ($errorCode -eq 32 -or $errorCode -eq 33) {
            # A reader/collector may briefly deny writes. Retry the latest
            # physical state on the next poll instead of losing input forever.
            # Lua's lease still expires normally if the lock persists.
            return $false
        }
        throw
    }
}

$outputDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$lastLine = $null
$suppressionActive = $true
$heartbeatCounter = [int64] 0
$heartbeatTimer = [System.Diagnostics.Stopwatch]::StartNew()
try {
    while ($true) {
        $buttons = @(Get-BridgeButtons)
        $modifierDown = Test-BridgeModifierDown
        $basePolicyAllowsInput = Test-EmulatorGameplayInput -ModifierDown $modifierDown
        $suppressionActive = Get-BridgeSuppressionState `
            -BasePolicyAllowsInput $basePolicyAllowsInput `
            -MappedButtonDown ($buttons.Count -gt 0) `
            -WasSuppressed $suppressionActive
        $gameplayInput = $basePolicyAllowsInput -and -not $suppressionActive

        # "suspended" is intentionally distinct from neutral gameplay input.
        # Lua treats it as authoritative and must not fall back to FCEUX's
        # stale/menu-forwarded input while emulator UI or a modifier owns keys.
        $line = if (-not $gameplayInput) {
            "suspended"
        } elseif ($buttons.Count -gt 0) {
            $buttons -join ","
        } else {
            "-"
        }

        # v3 adds physical keyboard activity for warning delivery, independently
        # of movement suppression. FCEUX input.get() can retain released keys.
        $keyboardActivity = [int][KeyboardBridgeState]::HasWarningKeyboardActivity()
        $publishedState = "{0}:{1}" -f $keyboardActivity, $line
        # The heartbeat gives Lua a fail-closed lease. If this process dies
        # while a button is present, Lua releases it instead of trusting the
        # last non-neutral file contents forever.
        if ($publishedState -ne $lastLine -or $heartbeatTimer.ElapsedMilliseconds -ge $HeartbeatMilliseconds) {
            $heartbeatCounter += 1
            $heartbeatTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            if (Write-State -Line ("v3:{0}:{1}:{2}" -f $heartbeatCounter, $heartbeatTimestamp, $publishedState)) {
                $lastLine = $publishedState
                $heartbeatTimer.Restart()
            }
        }

        Start-Sleep -Milliseconds $PollMilliseconds
    }
} finally {
    try {
        $heartbeatCounter += 1
        $heartbeatTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        [void] (Write-State -Line ("v2:{0}:{1}:suspended" -f $heartbeatCounter, $heartbeatTimestamp))
    } catch {
        # A force-killed process cannot guarantee cleanup; Lua's heartbeat
        # lease remains the authoritative fallback for that case.
    }
}
