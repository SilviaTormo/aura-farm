# dismissdialogs.ps1 - close Studio's startup modals that silently eat all
# keystrokes (Auto-recovery + crash-restore "Continuar"). Run before Play.
# Learned 2026-09-09: two stacked dialogs blocked every automated F5.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, (Get-Process RobloxStudioBeta).Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
if (-not $win) { Write-Output "no studio window"; exit 0 }
foreach ($id in @('RibbonMainWindow.AutoSave.ignoreButton')) {
  $btnCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, $id)
  $btn = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
  if ($btn) { ($btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke(); Write-Output "dismissed: $id" }
}
$btnCond2 = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Continuar')
$btn2 = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $btnCond2)
if ($btn2) { ($btn2.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke(); Write-Output "dismissed: Continuar" }
Write-Output "dialogs cleared"
