@echo off
:: ============================================================
:: INSTANT WIPE - XÓA NGAY LẬP TỨC
:: Khởi động lại và xóa tất cả ổ cứng
:: ============================================================

title INSTANT WIPE - KHẨN CẤP
color CF

echo.
echo  ╔════════════════════════════════════════════════════════════╗
echo  ║                                                            ║
echo  ║     ██╗███╗   ██╗███████╗████████╗ █████╗ ███╗   ██╗████████╗     ║
echo  ║     ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗████╗  ██║╚══██╔══╝     ║
echo  ║     ██║██╔██╗ ██║███████╗   ██║   ███████║██╔██╗ ██║   ██║        ║
echo  ║     ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║╚██╗██║   ██║        ║
echo  ║     ██║██║ ╚████║███████║   ██║   ██║  ██║██║ ╚████║   ██║        ║
echo  ║     ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝        ║
echo  ║                                                            ║
echo  ║              XOA KHAN CAP - TAT CA O CUNG                  ║
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
echo  - TAT CA o cung se bi XOA SACH
echo  - Bao gom ca Windows va du lieu
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
echo [*] Dang thiet lap PreOS Wipe...

:: Tạo script wipe
echo @echo off > C:\EmergencyWipe.cmd
echo color 4F >> C:\EmergencyWipe.cmd
echo title DANG XOA O CUNG... >> C:\EmergencyWipe.cmd
echo echo. >> C:\EmergencyWipe.cmd
echo echo ============================================ >> C:\EmergencyWipe.cmd
echo echo    DANG XOA TAT CA O CUNG - XIN CHO... >> C:\EmergencyWipe.cmd
echo echo ============================================ >> C:\EmergencyWipe.cmd
echo echo. >> C:\EmergencyWipe.cmd
echo echo [*] Bat dau trong 15 giay - TAT MAY DE HUY! >> C:\EmergencyWipe.cmd
echo timeout /t 15 /nobreak >> C:\EmergencyWipe.cmd
echo echo. >> C:\EmergencyWipe.cmd

:: Xóa từng disk
echo for /L %%%%i in (0,1,9) do ( >> C:\EmergencyWipe.cmd
echo     echo select disk %%%%i ^> %%temp%%\dp%%%%i.txt >> C:\EmergencyWipe.cmd
echo     echo clean all ^>^> %%temp%%\dp%%%%i.txt >> C:\EmergencyWipe.cmd
echo     diskpart /s %%temp%%\dp%%%%i.txt 2^>nul >> C:\EmergencyWipe.cmd
echo     echo [+] Disk %%%%i da duoc xu ly >> C:\EmergencyWipe.cmd
echo ) >> C:\EmergencyWipe.cmd

echo echo. >> C:\EmergencyWipe.cmd
echo echo ============================================ >> C:\EmergencyWipe.cmd
echo echo          XOA HOAN TAT! >> C:\EmergencyWipe.cmd
echo echo ============================================ >> C:\EmergencyWipe.cmd
echo shutdown /s /t 5 /f >> C:\EmergencyWipe.cmd

:: Đăng ký chạy khi boot Safe Mode
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "EmergencyWipe" /t REG_SZ /d "cmd.exe /c C:\EmergencyWipe.cmd" /f >nul

:: Thiết lập Safe Mode
bcdedit /set {current} safeboot minimal >nul

echo.
echo [!] KHOI DONG LAI TRONG 5 GIAY...
echo [!] TAT MAY NGAY NEU MUON HUY!
echo.
timeout /t 5 /nobreak

shutdown /r /t 0 /f
