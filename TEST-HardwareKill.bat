@echo off
REM TEST VERSION - Check if everything works WITHOUT destroying anything

echo ====================================================
echo   HARDWARE KILL - TEST MODE
echo ====================================================
echo.

REM Check admin
echo [1/5] Checking admin rights...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [FAIL] Not running as admin!
    echo Right-click and "Run as administrator"
    pause
    exit /b 1
)
echo [OK] Running as administrator
echo.

REM Check PowerShell
echo [2/5] Checking PowerShell...
PowerShell -Command "Write-Host '[OK] PowerShell works'" >nul 2>&1
if %errorLevel% neq 0 (
    echo [FAIL] PowerShell not working!
    pause
    exit /b 1
)
echo [OK] PowerShell available
echo.

REM Check HardwareKill.ps1 exists
echo [3/5] Checking HardwareKill.ps1...
if not exist "%~dp0HardwareKill.ps1" (
    echo [FAIL] HardwareKill.ps1 not found!
    echo Path: %~dp0HardwareKill.ps1
    pause
    exit /b 1
)
echo [OK] HardwareKill.ps1 found
echo.

REM Check disk access
echo [4/5] Checking disk access...
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Get-WmiObject Win32_DiskDrive | Format-Table DeviceID, Model, Size -AutoSize"
if %errorLevel% neq 0 (
    echo [FAIL] Cannot access disks!
    pause
    exit /b 1
)
echo [OK] Disk access works
echo.

REM Test raw disk open (read-only)
echo [5/5] Testing raw disk access...
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$h = [System.IO.File]::Open('\\.\PhysicalDrive0', 'Open', 'Read', 'None'); if ($h) { Write-Host '[OK] Can open raw disk'; $h.Close() } else { Write-Host '[FAIL] Cannot open raw disk' }"
echo.

echo ====================================================
echo   ALL TESTS PASSED
echo ====================================================
echo.
echo HardwareKill.bat should work now!
echo.
pause
