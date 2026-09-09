# closedocks2.ps1 - close west dock panes by UIA-invoking every Cerrar
# button (the only two belong to the Terrain/Toolbox dock panes). Immune
# to the focus/DPI issues that defeat synthetic clicks.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$proc = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { Write-Output "no studio"; exit 1 }
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
if (-not $win) { Write-Output "no window"; exit 1 }

$nameCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Cerrar')
$buttons = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $nameCond)
$n = 0
foreach ($b in $buttons) {
  try {
    ($b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke()
    $n++
  } catch { }
}
Write-Output "invoked $n Cerrar button(s)"