# Power Management Scripts

Scripts for diagnosing and fixing Windows sleep, hibernate, and power management issues.

## Scripts

### 1. `diagnose-sleep.ps1`
Comprehensive diagnostic tool that checks:
- Available sleep states (S0/S3/Hibernate)
- Devices that can wake the system
- Current power requests from applications
- Last wake source
- Active wake timers
- USB selective suspend settings
- Common Modern Standby issues
- Network adapter wake settings

**Usage:** `pwsh -ExecutionPolicy Bypass -File diagnose-sleep.ps1`

### 2. `fix-sleep.ps1`
Fixes common sleep interruption issues:
- Disables wake capability for network adapters
- Disables wake for USB4 Root Router
- Enables USB selective suspend
- Disables wake timers
- Configures Modern Standby settings

**Usage:** Run as Administrator

### 3. `fix-double-sleep.ps1`
Addresses the "double-click sleep" issue with Modern Standby:
- Disables Fast Startup
- Sets system unattended sleep timeout
- Disables Away Mode
- Configures lock screen behavior
- Provides alternative solutions (hibernate, shortcuts)

**Usage:** Run as Administrator

### 4. `enable-wake-on-lan.ps1`
Re-enables Wake-on-LAN functionality:
- Enables wake for Ethernet adapter only
- Keeps Wi-Fi wake disabled
- Verifies current wake devices

**Usage:** Run as Administrator

### 5. `sleep-vs-hibernate.ps1`
Comparison tool and configuration guide:
- Explains Modern Standby (S0) vs Hibernate
- Shows pros/cons of each mode
- Checks current hibernate status
- Provides configuration commands
- Recommends best option for your system

**Usage:** `pwsh -ExecutionPolicy Bypass -File sleep-vs-hibernate.ps1`

## Common Issues & Solutions

### Issue: Sleep is immediately interrupted
Run `diagnose-sleep.ps1` first, then `fix-sleep.ps1` as Administrator

### Issue: Need to click sleep twice
Run `fix-double-sleep.ps1` as Administrator, or consider using Hibernate instead

### Issue: Want Wake-on-LAN for remote access
Run `enable-wake-on-lan.ps1` as Administrator to enable for Ethernet only

### Issue: Unsure whether to use Sleep or Hibernate
Run `sleep-vs-hibernate.ps1` for detailed comparison and recommendations

## Quick Commands

Enable Hibernate in Start Menu:
```powershell
powercfg /hibernate on
```

Create Hibernate shortcut:
```cmd
shutdown /h
```

Check wake-capable devices:
```powershell
powercfg /devicequery wake_armed
```

Check last wake source:
```powershell
powercfg /lastwake
```