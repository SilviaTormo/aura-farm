# uitree.ps1 - dump Studio's UIA tree (control type + name + id + rect) to
# find the docked web pane that swallows synthetic input.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
foreach ($proc in (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue)) {
  $pidCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)
  $win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $pidCond)
  if (-not $win) { continue }
  $all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
  foreach ($el in $all) {
    $r = $el.Current.BoundingRectangle
    if ($r.IsEmpty) { continue }
    "{0} | {1} | {2} | x={3} y={4} w={5} h={6}" -f $el.Current.ControlType.ProgrammaticName, $el.Current.Name, $el.Current.AutomationId, [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height
  }
}