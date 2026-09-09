# viewportplay.ps1 - focus Studio, click the 3D viewport, tap F5 = Play.
# BUG FIXED 2026-09-09 15:10: mouse_event dx,dy are RELATIVE deltas — the
# old version passed absolute coords and clicked random screen edges on
# multi-monitor. SetCursorPos first, then click at the current position.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Vp2 {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint f, UIntPtr e);
  public const uint LEFTDOWN = 0x2, LEFTUP = 0x4, KEYUP = 0x2;
  public static void ClickHere() {
    mouse_event(LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(70);
    mouse_event(LEFTUP, 0, 0, 0, UIntPtr.Zero);
  }
  public static void Tap(byte vk) {
    keybd_event(vk, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(80);
    keybd_event(vk, 0, KEYUP, UIntPtr.Zero);
  }
}
'@
$wsh = New-Object -ComObject WScript.Shell
$ok = $false
for ($i = 0; $i -lt 8; $i++) { if ($wsh.AppActivate('AuraFarmPilot.rbxl - Roblox Studio')) { $ok = $true; break }; Start-Sleep -Milliseconds 500 }
if (-not $ok) { Write-Output "could not focus Studio"; exit 1 }
Start-Sleep -Milliseconds 800
# Viewport center (window-independent screen coords; west dock is x<745).
[void][Vp2]::SetCursorPos(1357, 719)
Start-Sleep -Milliseconds 400
[Vp2]::ClickHere()
Start-Sleep -Milliseconds 400
[Vp2]::Tap(0x74) # F5
Write-Output "viewport click (SetCursorPos) at 1357,719 + F5"