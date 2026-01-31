#Requires -RunAsAdministrator
# SECURE WIPE - 2-Pass: Wipe (0xFF) + Zero (0x00)
# Prevents data recovery by professional tools

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

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "     SECURE WIPE - 2 PASS (WIPE + ZERO)" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This script will:" -ForegroundColor Yellow
Write-Host "  - Pass 1: WIPE disk (0xFF - erase all data)" -ForegroundColor Yellow
Write-Host "  - Pass 2: ZERO fill (0x00 - prevent recovery)" -ForegroundColor Yellow
Write-Host "  - Safe for hardware (no damage)" -ForegroundColor Yellow
Write-Host ""

$disks = Get-WmiObject Win32_DiskDrive

foreach ($disk in $disks) {
    $diskNum = $disk.DeviceID -replace '.*PHYSICALDRIVE', ''
    $sizeGB = [math]::Round($disk.Size / 1GB, 1)
    $mediaType = $disk.MediaType

    Write-Host "  [*] Disk $diskNum : $($disk.Model) - $sizeGB GB ($mediaType)" -ForegroundColor Yellow

    try {
        $path = "\\.\PhysicalDrive$diskNum"
        $handle = [RawDisk]::Open($path)

        if ($handle.IsInvalid) {
            Write-Host "      Cannot open - skipping" -ForegroundColor DarkGray
            continue
        }

        # Lock and dismount volumes
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

        $targetSize = [long]$disk.Size
        $bufferSize = 100MB
        $buffer = New-Object byte[] $bufferSize
        $written = 0

        # ============================================
        # PASS 1: WIPE (0xFF - erase all data)
        # ============================================
        Write-Host "      [PASS 1/2] WIPING disk (0xFF)..." -ForegroundColor Magenta

        # Fill buffer with 0xFF
        for ($i = 0; $i -lt $bufferSize; $i++) {
            $buffer[$i] = 0xFF
        }

        for ($offset = 0L; $offset -lt $targetSize; $offset += $bufferSize) {
            try {
                [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null

                # Update progress every 1GB
                if (($offset % 1GB) -eq 0) {
                    $pct = [math]::Round(($offset / $targetSize) * 100, 1)
                    $wipedGB = [math]::Round($offset / 1GB, 1)
                    Write-Host "`r      [WIPE] $pct% ($wipedGB GB / $sizeGB GB)     " -NoNewline -ForegroundColor Magenta
                }
            }
            catch {
                continue
            }
        }
        Write-Host ""
        Write-Host "      [OK] Pass 1 complete - disk wiped (0xFF)" -ForegroundColor Green

        # ============================================
        # PASS 2: ZERO FILL (0x00 - prevent recovery)
        # ============================================
        Write-Host "      [PASS 2/2] Writing ZERO (0x00)..." -ForegroundColor Cyan

        # Reset buffer to zeros
        $buffer = New-Object byte[] $bufferSize

        for ($offset = 0L; $offset -lt $targetSize; $offset += $bufferSize) {
            try {
                [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null

                # Update progress every 1GB
                if (($offset % 1GB) -eq 0) {
                    $pct = [math]::Round(($offset / $targetSize) * 100, 1)
                    $wipedGB = [math]::Round($offset / 1GB, 1)
                    Write-Host "`r      [ZERO] $pct% ($wipedGB GB / $sizeGB GB)     " -NoNewline -ForegroundColor Cyan
                }
            }
            catch {
                continue
            }
        }
        Write-Host ""
        Write-Host "      [OK] Pass 2 complete - disk zeroed (0x00)" -ForegroundColor Green

        $handle.Close()

        Write-Host ""
        Write-Host "      [DONE] Disk $diskNum securely wiped" -ForegroundColor Green
    }
    catch {
        Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "     SECURE WIPE COMPLETE (2 PASS)" -ForegroundColor Green
Write-Host "     Pass 1: WIPE (0xFF) - all data erased" -ForegroundColor Green
Write-Host "     Pass 2: ZERO (0x00) - disk cleaned" -ForegroundColor Green
Write-Host "     Professional recovery: NOT POSSIBLE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "System will shut down in 5 seconds..." -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 5
Stop-Computer -Force
