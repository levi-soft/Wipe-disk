#Requires -RunAsAdministrator
<#
.SYNOPSIS
    PANIC WIPE - Proper WinRE injection like AOMEI
.DESCRIPTION
    1. Mount WinRE WIM image
    2. Inject wipe script into startnet.cmd
    3. Unmount and commit
    4. Reboot to WinRE
    5. Script runs automatically, wipes all disks
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "  ║         PANIC WIPE - INJECTING            ║" -ForegroundColor Red
Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

# Bước 1: Tìm WinRE WIM
Write-Host "  [1/5] Locating WinRE..." -ForegroundColor Cyan

$reagentXml = "$env:SystemRoot\System32\Recovery\ReAgent.xml"
$winrePath = $null

if (Test-Path $reagentXml) {
    [xml]$xml = Get-Content $reagentXml
    $winreLocation = $xml.WindowsRE.WinreBCD.Location
    if ($winreLocation) {
        # Parse path từ ReAgent.xml
        $winrePath = $winreLocation -replace '\\\\Device\\\\HarddiskVolume\d+', ''
    }
}

# Tìm recovery partition
$recoveryPartition = Get-Partition | Where-Object { $_.Type -eq "Recovery" } | Select-Object -First 1

if (-not $recoveryPartition) {
    # Fallback - tìm trong Windows folder
    $winrePath = "$env:SystemRoot\System32\Recovery\Winre.wim"
}
else {
    # Mount recovery partition tạm thời
    $letter = ($recoveryPartition | Add-PartitionAccessPath -AssignDriveLetter -PassThru).AccessPaths[0]
    $winrePath = Join-Path $letter "Recovery\WindowsRE\Winre.wim"
}

if (-not (Test-Path $winrePath)) {
    $winrePath = "$env:SystemRoot\System32\Recovery\Winre.wim"
}

if (-not (Test-Path $winrePath)) {
    Write-Host "  [!] WinRE not found. Using alternative method..." -ForegroundColor Yellow

    # Alternative: Tạo boot entry với diskpart script
    $wipeCmd = @'
@echo off
echo WIPING ALL DISKS...
for /L %%d in (0,1,15) do (
    (echo sel dis %%d
     echo clean all) | diskpart >nul 2>&1
)
shutdown /s /t 0 /f
'@
    $wipeCmd | Out-File "C:\wipe.cmd" -Encoding ASCII -Force

    # Sử dụng bcdedit để tạo boot entry
    $guid = (bcdedit /copy "{current}" /d "WIPE ALL DISKS" 2>&1) -replace '.*(\{[^}]+\}).*', '$1'
    bcdedit /set $guid path \Windows\System32\cmd.exe | Out-Null
    bcdedit /set $guid systemroot \ | Out-Null
    bcdedit /bootsequence $guid /addfirst | Out-Null

    Write-Host "  [*] Rebooting..." -ForegroundColor Red
    shutdown /r /t 0 /f
    exit
}

Write-Host "  [+] Found: $winrePath" -ForegroundColor Green

# Bước 2: Mount WinRE WIM
Write-Host "  [2/5] Mounting WinRE image..." -ForegroundColor Cyan

$mountDir = "$env:TEMP\WinRE_Mount"
if (Test-Path $mountDir) { Remove-Item $mountDir -Recurse -Force }
New-Item -ItemType Directory -Path $mountDir -Force | Out-Null

# Disable WinRE trước để unlock file
reagentc /disable 2>&1 | Out-Null

# Copy WIM để edit
$wimCopy = "$env:TEMP\Winre_wipe.wim"
Copy-Item $winrePath $wimCopy -Force

# Mount
$mountResult = Mount-WindowsImage -ImagePath $wimCopy -Index 1 -Path $mountDir

if (-not $mountResult) {
    Write-Host "  [!] Cannot mount WinRE" -ForegroundColor Red
    exit 1
}

Write-Host "  [+] WinRE mounted" -ForegroundColor Green

# Bước 3: Inject wipe script
Write-Host "  [3/5] Injecting wipe script..." -ForegroundColor Cyan

$startnetPath = "$mountDir\Windows\System32\startnet.cmd"

$wipeScript = @'
@echo off
wpeinit
echo.
echo  ========================================
echo       EMERGENCY WIPE IN PROGRESS
echo  ========================================
echo.
echo  Wiping all disks...
for /L %%d in (0,1,15) do (
    echo   Disk %%d...
    (echo sel dis %%d
     echo clean all) | diskpart >nul 2>&1
)
echo.
echo  ========================================
echo       WIPE COMPLETE - POWERING OFF
echo  ========================================
echo.
wpeutil shutdown
'@

$wipeScript | Out-File $startnetPath -Encoding ASCII -Force
Write-Host "  [+] Script injected into startnet.cmd" -ForegroundColor Green

# Bước 4: Unmount và commit
Write-Host "  [4/5] Saving changes..." -ForegroundColor Cyan

Dismount-WindowsImage -Path $mountDir -Save
Remove-Item $mountDir -Recurse -Force -ErrorAction SilentlyContinue

# Copy modified WIM back
Copy-Item $wimCopy $winrePath -Force
Remove-Item $wimCopy -Force -ErrorAction SilentlyContinue

# Re-enable WinRE
reagentc /enable 2>&1 | Out-Null

Write-Host "  [+] WinRE modified" -ForegroundColor Green

# Bước 5: Reboot to WinRE
Write-Host "  [5/5] Rebooting to WinRE..." -ForegroundColor Red
Write-Host ""
Write-Host "  !! WIPE WILL START AUTOMATICALLY !!" -ForegroundColor Red
Write-Host ""

Start-Sleep -Seconds 2
reagentc /boottore
shutdown /r /t 0 /f
