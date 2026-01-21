@echo off
REM Script per executar ShutdownReminder.ps1 amb privilegis d'Administrador

echo =========================================
echo  Shutdown Reminder - Iniciant...
echo =========================================
echo.

REM Comprova si s'està executant com a Administrador
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Executant amb privilegis d'Administrador
    echo.

    REM Executa el script de PowerShell
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0ShutdownReminder.ps1"

    echo.
    echo Premeu qualsevol tecla per sortir...
    pause >nul
) else (
    echo [ERROR] Aquest script requereix privilegis d'Administrador
    echo.
    echo Per executar-lo correctament:
    echo   1. Fes clic dret sobre RunAsAdmin.bat
    echo   2. Selecciona "Executar com a administrador"
    echo.
    echo Premeu qualsevol tecla per sortir...
    pause >nul
)
