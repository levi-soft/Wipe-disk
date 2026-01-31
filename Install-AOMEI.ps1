<#
.SYNOPSIS
    Silent installation script for AOMEI software
.DESCRIPTION
    This script silently installs AOMEI Backupper or Partition Assistant
.PARAMETER InstallerPath
    Path to the AOMEI installer executable
.PARAMETER InstallDir
    Custom installation directory (optional)
.PARAMETER Product
    Product type: "Backupper" or "Partition" (auto-detect if not specified)
.EXAMPLE
    .\Install-AOMEI.ps1 -InstallerPath "C:\Downloads\AOMEIBackupper.exe"
.EXAMPLE
    .\Install-AOMEI.ps1 -InstallerPath "C:\Downloads\AOMEIPartition.exe" -InstallDir "D:\AOMEI"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,

    [Parameter(Mandatory = $false)]
    [string]$InstallDir = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Backupper", "Partition", "Auto")]
    [string]$Product = "Auto"
)

# ============================================
# Configuration
# ============================================
$ErrorActionPreference = "Stop"
$LogFile = Join-Path $env:TEMP "AOMEI_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ============================================
# Functions
# ============================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

function Test-AdminPrivilege {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ProductType {
    param([string]$Path)

    $fileName = [System.IO.Path]::GetFileName($Path).ToLower()

    if ($fileName -match "backupper|backup|ab") {
        return "Backupper"
    }
    elseif ($fileName -match "partition|pa") {
        return "Partition"
    }
    else {
        # Try to detect from file properties
        try {
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
            if ($versionInfo.ProductName -match "Backupper") {
                return "Backupper"
            }
            elseif ($versionInfo.ProductName -match "Partition") {
                return "Partition"
            }
        }
        catch {
            # Ignore errors
        }
        return "Unknown"
    }
}

function Install-AOMEI {
    param(
        [string]$Installer,
        [string]$TargetDir,
        [string]$ProductType
    )

    # Build silent install arguments
    # AOMEI uses NSIS installer with standard silent switches
    $arguments = @("/S")  # Silent mode

    # Add custom install directory if specified
    if (-not [string]::IsNullOrEmpty($TargetDir)) {
        # Ensure directory path ends without backslash for NSIS
        $TargetDir = $TargetDir.TrimEnd('\')
        $arguments += "/D=$TargetDir"
    }

    $argString = $arguments -join " "
    Write-Log "Starting silent installation..."
    Write-Log "Installer: $Installer"
    Write-Log "Arguments: $argString"
    Write-Log "Product: $ProductType"

    try {
        $process = Start-Process -FilePath $Installer `
                                 -ArgumentList $argString `
                                 -Wait `
                                 -PassThru `
                                 -NoNewWindow

        return $process.ExitCode
    }
    catch {
        Write-Log "Failed to start installer: $_" -Level "ERROR"
        return -1
    }
}

function Test-Installation {
    param([string]$ProductType, [string]$CustomDir)

    $searchPaths = @()

    if (-not [string]::IsNullOrEmpty($CustomDir)) {
        $searchPaths += $CustomDir
    }

    # Default installation paths
    $searchPaths += "${env:ProgramFiles}\AOMEI"
    $searchPaths += "${env:ProgramFiles(x86)}\AOMEI"
    $searchPaths += "${env:ProgramFiles}\AOMEI Backupper"
    $searchPaths += "${env:ProgramFiles(x86)}\AOMEI Backupper"
    $searchPaths += "${env:ProgramFiles}\AOMEI Partition Assistant"
    $searchPaths += "${env:ProgramFiles(x86)}\AOMEI Partition Assistant"

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $exeFiles = Get-ChildItem -Path $path -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match "AOMEI|Backupper|Partition" }
            if ($exeFiles) {
                return $path
            }
        }
    }

    return $null
}

# ============================================
# Main Script
# ============================================
Write-Log "========================================"
Write-Log "AOMEI Silent Installer Script"
Write-Log "========================================"

# Check admin privileges
if (-not (Test-AdminPrivilege)) {
    Write-Log "This script requires administrator privileges!" -Level "ERROR"
    Write-Log "Please run PowerShell as Administrator and try again." -Level "ERROR"
    exit 1
}
Write-Log "Running with administrator privileges" -Level "SUCCESS"

# Validate installer path
if (-not (Test-Path $InstallerPath)) {
    Write-Log "Installer not found: $InstallerPath" -Level "ERROR"
    exit 1
}
Write-Log "Installer found: $InstallerPath" -Level "SUCCESS"

# Detect product type
if ($Product -eq "Auto") {
    $Product = Get-ProductType -Path $InstallerPath
    if ($Product -eq "Unknown") {
        Write-Log "Could not auto-detect product type. Proceeding with generic install." -Level "WARN"
        $Product = "Generic"
    }
}
Write-Log "Product type: $Product"

# Validate custom install directory
if (-not [string]::IsNullOrEmpty($InstallDir)) {
    $parentDir = Split-Path $InstallDir -Parent
    if (-not (Test-Path $parentDir)) {
        Write-Log "Parent directory does not exist: $parentDir" -Level "ERROR"
        exit 1
    }
    Write-Log "Custom install directory: $InstallDir"
}

# Run installation
Write-Log "----------------------------------------"
Write-Log "Starting installation process..."
$exitCode = Install-AOMEI -Installer $InstallerPath -TargetDir $InstallDir -ProductType $Product

# Check result
Write-Log "----------------------------------------"
if ($exitCode -eq 0) {
    Write-Log "Installation completed with exit code: $exitCode" -Level "SUCCESS"

    # Verify installation
    $installPath = Test-Installation -ProductType $Product -CustomDir $InstallDir
    if ($installPath) {
        Write-Log "Installation verified at: $installPath" -Level "SUCCESS"
    }
    else {
        Write-Log "Could not verify installation path (this may be normal)" -Level "WARN"
    }
}
else {
    Write-Log "Installation failed with exit code: $exitCode" -Level "ERROR"
    Write-Log "Check the log file for details: $LogFile" -Level "ERROR"
    exit $exitCode
}

Write-Log "========================================"
Write-Log "Installation complete!"
Write-Log "Log file: $LogFile"
Write-Log "========================================"

exit 0
