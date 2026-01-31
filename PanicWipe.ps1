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

        # DoD 5220.22-M: 3 passes (0x00, 0xFF, Random)
        $targetSize = [long]$disk.Size
        $patterns = @(
            @{ Name = "Pass 1/3: Zeros (0x00)"; Value = 0x00 },
            @{ Name = "Pass 2/3: Ones (0xFF)"; Value = 0xFF },
            @{ Name = "Pass 3/3: Random"; Value = -1 }
        )

        $totalSuccess = 0L
        $totalFailed = 0L

        foreach ($pattern in $patterns) {
            Write-Host "      $($pattern.Name)..." -ForegroundColor Red

            $buffer = New-Object byte[] (4MB)
            if ($pattern.Value -eq -1) {
                $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
                $rng.GetBytes($buffer)
            } elseif ($pattern.Value -ne 0) {
                for ($i = 0; $i -lt $buffer.Length; $i++) { $buffer[$i] = $pattern.Value }
            }

            $offset = 0L
            $passSuccess = 0L
            $passFailed = 0L
            $startTime = Get-Date

            while ($offset -lt $targetSize) {
                $written = 0

                if ($pattern.Value -eq -1) { $rng.GetBytes($buffer) }

                $result = [RawDisk]::WriteAt($handle, $offset, $buffer, [ref]$written)
                $lastErr = [RawDisk]::GetLastError()

                if ($result -and $written -gt 0) {
                    $passSuccess += $written
                    $offset += $written
                } else {
                    $passFailed += 4MB
                    $offset += 4MB
                    # First failure - show error code
                    if ($passFailed -eq 4MB) {
                        Write-Host ""
                        Write-Host "      [!] Write failed! Error code: $lastErr" -ForegroundColor Red
                    }
                }

                $pct = [int](($offset / $targetSize) * 100)
                $elapsed = ((Get-Date) - $startTime).TotalSeconds
                if ($elapsed -gt 0 -and $pct % 5 -eq 0) {
                    $speed = [math]::Round($passSuccess / $elapsed / 1MB, 1)
                    Write-Host ("`r      $($pattern.Name)... {0}% | Written: {1} GB | Failed: {2} GB | {3} MB/s" -f $pct, [math]::Round($passSuccess/1GB,1), [math]::Round($passFailed/1GB,1), $speed) -NoNewline -ForegroundColor Yellow
                }
            }
            Write-Host ""
            $totalSuccess += $passSuccess
            $totalFailed += $passFailed
        }

        $handle.Close()

        if ($totalFailed -gt 0) {
            Write-Host "      [!] WARNING: $([math]::Round($totalFailed/1GB,1)) GB FAILED to write!" -ForegroundColor Red
            Write-Host "      [!] Windows is blocking writes. Need to boot Recovery!" -ForegroundColor Red
        } else {
            Write-Host "      SUCCESS! Wrote $([math]::Round($totalSuccess/1GB,1)) GB" -ForegroundColor Green
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
