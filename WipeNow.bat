@echo off
title EMERGENCY DRIVE WIPE TOOL
color 4F

echo.
echo  ======================================================
echo           EMERGENCY DRIVE WIPE TOOL
echo        XOA O CUNG KHAN CAP - KHONG KHOI PHUC
echo  ======================================================
echo.

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Can quyen Administrator de chay tool nay!
    echo [*] Dang yeu cau quyen Admin...
    echo.

    :: Request admin privileges
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [*] Dang chay voi quyen Administrator...
echo.

:: Run the PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0EmergencyWipe.ps1" %*

echo.
echo [*] Nhan phim bat ky de thoat...
pause >nul
