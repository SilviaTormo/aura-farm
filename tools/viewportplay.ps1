# viewportplay.ps1 - click the Studio 3D viewport (steals focus from docked
# web panes, which silently eat keystrokes), then tap F5 = Play.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Vp {
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint f, UIntPtr e);
  public struct RECT { public int L, T, R, B; }
  public const uint LEFTDOWN = 0x2, LEFTUP = 0x4, KEYUP = 0x2;
  public static void Click(int x, int y) {
    mouse_event(LEFTDOWN, (uint)x, (uint)y, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(60);
    mouse_event(LEFTUP, (uint)x, (uint)y, 0, UIntPtr.Zero);
  }
  public static void Tap(byte vk) {
    keybd_event(vk, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(80);
    keybd_event(vk, 0, KEYUP, UIntPtr.Zero);
  }
}
'@
$h = (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1).MainWindowHandle
if (-not $h) { Write-Output "no studio window"; exit 1 }
$h = [IntPtr]$h
$r = New-Object Vp+RECT
[void][Vp]::GetWindowRect($h, [ref]$r)
# Viewport = upper-left region of the window, clear of ribbon and docked panes.
$vx = $r.L + 420
$vy = $r.T + 420
[void][Vp]::SetForegroundWindow($h)
Start-Sleep -Milliseconds 500
[Vp]::Click($vx, $vy)
Start-Sleep -Milliseconds 400
[Vp]::Tap(0x74) # F5
Write-Output "viewport click at $vx,$vy + F5 (window L=$($r.L) T=$($r.T))"