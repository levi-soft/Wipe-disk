#Requires -RunAsAdministrator
<#
.SYNOPSIS
    PreOS Emergency Wipe - Xóa ổ cứng từ môi trường Pre-OS
.DESCRIPTION
    Khởi động lại máy vào Windows Recovery Environment,
    chạy từ RAM và xóa toàn bộ ổ cứng bao gồm cả ổ hệ thống.
.NOTES
    CẢNH BÁO: KHÔNG THỂ KHÔI PHỤC! Xóa tất cả ổ đĩa!
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$SetupWipe,

    [Parameter(Mandatory=$false)]
    [switch]$CancelWipe,

    [Parameter(Mandatory=$false)]
    [ValidateSet("All", "SystemOnly", "DataOnly")]
    [string]$WipeTarget = "All",

    [Parameter(Mandatory=$false)]
    [int]$Passes = 1,

    [Parameter(Mandatory=$false)]
    [int]$DelaySeconds = 30
)

$WipeConfigPath = "$env:SystemDrive\WipeConfig.xml"
$WipeScriptPath = "$env:SystemDrive\EmergencyWipe.cmd"

function Write-Banner {
    $banner = @"

 ██████╗ ██████╗ ███████╗       ██████╗ ███████╗    ██╗    ██╗██╗██████╗ ███████╗
 ██╔══██╗██╔══██╗██╔════╝      ██╔═══██╗██╔════╝    ██║    ██║██║██╔══██╗██╔════╝
 ██████╔╝██████╔╝█████╗  █████╗██║   ██║███████╗    ██║ █╗ ██║██║██████╔╝█████╗
 ██╔═══╝ ██╔══██╗██╔══╝  ╚════╝██║   ██║╚════██║    ██║███╗██║██║██╔═══╝ ██╔══╝
 ██║     ██║  ██║███████╗      ╚██████╔╝███████║    ╚███╔███╔╝██║██║     ███████╗
 ╚═╝     ╚═╝  ╚═╝╚══════╝       ╚═════╝ ╚══════╝     ╚══╝╚══╝ ╚═╝╚═╝     ╚══════╝

              KHỞI ĐỘNG LẠI - CHẠY TỪ RAM - XÓA Ổ CỨNG

"@
    Write-Host $banner -ForegroundColor Red
}

function Show-DriveList {
    Write-Host "`n[*] Danh sách ổ đĩa sẽ bị xóa:" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor DarkGray

    $disks = Get-Disk | Select-Object Number, FriendlyName, Size, PartitionStyle
    foreach ($disk in $disks) {
        $sizeGB = [math]::Round($disk.Size / 1GB, 2)
        $isSystem = (Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq 'C' }) -ne $null
        $systemTag = if ($isSystem) { " [HỆ THỐNG]" } else { "" }
        Write-Host "  Disk $($disk.Number): $($disk.FriendlyName) - ${sizeGB}GB$systemTag" -ForegroundColor $(if ($isSystem) { "Red" } else { "White" })
    }
    Write-Host "=" * 60 -ForegroundColor DarkGray
}

function New-WipeScript {
    param(
        [string]$Target,
        [int]$Passes
    )

    # Tạo script diskpart
    $diskpartScript = @"

:: ============================================
:: EMERGENCY PRE-OS WIPE SCRIPT
:: Chạy từ Windows Recovery Environment
:: ============================================

@echo off
color 4F
title EMERGENCY WIPE - ĐANG XÓA Ổ CỨNG

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║     !!! ĐANG XÓA TẤT CẢ Ổ CỨNG - KHÔNG THỂ DỪNG !!!        ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: Đợi trước khi bắt đầu
echo [*] Bắt đầu xóa sau $DelaySeconds giây...
echo [*] TẮT MÁY NGAY NẾU MUỐN HỦY!
timeout /t $DelaySeconds /nobreak

echo.
echo [*] BẮT ĐẦU XÓA...
echo.

:: Lấy danh sách tất cả disk
for /f "tokens=2 delims= " %%i in ('wmic diskdrive get index ^| findstr [0-9]') do (
    echo [*] Đang xóa Disk %%i...

    :: Tạo script diskpart tạm
    echo select disk %%i > %temp%\dp_%%i.txt
    echo clean all >> %temp%\dp_%%i.txt

    :: Chạy diskpart
    diskpart /s %temp%\dp_%%i.txt

    echo [+] Disk %%i đã được xóa!
)

:: Xóa thêm với cipher nếu có thể
echo.
echo [*] Đang ghi đè thêm...

"@

    # Thêm multiple passes nếu cần
    for ($i = 1; $i -le $Passes; $i++) {
        $diskpartScript += @"

echo [*] Pass $i/$Passes...
for /f "tokens=2 delims= " %%i in ('wmic diskdrive get index ^| findstr [0-9]') do (
    echo select disk %%i > %temp%\dp_pass$i.txt
    echo clean all >> %temp%\dp_pass$i.txt
    diskpart /s %temp%\dp_pass$i.txt 2>nul
)

"@
    }

    $diskpartScript += @"

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║              XÓA HOÀN TẤT - TẤT CẢ DỮ LIỆU ĐÃ BỊ XÓA        ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo [*] Máy tính sẽ tắt sau 10 giây...
shutdown /s /t 10 /f
pause
"@

    return $diskpartScript
}

function Set-PreOSWipe {
    param(
        [string]$Target,
        [int]$Passes
    )

    Write-Host "`n[*] Thiết lập PreOS Wipe..." -ForegroundColor Cyan

    # Tạo wipe script
    $wipeScript = New-WipeScript -Target $Target -Passes $Passes
    $wipeScript | Out-File -FilePath $WipeScriptPath -Encoding ASCII -Force

    # Tạo file config
    @{
        Target = $Target
        Passes = $Passes
        SetupTime = (Get-Date).ToString()
    } | Export-Clixml -Path $WipeConfigPath

    # Thiết lập boot vào Recovery với script
    Write-Host "[*] Đang thiết lập Windows Recovery Environment..." -ForegroundColor Yellow

    # Copy script vào thư mục Recovery
    $recoveryPath = "$env:SystemDrive\Recovery\OEM"
    if (-not (Test-Path $recoveryPath)) {
        New-Item -ItemType Directory -Path $recoveryPath -Force | Out-Null
    }
    Copy-Item $WipeScriptPath "$recoveryPath\EmergencyWipe.cmd" -Force

    # Tạo unattend cho Recovery
    $winREScript = @"
@echo off
X:\Recovery\OEM\EmergencyWipe.cmd
"@
    $winREScript | Out-File -FilePath "$recoveryPath\winre_wipe.cmd" -Encoding ASCII -Force

    # Đăng ký chạy khi boot vào Safe Mode Command Prompt
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Set-ItemProperty -Path $regPath -Name "EmergencyWipe" -Value "cmd.exe /c $WipeScriptPath" -Force

    # Thiết lập boot vào Safe Mode với Command Prompt
    Write-Host "[*] Đang cấu hình Safe Mode boot..." -ForegroundColor Yellow
    bcdedit /set "{current}" safeboot minimal | Out-Null

    Write-Host "`n" + "=" * 60 -ForegroundColor Red
    Write-Host "  CẢNH BÁO: MÁY TÍNH SẼ KHỞI ĐỘNG LẠI VÀ XÓA TẤT CẢ!" -ForegroundColor Red
    Write-Host "=" * 60 -ForegroundColor Red

    return $true
}

function Remove-PreOSWipe {
    Write-Host "`n[*] Hủy thiết lập PreOS Wipe..." -ForegroundColor Yellow

    # Xóa Safe Mode boot
    bcdedit /deletevalue "{current}" safeboot 2>$null

    # Xóa RunOnce
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "EmergencyWipe" -ErrorAction SilentlyContinue

    # Xóa script files
    Remove-Item $WipeScriptPath -Force -ErrorAction SilentlyContinue
    Remove-Item $WipeConfigPath -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemDrive\Recovery\OEM\EmergencyWipe.cmd" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SystemDrive\Recovery\OEM\winre_wipe.cmd" -Force -ErrorAction SilentlyContinue

    Write-Host "[+] Đã hủy PreOS Wipe thành công!" -ForegroundColor Green
}

function Start-PreOSWipeSetup {
    Write-Banner
    Show-DriveList

    Write-Host "`n" + "=" * 60 -ForegroundColor Red
    Write-Host @"

  !!! CẢNH BÁO CỰC KỲ QUAN TRỌNG !!!

  Khi bạn xác nhận:
  1. Máy tính sẽ KHỞI ĐỘNG LẠI ngay lập tức
  2. Vào Safe Mode và chạy script xóa
  3. TẤT CẢ ổ cứng sẽ bị XÓA SẠCH
  4. DỮ LIỆU KHÔNG THỂ KHÔI PHỤC

  Đây là thao tác KHÔNG THỂ HOÀN TÁC!

"@ -ForegroundColor Red
    Write-Host "=" * 60 -ForegroundColor Red

    # Xác nhận nhiều lần
    Write-Host "`n[?] Nhập 'XOA TAT CA' để tiếp tục: " -ForegroundColor Yellow -NoNewline
    $confirm1 = Read-Host
    if ($confirm1 -ne "XOA TAT CA") {
        Write-Host "[*] Đã hủy." -ForegroundColor Green
        return
    }

    Write-Host "[?] Nhập 'KHONG KHOI PHUC' để xác nhận lần 2: " -ForegroundColor Yellow -NoNewline
    $confirm2 = Read-Host
    if ($confirm2 -ne "KHONG KHOI PHUC") {
        Write-Host "[*] Đã hủy." -ForegroundColor Green
        return
    }

    Write-Host "[?] LẦN CUỐI - Nhập 'TOI HIEU VA DONG Y' để bắt đầu: " -ForegroundColor Red -NoNewline
    $confirm3 = Read-Host
    if ($confirm3 -ne "TOI HIEU VA DONG Y") {
        Write-Host "[*] Đã hủy." -ForegroundColor Green
        return
    }

    # Thiết lập wipe
    $success = Set-PreOSWipe -Target $WipeTarget -Passes $Passes

    if ($success) {
        Write-Host "`n[!] MÁY TÍNH SẼ KHỞI ĐỘNG LẠI TRONG 10 GIÂY!" -ForegroundColor Red
        Write-Host "[!] TẮT MÁY NGAY NẾU MUỐN HỦY!" -ForegroundColor Red
        Write-Host "`n[*] Nhấn Ctrl+C và chạy: .\PreOSWipe.ps1 -CancelWipe" -ForegroundColor Yellow

        Start-Sleep -Seconds 10

        # Khởi động lại
        Restart-Computer -Force
    }
}

# Main
if ($CancelWipe) {
    Remove-PreOSWipe
    exit
}

if ($SetupWipe) {
    Start-PreOSWipeSetup
} else {
    Write-Banner
    Write-Host "Sử dụng:" -ForegroundColor Cyan
    Write-Host "  .\PreOSWipe.ps1 -SetupWipe              # Thiết lập và khởi động lại để xóa" -ForegroundColor White
    Write-Host "  .\PreOSWipe.ps1 -SetupWipe -Passes 3    # Xóa với 3 lần ghi đè" -ForegroundColor White
    Write-Host "  .\PreOSWipe.ps1 -CancelWipe             # Hủy thiết lập (nếu chưa reboot)" -ForegroundColor White
    Write-Host ""
    Show-DriveList
}
