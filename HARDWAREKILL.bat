@echo off
REM SECURE WIPE - Zero-fill disk to prevent data recovery

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
echo   SECURE WIPE - 2 PASS (RANDOM + ZERO)
echo ====================================================
echo.
echo [RUNNING AS ADMINISTRATOR - OK]
echo.
echo This script will ZERO-FILL all disks!
echo.
echo What it does:
echo   - Pass 1: Write RANDOM data (destroy original data)
echo   - Pass 2: Write ZERO (clean, prevent recovery)
echo   - Safe for hardware (no damage)
echo   - Professional recovery tools CANNOT recover
echo.
echo WARNING:
echo   - ALL DATA WILL BE PERMANENTLY ERASED
echo   - System will shut down after completion
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
echo   STARTING SECURE WIPE IN 5 SECONDS
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
