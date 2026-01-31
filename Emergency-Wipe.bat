@echo off
REM ================================================================
REM EMERGENCY DISK WIPE - LEVEL 2 (SECURE)
REM ================================================================
REM WARNING: THIS WILL WIPE ALL DISKS IMMEDIATELY!
REM Method: DiskPart Clean All (Zero Fill - 1 Pass)
REM Time: Hours (depends on disk size)
REM Security: Secure - cannot be recovered by software
REM ================================================================

cls
color 0C
echo.
echo ================================================================
echo              !!! EMERGENCY DISK WIPE !!!
echo ================================================================
echo.
echo   THIS WILL WIPE ALL DISKS ON THIS COMPUTER!
echo.
echo   Method: DiskPart Clean All (Zero Fill)
echo   Security: SECURE - Cannot be recovered by normal software
echo   Time: Will take HOURS for large disks
echo.
echo   ALL DATA WILL BE PERMANENTLY DESTROYED!
echo   THIS CANNOT BE UNDONE!
echo.
echo ================================================================
echo.

:: List all disks
echo Current disks on this system:
echo.
(echo list disk) | diskpart
echo.
echo ================================================================

:: Final confirmation
echo.
echo ARE YOU ABSOLUTELY SURE?
echo This will DESTROY ALL DATA on ALL DISKS!
echo.

choice /C YN /N /M "Press Y to WIPE ALL DISKS NOW, N to Cancel: "

if errorlevel 2 (
    echo.
    echo [CANCELLED] Emergency wipe cancelled.
    timeout /t 3
    exit /b 0
)

:: Start wipe
cls
color 0E
echo.
echo ================================================================
echo   EMERGENCY WIPE IN PROGRESS
echo ================================================================
echo.
echo   DO NOT TURN OFF THE COMPUTER!
echo   This will take several hours...
echo.
echo ================================================================
echo.

:: Get number of disks
for /f "tokens=2" %%a in ('(echo list disk^) ^| diskpart ^| find "Disk "') do (
    set DISK_COUNT=%%a
)

:: Wipe each disk
set DISK_NUM=0

:WIPE_LOOP
echo [INFO] Wiping Disk %DISK_NUM%...
echo.

:: Create diskpart script
(
    echo select disk %DISK_NUM%
    echo clean all
    echo exit
) > "%TEMP%\emergency_wipe_%DISK_NUM%.txt"

:: Execute wipe
diskpart /s "%TEMP%\emergency_wipe_%DISK_NUM%.txt"

:: Clean up temp script
del "%TEMP%\emergency_wipe_%DISK_NUM%.txt" >nul 2>&1

echo.
echo [DONE] Disk %DISK_NUM% wiped.
echo.

:: Next disk
set /a DISK_NUM+=1

:: Check if we've wiped all disks (simple check - wipe up to disk 9)
if %DISK_NUM% LSS 10 (
    :: Check if next disk exists
    (echo select disk %DISK_NUM%) | diskpart 2>nul | find "selected" >nul
    if not errorlevel 1 goto WIPE_LOOP
)

:: All disks wiped
cls
color 0A
echo.
echo ================================================================
echo   EMERGENCY WIPE COMPLETED
echo ================================================================
echo.
echo   All disks have been wiped.
echo   All data has been permanently destroyed.
echo.
echo   The computer will shutdown in 10 seconds...
echo.
echo ================================================================
echo.

timeout /t 10
shutdown /s /t 0 /f

exit /b 0
