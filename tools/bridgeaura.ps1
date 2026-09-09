# bridgeaura.ps1 - give the local player aura via Studio's command bar.
# Studio Play has session-only data (no API access), so pilot testing needs a
# balance bridge. Uses the real DataService API, not an exploit path.
param([int]$Amount = 25000)
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class KK {
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  public const uint UP = 2;
  public static void Tap(byte vk) {
    keybd_event(vk, 0, 0, UIntPtr.Zero);
    System.Threading.Thread.Sleep(40);
    keybd_event(vk, 0, UP, UIntPtr.Zero);
  }
}
'@
$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, (Get-Process RobloxStudioBeta).Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
if (-not $win) { Write-Output "no studio window"; exit 1 }
$edit = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
  (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, 'commandBarScriptEditor')))
if (-not $edit) { Write-Output "no command bar"; exit 1 }
$lua = 'game.ServerScriptService.AuraFarmServer.DataService.addAura(game.Players:GetPlayers()[1], ' + $Amount + ') print("[BRIDGE] aura bridged")'
$pat = $edit.GetCurrentPattern([System.Windows.Automation.ValuePattern])
$lua = $lua + "\n" # multiline bar needs a committed line or Run executes stale text
Write-Output ("pre-set value: " + $pat.Value.Value)
# Run via the command bar's own Ejecutar button (UIA Invoke - no focus or
# keystroke dependence; Enter proved unreliable from a background process).
$run = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants,
  (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, 'multiLineRunButtonContainer.commandBarRunButton')))
if (-not $run) { Write-Output "no run button"; exit 1 }
$lua2 = 'print("[BRIDGE] aura now: " .. game.ServerScriptService.AuraFarmServer.DataService.getSpendableAura(game.Players:GetPlayers()[1]))'
$lua2 = $lua2 + "\n"
$pat.SetValue($lua)
$run.GetCurrentPattern([System.Windows.Automation.InvokePattern]).Invoke()
Start-Sleep -Milliseconds 600
$pat.SetValue($lua2)
$run.GetCurrentPattern([System.Windows.Automation.InvokePattern]).Invoke()
Write-Output ("bridged: " + $Amount)
