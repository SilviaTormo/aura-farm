# clickplay.ps1 — invokes the Play button in Roblox Studio via UI Automation.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, (Get-Process RobloxStudioBeta).Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
if (-not $win) { Write-Output "WINDOW NOT FOUND"; exit 1 }
Write-Output ("window: " + $win.Current.Name)
$btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Play')
$btn = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
if (-not $btn) {
  $allBtnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
  $btns = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $allBtnCond)
  $names = @(); foreach ($b in $btns) { $names += $b.Current.Name }
  Write-Output ("NO 'Play' BUTTON. buttons: " + (($names | Select-Object -First 60) -join ' | '))
  exit 1
}
Write-Output ("found: " + $btn.Current.Name + " [" + $btn.Current.ControlType.ProgrammaticName + "]")
$invoke = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$invoke.Invoke()
Write-Output "INVOKED Play"
