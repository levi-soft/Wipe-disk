@echo off
title QUICK EMERGENCY WIPE
color CF

echo.
echo  =====================================================
echo         QUICK EMERGENCY WIPE - XOA NHANH KHAN CAP
echo  =====================================================
echo.
echo  [!!!] CANH BAO: Tool nay se XOA TAT CA du lieu!
echo.

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Can quyen Administrator!
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

set /p DRIVE="[?] Nhap ky tu o dia can xoa (vi du: D): "

if "%DRIVE%"=="" (
    echo [!] Vui long nhap o dia!
    pause
    exit /b
)

echo.
echo  [!!!] BAN SAP XOA VINH VIEN O DIA %DRIVE%:
echo.
set /p CONFIRM="[?] Nhap 'XOA' de xac nhan: "

if /i not "%CONFIRM%"=="XOA" (
    echo [*] Da huy.
    pause
    exit /b
)

echo.
echo [*] Dang xoa o dia %DRIVE%:...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0EmergencyWipe.ps1" -DriveLetter %DRIVE% -Method Quick -Force

echo.
pause
