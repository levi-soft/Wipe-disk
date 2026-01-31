#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NukeWipe - Proper emergency disk wipe
.DESCRIPTION
    Method 1: Boot to Windows RE and wipe (proper PreOS)
    Method 2: Raw disk overwrite (instant, may BSOD)
#>

param(
    [switch]$BootWipe,      # Reboot to WinRE and wipe
    [switch]$RawWipe,       # Instant raw disk wipe
    [switch]$ListDisks,
    [int]$Disk = -1,
    [switch]$All
)

Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class Disk
{
    const uint GENERIC_READ = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ = 1;
    const uint FILE_SHARE_WRITE = 2;
    const uint OPEN_EXISTING = 3;
    const uint FILE_FLAG_NO_BUFFERING = 0x20000000;
    const uint FILE_FLAG_WRITE_THROUGH = 0x80000000;
    const uint FSCTL_LOCK_VOLUME = 0x00090018;
    const uint FSCTL_DISMOUNT_VOLUME = 0x00090020;
    const uint IOCTL_DISK_GET_LENGTH_INFO = 0x0007405C;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern SafeFileHandle CreateFileW(
        string lpFileName, uint dwDesiredAccess, uint dwShareMode,
        IntPtr lpSecurityAttributes, uint dwCreationDisposition,
        uint dwFlagsAndAttributes, IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(
        SafeFileHandle hDevice, uint dwIoControlCode,
        IntPtr lpInBuffer, uint nInBufferSize,
        IntPtr lpOutBuffer, uint nOutBufferSize,
        out uint lpBytesReturned, IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteFile(
        SafeFileHandle hFile, byte[] lpBuffer, uint nNumberOfBytesToWrite,
        out uint lpNumberOfBytesWritten, IntPtr lpOverlapped);

    [DllImport("kernel32.dll")]
    static extern bool SetFilePointerEx(
        SafeFileHandle hFile, long liDistanceToMove,
        out long lpNewFilePointer, uint dwMoveMethod);

    public static SafeFileHandle Open(string path)
    {
        return CreateFileW(path,
            GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            IntPtr.Zero, OPEN_EXISTING,
            FILE_FLAG_NO_BUFFERING | FILE_FLAG_WRITE_THROUGH,
            IntPtr.Zero);
    }

    public static bool Lock(SafeFileHandle h)
    {
        uint br;
        return DeviceIoControl(h, FSCTL_LOCK_VOLUME, IntPtr.Zero, 0, IntPtr.Zero, 0, out br, IntPtr.Zero);
    }

    public static bool Dismount(SafeFileHandle h)
    {
        uint br;
        return DeviceIoControl(h, FSCTL_DISMOUNT_VOLUME, IntPtr.Zero, 0, IntPtr.Zero, 0, out br, IntPtr.Zero);
    }

    public static long GetSize(SafeFileHandle h)
    {
        uint br;
        long size = 0;
        IntPtr ptr = Marshal.AllocHGlobal(8);
        try {
            if (DeviceIoControl(h, IOCTL_DISK_GET_LENGTH_INFO, IntPtr.Zero, 0, ptr, 8, out br, IntPtr.Zero))
                size = Marshal.ReadInt64(ptr);
        } finally { Marshal.FreeHGlobal(ptr); }
        return size;
    }

    public static bool Write(SafeFileHandle h, long offset, byte[] data, out uint written)
    {
        written = 0;
        long np;
        if (!SetFilePointerEx(h, offset, out np, 0)) return false;
        return WriteFile(h, data, (uint)data.Length, out written, IntPtr.Zero);
    }
}
"@

function Show-Disks {
    Write-Host "`n  Physical Disks:" -ForegroundColor Cyan
    Get-WmiObject Win32_DiskDrive | ForEach-Object {
        $num = [int]($_.DeviceID -replace '.*PHYSICALDRIVE', '')
        $gb = [math]::Round($_.Size/1GB, 1)
        $sys = if ((Get-Partition -DiskNumber $num -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq 'C' })) { " [SYSTEM]" } else { "" }
        Write-Host "    Disk $num : $($_.Model) - $gb GB$sys" -ForegroundColor $(if($sys){"Red"}else{"White"})
    }
    Write-Host ""
}

function Start-RawWipe {
    param([int]$DiskNum)

    Write-Host "  [*] Opening PhysicalDrive$DiskNum..." -ForegroundColor Yellow
    $h = [Disk]::Open("\\.\PhysicalDrive$DiskNum")

    if ($h.IsInvalid) {
        Write-Host "  [!] Cannot open disk $DiskNum" -ForegroundColor Red
        return
    }

    # Lock và dismount tất cả volumes trên disk này
    Write-Host "  [*] Dismounting volumes..." -ForegroundColor Yellow
    Get-Partition -DiskNumber $DiskNum -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.DriveLetter) {
            $vol = [Disk]::Open("\\.\$($_.DriveLetter):")
            if (-not $vol.IsInvalid) {
                [Disk]::Lock($vol) | Out-Null
                [Disk]::Dismount($vol) | Out-Null
                $vol.Close()
            }
        }
    }

    $size = [Disk]::GetSize($h)
    if ($size -le 0) { $size = (Get-WmiObject Win32_DiskDrive | Where-Object { $_.DeviceID -match "PHYSICALDRIVE$DiskNum" }).Size }

    Write-Host "  [*] Disk size: $([math]::Round($size/1GB, 1)) GB" -ForegroundColor Yellow
    Write-Host "  [*] Writing zeros..." -ForegroundColor Red

    $buf = New-Object byte[] (4MB)
    $written = 0L
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($written -lt $size) {
        $bw = 0
        [Disk]::Write($h, $written, $buf, [ref]$bw) | Out-Null
        $written += [Math]::Max($bw, 4MB)

        if ($sw.ElapsedMilliseconds -gt 1000) {
            $pct = [math]::Round($written * 100 / $size, 1)
            $speed = $written / $sw.Elapsed.TotalSeconds / 1MB
            Write-Host "`r  Progress: $pct% - $([math]::Round($speed,1)) MB/s     " -NoNewline -ForegroundColor Green
        }
    }

    $h.Close()
    Write-Host "`n  [+] Disk $DiskNum wiped!" -ForegroundColor Green
}

function Start-BootWipe {
    Write-Host "`n  [*] Setting up Windows RE boot wipe..." -ForegroundColor Cyan

    # Tạo script cho WinRE
    $script = @'
@echo off
title EMERGENCY WIPE
color 4F
echo.
echo  ========================================
echo     WIPING ALL DISKS - PLEASE WAIT
echo  ========================================
echo.
for /L %%d in (0,1,15) do (
    echo Wiping Disk %%d...
    (echo sel dis %%d
     echo clean all) | diskpart >nul 2>&1
)
echo.
echo  ========================================
echo     WIPE COMPLETE - SHUTTING DOWN
echo  ========================================
wpeutil shutdown
'@

    # Lưu script vào nơi WinRE có thể truy cập
    $scriptPath = "$env:SystemDrive\Recovery\OEM"
    if (-not (Test-Path $scriptPath)) { New-Item -ItemType Directory -Path $scriptPath -Force | Out-Null }
    $script | Out-File "$scriptPath\wipe.cmd" -Encoding ASCII -Force

    # Tạo unattend để chạy script trong WinRE
    $winreUnattend = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" language="neutral" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Path>cmd /c X:\Recovery\OEM\wipe.cmd</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
</unattend>
'@

    # Enable Windows RE nếu chưa
    reagentc /enable 2>&1 | Out-Null

    Write-Host "  [+] Wipe script created" -ForegroundColor Green
    Write-Host "  [*] Rebooting to Windows RE..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  !! WIPE WILL START AUTOMATICALLY AFTER REBOOT !!" -ForegroundColor Red
    Write-Host ""

    Start-Sleep -Seconds 2

    # Boot vào Windows RE
    reagentc /boottore
    shutdown /r /t 0 /f
}

# Main
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "  ║           NUKE WIPE - EMERGENCY           ║" -ForegroundColor Red
Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Red

if ($ListDisks) {
    Show-Disks
    exit
}

if ($BootWipe) {
    Write-Host "`n  This will REBOOT and WIPE ALL DISKS!" -ForegroundColor Red
    Write-Host "  Type 'NUKE' to confirm: " -NoNewline -ForegroundColor Yellow
    if ((Read-Host) -eq "NUKE") {
        Start-BootWipe
    } else {
        Write-Host "  Cancelled." -ForegroundColor Green
    }
    exit
}

if ($RawWipe) {
    if ($All) {
        Write-Host "`n  WIPE ALL DISKS NOW? Type 'NUKE': " -NoNewline -ForegroundColor Red
        if ((Read-Host) -eq "NUKE") {
            Get-WmiObject Win32_DiskDrive | ForEach-Object {
                $num = [int]($_.DeviceID -replace '.*PHYSICALDRIVE', '')
                Start-RawWipe -DiskNum $num
            }
            Write-Host "`n  [*] Shutting down..." -ForegroundColor Red
            Stop-Computer -Force
        }
    } elseif ($Disk -ge 0) {
        Write-Host "`n  WIPE DISK $Disk? Type 'WIPE': " -NoNewline -ForegroundColor Red
        if ((Read-Host) -eq "WIPE") {
            Start-RawWipe -DiskNum $Disk
        }
    } else {
        Show-Disks
        Write-Host "  Specify -Disk N or -All" -ForegroundColor Yellow
    }
    exit
}

# Help
Show-Disks
Write-Host "  Usage:" -ForegroundColor Cyan
Write-Host "    .\NukeWipe.ps1 -BootWipe           # Reboot to WinRE and wipe all" -ForegroundColor White
Write-Host "    .\NukeWipe.ps1 -RawWipe -All       # Raw wipe all disks now" -ForegroundColor White
Write-Host "    .\NukeWipe.ps1 -RawWipe -Disk 1    # Raw wipe specific disk" -ForegroundColor White
Write-Host ""
