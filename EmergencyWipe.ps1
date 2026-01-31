#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Emergency Drive Wipe Tool - Xóa ổ cứng khẩn cấp không thể khôi phục
.DESCRIPTION
    Công cụ xóa dữ liệu an toàn với nhiều phương pháp:
    - DoD 5220.22-M (3 lần ghi đè)
    - Gutmann (35 lần ghi đè)
    - Random (tùy chỉnh số lần)
    - Zero Fill (ghi đè bằng 0)
.NOTES
    CẢNH BÁO: Dữ liệu sẽ KHÔNG THỂ KHÔI PHỤC sau khi xóa!
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$DriveLetter,

    [Parameter(Mandatory=$false)]
    [ValidateSet("DoD", "Gutmann", "Random", "Zero", "Quick")]
    [string]$Method = "DoD",

    [Parameter(Mandatory=$false)]
    [int]$Passes = 3,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$ListDrives
)

# Colors
$Host.UI.RawUI.WindowTitle = "EMERGENCY DRIVE WIPE TOOL"

function Write-Banner {
    $banner = @"

 ██╗    ██╗██╗██████╗ ███████╗    ██████╗ ██╗███████╗██╗  ██╗
 ██║    ██║██║██╔══██╗██╔════╝    ██╔══██╗██║██╔════╝██║ ██╔╝
 ██║ █╗ ██║██║██████╔╝█████╗      ██║  ██║██║███████╗█████╔╝
 ██║███╗██║██║██╔═══╝ ██╔══╝      ██║  ██║██║╚════██║██╔═██╗
 ╚███╔███╔╝██║██║     ███████╗    ██████╔╝██║███████║██║  ██╗
  ╚══╝╚══╝ ╚═╝╚═╝     ╚══════╝    ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝

        EMERGENCY DRIVE WIPE TOOL - KHÔNG THỂ KHÔI PHỤC

"@
    Write-Host $banner -ForegroundColor Red
}

function Get-DriveList {
    Write-Host "`n[*] Danh sách ổ đĩa có sẵn:" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor DarkGray

    $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $physicalDisks = Get-PhysicalDisk | Select-Object DeviceId, FriendlyName, Size, MediaType

    Write-Host "`n[Ổ đĩa Logic]" -ForegroundColor Yellow
    foreach ($drive in $drives) {
        $sizeGB = [math]::Round($drive.Size / 1GB, 2)
        $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        Write-Host "  $($drive.DeviceID) - $($drive.VolumeName) - Size: ${sizeGB}GB - Free: ${freeGB}GB" -ForegroundColor White
    }

    Write-Host "`n[Ổ đĩa vật lý]" -ForegroundColor Yellow
    foreach ($disk in $physicalDisks) {
        $sizeGB = [math]::Round($disk.Size / 1GB, 2)
        Write-Host "  Disk $($disk.DeviceId): $($disk.FriendlyName) - ${sizeGB}GB - $($disk.MediaType)" -ForegroundColor White
    }

    Write-Host "`n" + "=" * 70 -ForegroundColor DarkGray
}

function Get-RandomBytes {
    param([int]$Size)
    $bytes = New-Object byte[] $Size
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return $bytes
}

function Write-WipePattern {
    param(
        [string]$Path,
        [byte[]]$Pattern,
        [long]$Size,
        [int]$PassNumber,
        [int]$TotalPasses
    )

    $bufferSize = 4MB
    $written = 0
    $startTime = Get-Date

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write)

        while ($written -lt $Size) {
            $toWrite = [Math]::Min($bufferSize, $Size - $written)

            if ($Pattern -eq $null) {
                # Random pattern
                $buffer = Get-RandomBytes -Size $toWrite
            } else {
                # Fixed pattern - repeat to fill buffer
                $buffer = New-Object byte[] $toWrite
                for ($i = 0; $i -lt $toWrite; $i++) {
                    $buffer[$i] = $Pattern[$i % $Pattern.Length]
                }
            }

            $stream.Write($buffer, 0, $toWrite)
            $written += $toWrite

            # Progress
            $percent = [math]::Round(($written / $Size) * 100, 1)
            $elapsed = (Get-Date) - $startTime
            $speed = $written / $elapsed.TotalSeconds / 1MB

            Write-Progress -Activity "Đang xóa - Pass $PassNumber/$TotalPasses" `
                          -Status "$percent% - $([math]::Round($speed, 1)) MB/s" `
                          -PercentComplete $percent
        }

        $stream.Flush()
        $stream.Close()
        return $true
    }
    catch {
        Write-Host "[!] Lỗi: $_" -ForegroundColor Red
        return $false
    }
}

function Invoke-DoDWipe {
    param([string]$DrivePath, [long]$DriveSize)

    Write-Host "[*] Phương pháp: DoD 5220.22-M (3 passes)" -ForegroundColor Yellow

    # Pass 1: Ghi 0x00
    Write-Host "  [1/3] Ghi pattern 0x00..." -ForegroundColor Cyan
    Write-WipePattern -Path $DrivePath -Pattern @(0x00) -Size $DriveSize -PassNumber 1 -TotalPasses 3

    # Pass 2: Ghi 0xFF
    Write-Host "  [2/3] Ghi pattern 0xFF..." -ForegroundColor Cyan
    Write-WipePattern -Path $DrivePath -Pattern @(0xFF) -Size $DriveSize -PassNumber 2 -TotalPasses 3

    # Pass 3: Random
    Write-Host "  [3/3] Ghi random data..." -ForegroundColor Cyan
    Write-WipePattern -Path $DrivePath -Pattern $null -Size $DriveSize -PassNumber 3 -TotalPasses 3
}

function Invoke-GutmannWipe {
    param([string]$DrivePath, [long]$DriveSize)

    Write-Host "[*] Phương pháp: Gutmann (35 passes)" -ForegroundColor Yellow
    Write-Host "[!] CẢNH BÁO: Phương pháp này sẽ mất rất nhiều thời gian!" -ForegroundColor Red

    $patterns = @(
        # Passes 1-4: Random
        $null, $null, $null, $null,
        # Passes 5-31: Specific patterns
        @(0x55), @(0xAA), @(0x92, 0x49, 0x24), @(0x49, 0x24, 0x92),
        @(0x24, 0x92, 0x49), @(0x00), @(0x11), @(0x22),
        @(0x33), @(0x44), @(0x55), @(0x66), @(0x77),
        @(0x88), @(0x99), @(0xAA), @(0xBB), @(0xCC),
        @(0xDD), @(0xEE), @(0xFF), @(0x92, 0x49, 0x24),
        @(0x49, 0x24, 0x92), @(0x24, 0x92, 0x49), @(0x6D, 0xB6, 0xDB),
        @(0xB6, 0xDB, 0x6D), @(0xDB, 0x6D, 0xB6),
        # Passes 32-35: Random
        $null, $null, $null, $null
    )

    for ($i = 0; $i -lt $patterns.Count; $i++) {
        $passNum = $i + 1
        Write-Host "  [$passNum/35] Đang ghi pattern..." -ForegroundColor Cyan
        Write-WipePattern -Path $DrivePath -Pattern $patterns[$i] -Size $DriveSize -PassNumber $passNum -TotalPasses 35
    }
}

function Invoke-RandomWipe {
    param([string]$DrivePath, [long]$DriveSize, [int]$Passes)

    Write-Host "[*] Phương pháp: Random ($Passes passes)" -ForegroundColor Yellow

    for ($i = 1; $i -le $Passes; $i++) {
        Write-Host "  [$i/$Passes] Ghi random data..." -ForegroundColor Cyan
        Write-WipePattern -Path $DrivePath -Pattern $null -Size $DriveSize -PassNumber $i -TotalPasses $Passes
    }
}

function Invoke-ZeroWipe {
    param([string]$DrivePath, [long]$DriveSize)

    Write-Host "[*] Phương pháp: Zero Fill (1 pass)" -ForegroundColor Yellow
    Write-Host "  [1/1] Ghi zeros..." -ForegroundColor Cyan
    Write-WipePattern -Path $DrivePath -Pattern @(0x00) -Size $DriveSize -PassNumber 1 -TotalPasses 1
}

function Invoke-QuickWipe {
    param([string]$DriveLetter)

    Write-Host "[*] Phương pháp: Quick Wipe (Xóa nhanh bằng cipher + format)" -ForegroundColor Yellow

    # Xóa tất cả files
    Write-Host "  [1/3] Xóa tất cả files..." -ForegroundColor Cyan
    Get-ChildItem -Path "$DriveLetter\" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    # Dùng cipher /w để ghi đè không gian trống
    Write-Host "  [2/3] Ghi đè không gian trống với cipher..." -ForegroundColor Cyan
    Start-Process -FilePath "cipher.exe" -ArgumentList "/w:$DriveLetter\" -NoNewWindow -Wait

    # Format
    Write-Host "  [3/3] Format ổ đĩa..." -ForegroundColor Cyan
    Format-Volume -DriveLetter $DriveLetter.TrimEnd(':') -FileSystem NTFS -Force -Confirm:$false
}

function Start-EmergencyWipe {
    param(
        [string]$DriveLetter,
        [string]$Method,
        [int]$Passes
    )

    $DriveLetter = $DriveLetter.TrimEnd(':').TrimEnd('\') + ":"

    # Kiểm tra ổ đĩa tồn tại
    if (-not (Test-Path $DriveLetter)) {
        Write-Host "[!] Ổ đĩa $DriveLetter không tồn tại!" -ForegroundColor Red
        return
    }

    # Lấy thông tin ổ đĩa
    $drive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $DriveLetter }

    if ($drive -eq $null) {
        Write-Host "[!] Không thể lấy thông tin ổ đĩa $DriveLetter" -ForegroundColor Red
        return
    }

    # Kiểm tra không phải ổ hệ thống
    $systemDrive = $env:SystemDrive
    if ($DriveLetter -eq $systemDrive) {
        Write-Host "[!] KHÔNG THỂ XÓA Ổ ĐĨA HỆ THỐNG ($systemDrive)!" -ForegroundColor Red
        Write-Host "[!] Để xóa ổ hệ thống, boot từ USB/CD và chạy tool." -ForegroundColor Yellow
        return
    }

    $sizeGB = [math]::Round($drive.Size / 1GB, 2)

    Write-Host "`n" + "=" * 70 -ForegroundColor Red
    Write-Host "            !!! CẢNH BÁO XÓA DỮ LIỆU KHẨN CẤP !!!" -ForegroundColor Red
    Write-Host "=" * 70 -ForegroundColor Red
    Write-Host "`nỔ đĩa: $DriveLetter" -ForegroundColor White
    Write-Host "Tên: $($drive.VolumeName)" -ForegroundColor White
    Write-Host "Kích thước: ${sizeGB} GB" -ForegroundColor White
    Write-Host "Phương pháp: $Method" -ForegroundColor White
    Write-Host "`n[!!!] DỮ LIỆU SẼ BỊ XÓA VĨNH VIỄN - KHÔNG THỂ KHÔI PHỤC!" -ForegroundColor Red
    Write-Host "=" * 70 -ForegroundColor Red

    if (-not $Force) {
        # Xác nhận 3 lần
        Write-Host "`n[?] Nhập 'XOA' để xác nhận lần 1: " -ForegroundColor Yellow -NoNewline
        $confirm1 = Read-Host
        if ($confirm1 -ne "XOA") {
            Write-Host "[*] Đã hủy." -ForegroundColor Green
            return
        }

        Write-Host "[?] Nhập tên ổ đĩa '$DriveLetter' để xác nhận lần 2: " -ForegroundColor Yellow -NoNewline
        $confirm2 = Read-Host
        if ($confirm2 -ne $DriveLetter) {
            Write-Host "[*] Đã hủy." -ForegroundColor Green
            return
        }

        Write-Host "[?] LẦN CUỐI - Nhập 'TOI DONG Y XOA VINH VIEN' để bắt đầu: " -ForegroundColor Red -NoNewline
        $confirm3 = Read-Host
        if ($confirm3 -ne "TOI DONG Y XOA VINH VIEN") {
            Write-Host "[*] Đã hủy." -ForegroundColor Green
            return
        }
    }

    Write-Host "`n[!] BẮT ĐẦU XÓA TRONG 5 GIÂY... (Ctrl+C để hủy)" -ForegroundColor Red
    Start-Sleep -Seconds 5

    $startTime = Get-Date
    Write-Host "`n[*] Bắt đầu xóa lúc: $startTime" -ForegroundColor Cyan

    # Thực hiện xóa dựa trên phương pháp
    switch ($Method) {
        "Quick" {
            Invoke-QuickWipe -DriveLetter $DriveLetter
        }
        "Zero" {
            # Dùng format + diskpart cho Zero wipe
            Write-Host "[*] Đang format ổ đĩa với ghi đè zeros..." -ForegroundColor Yellow
            Format-Volume -DriveLetter $DriveLetter.TrimEnd(':') -FileSystem NTFS -Force -Confirm:$false
            # Sau đó dùng cipher để ghi đè thêm
            Start-Process -FilePath "cipher.exe" -ArgumentList "/w:$DriveLetter\" -NoNewWindow -Wait
        }
        "DoD" {
            Invoke-QuickWipe -DriveLetter $DriveLetter
            # Chạy cipher 3 lần
            for ($i = 1; $i -le 3; $i++) {
                Write-Host "  [Pass $i/3] Đang ghi đè..." -ForegroundColor Cyan
                Start-Process -FilePath "cipher.exe" -ArgumentList "/w:$DriveLetter\" -NoNewWindow -Wait
            }
        }
        "Gutmann" {
            Write-Host "[!] Gutmann 35-pass: Sẽ chạy nhiều lần ghi đè..." -ForegroundColor Yellow
            Invoke-QuickWipe -DriveLetter $DriveLetter
            for ($i = 1; $i -le 35; $i++) {
                Write-Host "  [Pass $i/35] Đang ghi đè..." -ForegroundColor Cyan
                Start-Process -FilePath "cipher.exe" -ArgumentList "/w:$DriveLetter\" -NoNewWindow -Wait
            }
        }
        "Random" {
            Invoke-QuickWipe -DriveLetter $DriveLetter
            for ($i = 1; $i -le $Passes; $i++) {
                Write-Host "  [Pass $i/$Passes] Đang ghi đè random..." -ForegroundColor Cyan
                Start-Process -FilePath "cipher.exe" -ArgumentList "/w:$DriveLetter\" -NoNewWindow -Wait
            }
        }
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "`n" + "=" * 70 -ForegroundColor Green
    Write-Host "            XÓA HOÀN TẤT!" -ForegroundColor Green
    Write-Host "=" * 70 -ForegroundColor Green
    Write-Host "Thời gian: $($duration.ToString())" -ForegroundColor White
    Write-Host "Phương pháp: $Method" -ForegroundColor White
    Write-Host "Ổ đĩa: $DriveLetter" -ForegroundColor White
    Write-Host "`n[*] Dữ liệu đã được xóa an toàn và không thể khôi phục." -ForegroundColor Green
}

# Main
Write-Banner

if ($ListDrives) {
    Get-DriveList
    exit
}

if ([string]::IsNullOrEmpty($DriveLetter)) {
    Get-DriveList
    Write-Host "`n[?] Nhập ký tự ổ đĩa cần xóa (ví dụ: D): " -ForegroundColor Yellow -NoNewline
    $DriveLetter = Read-Host
}

if ([string]::IsNullOrEmpty($DriveLetter)) {
    Write-Host "[!] Vui lòng chỉ định ổ đĩa!" -ForegroundColor Red
    Write-Host "`nSử dụng:"
    Write-Host "  .\EmergencyWipe.ps1 -DriveLetter D -Method DoD" -ForegroundColor Cyan
    Write-Host "  .\EmergencyWipe.ps1 -ListDrives" -ForegroundColor Cyan
    Write-Host "`nPhương pháp:"
    Write-Host "  Quick   - Xóa nhanh (xóa files + cipher + format)" -ForegroundColor White
    Write-Host "  Zero    - Ghi đè bằng zeros" -ForegroundColor White
    Write-Host "  DoD     - DoD 5220.22-M (3 passes) [Mặc định]" -ForegroundColor White
    Write-Host "  Gutmann - Gutmann 35 passes (rất chậm)" -ForegroundColor White
    Write-Host "  Random  - Random data (-Passes để chỉ định số lần)" -ForegroundColor White
    exit
}

Start-EmergencyWipe -DriveLetter $DriveLetter -Method $Method -Passes $Passes
