@echo off
:: Boot to Recovery and wipe all disks with diskpart clean all
:: For system disk - MUST use this method

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

color 4F
cls
echo.
echo  =====================================================
echo     BOOT RECOVERY WIPE - For System Disk
echo  =====================================================
echo.
echo  Creating wipe script...

:: Create diskpart script at root (accessible from Recovery)
(
echo @echo off
echo echo.
echo echo  ========================================
echo echo     WIPING ALL DISKS - diskpart clean all
echo echo  ========================================
echo echo.
echo for /L %%%%d in ^(0,1,9^) do ^(
echo     echo Disk %%%%d...
echo     ^(echo select disk %%%%d
echo      echo clean all^) ^| diskpart
echo ^)
echo echo.
echo echo  DONE! Press any key to shutdown...
echo pause
echo wpeutil shutdown
) > C:\WipeAll.cmd

echo  [+] Created: C:\WipeAll.cmd
echo.
echo  =====================================================
echo     REBOOTING TO RECOVERY...
echo  =====================================================
echo.
echo  When Recovery loads:
echo     1. Troubleshoot
echo     2. Command Prompt
echo     3. Type: C:\WipeAll.cmd
echo     4. Press Enter
echo.
echo  =====================================================
echo.
timeout /t 5
shutdown /r /o /t 0
