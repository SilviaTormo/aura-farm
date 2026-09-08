# key.ps1 - focus Studio (optional) and send keystrokes
param([string]$Keys = "t", [switch]$NoFocus)
$wsh = New-Object -ComObject WScript.Shell
if (-not $NoFocus) {
  for ($i = 0; $i -lt 10; $i++) {
    if ($wsh.AppActivate('AuraFarmPilot.rbxl - Roblox Studio')) { break }
    Start-Sleep -Milliseconds 400
  }
  Start-Sleep -Milliseconds 400
}
$wsh.SendKeys($Keys)
Write-Output ("sent: " + $Keys)
