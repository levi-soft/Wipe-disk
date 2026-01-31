# Disk Wiper

Professional emergency disk wipe tool for Windows using **raw disk access**.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│  Opens \\.\PhysicalDriveX with GENERIC_WRITE                    │
│  ↓                                                              │
│  Writes directly to disk sectors (bypasses filesystem)         │
│  ↓                                                              │
│  Overwrites MBR/GPT, partition tables, all data                │
│  ↓                                                              │
│  Data is UNRECOVERABLE                                          │
└─────────────────────────────────────────────────────────────────┘
```

**No reboot required.** Writes directly to physical disk. If system disk is wiped, Windows crashes immediately but data is already destroyed.

## Files

| File | Description |
|------|-------------|
| `PanicWipe.bat` | **EMERGENCY** - One click wipe ALL disks, no confirmation |
| `Wipe.bat` | Interactive wipe with disk selection |
| `Wipe.ps1` | PowerShell interface with options |
| `DiskWiper.psm1` | Core module with raw disk access |

## Usage

### Emergency (No Confirmation)

```
Double-click PanicWipe.bat
→ Immediately wipes ALL physical disks
→ Shuts down when complete
```

### Interactive

```powershell
# List disks
.\Wipe.ps1 -List

# Wipe disk 1 with zeros
.\Wipe.ps1 -Disk 1 -Method Zero

# Wipe disk 1 with DoD standard (3 passes)
.\Wipe.ps1 -Disk 1 -Method DoD

# Wipe without confirmation (DANGEROUS)
.\Wipe.ps1 -Disk 1 -Method Zero -Force
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
