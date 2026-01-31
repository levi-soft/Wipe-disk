# Disk Wiper

Professional emergency disk wipe tool for Windows - **like AOMEI/MiniTool**.

## How It Works (AOMEI Style)

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Mount WinRE.wim (Windows Recovery Image)                   │
│  2. Inject wipe script into startnet.cmd                       │
│  3. Save and unmount WIM                                        │
│  4. reagentc /boottore → Reboot to WinRE                       │
│  5. WinRE boots → startnet.cmd runs automatically              │
│  6. diskpart clean all on ALL disks                            │
│  7. wpeutil shutdown                                            │
└─────────────────────────────────────────────────────────────────┘
```

**This is how AOMEI and MiniTool actually work** - they inject code into WinRE.

## Files

```
Wipe-disk/
├── PanicWipe.bat       # ONE CLICK - Inject + Reboot + Wipe All
├── PanicWipe.ps1       # Main script (WinRE injection)
├── NukeWipe.ps1        # Interactive with options
├── Wipe.ps1            # Raw disk access wipe
├── Wipe.bat            # Launcher
└── DiskWiper.psm1      # Core module
```

## Usage

### PANIC MODE (No Confirmation)

**Double-click `PanicWipe.bat`**

What happens:
1. Mounts WinRE.wim
2. Injects wipe script into startnet.cmd
3. Reboots to Windows RE
4. Automatically wipes ALL disks with `diskpart clean all`
5. Shuts down

### Interactive

```powershell
# Reboot to WinRE and wipe (with confirmation)
.\NukeWipe.ps1 -BootWipe

# Raw wipe all disks instantly
.\NukeWipe.ps1 -RawWipe -All

# Raw wipe specific disk
.\NukeWipe.ps1 -RawWipe -Disk 1

# List disks
.\NukeWipe.ps1 -ListDisks
```

## Methods

| Method | Description |
|--------|-------------|
| **WinRE Inject** | Modify WinRE → Reboot → Auto wipe (proper PreOS) |
| **Raw Disk** | Direct sector write via `\\.\PhysicalDriveX` |

## Technical Details

### WinRE Injection
- Locates `Winre.wim` via ReAgent.xml or Recovery partition
- Uses `Mount-WindowsImage` to mount WIM
- Modifies `startnet.cmd` (auto-runs on WinRE boot)
- Uses `reagentc /boottore` to boot into WinRE

### Raw Disk Access
- Opens `\\.\PhysicalDriveX` with `GENERIC_WRITE`
- Dismounts volumes with `FSCTL_DISMOUNT_VOLUME`
- Direct sector write with `FILE_FLAG_NO_BUFFERING`

## Requirements

- Windows 10/11
- Administrator privileges
- Windows RE enabled (default on most systems)

## Warning

```
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   ALL DATA WILL BE PERMANENTLY DESTROYED                          ║
║                                                                   ║
║   • PanicWipe has NO CONFIRMATION                                 ║
║   • Wipes ALL connected disks including system                    ║
║   • Data is UNRECOVERABLE                                         ║
║   • Machine will not boot after wipe                              ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
```

## License

MIT License - Use at your own risk.
