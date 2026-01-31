@echo off
REM ================================================================
REM DISK WIPE SCRIPT - DISK 0
REM ================================================================
REM WARNING: THIS WILL COMPLETELY ERASE DISK 0!
REM DISK 0 IS USUALLY YOUR SYSTEM DISK - THIS WILL DESTROY WINDOWS!
REM ================================================================

setlocal enabledelayedexpansion

:: Set paths
set "AOMEI_PATH=C:\Program Files (x86)\AOMEI Partition Assistant"
set "AOMEI_EXE=%AOMEI_PATH%\PartAssist.exe"
set "LOG_DIR=%~dp0Logs"
set "LOG_FILE=%LOG_DIR%\Wipe_Disk0_%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
set "LOG_FILE=%LOG_FILE: =0%"

:: Create log directory
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Display warning
cls
echo.
echo ================================================================
echo                   ⚠️  CRITICAL WARNING  ⚠️
echo ================================================================
echo.
echo   THIS SCRIPT WILL COMPLETELY WIPE DISK 0!
echo.
echo   DISK 0 IS TYPICALLY YOUR SYSTEM DISK (C:)
echo   WIPING IT WILL:
echo   - DESTROY ALL DATA ON DISK 0
echo   - DELETE WINDOWS OPERATING SYSTEM
echo   - MAKE YOUR COMPUTER UNBOOTABLE
echo   - THIS CANNOT BE UNDONE!
echo.
echo ================================================================
echo.

:: List all disks first
echo [INFO] Listing all disks on this system...
echo [INFO] Listing all disks... >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

if exist "%AOMEI_EXE%" (
    "%AOMEI_EXE%" /list
    "%AOMEI_EXE%" /list >> "%LOG_FILE%" 2>&1
) else (
    echo [ERROR] AOMEI Partition Assistant not found!
    echo [ERROR] Please install AOMEI first using Install-AOMEI-Silent.bat
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================================
echo   PLEASE VERIFY THAT DISK 0 IS THE CORRECT DISK TO WIPE!
echo ================================================================
echo.
echo   If you are ABSOLUTELY CERTAIN you want to wipe Disk 0,
echo   type exactly: WIPE DISK 0
echo   (case sensitive)
echo.

set /p CONFIRM="Enter confirmation: "

if not "%CONFIRM%"=="WIPE DISK 0" (
    echo.
    echo [CANCELLED] Wipe operation cancelled.
    echo [CANCELLED] User did not confirm. >> "%LOG_FILE%"
    echo.
    pause
    exit /b 0
)

:: Second confirmation
echo.
echo ================================================================
echo   FINAL WARNING - LAST CHANCE TO CANCEL!
echo ================================================================
echo.
echo   Press Ctrl+C to CANCEL now, or
pause

:: Log start
echo. >> "%LOG_FILE%"
echo ================================================================ >> "%LOG_FILE%"
echo WIPE OPERATION STARTED >> "%LOG_FILE%"
echo ================================================================ >> "%LOG_FILE%"
echo Start Time: %date% %time% >> "%LOG_FILE%"
echo Target: Disk 0 >> "%LOG_FILE%"
echo Method: Zero Fill (1 pass) >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

:: Execute wipe
echo.
echo [INFO] Starting wipe operation on Disk 0...
echo [INFO] Method: Zero Fill (1 pass)
echo [INFO] This may take a long time depending on disk size...
echo.

"%AOMEI_EXE%" /hd:0 /wipedisk /method:1 /out:"%LOG_DIR%\AOMEI_Wipe_Detail.log"

set WIPE_RESULT=%errorLevel%

:: Log result
echo. >> "%LOG_FILE%"
echo Wipe completed with exit code: %WIPE_RESULT% >> "%LOG_FILE%"
echo End Time: %date% %time% >> "%LOG_FILE%"
echo ================================================================ >> "%LOG_FILE%"

:: Display result
echo.
echo ================================================================
if %WIPE_RESULT% equ 0 (
    echo [SUCCESS] Disk 0 wipe completed successfully!
    echo [SUCCESS] All data on Disk 0 has been erased.
    echo.
    echo [INFO] If this was your system disk, the computer will not boot.
) else (
    echo [ERROR] Wipe operation failed with error code: %WIPE_RESULT%
    echo [ERROR] Please check the log files for details.
)
echo ================================================================
echo.
echo [INFO] Log files:
echo   - %LOG_FILE%
echo   - %LOG_DIR%\AOMEI_Wipe_Detail.log
echo.

pause
exit /b %WIPE_RESULT%
