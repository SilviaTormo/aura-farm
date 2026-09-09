# invokerun.ps1 - UIA-invoke Studio's command-bar Run/Play button directly
# (InvokePattern ignores z-order, focus, and DPI entirely).
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$proc = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { Write-Output "no studio"; exit 1 }
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
if (-not $win) { Write-Output "no window"; exit 1 }
$idCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, 'multiLineRunButtonContainer.commandBarRunButton')
$btn = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $idCond)
if (-not $btn) { Write-Output "run button not found"; exit 1 }
($btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
Write-Output "invoked commandBarRunButton"