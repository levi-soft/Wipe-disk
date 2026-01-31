#Requires -RunAsAdministrator
# PANIC WIPE - Raw disk overwrite, no questions asked

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

    public static bool Write(SafeFileHandle h, byte[] data, out uint written) {
        return WriteFile(h, data, (uint)data.Length, out written, IntPtr.Zero);
    }

    public static bool Seek(SafeFileHandle h, long offset) {
        long n;
        return SetFilePointerEx(h, offset, out n, 0);
    }

    public static bool WriteAt(SafeFileHandle h, long offset, byte[] data, out uint written) {
        Seek(h, offset);
        return WriteFile(h, data, (uint)data.Length, out written, IntPtr.Zero);
    }

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool ReadFile(SafeFileHandle h, byte[] b, uint n, out uint r, IntPtr o);

    public static bool ReadAt(SafeFileHandle h, long offset, byte[] data, out uint read) {
        Seek(h, offset);
        return ReadFile(h, data, (uint)data.Length, out read, IntPtr.Zero);
    }

    [DllImport("kernel32.dll")]
    public static extern int GetLastError();
}
"@

Write-Host ""
Write-Host "  ===========================================" -ForegroundColor Red
Write-Host "     PANIC WIPE - DESTROYING ALL DISKS" -ForegroundColor Red
Write-Host "  ===========================================" -ForegroundColor Red
Write-Host ""

# Get all physical disks
$disks = Get-WmiObject Win32_DiskDrive

foreach ($disk in $disks) {
    $diskNum = $disk.DeviceID -replace '.*PHYSICALDRIVE', ''
    $sizeGB = [math]::Round($disk.Size / 1GB, 1)

    Write-Host "  [*] Disk $diskNum : $($disk.Model) - $sizeGB GB" -ForegroundColor Yellow

    try {
        # Open physical disk
        $path = "\\.\PhysicalDrive$diskNum"
        $handle = [RawDisk]::Open($path)

        if ($handle.IsInvalid) {
            Write-Host "      Cannot open - skipping" -ForegroundColor DarkGray
            continue
        }

        # Lock and dismount all volumes on this disk
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

        # Write zeros to entire disk
        $targetSize = [long]$disk.Size
        $buffer = New-Object byte[] (4MB)  # All zeros
        $offset = 0L
        $written_total = 0L
        $failed_total = 0L
        $startTime = Get-Date

        Write-Host "      Writing zeros..." -ForegroundColor Red

        while ($offset -lt $targetSize) {
            $written = 0
            $result = [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written)

            if ($result -and $written -gt 0) {
                $written_total += $written
                $offset += $written
            } else {
                if ($failed_total -eq 0) {
                    $err = [RawDisk]::GetLastError()
                    Write-Host "`n      [!] Write failed! Error: $err" -ForegroundColor Red
                }
                $failed_total += 4MB
                $offset += 4MB
            }

            $pct = [int](($offset / $targetSize) * 100)
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            if ($elapsed -gt 0) {
                $speed = [math]::Round($written_total / $elapsed / 1MB, 1)
                Write-Host ("`r      Wiping zeros... {0}% | {1} MB/s" -f $pct, $speed) -NoNewline -ForegroundColor Yellow
            }
        }

        $handle.Close()
        Write-Host ""

        if ($failed_total -gt 0) {
            Write-Host "      [!] FAILED: $([math]::Round($failed_total/1GB,1)) GB blocked by Windows!" -ForegroundColor Red
        } else {
            Write-Host "      SUCCESS! $([math]::Round($written_total/1GB,1)) GB wiped with zeros" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "  ===========================================" -ForegroundColor Green
Write-Host "     ALL DISKS DESTROYED - SHUTTING DOWN" -ForegroundColor Green
Write-Host "  ===========================================" -ForegroundColor Green
Write-Host ""

Stop-Computer -Force
