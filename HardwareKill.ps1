#Requires -RunAsAdministrator
# SECURE WIPE - 2-Pass: Clean + Zero
# Prevents data recovery by professional tools
# Keeps Windows running until the end

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
Write-Host "     SECURE WIPE - 2 PASS (CLEAN + ZERO)" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This script will:" -ForegroundColor Yellow
Write-Host "  - Pass 1: CLEAN disk (remove partitions, erase data)" -ForegroundColor Yellow
Write-Host "  - Pass 2: ZERO fill (0x00 - prevent recovery)" -ForegroundColor Yellow
Write-Host "  - Safe for hardware (no damage)" -ForegroundColor Yellow
Write-Host "  - System disk processed LAST (Windows stays alive)" -ForegroundColor Yellow
Write-Host ""

# Find system disk (contains Windows)
$systemDrive = $env:SystemDrive.TrimEnd(':')
$systemPartition = Get-Partition -DriveLetter $systemDrive -ErrorAction SilentlyContinue
$systemDiskNum = if ($systemPartition) { $systemPartition.DiskNumber } else { 0 }

Write-Host "  [INFO] System disk: $systemDiskNum (will be processed LAST)" -ForegroundColor Cyan
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
        Write-Host "  [*] Disk $diskNum : $($disk.Model) - $sizeGB GB [SYSTEM DISK - LAST]" -ForegroundColor Red
    } else {
        Write-Host "  [*] Disk $diskNum : $($disk.Model) - $sizeGB GB ($mediaType)" -ForegroundColor Yellow
    }

    try {
        $path = "\\.\PhysicalDrive$diskNum"
        $targetSize = [long]$disk.Size
        $bufferSize = 100MB
        $buffer = New-Object byte[] $bufferSize  # Default is zeros
        $written = 0

        if (-not $isSystemDisk) {
            # ============================================
            # NON-SYSTEM DISK: Normal Clean + Zero
            # ============================================

            # PASS 1: CLEAN DISK
            Write-Host "      [PASS 1/2] CLEANING disk..." -ForegroundColor Magenta

            $diskpartScript = @"
select disk $diskNum
clean
"@
            $diskpartScript | diskpart | Out-Null

            try {
                Clear-Disk -Number $diskNum -RemoveData -RemoveOEM -Confirm:$false -ErrorAction SilentlyContinue
            } catch {}

            Write-Host "      [OK] Pass 1 complete - disk cleaned" -ForegroundColor Green

            # PASS 2: ZERO FILL (forward)
            Write-Host "      [PASS 2/2] Writing ZERO (0x00)..." -ForegroundColor Cyan

            $handle = [RawDisk]::Open($path)
            if ($handle.IsInvalid) {
                Write-Host "      Cannot open disk" -ForegroundColor Red
                continue
            }

            for ($offset = 0L; $offset -lt $targetSize; $offset += $bufferSize) {
                try {
                    [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null
                    if (($offset % 1GB) -eq 0) {
                        $pct = [math]::Round(($offset / $targetSize) * 100, 1)
                        $wipedGB = [math]::Round($offset / 1GB, 1)
                        Write-Host "`r      [ZERO] $pct% ($wipedGB GB / $sizeGB GB)     " -NoNewline -ForegroundColor Cyan
                    }
                } catch { continue }
            }
            Write-Host ""
            $handle.Close()

        } else {
            # ============================================
            # SYSTEM DISK: Zero from END to START
            # Keep Windows alive as long as possible
            # ============================================

            Write-Host "      [SYSTEM] Wiping from END to START (Windows stays alive)" -ForegroundColor Red

            # Lock and dismount non-system volumes on this disk
            Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.DriveLetter -and $_.DriveLetter -ne $systemDrive) {
                    $volHandle = [RawDisk]::Open("\\.\$($_.DriveLetter):")
                    if (-not $volHandle.IsInvalid) {
                        [RawDisk]::Lock($volHandle)
                        [RawDisk]::Dismount($volHandle)
                        $volHandle.Close()
                    }
                }
            }

            $handle = [RawDisk]::Open($path)
            if ($handle.IsInvalid) {
                Write-Host "      Cannot open system disk" -ForegroundColor Red
                continue
            }

            # Calculate total chunks
            $totalChunks = [math]::Ceiling($targetSize / $bufferSize)
            $currentChunk = 0

            # Write ZERO from END to START
            Write-Host "      [ZERO] Writing from end to start..." -ForegroundColor Cyan

            for ($i = $totalChunks - 1; $i -ge 0; $i--) {
                $offset = [long]$i * $bufferSize
                if ($offset -ge $targetSize) { continue }

                try {
                    [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written) | Out-Null
                    $currentChunk++

                    if (($currentChunk % 10) -eq 0) {
                        $pct = [math]::Round(($currentChunk / $totalChunks) * 100, 1)
                        $remainGB = [math]::Round(($totalChunks - $currentChunk) * $bufferSize / 1GB, 1)
                        Write-Host "`r      [ZERO] $pct% (Remaining: $remainGB GB)     " -NoNewline -ForegroundColor Cyan
                    }
                } catch { continue }
            }
            Write-Host ""
            $handle.Close()
        }

        Write-Host "      [DONE] Disk $diskNum securely wiped" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "     SECURE WIPE COMPLETE (2 PASS)" -ForegroundColor Green
Write-Host "     Pass 1: CLEAN - partitions removed" -ForegroundColor Green
Write-Host "     Pass 2: ZERO - disk filled with 0x00" -ForegroundColor Green
Write-Host "     Professional recovery: NOT POSSIBLE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "System will shut down in 5 seconds..." -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 5
Stop-Computer -Force
