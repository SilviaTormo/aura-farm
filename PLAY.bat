@echo off
rem ============================================================
rem  AURA FARM - JUGAR (un solo doble clic)
rem  1. Cierra las ventanas viejas de Studio (ensenan mapas viejos)
rem  2. Reconstruye el juego desde el codigo
rem  3. Abre la version nueva en Studio
rem  Despues: pulsa PLAY (F5) dentro de Studio.
rem ============================================================
setlocal
cd /d "%~dp0"

echo.
echo  [1/3] Cerrando ventanas viejas de Studio...
taskkill /IM RobloxStudioBeta.exe /F
timeout /t 2 /nobreak

echo  [2/3] Construyendo el juego...
".\tools\rojo\rojo.exe" build default.project.json -o AuraFarmPilot.rbxl
if errorlevel 1 (
    echo.
    echo   X  LA CONSTRUCCION FALLO - manda una captura de esta ventana a la IA.
    pause
    exit /b 1
)

echo  [3/3] Abriendo Roblox Studio...
set "STUDIO="
for /f "delims=" %%v in ('dir /b /ad /o-d "%LOCALAPPDATA%\Roblox\Versions"') do (
    if not defined STUDIO if exist "%LOCALAPPDATA%\Roblox\Versions\%%v\RobloxStudioBeta.exe" set "STUDIO=%LOCALAPPDATA%\Roblox\Versions\%%v\RobloxStudioBeta.exe"
)
if not defined STUDIO (
    echo.
    echo   X  Roblox Studio no encontrado. Instalalo desde roblox.com/create
    pause
    exit /b 1
)
start "" "%STUDIO%" "%~dp0AuraFarmPilot.rbxl"

echo.
echo  ================================================
echo   LISTO. En Studio pulsa PLAY (F5).
echo   Si sale una ventana de "Roblox crashed", pulsa OMITIR.
echo   Controles: P=pose  B=tienda  T=entrenar  M=MOG
echo  ================================================
timeout /t 10
