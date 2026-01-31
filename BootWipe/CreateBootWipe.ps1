#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Create PreOS Boot Wipe Environment
.DESCRIPTION
    Creates a bootable WinPE-style environment for emergency disk wipe.
    Modifies BCD to boot into wipe mode on next restart.
.NOTES
    Similar to how AOMEI/MiniTool handles PreOS operations.
#>

param(
    [switch]$Setup,
    [switch]$Cancel,
    [switch]$CreateUSB,
    [string]$USBDrive
)

$BootWipePath = "$env:SystemDrive\BootWipe"
$WipeScriptName = "WipeAll.cmd"

function Write-Banner {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║              BOOT WIPE - PreOS Environment                ║" -ForegroundColor Red
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

function New-WipeScript {
    # Script chạy trong Windows RE / PreOS
    $script = @'
@echo off
title EMERGENCY DISK WIPE
color 4F
cls

echo.
echo  ============================================================
echo            EMERGENCY DISK WIPE - PreOS Mode
echo  ============================================================
echo.
echo  [!] Starting wipe in 10 seconds...
echo  [!] POWER OFF NOW to cancel!
echo.

:: Countdown
for /L %%i in (10,-1,1) do (
    echo  %%i...
    ping -n 2 127.0.0.1 > nul
)

echo.
echo  [*] Wiping all disks...
echo.

:: Wipe tất cả disk với diskpart
for /L %%d in (0,1,9) do (
    echo  [*] Processing Disk %%d...

    (
        echo select disk %%d
        echo clean all
    ) > %temp%\wipe%%d.txt

    diskpart /s %temp%\wipe%%d.txt 2>nul

    if not errorlevel 1 (
        echo  [+] Disk %%d wiped successfully
    )
)

echo.
echo  ============================================================
echo            WIPE COMPLETE - ALL DATA DESTROYED
echo  ============================================================
echo.
echo  Shutting down in 5 seconds...
ping -n 6 127.0.0.1 > nul
shutdown /s /t 0 /f
'@
    return $script
}

function Install-BootWipe {
    Write-Host "  [*] Creating BootWipe environment..." -ForegroundColor Cyan

    # Tạo thư mục
    if (-not (Test-Path $BootWipePath)) {
        New-Item -ItemType Directory -Path $BootWipePath -Force | Out-Null
    }

    # Tạo wipe script
    $wipeScript = New-WipeScript
    $scriptPath = Join-Path $BootWipePath $WipeScriptName
    $wipeScript | Out-File -FilePath $scriptPath -Encoding ASCII -Force
    Write-Host "  [+] Created wipe script" -ForegroundColor Green

    # Lấy thông tin về Windows RE
    $reagentInfo = reagentc /info 2>&1
    $winREEnabled = $reagentInfo -match "Enabled"

    if ($winREEnabled) {
        Write-Host "  [*] Windows RE detected, configuring boot..." -ForegroundColor Cyan

        # Tạo custom boot entry sử dụng Windows RE
        # Copy script vào Recovery partition
        $recoveryPath = (Get-Partition | Where-Object { $_.Type -eq "Recovery" } | Select-Object -First 1).AccessPaths[0]

        if ($recoveryPath) {
            $destPath = Join-Path $recoveryPath "BootWipe"
            New-Item -ItemType Directory -Path $destPath -Force -ErrorAction SilentlyContinue | Out-Null
            Copy-Item $scriptPath $destPath -Force -ErrorAction SilentlyContinue
        }
    }

    # Phương pháp chính: Sử dụng bcdedit để tạo boot entry
    Write-Host "  [*] Creating boot entry..." -ForegroundColor Cyan

    # Backup current BCD
    bcdedit /export "$BootWipePath\bcd_backup" | Out-Null
    Write-Host "  [+] BCD backed up" -ForegroundColor Green

    # Tạo boot entry mới copy từ current
    $newGuid = (bcdedit /copy "{current}" /d "Emergency Disk Wipe" 2>&1) -replace '.*(\{.*\}).*', '$1'

    if ($newGuid -match '\{.*\}') {
        # Cấu hình boot entry để chạy wipe script
        # Sử dụng winload với custom init
        bcdedit /set $newGuid description "EMERGENCY DISK WIPE - ALL DATA WILL BE DESTROYED" | Out-Null
        bcdedit /set $newGuid recoveryenabled No | Out-Null

        # Set làm default boot cho lần boot tiếp theo
        bcdedit /bootsequence $newGuid /addfirst | Out-Null

        # Lưu GUID để có thể cancel
        $newGuid | Out-File -FilePath "$BootWipePath\boot_guid.txt" -Force

        Write-Host "  [+] Boot entry created: $newGuid" -ForegroundColor Green

        # Tạo RunOnce để chạy wipe script sau khi boot
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        Set-ItemProperty -Path $regPath -Name "BootWipe" -Value "cmd.exe /c $scriptPath" -Force

        Write-Host ""
        Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "  ║                      READY TO WIPE                        ║" -ForegroundColor Red
        Write-Host "  ╠═══════════════════════════════════════════════════════════╣" -ForegroundColor Red
        Write-Host "  ║  Next boot will run emergency wipe!                       ║" -ForegroundColor Red
        Write-Host "  ║  ALL DISKS will be PERMANENTLY ERASED!                    ║" -ForegroundColor Red
        Write-Host "  ║                                                           ║" -ForegroundColor Red
        Write-Host "  ║  To cancel: Run this script with -Cancel                  ║" -ForegroundColor Red
        Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""

        return $true
    }
    else {
        Write-Host "  [!] Failed to create boot entry" -ForegroundColor Red
        return $false
    }
}

function Remove-BootWipe {
    Write-Host "  [*] Removing BootWipe configuration..." -ForegroundColor Yellow

    # Đọc GUID đã lưu
    $guidFile = "$BootWipePath\boot_guid.txt"
    if (Test-Path $guidFile) {
        $guid = Get-Content $guidFile -Raw
        $guid = $guid.Trim()

        if ($guid -match '\{.*\}') {
            # Xóa boot entry
            bcdedit /delete $guid /f 2>&1 | Out-Null
            Write-Host "  [+] Boot entry removed" -ForegroundColor Green
        }
    }

    # Xóa bootsequence
    bcdedit /bootsequence "{bootmgr}" /remove 2>&1 | Out-Null

    # Xóa RunOnce
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "BootWipe" -ErrorAction SilentlyContinue

    # Restore BCD nếu có backup
    if (Test-Path "$BootWipePath\bcd_backup") {
        # bcdedit /import "$BootWipePath\bcd_backup" | Out-Null
        Write-Host "  [+] BCD backup available at $BootWipePath\bcd_backup" -ForegroundColor Gray
    }

    # Xóa thư mục
    Remove-Item -Path $BootWipePath -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "  [+] BootWipe removed successfully" -ForegroundColor Green
    Write-Host "  [*] System will boot normally" -ForegroundColor Cyan
}

function New-BootableUSB {
    param([string]$DriveLetter)

    Write-Host "  [*] Creating bootable USB wipe tool..." -ForegroundColor Cyan

    $DriveLetter = $DriveLetter.TrimEnd(':').TrimEnd('\')
    $usbPath = "${DriveLetter}:"

    if (-not (Test-Path $usbPath)) {
        Write-Host "  [!] Drive $usbPath not found!" -ForegroundColor Red
        return
    }

    # Tạo cấu trúc thư mục
    $bootPath = Join-Path $usbPath "Boot"
    New-Item -ItemType Directory -Path $bootPath -Force | Out-Null

    # Copy boot files từ Windows
    $winPath = $env:SystemRoot
    Copy-Item "$winPath\Boot\DVD\PCAT\boot.sdi" $bootPath -Force -ErrorAction SilentlyContinue

    # Tạo wipe script
    $wipeScript = New-WipeScript
    $wipeScript | Out-File -FilePath "$usbPath\WipeAll.cmd" -Encoding ASCII -Force

    # Tạo autorun
    @"
[autorun]
open=WipeAll.cmd
label=Emergency Disk Wipe
"@ | Out-File -FilePath "$usbPath\autorun.inf" -Encoding ASCII -Force

    Write-Host "  [+] USB prepared at $usbPath" -ForegroundColor Green
    Write-Host "  [*] Boot from this USB and run WipeAll.cmd" -ForegroundColor Cyan
}

# Main
Write-Banner

if ($Cancel) {
    Remove-BootWipe
    exit
}

if ($CreateUSB) {
    if ([string]::IsNullOrEmpty($USBDrive)) {
        Write-Host "  [!] Please specify USB drive: -USBDrive E" -ForegroundColor Red
        exit
    }
    New-BootableUSB -DriveLetter $USBDrive
    exit
}

if ($Setup) {
    Write-Host "  [!] WARNING: This will configure system to WIPE ALL DISKS on next boot!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Type 'WIPE ALL' to confirm: " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host

    if ($confirm -eq "WIPE ALL") {
        $success = Install-BootWipe

        if ($success) {
            Write-Host ""
            Write-Host "  Reboot now? (Y/N): " -ForegroundColor Yellow -NoNewline
            $reboot = Read-Host
            if ($reboot -eq "Y" -or $reboot -eq "y") {
                Write-Host "  [*] Rebooting in 5 seconds..." -ForegroundColor Red
                Start-Sleep -Seconds 5
                Restart-Computer -Force
            }
        }
    }
    else {
        Write-Host "  [*] Cancelled." -ForegroundColor Green
    }
    exit
}

# Show help
Write-Host "  Usage:" -ForegroundColor Cyan
Write-Host "    .\CreateBootWipe.ps1 -Setup        # Configure boot wipe" -ForegroundColor White
Write-Host "    .\CreateBootWipe.ps1 -Cancel       # Remove boot wipe config" -ForegroundColor White
Write-Host "    .\CreateBootWipe.ps1 -CreateUSB -USBDrive E  # Create USB tool" -ForegroundColor White
Write-Host ""
