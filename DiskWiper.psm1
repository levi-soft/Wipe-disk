#Requires -RunAsAdministrator
#Requires -Version 5.1
<#
.SYNOPSIS
    DiskWiper - Professional Emergency Disk Wipe Tool
.DESCRIPTION
    Raw disk access wipe tool - writes directly to physical disk sectors.
    Bypasses filesystem, immediately destroys data.
.NOTES
    Author: Emergency Wipe Project
    Version: 2.0
    WARNING: Data is UNRECOVERABLE after wipe!
#>

Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public class RawDisk
{
    // CreateFile flags
    const uint GENERIC_READ = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ = 0x00000001;
    const uint FILE_SHARE_WRITE = 0x00000002;
    const uint OPEN_EXISTING = 3;
    const uint FILE_FLAG_NO_BUFFERING = 0x20000000;
    const uint FILE_FLAG_WRITE_THROUGH = 0x80000000;

    // IOCTL codes
    const uint FSCTL_LOCK_VOLUME = 0x00090018;
    const uint FSCTL_UNLOCK_VOLUME = 0x0009001C;
    const uint FSCTL_DISMOUNT_VOLUME = 0x00090020;
    const uint IOCTL_DISK_GET_DRIVE_GEOMETRY = 0x00070000;
    const uint IOCTL_DISK_GET_LENGTH_INFO = 0x0007405C;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    static extern SafeFileHandle CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(
        SafeFileHandle hDevice,
        uint dwIoControlCode,
        IntPtr lpInBuffer,
        uint nInBufferSize,
        IntPtr lpOutBuffer,
        uint nOutBufferSize,
        out uint lpBytesReturned,
        IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteFile(
        SafeFileHandle hFile,
        byte[] lpBuffer,
        uint nNumberOfBytesToWrite,
        out uint lpNumberOfBytesWritten,
        IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetFilePointerEx(
        SafeFileHandle hFile,
        long liDistanceToMove,
        out long lpNewFilePointer,
        uint dwMoveMethod);

    [StructLayout(LayoutKind.Sequential)]
    struct DISK_GEOMETRY
    {
        public long Cylinders;
        public int MediaType;
        public int TracksPerCylinder;
        public int SectorsPerTrack;
        public int BytesPerSector;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct GET_LENGTH_INFORMATION
    {
        public long Length;
    }

    public static SafeFileHandle OpenDisk(int diskNumber)
    {
        string path = @"\\.\PhysicalDrive" + diskNumber;
        SafeFileHandle handle = CreateFile(
            path,
            GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            IntPtr.Zero,
            OPEN_EXISTING,
            FILE_FLAG_NO_BUFFERING | FILE_FLAG_WRITE_THROUGH,
            IntPtr.Zero);

        if (handle.IsInvalid)
        {
            throw new IOException("Cannot open disk " + diskNumber + ". Error: " + Marshal.GetLastWin32Error());
        }
        return handle;
    }

    public static SafeFileHandle OpenVolume(string driveLetter)
    {
        string path = @"\\.\" + driveLetter.TrimEnd(':').TrimEnd('\\') + ":";
        SafeFileHandle handle = CreateFile(
            path,
            GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            IntPtr.Zero,
            OPEN_EXISTING,
            FILE_FLAG_NO_BUFFERING | FILE_FLAG_WRITE_THROUGH,
            IntPtr.Zero);

        if (handle.IsInvalid)
        {
            throw new IOException("Cannot open volume " + driveLetter + ". Error: " + Marshal.GetLastWin32Error());
        }
        return handle;
    }

    public static bool LockVolume(SafeFileHandle handle)
    {
        uint bytesReturned;
        return DeviceIoControl(handle, FSCTL_LOCK_VOLUME, IntPtr.Zero, 0, IntPtr.Zero, 0, out bytesReturned, IntPtr.Zero);
    }

    public static bool DismountVolume(SafeFileHandle handle)
    {
        uint bytesReturned;
        return DeviceIoControl(handle, FSCTL_DISMOUNT_VOLUME, IntPtr.Zero, 0, IntPtr.Zero, 0, out bytesReturned, IntPtr.Zero);
    }

    public static long GetDiskSize(SafeFileHandle handle)
    {
        uint bytesReturned;
        GET_LENGTH_INFORMATION info = new GET_LENGTH_INFORMATION();
        IntPtr ptr = Marshal.AllocHGlobal(Marshal.SizeOf(info));

        try
        {
            if (DeviceIoControl(handle, IOCTL_DISK_GET_LENGTH_INFO, IntPtr.Zero, 0, ptr, (uint)Marshal.SizeOf(info), out bytesReturned, IntPtr.Zero))
            {
                info = (GET_LENGTH_INFORMATION)Marshal.PtrToStructure(ptr, typeof(GET_LENGTH_INFORMATION));
                return info.Length;
            }
        }
        finally
        {
            Marshal.FreeHGlobal(ptr);
        }
        return -1;
    }

    public static bool WriteSector(SafeFileHandle handle, long offset, byte[] data)
    {
        long newPos;
        if (!SetFilePointerEx(handle, offset, out newPos, 0))
        {
            return false;
        }

        uint bytesWritten;
        return WriteFile(handle, data, (uint)data.Length, out bytesWritten, IntPtr.Zero);
    }

    public static bool WriteAt(SafeFileHandle handle, long offset, byte[] data, out uint bytesWritten)
    {
        bytesWritten = 0;
        long newPos;
        if (!SetFilePointerEx(handle, offset, out newPos, 0))
        {
            return false;
        }
        return WriteFile(handle, data, (uint)data.Length, out bytesWritten, IntPtr.Zero);
    }
}
"@

Add-Type -TypeDefinition @"
using System;
using System.Security.Cryptography;

public class WipePatterns
{
    private static RNGCryptoServiceProvider rng = new RNGCryptoServiceProvider();

    public static byte[] GetZeroPattern(int size)
    {
        return new byte[size];
    }

    public static byte[] GetOnePattern(int size)
    {
        byte[] data = new byte[size];
        for (int i = 0; i < size; i++) data[i] = 0xFF;
        return data;
    }

    public static byte[] GetRandomPattern(int size)
    {
        byte[] data = new byte[size];
        rng.GetBytes(data);
        return data;
    }

    public static byte[] GetPattern(int size, byte value)
    {
        byte[] data = new byte[size];
        for (int i = 0; i < size; i++) data[i] = value;
        return data;
    }

    public static byte[] GetDoDPattern(int size, int pass)
    {
        switch (pass)
        {
            case 0: return GetZeroPattern(size);
            case 1: return GetOnePattern(size);
            case 2: return GetRandomPattern(size);
            default: return GetRandomPattern(size);
        }
    }
}
"@

# Global variables
$script:BufferSize = 1MB
$script:SectorSize = 512

function Write-Banner {
    $banner = @"

 ╔══════════════════════════════════════════════════════════════════════╗
 ║                                                                      ║
 ║     ██████╗ ██╗███████╗██╗  ██╗    ██╗    ██╗██╗██████╗ ███████╗     ║
 ║     ██╔══██╗██║██╔════╝██║ ██╔╝    ██║    ██║██║██╔══██╗██╔════╝     ║
 ║     ██║  ██║██║███████╗█████╔╝     ██║ █╗ ██║██║██████╔╝█████╗       ║
 ║     ██║  ██║██║╚════██║██╔═██╗     ██║███╗██║██║██╔═══╝ ██╔══╝       ║
 ║     ██████╔╝██║███████║██║  ██╗    ╚███╔███╔╝██║██║     ███████╗     ║
 ║     ╚═════╝ ╚═╝╚══════╝╚═╝  ╚═╝     ╚══╝╚══╝ ╚═╝╚═╝     ╚══════╝     ║
 ║                                                                      ║
 ║              Professional Raw Disk Wipe Tool v2.0                    ║
 ║                                                                      ║
 ╚══════════════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Red
}

function Get-PhysicalDisks {
    $disks = @()

    Get-WmiObject -Class Win32_DiskDrive | ForEach-Object {
        $disk = @{
            Number = [int]($_.DeviceID -replace '.*PHYSICALDRIVE', '')
            Model = $_.Model
            Size = $_.Size
            SizeGB = [math]::Round($_.Size / 1GB, 2)
            MediaType = $_.MediaType
            InterfaceType = $_.InterfaceType
            Partitions = $_.Partitions
            IsSystem = $false
        }

        # Check if system disk
        $partitions = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($_.DeviceID)'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"
        foreach ($partition in $partitions) {
            $logicalDisks = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition"
            foreach ($logicalDisk in $logicalDisks) {
                if ($logicalDisk.DeviceID -eq $env:SystemDrive) {
                    $disk.IsSystem = $true
                }
            }
        }

        $disks += [PSCustomObject]$disk
    }

    return $disks | Sort-Object Number
}

function Show-DiskList {
    Write-Host "`n  Physical Disks:" -ForegroundColor Cyan
    Write-Host "  $('=' * 70)" -ForegroundColor DarkGray

    $disks = Get-PhysicalDisks
    foreach ($disk in $disks) {
        $sysTag = if ($disk.IsSystem) { " [SYSTEM]" } else { "" }
        $color = if ($disk.IsSystem) { "Red" } else { "White" }
        Write-Host ("  Disk {0}: {1} - {2} GB{3}" -f $disk.Number, $disk.Model, $disk.SizeGB, $sysTag) -ForegroundColor $color
    }

    Write-Host "  $('=' * 70)" -ForegroundColor DarkGray
    return $disks
}

function Invoke-DiskWipe {
    param(
        [Parameter(Mandatory)]
        [int]$DiskNumber,

        [Parameter()]
        [ValidateSet("Zero", "Random", "DoD", "Gutmann")]
        [string]$Method = "Zero",

        [Parameter()]
        [int]$Passes = 1,

        [Parameter()]
        [switch]$Quick
    )

    $disks = Get-PhysicalDisks
    $targetDisk = $disks | Where-Object { $_.Number -eq $DiskNumber }

    if (-not $targetDisk) {
        Write-Host "`n  [ERROR] Disk $DiskNumber not found!" -ForegroundColor Red
        return $false
    }

    Write-Host "`n  Target: Disk $DiskNumber - $($targetDisk.Model)" -ForegroundColor Yellow
    Write-Host "  Size: $($targetDisk.SizeGB) GB" -ForegroundColor Yellow
    Write-Host "  Method: $Method" -ForegroundColor Yellow

    if ($targetDisk.IsSystem) {
        Write-Host "`n  [WARNING] This is the SYSTEM disk!" -ForegroundColor Red
        Write-Host "  [WARNING] Windows will crash after MBR is wiped!" -ForegroundColor Red
    }

    try {
        Write-Host "`n  [*] Opening physical disk..." -ForegroundColor Cyan
        $handle = [RawDisk]::OpenDisk($DiskNumber)

        $diskSize = [RawDisk]::GetDiskSize($handle)
        if ($diskSize -le 0) {
            $diskSize = $targetDisk.Size
        }

        Write-Host "  [*] Disk size: $([math]::Round($diskSize / 1GB, 2)) GB" -ForegroundColor Cyan

        # Determine passes based on method
        $totalPasses = switch ($Method) {
            "Zero" { 1 }
            "Random" { $Passes }
            "DoD" { 3 }
            "Gutmann" { 35 }
            default { 1 }
        }

        Write-Host "  [*] Starting wipe ($totalPasses passes)..." -ForegroundColor Yellow
        Write-Host ""

        $startTime = Get-Date
        $bufferSize = if ($Quick) { 4MB } else { 1MB }

        for ($pass = 0; $pass -lt $totalPasses; $pass++) {
            Write-Host "  [Pass $($pass + 1)/$totalPasses]" -ForegroundColor Magenta

            # Generate pattern for this pass
            $pattern = switch ($Method) {
                "Zero" { [WipePatterns]::GetZeroPattern($bufferSize) }
                "Random" { [WipePatterns]::GetRandomPattern($bufferSize) }
                "DoD" { [WipePatterns]::GetDoDPattern($bufferSize, $pass) }
                "Gutmann" { [WipePatterns]::GetRandomPattern($bufferSize) }
                default { [WipePatterns]::GetZeroPattern($bufferSize) }
            }

            $written = 0L
            $lastPercent = -1

            while ($written -lt $diskSize) {
                $toWrite = [Math]::Min($bufferSize, $diskSize - $written)

                if ($toWrite -lt $bufferSize) {
                    # Last chunk - resize pattern
                    $pattern = switch ($Method) {
                        "Zero" { [WipePatterns]::GetZeroPattern($toWrite) }
                        "Random" { [WipePatterns]::GetRandomPattern($toWrite) }
                        "DoD" { [WipePatterns]::GetDoDPattern($toWrite, $pass) }
                        default { [WipePatterns]::GetZeroPattern($toWrite) }
                    }
                }

                $bytesWritten = 0
                $success = [RawDisk]::WriteAt($handle, $written, $pattern, [ref]$bytesWritten)

                if (-not $success -or $bytesWritten -eq 0) {
                    # Some sectors may be protected, skip them
                    $written += $bufferSize
                    continue
                }

                $written += $bytesWritten

                # Progress
                $percent = [math]::Floor(($written / $diskSize) * 100)
                if ($percent -ne $lastPercent -and $percent % 5 -eq 0) {
                    $elapsed = (Get-Date) - $startTime
                    $speed = $written / $elapsed.TotalSeconds / 1MB
                    Write-Host ("`r  Progress: {0}% - {1:N1} MB/s" -f $percent, $speed) -NoNewline -ForegroundColor Green
                    $lastPercent = $percent
                }

                # Regenerate random pattern each iteration for Random/DoD
                if ($Method -eq "Random" -or ($Method -eq "DoD" -and $pass -eq 2)) {
                    $pattern = [WipePatterns]::GetRandomPattern($bufferSize)
                }
            }
            Write-Host ""
        }

        $handle.Close()

        $endTime = Get-Date
        $duration = $endTime - $startTime

        Write-Host "`n  $('=' * 50)" -ForegroundColor Green
        Write-Host "  WIPE COMPLETE!" -ForegroundColor Green
        Write-Host "  Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
        Write-Host "  $('=' * 50)" -ForegroundColor Green

        return $true
    }
    catch {
        Write-Host "`n  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Start-EmergencyWipe {
    param(
        [Parameter(Mandatory)]
        [int]$DiskNumber,

        [Parameter()]
        [switch]$Force
    )

    if (-not $Force) {
        Write-Host "`n  [!] This will PERMANENTLY DESTROY all data on Disk $DiskNumber!" -ForegroundColor Red
        Write-Host "  [!] Type 'DESTROY' to confirm: " -ForegroundColor Red -NoNewline
        $confirm = Read-Host
        if ($confirm -ne "DESTROY") {
            Write-Host "  [*] Cancelled." -ForegroundColor Green
            return
        }
    }

    Invoke-DiskWipe -DiskNumber $DiskNumber -Method Zero -Quick
}

# Export functions
Export-ModuleMember -Function @(
    'Write-Banner',
    'Get-PhysicalDisks',
    'Show-DiskList',
    'Invoke-DiskWipe',
    'Start-EmergencyWipe'
)
