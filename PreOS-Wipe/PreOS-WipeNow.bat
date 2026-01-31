@echo off
title PRE-OS EMERGENCY WIPE
color 4F

echo.
echo  ==============================================================
echo        PRE-OS EMERGENCY WIPE - XOA O CUNG TU RAM
echo  ==============================================================
echo.
echo  [!!!] CANH BAO: Tool nay se:
echo        1. Khoi dong lai may tinh
echo        2. Boot vao Safe Mode
echo        3. XOA TAT CA o cung (bao gom ca Windows)
echo        4. Du lieu KHONG THE KHOI PHUC!
echo.
echo  ==============================================================
echo.

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Can quyen Administrator!
    echo [*] Dang yeu cau quyen Admin...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [*] Dang chay voi quyen Administrator...
echo.

set /p CONFIRM="[?] Nhap 'SETUP' de thiet lap PreOS Wipe, hoac 'CANCEL' de huy: "

if /i "%CONFIRM%"=="CANCEL" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PreOSWipe.ps1" -CancelWipe
    pause
    exit /b
)

if /i "%CONFIRM%"=="SETUP" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PreOSWipe.ps1" -SetupWipe
) else (
    echo [!] Lua chon khong hop le!
)

pause
