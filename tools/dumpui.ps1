Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, (Get-Process RobloxStudioBeta).Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
$all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
$i = 0
foreach ($e in $all) {
  $c = $e.Current
  if ($c.Name -ne '' -or $c.ControlType.ProgrammaticName -match 'Button|ToggleButton|SplitButton') {
    Write-Output ($c.ControlType.ProgrammaticName + " | name='" + $c.Name + "' | id='" + $c.AutomationId + "' | class='" + $c.ClassName + "'")
    $i++
    if ($i -gt 120) { break }
  }
}
