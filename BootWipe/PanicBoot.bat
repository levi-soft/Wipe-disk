@echo off
:: PANIC BOOT WIPE - No confirmation, immediate reboot and wipe
:: Double-click = Setup + Reboot + Wipe All

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Tạo wipe script
if not exist C:\BootWipe mkdir C:\BootWipe

(
echo @echo off
echo color 4F
echo ping -n 5 127.0.0.1 ^> nul
echo for /L %%%%d in ^(0,1,9^) do ^(
echo     echo select disk %%%%d ^> %%temp%%\w%%%%d.txt
echo     echo clean all ^>^> %%temp%%\w%%%%d.txt
echo     diskpart /s %%temp%%\w%%%%d.txt 2^>nul
echo ^)
echo shutdown /s /t 0 /f
) > C:\BootWipe\Wipe.cmd

:: Set RunOnce
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "Wipe" /t REG_SZ /d "cmd.exe /c C:\BootWipe\Wipe.cmd" /f >nul

:: Reboot ngay
shutdown /r /t 0 /f
