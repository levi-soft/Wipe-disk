@echo off
REM Emergency Raw Disk Wipe
REM Wipes Disk 0 using PowerShell raw disk access

echo ================================================================
echo EMERGENCY RAW DISK WIPE
echo ================================================================
echo.
echo WARNING: This will DESTROY all data on Disk 0!
echo.
echo This script will attempt to wipe the disk using:
echo   1. DiskPart clean all
echo   2. Raw disk write (zeros)
echo.
echo Note: System disk may be locked by Windows
echo.

REM Check for admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Must run as Administrator!
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Running PowerShell script...
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Wipe-Raw-Disk.ps1" -DiskNumber 0 -Method zero

echo.
echo ================================================================
echo.
pause
