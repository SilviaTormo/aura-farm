@echo off
rem ============================================================
rem  AURA FARM - Ejecutar las pruebas offline (sin abrir Studio)
rem  Verde = el codigo esta sano. Rojo = copia el error para la IA.
rem ============================================================
setlocal
cd /d "%~dp0"
echo.
echo  [1/2] Empaquetando modulos...
node tests\bundle.js
if errorlevel 1 (
    echo   X  Node no encontrado o fallo el empaquetado.
    pause
    exit /b 1
)
echo  [2/2] Ejecutando pruebas...
".\tools\luau\luau.exe" tests\run_tests.lua
echo.
pause
