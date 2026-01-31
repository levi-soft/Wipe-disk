@echo off
:: ============================================
:: AOMEI Silent Installer - Batch Wrapper
:: ============================================
:: Usage: Install-AOMEI.bat [path_to_installer] [install_directory]
:: Example: Install-AOMEI.bat "C:\Downloads\AOMEIBackupper.exe"
:: Example: Install-AOMEI.bat "C:\Downloads\AOMEIBackupper.exe" "D:\AOMEI"
:: ============================================

setlocal EnableDelayedExpansion

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script requires administrator privileges!
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

:: Check if installer path is provided
if "%~1"=="" (
    echo ============================================
    echo   AOMEI Silent Installer
    echo ============================================
    echo.
    echo Usage: %~nx0 [installer_path] [install_directory]
    echo.
    echo Examples:
    echo   %~nx0 "C:\Downloads\AOMEIBackupper.exe"
    echo   %~nx0 "C:\Downloads\AOMEIPartition.exe" "D:\AOMEI"
    echo.
    echo Or drag and drop the AOMEI installer onto this batch file.
    echo.
    pause
    exit /b 1
)

set "INSTALLER=%~1"
set "INSTALL_DIR=%~2"

:: Verify installer exists
if not exist "%INSTALLER%" (
    echo [ERROR] Installer not found: %INSTALLER%
    pause
    exit /b 1
)

echo ============================================
echo   AOMEI Silent Installer
echo ============================================
echo.
echo Installer: %INSTALLER%
if defined INSTALL_DIR echo Install Dir: %INSTALL_DIR%
echo.
echo Starting silent installation...
echo.

:: Run the installer with silent switch
:: AOMEI uses NSIS installer: /S for silent, /D= for directory
if defined INSTALL_DIR (
    "%INSTALLER%" /S /D=%INSTALL_DIR%
) else (
    "%INSTALLER%" /S
)

set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% equ 0 (
    echo [SUCCESS] Installation completed successfully!
) else (
    echo [ERROR] Installation failed with exit code: %EXIT_CODE%
)

echo.
echo ============================================
pause
exit /b %EXIT_CODE%
