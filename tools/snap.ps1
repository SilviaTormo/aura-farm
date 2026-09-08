# snap.ps1 - capture one desktop frame via ffmpeg
param([string]$Out = "evidence/snap.png")
ffmpeg -y -f gdigrab -framerate 1 -i desktop -frames:v 1 $Out 2>$null
Write-Output ("snapped: " + $Out)
