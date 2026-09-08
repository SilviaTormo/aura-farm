# sendkey.ps1 — focuses Roblox Studio and taps a key (default F5 = Play).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools/sendkey.ps1 [-Vk 0x74] [-Title 'Roblox Studio']
param(
  [string]$Vk = "0x74",
  [string]$Title = "Roblox Studio"
)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Kb {
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  public const uint KEYUP = 0x2;
  public static void Tap(byte vk) {
    keybd_event(vk, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(80);
    keybd_event(vk, 0, KEYUP, UIntPtr.Zero);
  }
}
'@
$wsh = New-Object -ComObject WScript.Shell
for ($i = 0; $i -lt 10; $i++) {
  if ($wsh.AppActivate($Title)) { break }
  Start-Sleep -Milliseconds 500
}
Start-Sleep -Milliseconds 800
[Kb]::Tap([byte]([Convert]::ToInt32($Vk, 16)))
Write-Output "tapped $Vk into '$Title'"
