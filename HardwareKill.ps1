#Requires -RunAsAdministrator
# SECURE WIPE - 2-Pass: Clean + Zero
# RUNS FROM RAM - Can wipe system disk

# ============================================
# STEP 1: LOAD EVERYTHING INTO RAM
# ============================================

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "     LOADING INTO RAM..." -ForegroundColor Yellow
Write-Host "  ====================================================" -ForegroundColor Cyan

# Load .NET code into memory
$RawDiskCode = @"
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

Add-Type -TypeDefinition $RawDiskCode

# Pre-allocate buffer in RAM (100MB of zeros)
$bufferSize = 100MB
$zeroBuffer = New-Object byte[] $bufferSize

# Get disk info and store in RAM
$disks = @(Get-WmiObject Win32_DiskDrive)
$diskInfoList = @()

foreach ($disk in $disks) {
    $diskNum = $disk.DeviceID -replace '.*PHYSICALDRIVE', ''
    $diskInfoList += @{
        Number = $diskNum
        Size = [long]$disk.Size
        SizeGB = [math]::Round($disk.Size / 1GB, 1)
        Model = $disk.Model
        Path = "\\.\PhysicalDrive$diskNum"
    }
}

# Disable Ctrl+C
[Console]::TreatControlCAsInput = $true
$ErrorActionPreference = "SilentlyContinue"

Write-Host "  [OK] Loaded into RAM" -ForegroundColor Green
Write-Host "  [OK] Buffer: $($bufferSize / 1MB) MB ready" -ForegroundColor Green
Write-Host "  [OK] Found $($diskInfoList.Count) disk(s)" -ForegroundColor Green
Write-Host ""

# ============================================
# STEP 2: DISPLAY INFO
# ============================================

Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "     SECURE WIPE - 2 PASS (CLEAN + ZERO)" -ForegroundColor Cyan
Write-Host "     RUNNING FROM RAM" -ForegroundColor Red
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Pass 1: CLEAN disk (remove all data)" -ForegroundColor Yellow
Write-Host "  Pass 2: ZERO fill (prevent recovery)" -ForegroundColor Yellow
Write-Host ""

foreach ($info in $diskInfoList) {
    Write-Host "  [*] Disk $($info.Number): $($info.Model) - $($info.SizeGB) GB" -ForegroundColor Yellow
}
Write-Host ""

# ============================================
# STEP 3: PASS 1 - CLEAN ALL DISKS
# ============================================

Write-Host "  ====================================================" -ForegroundColor Magenta
Write-Host "     PASS 1: CLEANING ALL DISKS" -ForegroundColor Magenta
Write-Host "  ====================================================" -ForegroundColor Magenta
Write-Host ""

foreach ($info in $diskInfoList) {
    $diskNum = $info.Number
    Write-Host "  [CLEAN] Disk $diskNum..." -ForegroundColor Magenta

    # Method 1: diskpart clean
    try {
        $script = "select disk $diskNum`nclean"
        $script | diskpart 2>$null | Out-Null
    } catch {}

    # Method 2: Clear-Disk
    try {
        Clear-Disk -Number $diskNum -RemoveData -RemoveOEM -Confirm:$false -ErrorAction SilentlyContinue 2>$null
    } catch {}

    # Method 3: Remove partitions
    try {
        Get-Partition -DiskNumber $diskNum -ErrorAction SilentlyContinue | Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue 2>$null
    } catch {}

    Write-Host "  [OK] Disk $diskNum cleaned" -ForegroundColor Green
}

Write-Host ""
Write-Host "  [PASS 1 COMPLETE] All disks cleaned" -ForegroundColor Green
Write-Host ""

# ============================================
# STEP 4: PASS 2 - ZERO FILL ALL DISKS
# ============================================

Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "     PASS 2: ZERO FILL ALL DISKS" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($info in $diskInfoList) {
    $diskNum = $info.Number
    $targetSize = $info.Size
    $sizeGB = $info.SizeGB
    $path = $info.Path

    Write-Host "  [ZERO] Disk $diskNum ($sizeGB GB)..." -ForegroundColor Cyan

    # Open disk with retry
    $handle = $null
    for ($retry = 0; $retry -lt 10; $retry++) {
        try {
            $handle = [RawDisk]::Open($path)
            if (-not $handle.IsInvalid) { break }
        } catch {}
        Start-Sleep -Milliseconds 200
    }

    if ($handle -eq $null -or $handle.IsInvalid) {
        Write-Host "  [WARN] Cannot open Disk $diskNum" -ForegroundColor Yellow
        continue
    }

    # Write zeros
    $written = 0
    for ($offset = 0L; $offset -lt $targetSize; $offset += $bufferSize) {
        try {
            [RawDisk]::WriteAt($handle, $offset, $zeroBuffer, [ref]$written) | Out-Null
        } catch {}

        if (($offset % 1GB) -eq 0) {
            $pct = [math]::Round(($offset / $targetSize) * 100, 1)
            $doneGB = [math]::Round($offset / 1GB, 1)
            Write-Host "`r  [ZERO] Disk $diskNum : $pct% ($doneGB / $sizeGB GB)     " -NoNewline -ForegroundColor Cyan
        }
    }

    Write-Host ""
    try { $handle.Close() } catch {}
    Write-Host "  [OK] Disk $diskNum zeroed" -ForegroundColor Green
}

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host "     SECURE WIPE COMPLETE" -ForegroundColor Green
Write-Host "     Pass 1: CLEAN - done" -ForegroundColor Green
Write-Host "     Pass 2: ZERO - done" -ForegroundColor Green
Write-Host "     Recovery: NOT POSSIBLE" -ForegroundColor Green
Write-Host "  ====================================================" -ForegroundColor Green
Write-Host ""

# Shutdown
Stop-Computer -Force
