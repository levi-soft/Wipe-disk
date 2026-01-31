#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Emergency Disk Wipe Tool - Main Interface
.DESCRIPTION
    Professional raw disk wipe tool with multiple secure erase methods.
.PARAMETER Disk
    Physical disk number to wipe (0, 1, 2, etc.)
.PARAMETER Method
    Wipe method: Zero, Random, DoD, Gutmann
.PARAMETER Passes
    Number of passes (for Random method)
.PARAMETER List
    List all physical disks
.PARAMETER Force
    Skip confirmation (DANGEROUS!)
.EXAMPLE
    .\Wipe.ps1 -List
    .\Wipe.ps1 -Disk 1 -Method Zero
    .\Wipe.ps1 -Disk 1 -Method DoD -Force
#>

param(
    [Parameter()]
    [int]$Disk = -1,

    [Parameter()]
    [ValidateSet("Zero", "Random", "DoD", "Gutmann")]
    [string]$Method = "Zero",

    [Parameter()]
    [int]$Passes = 1,

    [Parameter()]
    [switch]$List,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Quick
)

# Import module
$modulePath = Join-Path $PSScriptRoot "DiskWiper.psm1"
Import-Module $modulePath -Force

Write-Banner

if ($List -or $Disk -lt 0) {
    $disks = Show-DiskList

    if ($Disk -lt 0) {
        Write-Host "`n  Usage:" -ForegroundColor Cyan
        Write-Host "    .\Wipe.ps1 -Disk <number> -Method <method> [-Force]" -ForegroundColor White
        Write-Host ""
        Write-Host "  Methods:" -ForegroundColor Cyan
        Write-Host "    Zero    - Single pass zeros (fast)" -ForegroundColor White
        Write-Host "    Random  - Random data (-Passes N)" -ForegroundColor White
        Write-Host "    DoD     - DoD 5220.22-M (3 passes)" -ForegroundColor White
        Write-Host "    Gutmann - Gutmann 35 passes (slow)" -ForegroundColor White
        Write-Host ""
        Write-Host "  Examples:" -ForegroundColor Cyan
        Write-Host "    .\Wipe.ps1 -Disk 1 -Method Zero" -ForegroundColor Gray
        Write-Host "    .\Wipe.ps1 -Disk 1 -Method DoD -Force" -ForegroundColor Gray
        Write-Host ""
    }
    exit
}

# Confirm if not forced
if (-not $Force) {
    $disks = Get-PhysicalDisks
    $target = $disks | Where-Object { $_.Number -eq $Disk }

    if (-not $target) {
        Write-Host "`n  [ERROR] Disk $Disk not found!" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n  Target: Disk $Disk - $($target.Model)" -ForegroundColor Yellow
    Write-Host "  Size: $($target.SizeGB) GB" -ForegroundColor Yellow
    Write-Host "  Method: $Method" -ForegroundColor Yellow

    if ($target.IsSystem) {
        Write-Host "`n  [!!!] WARNING: This is the SYSTEM DISK!" -ForegroundColor Red
        Write-Host "  [!!!] Windows will CRASH immediately after wipe starts!" -ForegroundColor Red
        Write-Host "  [!!!] This is IRREVERSIBLE!" -ForegroundColor Red
    }

    Write-Host "`n  Type 'WIPE' to confirm: " -ForegroundColor Red -NoNewline
    $confirm = Read-Host
    if ($confirm -ne "WIPE") {
        Write-Host "  Cancelled." -ForegroundColor Green
        exit
    }
}

# Execute wipe
Invoke-DiskWipe -DiskNumber $Disk -Method $Method -Passes $Passes -Quick:$Quick
