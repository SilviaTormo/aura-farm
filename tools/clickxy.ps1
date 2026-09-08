# clickxy.ps1 - REAL mouse click at absolute screen coords
param([int]$X, [int]$Y)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class M2 {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  public static void Click(int x, int y) {
    SetCursorPos(x, y);
    System.Threading.Thread.Sleep(200);
    mouse_event(0x02, 0, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(70);
    mouse_event(0x04, 0, 0, 0, UIntPtr.Zero);
  }
}
'@
[M2]::Click($X, $Y)
Write-Output "clicked $X,$Y"
