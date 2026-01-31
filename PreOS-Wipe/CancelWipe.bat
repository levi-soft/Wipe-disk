@echo off
title HUY PRE-OS WIPE
color 2F

echo.
echo  ==============================================================
echo              HUY THIET LAP PRE-OS WIPE
echo  ==============================================================
echo.

:: Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Can quyen Administrator!
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [*] Dang huy thiet lap PreOS Wipe...
echo.

:: Xóa Safe Mode boot
bcdedit /deletevalue {current} safeboot >nul 2>&1
echo [+] Da xoa cau hinh Safe Mode

:: Xóa RunOnce
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "EmergencyWipe" /f >nul 2>&1
echo [+] Da xoa RunOnce registry

:: Xóa script files
del /f /q C:\EmergencyWipe.cmd >nul 2>&1
del /f /q C:\WipeConfig.xml >nul 2>&1
echo [+] Da xoa cac file script

echo.
echo  ==============================================================
echo              HUY THANH CONG!
echo  ==============================================================
echo.
echo  May tinh se khoi dong binh thuong.
echo.

pause
