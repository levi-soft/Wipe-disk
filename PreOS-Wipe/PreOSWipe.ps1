#Requires -RunAsAdministrator
<#
.SYNOPSIS
    PreOS Emergency Wipe - Xóa ổ cứng khẩn cấp
.DESCRIPTION
    Tạo Scheduled Task chạy lúc BOOT (trước login) với SYSTEM privileges.
    Sử dụng DISKPART CLEAN ALL để xóa toàn bộ ổ cứng.
.NOTES
    CẢNH BÁO: KHÔNG THỂ KHÔI PHỤC! Xóa tất cả ổ đĩa!
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$SetupWipe,

    [Parameter(Mandatory=$false)]
    [switch]$CancelWipe,

    [Parameter(Mandatory=$false)]
    [switch]$ListDisks,

    [Parameter(Mandatory=$false)]
    [int]$DelaySeconds = 10
)

function Write-Banner {
    $banner = @"

 ██████╗ ██████╗ ███████╗       ██████╗ ███████╗    ██╗    ██╗██╗██████╗ ███████╗
 ██╔══██╗██╔══██╗██╔════╝      ██╔═══██╗██╔════╝    ██║    ██║██║██╔══██╗██╔════╝
 ██████╔╝██████╔╝█████╗  █████╗██║   ██║███████╗    ██║ █╗ ██║██║██████╔╝█████╗
 ██╔═══╝ ██╔══██╗██╔══╝  ╚════╝██║   ██║╚════██║    ██║███╗██║██║██╔═══╝ ██╔══╝
 ██║     ██║  ██║███████╗      ╚██████╔╝███████║    ╚███╔███╔╝██║██║     ███████╗
 ╚═╝     ╚═╝  ╚═╝╚══════╝       ╚═════╝ ╚══════╝     ╚══╝╚══╝ ╚═╝╚═╝     ╚══════╝

         SCHEDULED TASK BOOT WIPE - CHẠY TRƯỚC LOGIN

"@
    Write-Host $banner -ForegroundColor Red
}

function Show-DiskList {
    Write-Host "`n[*] Danh sách ổ đĩa sẽ bị xóa:" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor DarkGray

    Get-Disk | ForEach-Object {
        $sizeGB = [math]::Round($_.Size / 1GB, 2)
        $partitions = Get-Partition -DiskNumber $_.Number -ErrorAction SilentlyContinue
        $isSystem = ($partitions | Where-Object { $_.DriveLetter -eq 'C' }) -ne $null
        $systemTag = if ($isSystem) { " [HỆ THỐNG]" } else { "" }
        $color = if ($isSystem) { "Red" } else { "White" }
        Write-Host "  Disk $($_.Number): $($_.FriendlyName) - ${sizeGB}GB$systemTag" -ForegroundColor $color
    }
    Write-Host "=" * 60 -ForegroundColor DarkGray
}

function New-WipeScript {
    param([int]$Delay)

    $script = @"
@echo off
:: ================================================
:: EMERGENCY WIPE - Chay tu dong luc boot
:: ================================================

:: Cho $Delay giay truoc khi bat dau
ping 127.0.0.1 -n $Delay > nul

:: Xoa nhanh MBR/GPT truoc (lam mat boot)
for /L %%d in (0,1,9) do (
    echo select disk %%d > %temp%\dp%%d.txt
    echo clean >> %temp%\dp%%d.txt
    diskpart /s %temp%\dp%%d.txt 2>nul
)

:: Xoa sach voi clean all
for /L %%d in (0,1,9) do (
    echo select disk %%d > %temp%\wipe%%d.txt
    echo clean all >> %temp%\wipe%%d.txt
    diskpart /s %temp%\wipe%%d.txt 2>nul
)

:: Tat may
shutdown /s /t 0 /f
"@
    return $script
}

function Set-BootWipe {
    param([int]$Delay)

    Write-Host "`n[*] Đang thiết lập Boot Wipe..." -ForegroundColor Cyan

    # Tạo script
    $scriptPath = "C:\WipeOnBoot.cmd"
    $script = New-WipeScript -Delay $Delay
    $script | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    Write-Host "[+] Đã tạo script: $scriptPath" -ForegroundColor Green

    # Tạo Scheduled Task chạy lúc boot với SYSTEM
    $taskName = "EmergencyWipe"
    $action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c $scriptPath"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    # Xóa task cũ nếu có
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    # Tạo task mới
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Write-Host "[+] Đã tạo Scheduled Task: $taskName" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[!] Không thể tạo Scheduled Task!" -ForegroundColor Red
        return $false
    }
}

function Remove-BootWipe {
    Write-Host "`n[*] Đang hủy thiết lập..." -ForegroundColor Yellow

    # Hủy shutdown
    Start-Process -FilePath "shutdown.exe" -ArgumentList "/a" -NoNewWindow -Wait -ErrorAction SilentlyContinue

    # Xóa Scheduled Task
    Unregister-ScheduledTask -TaskName "EmergencyWipe" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "[+] Đã xóa Scheduled Task" -ForegroundColor Green

    # Xóa script
    Remove-Item "C:\WipeOnBoot.cmd" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\EmergencyWipe.cmd" -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Đã xóa script files" -ForegroundColor Green

    Write-Host "`n[*] Hủy thành công! Máy sẽ khởi động bình thường." -ForegroundColor Green
}

function Start-WipeSetup {
    Write-Banner
    Show-DiskList

    Write-Host "`n" + "=" * 60 -ForegroundColor Red
    Write-Host @"

  !!! CẢNH BÁO CỰC KỲ QUAN TRỌNG !!!

  Khi bạn xác nhận:
  1. Máy tính sẽ KHỞI ĐỘNG LẠI
  2. Scheduled Task chạy TRƯỚC KHI LOGIN
  3. DISKPART CLEAN ALL xóa TẤT CẢ ổ đĩa
  4. MBR/GPT bị ghi đè - MÁY KHÔNG THỂ BOOT
  5. DỮ LIỆU KHÔNG THỂ KHÔI PHỤC

"@ -ForegroundColor Red
    Write-Host "=" * 60 -ForegroundColor Red

    # Xác nhận
    Write-Host "`n[?] Nhập 'XOA TAT CA' để tiếp tục: " -ForegroundColor Yellow -NoNewline
    if ((Read-Host) -ne "XOA TAT CA") {
        Write-Host "[*] Đã hủy." -ForegroundColor Green
        return
    }

    Write-Host "[?] Nhập 'KHONG KHOI PHUC' để xác nhận: " -ForegroundColor Yellow -NoNewline
    if ((Read-Host) -ne "KHONG KHOI PHUC") {
        Write-Host "[*] Đã hủy." -ForegroundColor Green
        return
    }

    Write-Host "[?] LẦN CUỐI - Nhập 'TOI DONG Y': " -ForegroundColor Red -NoNewline
    if ((Read-Host) -ne "TOI DONG Y") {
        Write-Host "[*] Đã hủy." -ForegroundColor Green
        return
    }

    # Thiết lập
    $success = Set-BootWipe -Delay $DelaySeconds

    if ($success) {
        Write-Host "`n" + "=" * 60 -ForegroundColor Red
        Write-Host "  MÁY TÍNH SẼ KHỞI ĐỘNG LẠI TRONG 15 GIÂY!" -ForegroundColor Red
        Write-Host "  SAU KHI REBOOT, WIPE SẼ TỰ ĐỘNG CHẠY!" -ForegroundColor Red
        Write-Host "  " -ForegroundColor Red
        Write-Host "  Để hủy: shutdown /a  HOẶC  chạy CancelWipe.bat" -ForegroundColor Yellow
        Write-Host "=" * 60 -ForegroundColor Red

        Start-Sleep -Seconds 2
        Restart-Computer -Force
    }
}

# Main
if ($CancelWipe) {
    Write-Banner
    Remove-BootWipe
    exit
}

if ($ListDisks) {
    Write-Banner
    Show-DiskList
    exit
}

if ($SetupWipe) {
    Start-WipeSetup
} else {
    Write-Banner
    Write-Host "Sử dụng:" -ForegroundColor Cyan
    Write-Host "  .\PreOSWipe.ps1 -SetupWipe              # Thiết lập và reboot để xóa" -ForegroundColor White
    Write-Host "  .\PreOSWipe.ps1 -SetupWipe -DelaySeconds 30   # Đợi 30s trước khi xóa" -ForegroundColor White
    Write-Host "  .\PreOSWipe.ps1 -CancelWipe             # Hủy thiết lập" -ForegroundColor White
    Write-Host "  .\PreOSWipe.ps1 -ListDisks              # Xem danh sách ổ đĩa" -ForegroundColor White
    Write-Host ""
    Show-DiskList
}
