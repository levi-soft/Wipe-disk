@echo off
:: ============================================================
:: PANIC WIPE - XÓA NGAY LẬP TỨC - KHÔNG HỎI
:: Double-click = Reboot + Xóa tất cả
:: ============================================================

:: Yêu cầu Admin tự động
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Tạo script wipe
echo @echo off > C:\WipeOnBoot.cmd
echo ping 127.0.0.1 -n 5 ^> nul >> C:\WipeOnBoot.cmd
echo for /L %%%%d in (0,1,9) do ( >> C:\WipeOnBoot.cmd
echo     echo select disk %%%%d ^> %%temp%%\dp%%%%d.txt >> C:\WipeOnBoot.cmd
echo     echo clean ^>^> %%temp%%\dp%%%%d.txt >> C:\WipeOnBoot.cmd
echo     diskpart /s %%temp%%\dp%%%%d.txt 2^>nul >> C:\WipeOnBoot.cmd
echo ) >> C:\WipeOnBoot.cmd
echo for /L %%%%d in (0,1,9) do ( >> C:\WipeOnBoot.cmd
echo     echo select disk %%%%d ^> %%temp%%\wipe%%%%d.txt >> C:\WipeOnBoot.cmd
echo     echo clean all ^>^> %%temp%%\wipe%%%%d.txt >> C:\WipeOnBoot.cmd
echo     diskpart /s %%temp%%\wipe%%%%d.txt 2^>nul >> C:\WipeOnBoot.cmd
echo ) >> C:\WipeOnBoot.cmd
echo shutdown /s /t 0 /f >> C:\WipeOnBoot.cmd

:: Tạo Scheduled Task
schtasks /create /tn "EmergencyWipe" /tr "cmd.exe /c C:\WipeOnBoot.cmd" /sc onstart /ru SYSTEM /rl HIGHEST /f >nul 2>&1

:: Reboot ngay lập tức
shutdown /r /t 0 /f
