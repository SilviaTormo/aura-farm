Add-Type @'
using System;
using System.Runtime.InteropServices;
public struct RECT { public int Left, Top, Right, Bottom; }
public static class WinQ {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
$p = Get-Process RobloxStudioBeta
$r = New-Object RECT
[WinQ]::GetWindowRect($p.MainWindowHandle, [ref]$r) | Out-Null
Write-Output ("window rect: L=" + $r.Left + " T=" + $r.Top + " R=" + $r.Right + " B=" + $r.Bottom)
[WinQ]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 500
$wsh = New-Object -ComObject WScript.Shell
$wsh.SendKeys("{F5}")
Write-Output "F5 sent via SendKeys"
