# Disk Wiper

Professional emergency disk wipe tool for Windows.

## Two Methods

### Method 1: Raw Disk Access (Instant)

```
Opens \\.\PhysicalDriveX → Direct sector write → Immediate destruction
```
- No reboot required
- Windows crashes if system disk is wiped (but data already destroyed)

### Method 2: Boot Wipe (Like AOMEI)

```
Setup → Reboot → Boot into PreOS → Wipe all disks → Shutdown
```
- Proper PreOS environment
- Can cleanly wipe system disk
- Uses diskpart clean all

## Files

```
Wipe-disk/
├── PanicWipe.bat           # INSTANT - Raw wipe all disks now
├── Wipe.bat                # Interactive raw disk wipe
├── Wipe.ps1                # PowerShell interface
├── DiskWiper.psm1          # Core raw disk module
│
└── BootWipe/               # PreOS Boot Wipe (like AOMEI)
    ├── PanicBoot.bat       # One-click reboot + wipe all
    ├── BootWipe.bat        # Interactive setup
    └── CreateBootWipe.ps1  # PowerShell setup
```

## Usage

### PANIC MODE (No Confirmation)

| Action | Method |
|--------|--------|
| `PanicWipe.bat` | Raw wipe ALL disks instantly (Windows crashes) |
| `BootWipe/PanicBoot.bat` | Reboot → Wipe all → Shutdown |

### Interactive Raw Wipe

```powershell
.\Wipe.ps1 -List                        # List disks
.\Wipe.ps1 -Disk 1 -Method Zero         # Wipe disk 1
.\Wipe.ps1 -Disk 1 -Method DoD -Force   # No confirmation
```

### Boot Wipe (PreOS)

```powershell
# Setup boot wipe
.\BootWipe\CreateBootWipe.ps1 -Setup

# Cancel before reboot
.\BootWipe\CreateBootWipe.ps1 -Cancel

# Create USB tool
.\BootWipe\CreateBootWipe.ps1 -CreateUSB -USBDrive E
```

## Wipe Methods

| Method | Passes | Description | Security |
|--------|--------|-------------|----------|
| `Zero` | 1 | Write zeros | Standard |
| `Random` | N | Random data | High |
| `DoD` | 3 | DoD 5220.22-M (0x00, 0xFF, random) | Military |
| `Gutmann` | 35 | Gutmann algorithm | Maximum |

## Technical Details

- Uses Windows API `CreateFile` with `\\.\PhysicalDriveX`
- Flags: `FILE_FLAG_NO_BUFFERING | FILE_FLAG_WRITE_THROUGH`
- Writes directly to disk sectors, bypassing filesystem cache
- Can wipe system disk while Windows is running (will cause BSOD)
- Buffer size: 1-4 MB for optimal performance

## Requirements

- Windows 10/11
- Administrator privileges
- PowerShell 5.1+

## Warning

```
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   DATA IS PERMANENTLY DESTROYED AND CANNOT BE RECOVERED           ║
║                                                                   ║
║   • Wiping system disk will crash Windows immediately             ║
║   • No confirmation in PanicWipe mode                             ║
║   • Affects ALL connected physical disks in Panic mode            ║
║   • USE ONLY IN GENUINE EMERGENCIES                               ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
```

## License

MIT License - Use at your own risk.
