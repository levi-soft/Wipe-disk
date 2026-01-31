#Requires -RunAsAdministrator
<#
.SYNOPSIS
    PANIC WIPE - Instant wipe ALL disks, no confirmation
.DESCRIPTION
    Emergency wipe - destroys ALL physical disks immediately.
    No prompts, no confirmation. Use with extreme caution.
.NOTES
    This will crash Windows if system disk is wiped.
#>

# Import module
$modulePath = Join-Path $PSScriptRoot "DiskWiper.psm1"
Import-Module $modulePath -Force

Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "  ║         PANIC WIPE - ALL DISKS            ║" -ForegroundColor Red
Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

# Get all disks and wipe them all
$disks = Get-PhysicalDisks

foreach ($disk in $disks) {
    Write-Host "  [*] Wiping Disk $($disk.Number): $($disk.Model)..." -ForegroundColor Yellow

    try {
        $handle = [RawDisk]::OpenDisk($disk.Number)
        $diskSize = [RawDisk]::GetDiskSize($handle)
        if ($diskSize -le 0) { $diskSize = $disk.Size }

        $bufferSize = 4MB
        $pattern = [WipePatterns]::GetZeroPattern($bufferSize)
        $written = 0L

        while ($written -lt $diskSize) {
            $toWrite = [Math]::Min($bufferSize, $diskSize - $written)
            if ($toWrite -lt $bufferSize) {
                $pattern = [WipePatterns]::GetZeroPattern($toWrite)
            }

            $bytesWritten = 0
            [RawDisk]::WriteAt($handle, $written, $pattern, [ref]$bytesWritten) | Out-Null
            $written += [Math]::Max($bytesWritten, $bufferSize)

            $percent = [math]::Floor(($written / $diskSize) * 100)
            if ($percent % 10 -eq 0) {
                Write-Host ("`r  Disk $($disk.Number): {0}%" -f $percent) -NoNewline -ForegroundColor Green
            }
        }

        $handle.Close()
        Write-Host "`r  Disk $($disk.Number): DONE                    " -ForegroundColor Green
    }
    catch {
        Write-Host "`r  Disk $($disk.Number): ERROR - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "  [*] All disks wiped. Shutting down..." -ForegroundColor Red
Start-Sleep -Seconds 2
Stop-Computer -Force
