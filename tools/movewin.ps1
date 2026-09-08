# movewin.ps1 — moves the Studio window to the primary monitor and maximizes it.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Win {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
}
'@
Add-Type -AssemblyName System.Windows.Forms
$p = Get-Process RobloxStudioBeta
$h = $p.MainWindowHandle
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
Write-Output ("primary: " + $b.Width + "x" + $b.Height)
[Win]::ShowWindow($h, 9) | Out-Null   # SW_RESTORE
Start-Sleep -Milliseconds 300
# Move to primary, size to its work area (leave taskbar)
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
[Win]::SetWindowPos($h, [IntPtr]::Zero, $wa.X, $wa.Y, $wa.Width, $wa.Height, 0x0040) | Out-Null
Start-Sleep -Milliseconds 300
[Win]::SetForegroundWindow($h) | Out-Null
Write-Output ("moved to " + $wa.X + "," + $wa.Y + " " + $wa.Width + "x" + $wa.Height)
