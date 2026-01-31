@echo off
:: Boot Wipe Launcher
:: Configure system to wipe all disks on next boot

title Boot Wipe Setup
color 4F

echo.
echo  ============================================================
echo           BOOT WIPE - Wipe All Disks on Next Boot
echo  ============================================================
echo.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Requesting Administrator...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo  [1] Setup Boot Wipe (wipe on next reboot)
echo  [2] Cancel Boot Wipe
echo  [3] Exit
echo.
set /p choice="  Select option: "

if "%choice%"=="1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CreateBootWipe.ps1" -Setup
) else if "%choice%"=="2" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0CreateBootWipe.ps1" -Cancel
) else (
    exit /b
)

pause
