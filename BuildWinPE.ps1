#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Build WinPE USB with auto-wipe script
.DESCRIPTION
    Creates bootable WinPE USB that automatically wipes all disks on boot
.PARAMETER USBDrive
    USB drive letter (e.g., E)
.PARAMETER CreateISO
    Create ISO file instead of USB
.EXAMPLE
    .\BuildWinPE.ps1 -USBDrive E
    .\BuildWinPE.ps1 -CreateISO
#>

param(
    [string]$USBDrive,
    [switch]$CreateISO
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "     BUILD WINPE - Auto Wipe All Disks" -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""

# Check Windows ADK
$adkPath = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit"
$winpePath = "$adkPath\Windows Preinstallation Environment"
$deployTools = "$adkPath\Deployment Tools"

if (-not (Test-Path $winpePath)) {
    Write-Host "  [!] Windows ADK with WinPE not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Please install Windows ADK:" -ForegroundColor Yellow
    Write-Host "  1. Download: https://go.microsoft.com/fwlink/?linkid=2243390" -ForegroundColor White
    Write-Host "  2. Install 'Deployment Tools'" -ForegroundColor White
    Write-Host "  3. Download WinPE add-on: https://go.microsoft.com/fwlink/?linkid=2243391" -ForegroundColor White
    Write-Host "  4. Install 'Windows PE'" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "  [+] Windows ADK found" -ForegroundColor Green

# Setup paths
$workDir = "$env:TEMP\WinPE_Wipe"
$mountDir = "$workDir\mount"
$mediaDir = "$workDir\media"
$arch = "amd64"

# Clean previous
if (Test-Path $workDir) {
    Write-Host "  [*] Cleaning previous build..." -ForegroundColor Yellow
    dism /Unmount-Wim /MountDir:$mountDir /Discard 2>$null
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Create working directory
Write-Host "  [*] Creating WinPE environment..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $mountDir -Force | Out-Null

# Copy WinPE files
$winpeWim = "$winpePath\$arch\en-us\winpe.wim"
$winpeMedia = "$winpePath\$arch\Media"

if (-not (Test-Path $winpeWim)) {
    Write-Host "  [!] WinPE WIM not found: $winpeWim" -ForegroundColor Red
    exit 1
}

Copy-Item -Path $winpeMedia -Destination $mediaDir -Recurse -Force
Copy-Item -Path $winpeWim -Destination "$mediaDir\sources\boot.wim" -Force

Write-Host "  [+] WinPE files copied" -ForegroundColor Green

# Mount WIM
Write-Host "  [*] Mounting WinPE image..." -ForegroundColor Cyan
dism /Mount-Wim /WimFile:"$mediaDir\sources\boot.wim" /Index:1 /MountDir:$mountDir

if (-not (Test-Path "$mountDir\Windows")) {
    Write-Host "  [!] Mount failed!" -ForegroundColor Red
    exit 1
}

Write-Host "  [+] WinPE mounted" -ForegroundColor Green

# Create wipe script
Write-Host "  [*] Injecting wipe script..." -ForegroundColor Cyan

$startnetCmd = @'
@echo off
wpeinit
color 4F
cls
echo.
echo  ========================================================
echo       EMERGENCY DISK WIPE - ALL DATA WILL BE DESTROYED
echo  ========================================================
echo.
echo  Starting in 10 seconds... Press Ctrl+C to cancel
echo.
ping -n 11 127.0.0.1 > nul
echo.
echo  Wiping all disks with zeros (diskpart clean all)...
echo.

for /L %%d in (0,1,15) do (
    echo  [*] Disk %%d...
    (
        echo select disk %%d
        echo clean all
    ) | diskpart
)

echo.
echo  ========================================================
echo       WIPE COMPLETE - ALL DISKS DESTROYED
echo  ========================================================
echo.
echo  Press any key to shutdown...
pause > nul
wpeutil shutdown
'@

$startnetCmd | Out-File -FilePath "$mountDir\Windows\System32\startnet.cmd" -Encoding ASCII -Force
Write-Host "  [+] Wipe script injected into startnet.cmd" -ForegroundColor Green

# Unmount and commit
Write-Host "  [*] Saving changes..." -ForegroundColor Cyan
dism /Unmount-Wim /MountDir:$mountDir /Commit

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [!] Failed to save WIM" -ForegroundColor Red
    exit 1
}

Write-Host "  [+] WinPE image saved" -ForegroundColor Green

# Create ISO or USB
if ($CreateISO) {
    Write-Host "  [*] Creating ISO..." -ForegroundColor Cyan

    $oscdimg = "$deployTools\$arch\Oscdimg\oscdimg.exe"
    $etfsboot = "$deployTools\$arch\Oscdimg\etfsboot.com"
    $efisys = "$deployTools\$arch\Oscdimg\efisys.bin"
    $isoPath = "$PSScriptRoot\WinPE_Wipe.iso"

    & $oscdimg -m -o -u2 -udfver102 -bootdata:2`#p0,e,b$etfsboot`#pEF,e,b$efisys $mediaDir $isoPath

    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Green
    Write-Host "     ISO CREATED: $isoPath" -ForegroundColor Green
    Write-Host "  ================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Burn to USB with Rufus or similar tool" -ForegroundColor Yellow
}
elseif ($USBDrive) {
    $USBDrive = $USBDrive.TrimEnd(':')
    $usbPath = "${USBDrive}:"

    if (-not (Test-Path $usbPath)) {
        Write-Host "  [!] USB drive $usbPath not found!" -ForegroundColor Red
        exit 1
    }

    Write-Host "  [*] Formatting USB $usbPath..." -ForegroundColor Yellow
    Write-Host "  [!] ALL DATA ON USB WILL BE ERASED!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Press Enter to continue or Ctrl+C to cancel..." -ForegroundColor Yellow
    Read-Host

    # Format USB
    $disk = Get-Disk | Where-Object { $_.Path -match "PhysicalDrive" } | Where-Object {
        (Get-Partition -DiskNumber $_.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq $USBDrive })
    }

    if ($disk) {
        Clear-Disk -Number $disk.Number -RemoveData -RemoveOEM -Confirm:$false
        Initialize-Disk -Number $disk.Number -PartitionStyle MBR
        $part = New-Partition -DiskNumber $disk.Number -UseMaximumSize -IsActive -AssignDriveLetter
        Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel "WINPE_WIPE" -Confirm:$false
        $usbPath = "$($part.DriveLetter):"
    }

    Write-Host "  [*] Copying WinPE to USB..." -ForegroundColor Cyan
    Copy-Item -Path "$mediaDir\*" -Destination $usbPath -Recurse -Force

    # Make bootable
    $bootsect = "$deployTools\$arch\bootsect.exe"
    & $bootsect /nt60 $usbPath /mbr

    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Green
    Write-Host "     USB READY: $usbPath" -ForegroundColor Green
    Write-Host "  ================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Boot from USB to auto-wipe all disks" -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "  WinPE files ready at: $mediaDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    .\BuildWinPE.ps1 -USBDrive E      # Create bootable USB" -ForegroundColor White
    Write-Host "    .\BuildWinPE.ps1 -CreateISO       # Create ISO file" -ForegroundColor White
}

# Cleanup
Remove-Item $mountDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
