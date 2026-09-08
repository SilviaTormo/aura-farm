# clickplay-dpi.ps1 — set this process DPI-aware, then REAL-click the
# Studio Play button. At 150% scaling the UIA rects are physical pixels;
# a DPI-unaware process virtualizes mouse_event coords and the click
# lands off-screen (learned the hard way 2026-09-09).
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DpiHelper {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
[DpiHelper]::SetProcessDPIAware() | Out-Null
& "$PSScriptRoot/realclick.ps1" -Id "multiLineRunButtonContainer.commandBarRunButton"
