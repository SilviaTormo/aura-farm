@echo off
rem Rebuilds AuraFarmPilot.rbxl from the Luau sources in src/.
rem After editing any .lua file, double-click this, then re-open the place in Studio.
cd /d "%~dp0"
".\tools\rojo\rojo.exe" build default.project.json -o AuraFarmPilot.rbxl
pause