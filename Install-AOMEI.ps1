<#
.SYNOPSIS
    Silent installation script for AOMEI software
.DESCRIPTION
    Automatically runs setup.exe in the same directory as this script
.EXAMPLE
    .\Install-AOMEI.ps1
#>

# ============================================
# Configuration
# ============================================
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallerPath = Join-Path $ScriptDir "setup.exe"
$LogFile = Join-Path $ScriptDir "AOMEI_Install.log"

# ============================================
# Functions
# ============================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARN"    { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
}

function Test-AdminPrivilege {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================
# Main Script
# ============================================
Write-Log "========================================"
Write-Log "AOMEI Silent Installer"
Write-Log "========================================"

# Check admin privileges
if (-not (Test-AdminPrivilege)) {
    Write-Log "Yeu cau quyen Administrator!" -Level "ERROR"
    Write-Log "Hay chay PowerShell voi quyen Admin." -Level "ERROR"
    pause
    exit 1
}
Write-Log "Dang chay voi quyen Administrator" -Level "SUCCESS"

# Check installer exists
if (-not (Test-Path $InstallerPath)) {
    Write-Log "Khong tim thay file: $InstallerPath" -Level "ERROR"
    Write-Log "Hay dat file setup.exe cung thu muc voi script nay." -Level "ERROR"
    pause
    exit 1
}
Write-Log "Tim thay installer: $InstallerPath" -Level "SUCCESS"

# Run silent installation
Write-Log "Bat dau cai dat..."
try {
    $process = Start-Process -FilePath $InstallerPath `
                             -ArgumentList "/S" `
                             -Wait `
                             -PassThru `
                             -NoNewWindow

    if ($process.ExitCode -eq 0) {
        Write-Log "Cai dat thanh cong!" -Level "SUCCESS"
    }
    else {
        Write-Log "Cai dat that bai. Exit code: $($process.ExitCode)" -Level "ERROR"
    }
}
catch {
    Write-Log "Loi khi chay installer: $_" -Level "ERROR"
}

Write-Log "========================================"
Write-Log "Log file: $LogFile"
pause
exit $process.ExitCode
