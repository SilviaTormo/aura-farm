# clickid.ps1 — invokes an element by AutomationId. param -Id.
param([string]$Id = "multiLineRunButtonContainer.commandBarRunButton")
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, (Get-Process RobloxStudioBeta).Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
if (-not $win) { Write-Output "WINDOW NOT FOUND"; exit 1 }
$elCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $Id)
$el = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $elCond)
if (-not $el) { Write-Output ("NOT FOUND: " + $Id); exit 1 }
$invoke = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$invoke.Invoke()
Write-Output ("INVOKED: " + $Id)
