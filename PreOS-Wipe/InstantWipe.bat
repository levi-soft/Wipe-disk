@echo off
:: ============================================================
:: INSTANT WIPE - XÓA NGAY LẬP TỨC
:: Khởi động lại, chạy task SYSTEM trước login, xóa tất cả
:: ============================================================

title INSTANT WIPE - KHẨN CẤP
color CF

echo.
echo  ╔════════════════════════════════════════════════════════════╗
echo  ║                                                            ║
echo  ║        INSTANT WIPE - XOA KHAN CAP TAT CA O CUNG           ║
echo  ║                                                            ║
echo  ╚════════════════════════════════════════════════════════════╝
echo.

:: Check admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Can quyen Administrator!
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo  [!!!] CANH BAO CUOI CUNG:
echo.
echo  - May tinh se KHOI DONG LAI ngay lap tuc
echo  - TAT CA o cung se bi XOA SACH (ke ca Windows)
echo  - MBR/GPT bi ghi de - may KHONG THE BOOT lai
echo  - KHONG THE KHOI PHUC!
echo.
echo  ============================================================
echo.

set /p C1="[?] Nhap 'XOA' de xac nhan: "
if /i not "%C1%"=="XOA" (
    echo [*] Da huy.
    pause
    exit /b
)

set /p C2="[?] Nhap 'KHAN CAP' de xac nhan lan 2: "
if /i not "%C2%"=="KHAN CAP" (
    echo [*] Da huy.
    pause
    exit /b
)

set /p C3="[?] LAN CUOI - Nhap 'TOI DONG Y XOA TAT CA': "
if /i not "%C3%"=="TOI DONG Y XOA TAT CA" (
    echo [*] Da huy.
    pause
    exit /b
)

echo.
echo [*] Dang thiet lap Emergency Wipe...

:: Tạo script wipe chính
echo @echo off > C:\WipeOnBoot.cmd
echo :: Emergency Wipe Script - Runs at boot before login >> C:\WipeOnBoot.cmd
echo. >> C:\WipeOnBoot.cmd
echo :: Doi 10 giay de cho phep huy >> C:\WipeOnBoot.cmd
echo ping 127.0.0.1 -n 10 ^> nul >> C:\WipeOnBoot.cmd
echo. >> C:\WipeOnBoot.cmd

:: Ghi đè MBR của tất cả disk (làm máy không boot được)
echo :: Ghi de MBR/Boot sector >> C:\WipeOnBoot.cmd
echo for /L %%%%d in (0,1,9) do ( >> C:\WipeOnBoot.cmd
echo     echo select disk %%%%d ^> %%temp%%\dp%%%%d.txt >> C:\WipeOnBoot.cmd
echo     echo clean ^>^> %%temp%%\dp%%%%d.txt >> C:\WipeOnBoot.cmd
echo     diskpart /s %%temp%%\dp%%%%d.txt 2^>nul >> C:\WipeOnBoot.cmd
echo ) >> C:\WipeOnBoot.cmd
echo. >> C:\WipeOnBoot.cmd

:: Ghi đè với clean all (mất nhiều thời gian hơn nhưng an toàn)
echo :: Ghi de toan bo - KHONG KHOI PHUC >> C:\WipeOnBoot.cmd
echo for /L %%%%d in (0,1,9) do ( >> C:\WipeOnBoot.cmd
echo     echo select disk %%%%d ^> %%temp%%\wipe%%%%d.txt >> C:\WipeOnBoot.cmd
echo     echo clean all ^>^> %%temp%%\wipe%%%%d.txt >> C:\WipeOnBoot.cmd
echo     diskpart /s %%temp%%\wipe%%%%d.txt 2^>nul >> C:\WipeOnBoot.cmd
echo ) >> C:\WipeOnBoot.cmd
echo. >> C:\WipeOnBoot.cmd
echo shutdown /s /t 0 /f >> C:\WipeOnBoot.cmd

:: Tạo Scheduled Task chạy lúc BOOT với SYSTEM account (trước login)
echo [*] Tao Scheduled Task chay luc boot...
schtasks /create /tn "EmergencyWipe" /tr "cmd.exe /c C:\WipeOnBoot.cmd" /sc onstart /ru SYSTEM /rl HIGHEST /f >nul 2>&1

if %errorlevel% neq 0 (
    echo [!] Khong the tao scheduled task!
    pause
    exit /b
)

echo [+] Da thiet lap thanh cong!
echo.
echo  ============================================================
echo   MAY TINH SE KHOI DONG LAI TRONG 10 GIAY
echo   SAU KHI REBOOT, WIPE SE CHAY TU DONG TRUOC LOGIN
echo   TAT MAY NGAY NEU MUON HUY!
echo  ============================================================
echo.
echo   De huy: shutdown /a
echo.

shutdown /r /t 10 /f /c "EMERGENCY WIPE - Restarting to wipe all drives..."
pause
