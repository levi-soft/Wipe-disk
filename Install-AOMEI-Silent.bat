@echo off
REM ================================================================
REM AOMEI Silent Installation Script
REM ================================================================
REM Author: Claude Code
REM Date: 2026-01-31
REM Description: Script cai dat tu dong (silent) cho phan mem AOMEI
REM ================================================================

setlocal enabledelayedexpansion

:: Dat bien moi truong
set "SCRIPT_DIR=%~dp0"
set "SETUP_FILE=%SCRIPT_DIR%Setup.exe"
set "LOG_DIR=%SCRIPT_DIR%Logs"

:: Tao thu muc log neu chua ton tai
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%"
)

echo.
echo ================================================================
echo AOMEI Silent Installation Script
echo ================================================================
echo.

:: Kiem tra file Setup.exe co ton tai khong
echo [INFO] Dang kiem tra file Setup.exe...
if not exist "%SETUP_FILE%" (
    echo [ERROR] Khong tim thay file Setup.exe tai: %SETUP_FILE%
    echo [ERROR] Vui long dam bao file Setup.exe nam cung thu muc voi script nay.
    echo.
    pause
    exit /b 2
)
echo [OK] Tim thay file Setup.exe: %SETUP_FILE%
echo.

:: Bat dau cai dat
echo [INFO] Bat dau cai dat AOMEI...
echo [INFO] Vui long doi trong giay lat...
echo.

:: Chay cai dat voi cac tham so silent
:: /VERYSILENT - Cai dat hoan toan im lang, khong hien thi gi
:: /SUPPRESSMSGBOXES - Khong hien thi cac hop thoai
:: /NORESTART - Khong tu dong khoi dong lai may
:: /LOG - Tao file log chi tiet cua qua trinh cai dat

"%SETUP_FILE%" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="%LOG_DIR%\AOMEI_Setup_Detail.log"

:: Luu error level
set INSTALL_RESULT=%errorLevel%

:: Kiem tra ket qua cai dat
echo.
echo ================================================================
if %INSTALL_RESULT% equ 0 (
    echo [SUCCESS] Cai dat thanh cong!
    echo [SUCCESS] AOMEI da duoc cai dat tren he thong.
) else if %INSTALL_RESULT% equ 1 (
    echo [SUCCESS] Cai dat hoan thanh!
    echo [INFO] Exit code: 1 (Normal for AOMEI installer^)
    echo [INFO] AOMEI da duoc cai dat tren he thong.
) else (
    echo [WARNING] Cai dat ket thuc voi ma loi: %INSTALL_RESULT%
    echo [WARNING] Vui long kiem tra file log de biet them chi tiet.
)
echo ================================================================
echo.
echo [INFO] Chi tiet cai dat: %LOG_DIR%\AOMEI_Setup_Detail.log
echo.

:end
echo.
echo Nhan phim bat ky de dong cua so nay...
pause >nul
exit /b %INSTALL_RESULT%
