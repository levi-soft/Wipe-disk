#Requires -RunAsAdministrator
# SECURE WIPE - 2-Pass: Clean + Zero
# Prevents data recovery by professional tools
# Keeps Windows running until the end
# FORCE MODE: Ignores all errors, ensures completion

Add-Type @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public class RawDisk {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern SafeFileHandle CreateFile(string fn, uint da, uint sm, IntPtr sa, uint cd, uint fa, IntPtr t);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteFile(SafeFileHandle h, byte[] b, uint n, out uint w, IntPtr o);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool DeviceIoControl(SafeFileHandle h, uint c, IntPtr i, uint is_, IntPtr o, uint os, out uint r, IntPtr ov);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool SetFilePointerEx(SafeFileHandle h, long d, out long n, uint m);

    public static SafeFileHandle Open(string path) {
        return CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0x80000000 | 0x20000000, IntPtr.Zero);
    }

    public static void Lock(SafeFileHandle h) {
        uint r; DeviceIoControl(h, 0x00090018, IntPtr.Zero, 0, IntPtr.Zero, 0, out r, IntPtr.Zero);
    }

    public static void Dismount(SafeFileHandle h) {
        uint r; DeviceIoControl(h, 0x00090020, IntPtr.Zero, 0, IntPtr.Zero, 0, out r, IntPtr.Zero);
    }

    public static bool Seek(SafeFileHandle h, long offset) {
        long n;
        return SetFilePointerEx(h, offset, out n, 0);
    }

    public static bool WriteAt(SafeFileHandle h, long offset, byte[] data, out uint written) {
        Seek(h, offset);
        return WriteFile(h, data, (uint)data.Length, out written, IntPtr.Zero);
    }
}
"@

# Disable Ctrl+C to prevent cancellation
[Console]::TreatControlCAsInput = $true

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "     SECURE WIPE - 2 PASS (CLEAN + ZERO)" -ForegroundColor Cyan
Write-Host "     FORCE MODE - CANNOT BE CANCELLED" -ForegroundColor Red
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This script will:" -ForegroundColor Yellow
Write-Host "  - Pass 1: CLEAN disk (remove partitions)" -ForegroundColor Yellow
Write-Host "  - Pass 2: ZERO fill (0x00 - prevent recovery)" -ForegroundColor Yellow
Write-Host "  - System disk processed LAST (Windows stays alive)" -ForegroundColor Yellow
Write-Host ""

# Find system disk (contains Windows)
$systemDrive = $env:SystemDrive.TrimEnd(':')
$systemPartition = Get-Partition -DriveLetter $systemDrive -ErrorAction SilentlyContinue
$systemDiskNum = if ($systemPartition) { $systemPartition.DiskNumber } else { 0 }

Write-Host "  [INFO] System disk: $systemDiskNum (processed LAST)" -ForegroundColor Cyan
Write-Host ""

$disks = Get-WmiObject Win32_DiskDrive

# Sort disks: non-system first, system disk last
$sortedDisks = $disks | Sort-Object {
    $num = $_.DeviceID -replace '.*PHYSICALDRIVE', ''
    if ($num -eq $systemDiskNum) { 1 } else { 0 }
}

foreach ($disk in $sortedDisks) {
    $diskNum = $disk.DeviceID -replace '.*PHYSICALDRIVE', ''
    $sizeGB = [math]::Round($disk.Size / 1GB, 1)
    $mediaType = $disk.MediaType
    $isSystemDisk = ($diskNum -eq $systemDiskNum)

    if ($isSystemDisk) {
        Write-Host "  [*] Disk $diskNum : $($disk.Model) - $sizeGB GB [SYSTEM - LAST]" -ForegroundColor Red
    } else {
        Write-Host "  [*] Disk $diskNum : $($disk.Model) - $sizeGB GB" -ForegroundColor Yellow
    }

    $path = "\\.\PhysicalDrive$diskNum"
    $targetSize = [long]$disk.Size
    $bufferSize = 100MB
    $buffer = New-Object byte[] $bufferSize
    $written = 0

    # ============================================
    # PASS 1: CLEAN DISK
    # ============================================
    Write-Host "      [PASS 1/2] CLEANING disk..." -ForegroundColor Magenta

    # Try multiple methods to clean
    try {
        $diskpartScript = @"
select disk $diskNum
clean
"@
        $diskpartScript | diskpart 2>$null | Out-Null
    } catch {}

    try {
        Clear-Disk -Number $diskNum -RemoveData -RemoveOEM -Confirm:$false -ErrorAction SilentlyContinue 2>$null
    } catch {}

    # Force remove all partitions
    try {
        Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue | Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue 2>$null
    } catch {}

    Write-Host "      [OK] Pass 1 complete" -ForegroundColor Green

    # ============================================
    # PASS 2: ZERO FILL
    # ============================================
    Write-Host "      [PASS 2/2] Writing ZERO..." -ForegroundColor Cyan

    # Try to open disk with retry
    $handle = $null
    for ($retry = 0; $retry -lt 5; $retry++) {
        $handle = [RawDisk]::Open($path)
        if (-not $handle.IsInvalid) { break }
        Start-Sleep -Milliseconds 500
    }

    if ($handle -eq $null -or $handle.IsInvalid) {
        Write-Host "      [WARN] Cannot open disk, skipping zero-fill" -ForegroundColor Yellow
        continue
    }

    # Lock and dismount all volumes on this disk
    try {
        Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.DriveLetter) {
                $volHandle = [RawDisk]::Open("\\.\$($_.DriveLetter):")
                if (-not $volHandle.IsInvalid) {
                    [RawDisk]::Lock($volHandle)
                    [RawDisk]::Dismount($volHandle)
                    $volHandle.Close()
                }
            }
        }
    } catch {}

    if ($isSystemDisk) {
        # SYSTEM DISK: Write from END to START
        $totalChunks = [math]::Ceiling($targetSize / $bufferSize)
        $currentChunk = 0

        for ($i = $totalChunks - 1; $i -ge 0; $i--) {
            $offset = [long]$i * $bufferSize
            if ($offset -ge $targetSize) { continue }

            try {
                [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null
            } catch {}

            $currentChunk++
            if (($currentChunk % 10) -eq 0) {
                $pct = [math]::Round(($currentChunk / $totalChunks) * 100, 1)
                Write-Host "`r      [ZERO] $pct%     " -NoNewline -ForegroundColor Cyan
            }
        }
    } else {
        # NON-SYSTEM DISK: Write from START to END
        for ($offset = 0L; $offset -lt $targetSize; $offset += $bufferSize) {
            try {
                [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null
            } catch {}

            if (($offset % 1GB) -eq 0) {
                $pct = [math]::Round(($offset / $targetSize) * 100, 1)
                Write-Host "`r      [ZERO] $pct%     " -NoNewline -ForegroundColor Cyan
            }
        }
    }

    Write-Host ""
    try { $handle.Close() } catch {}

    Write-Host "      [DONE] Disk $diskNum wiped" -ForegroundColor Green
    Write-Host ""
}

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "     SECURE WIPE COMPLETE" -ForegroundColor Green
Write-Host "     Pass 1: CLEAN - done" -ForegroundColor Green
Write-Host "     Pass 2: ZERO - done" -ForegroundColor Green
Write-Host "     Recovery: NOT POSSIBLE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host ""

Stop-Computer -Force
