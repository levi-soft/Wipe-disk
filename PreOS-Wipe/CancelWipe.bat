@echo off
title HUY EMERGENCY WIPE
color 2F

echo.
echo  ==============================================================
echo              HUY THIET LAP EMERGENCY WIPE
echo  ==============================================================
echo.

:: Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Can quyen Administrator!
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [*] Dang huy...
echo.

:: Hủy shutdown nếu đang pending
shutdown /a >nul 2>&1
echo [+] Da huy shutdown pending (neu co)

:: Xóa Scheduled Task
schtasks /delete /tn "EmergencyWipe" /f >nul 2>&1
echo [+] Da xoa Scheduled Task

:: Xóa script files
del /f /q C:\WipeOnBoot.cmd >nul 2>&1
del /f /q C:\EmergencyWipe.cmd >nul 2>&1
del /f /q C:\WipeConfig.xml >nul 2>&1
echo [+] Da xoa cac file script

:: Xóa Safe Mode config (nếu có từ version cũ)
bcdedit /deletevalue {current} safeboot >nul 2>&1

:: Xóa RunOnce (nếu có)
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "EmergencyWipe" /f >nul 2>&1

echo.
echo  ==============================================================
echo              HUY THANH CONG!
echo  ==============================================================
echo.
echo  May tinh se khoi dong binh thuong.
echo.

pause
