[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int] $ProcessId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class WindowLister {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    public static List<string> ListWindows(uint targetPid) {
        var results = new List<string>();
        EnumWindows(delegate (IntPtr hWnd, IntPtr lParam) {
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            if (pid != targetPid) {
                return true;
            }

            var title = new StringBuilder(512);
            GetWindowText(hWnd, title, title.Capacity);

            var cls = new StringBuilder(256);
            GetClassName(hWnd, cls, cls.Capacity);

            results.Add(string.Format(
                "hwnd=0x{0:X} visible={1} class={2} title={3}",
                hWnd.ToInt64(),
                IsWindowVisible(hWnd),
                cls.ToString(),
                title.ToString()
            ));
            return true;
        }, IntPtr.Zero);
        return results;
    }
}
"@

$lines = [WindowLister]::ListWindows([uint32]$ProcessId)
if ($lines.Count -eq 0) {
    Write-Output "no-windows"
} else {
    $lines | ForEach-Object { Write-Output $_ }
}
