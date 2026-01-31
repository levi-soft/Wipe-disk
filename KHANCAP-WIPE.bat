@echo off
REM KHAN CAP - EMERGENCY WIPE (NO CONFIRMATION)
REM Auto-wipes Disk 0 immediately without asking

echo ================================================================
echo KHANCAP WIPE - STARTING IN 3 SECONDS
echo ================================================================
echo.
echo Target: Disk 0
echo Method: Zero fill
echo.
echo Press Ctrl+C to CANCEL!
echo.

timeout /t 3 /nobreak

echo.
echo STARTING WIPE...
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0Wipe-Raw-Disk.ps1' -DiskNumber 0 -Method zero -Force"

echo.
echo ================================================================
echo WIPE COMPLETED
echo ================================================================
echo.

timeout /t 5
