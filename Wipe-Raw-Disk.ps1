# Emergency Raw Disk Wipe
# WARNING: This will DESTROY all data on the specified disk!

param(
    [int]$DiskNumber = 0,
    [string]$Method = "zero",  # zero, random, dod3, dod7
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] Must run as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "EMERGENCY RAW DISK WIPE" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Show disk info
$disk = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
if (-not $disk) {
    Write-Host "[ERROR] Disk $DiskNumber not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Target Disk:" -ForegroundColor Yellow
Write-Host "  Number: $DiskNumber"
Write-Host "  Size: $([math]::Round($disk.Size / 1GB, 2)) GB"
Write-Host "  Model: $($disk.Model)"
Write-Host "  Serial: $($disk.SerialNumber)"
Write-Host "  Boot: $($disk.IsBoot)"
Write-Host "  System: $($disk.IsSystem)"
Write-Host ""

# Warning
if ($disk.IsBoot -or $disk.IsSystem) {
    Write-Host "[WARNING] This is a BOOT/SYSTEM disk!" -ForegroundColor Red
    Write-Host "[WARNING] Windows will likely prevent wiping it while running!" -ForegroundColor Red
    Write-Host ""
}

Write-Host "Wipe Method: $Method" -ForegroundColor Yellow
Write-Host ""
Write-Host "THIS WILL DESTROY ALL DATA ON DISK $DiskNumber!" -ForegroundColor Red
Write-Host "THIS CANNOT BE UNDONE!" -ForegroundColor Red
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Type 'WIPE' to continue, or anything else to cancel"
    if ($confirm -ne "WIPE") {
        Write-Host "[CANCELLED]" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "STARTING WIPE OPERATION" -ForegroundColor Red
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Method 1: DiskPart clean all (fastest, but limited)
Write-Host "[1/2] Attempting DiskPart clean all..." -ForegroundColor Yellow

$diskpartScript = @"
select disk $DiskNumber
clean all
"@

$diskpartScript | diskpart

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] DiskPart clean all completed!" -ForegroundColor Green
} else {
    Write-Host "[FAILED] DiskPart clean all failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
    Write-Host "[INFO] This is expected for system/boot disks" -ForegroundColor Yellow
}

# Method 2: Raw disk write (more aggressive)
Write-Host ""
Write-Host "[2/2] Attempting raw disk write..." -ForegroundColor Yellow

try {
    $diskPath = "\\.\PhysicalDrive$DiskNumber"
    $bufferSize = 1MB
    $buffer = New-Object byte[] $bufferSize

    # Fill buffer based on method
    switch ($Method) {
        "zero" {
            # Already zeros
            Write-Host "[INFO] Writing zeros..." -ForegroundColor Cyan
        }
        "random" {
            $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
            $rng.GetBytes($buffer)
            Write-Host "[INFO] Writing random data..." -ForegroundColor Cyan
        }
        default {
            Write-Host "[INFO] Writing zeros (default)..." -ForegroundColor Cyan
        }
    }

    # Open disk for writing
    $fileStream = [System.IO.File]::Open($diskPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

    $totalSize = $disk.Size
    $written = 0
    $lastPercent = 0

    Write-Host "[INFO] Writing to disk... (This will take a while)" -ForegroundColor Cyan

    while ($written -lt $totalSize) {
        $toWrite = [Math]::Min($bufferSize, $totalSize - $written)
        $fileStream.Write($buffer, 0, $toWrite)
        $written += $toWrite

        $percent = [math]::Floor(($written / $totalSize) * 100)
        if ($percent -ne $lastPercent -and $percent % 5 -eq 0) {
            Write-Host "  Progress: $percent% ($([math]::Round($written / 1GB, 2)) GB / $([math]::Round($totalSize / 1GB, 2)) GB)" -ForegroundColor Cyan
            $lastPercent = $percent
        }
    }

    $fileStream.Close()

    Write-Host "[OK] Raw disk write completed!" -ForegroundColor Green

} catch {
    Write-Host "[FAILED] Raw disk write failed: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Message -like "*access is denied*" -or $_.Exception.Message -like "*being used*") {
        Write-Host ""
        Write-Host "[INFO] Disk is locked by Windows (system/boot disk)" -ForegroundColor Yellow
        Write-Host "[INFO] To wipe system disk, you need to:" -ForegroundColor Yellow
        Write-Host "  1. Boot from USB/CD" -ForegroundColor Yellow
        Write-Host "  2. Use WinPE or Linux LiveCD" -ForegroundColor Yellow
        Write-Host "  3. Run wipe tool from there" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "WIPE OPERATION COMPLETED" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Check results above to see which methods succeeded." -ForegroundColor Yellow
Write-Host ""
