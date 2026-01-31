@echo off
:: PANIC WIPE - Boot to Recovery + diskpart clean all
:: Xoa toan bo o cung bao gom Windows

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

color 4F
cls
echo.
echo  ==========================================
echo     PANIC WIPE - CLEAN ALL DISKS
echo  ==========================================
echo.

:: Tao script wipe
echo @echo off > C:\BootWipe.cmd
echo color 4F >> C:\BootWipe.cmd
echo echo. >> C:\BootWipe.cmd
echo echo  WIPING ALL DISKS... >> C:\BootWipe.cmd
echo echo. >> C:\BootWipe.cmd
echo for /L %%%%i in (0,1,9) do ( >> C:\BootWipe.cmd
echo     echo  Disk %%%%i... >> C:\BootWipe.cmd
echo     echo select disk %%%%i ^> %%temp%%\d%%%%i.txt >> C:\BootWipe.cmd
echo     echo clean all ^>^> %%temp%%\d%%%%i.txt >> C:\BootWipe.cmd
echo     diskpart /s %%temp%%\d%%%%i.txt >> C:\BootWipe.cmd
echo ) >> C:\BootWipe.cmd
echo echo. >> C:\BootWipe.cmd
echo echo  DONE! Shutting down... >> C:\BootWipe.cmd
echo wpeutil shutdown >> C:\BootWipe.cmd

echo  [+] Script created: C:\BootWipe.cmd
echo.
echo  ==========================================
echo  Rebooting to Recovery Environment...
echo  ==========================================
echo.
echo  When Recovery loads:
echo    1. Troubleshoot
echo    2. Command Prompt
echo    3. Type: C:\BootWipe.cmd
echo.
echo  ==========================================
echo.

timeout /t 5
shutdown /r /o /t 0
