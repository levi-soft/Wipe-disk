@echo off
:: ============================================
:: AOMEI Silent Installer
:: Chay setup.exe trong cung thu muc
:: ============================================

setlocal

:: Get script directory
set "SCRIPT_DIR=%~dp0"
set "INSTALLER=%SCRIPT_DIR%setup.exe"

echo ============================================
echo   AOMEI Silent Installer
echo ============================================
echo.

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [LOI] Can quyen Administrator!
    echo Hay click chuot phai va chon "Run as administrator"
    echo.
    pause
    exit /b 1
)

:: Check if setup.exe exists
if not exist "%INSTALLER%" (
    echo [LOI] Khong tim thay file: %INSTALLER%
    echo Hay dat file setup.exe cung thu muc voi script nay.
    echo.
    pause
    exit /b 1
)

echo Installer: %INSTALLER%
echo.
echo Dang cai dat...
echo.

:: Run silent installation
"%INSTALLER%" /S

set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% equ 0 (
    echo [THANH CONG] Cai dat hoan tat!
) else (
    echo [LOI] Cai dat that bai. Ma loi: %EXIT_CODE%
)

echo.
echo ============================================
pause
exit /b %EXIT_CODE%
