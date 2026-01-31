@echo off
REM HARDWARE KILL - PERMANENT HARDWARE DESTRUCTION

cls
echo.
echo ====================================================
echo   WARNING - HARDWARE DESTRUCTION
echo ====================================================
echo.
echo This script will PERMANENTLY DAMAGE your hard drives!
echo.
echo Methods used:
echo   - Boot sector destruction
echo   - Firmware zone corruption
echo   - Head thrashing (HDD - mechanical damage)
echo   - Random overwrites (wear out NAND/platters)
echo   - Critical zone destruction
echo.
echo RISKS:
echo   - Drive will be UNUSABLE FOREVER
echo   - Potential FIRE HAZARD
echo   - May damage motherboard
echo.
echo ====================================================
echo.

set /p confirm="Type DESTROY to continue: "

if /i NOT "%confirm%"=="DESTROY" (
    echo.
    echo Cancelled.
    timeout /t 3
    exit /b 0
)

echo.
echo ====================================================
echo   STARTING HARDWARE DESTRUCTION IN 5 SECONDS
echo   Press Ctrl+C to ABORT!
echo ====================================================
echo.

timeout /t 5

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HardwareKill.ps1"
