# realclick.ps1 — REAL mouse click on an element found by AutomationId.
param([string]$Id = "multiLineRunButtonContainer.commandBarRunButton")
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Mouse {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
  public const uint LEFTDOWN = 0x02, LEFTUP = 0x04;
  public static void Click() {
    mouse_event(LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(60);
    mouse_event(LEFTUP, 0, 0, 0, UIntPtr.Zero);
  }
}
'@
$root = [System.Windows.Automation.AutomationElement]::RootElement
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, (Get-Process RobloxStudioBeta).Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
if (-not $win) { Write-Output "WINDOW NOT FOUND"; exit 1 }
$elCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $Id)
$el = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $elCond)
if (-not $el) { Write-Output ("NOT FOUND: " + $Id); exit 1 }
$r = $el.Current.BoundingRectangle
Write-Output ("rect: x=" + $r.X + " y=" + $r.Y + " w=" + $r.Width + " h=" + $r.Height)
$cx = [int]($r.X + $r.Width / 2); $cy = [int]($r.Y + $r.Height / 2)
[Mouse]::SetCursorPos($cx, $cy) | Out-Null
Start-Sleep -Milliseconds 300
[Mouse]::Click()
Write-Output ("REAL CLICK at " + $cx + "," + $cy)
