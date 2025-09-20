# Fix Sleep Issues Script - Run as Administrator
# Right-click this file and select "Run with PowerShell" as Administrator

Write-Host "=== Fixing Sleep Issues ===" -ForegroundColor Cyan
Write-Host "This script needs to run as Administrator" -ForegroundColor Yellow
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Not running as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click this script and select 'Run as Administrator'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "Running as Administrator - proceeding with fixes..." -ForegroundColor Green
Write-Host ""

# Disable wake for network adapters
Write-Host "1. Disabling wake capability for network adapters..." -ForegroundColor Yellow
try {
    powercfg /devicedisablewake "Killer E5000 5 Gigabit Ethernet Controller"
    Write-Host "   - Disabled wake for Killer Ethernet" -ForegroundColor Green
} catch {
    Write-Host "   - Error disabling Killer Ethernet wake" -ForegroundColor Red
}

try {
    powercfg /devicedisablewake "Killer(TM) Wi-Fi 7 BE1750w 320MHz Wireless Network Adapter (BE200D2W)"
    Write-Host "   - Disabled wake for Killer Wi-Fi" -ForegroundColor Green
} catch {
    Write-Host "   - Error disabling Killer Wi-Fi wake" -ForegroundColor Red
}

# Disable wake for USB4 Root Router
Write-Host ""
Write-Host "2. Disabling wake capability for USB devices..." -ForegroundColor Yellow
try {
    powercfg /devicedisablewake "USB4 Root Router (2.0)"
    Write-Host "   - Disabled wake for USB4 Root Router" -ForegroundColor Green
} catch {
    Write-Host "   - Error disabling USB4 wake" -ForegroundColor Red
}

# Enable USB selective suspend
Write-Host ""
Write-Host "3. Enabling USB selective suspend..." -ForegroundColor Yellow
powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
powercfg /SETACTIVE SCHEME_CURRENT
Write-Host "   - USB selective suspend enabled" -ForegroundColor Green

# Disable wake timers
Write-Host ""
Write-Host "4. Disabling wake timers..." -ForegroundColor Yellow
powercfg /SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d 0
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d 0
powercfg /SETACTIVE SCHEME_CURRENT
Write-Host "   - Wake timers disabled" -ForegroundColor Green

# Disable network connectivity in standby
Write-Host ""
Write-Host "5. Configuring Modern Standby settings..." -ForegroundColor Yellow
powercfg /SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 f15576e8-98b7-4186-b944-eafa664402d9 0
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 f15576e8-98b7-4186-b944-eafa664402d9 0
powercfg /SETACTIVE SCHEME_CURRENT
Write-Host "   - Network connectivity in standby disabled" -ForegroundColor Green

# Verify changes
Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan
Write-Host "Devices that can still wake the system:" -ForegroundColor Yellow
$wakeDevices = powercfg /devicequery wake_armed
if ($wakeDevices) {
    $wakeDevices | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
} else {
    Write-Host "   None - all wake sources disabled!" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Additional Recommendations ===" -ForegroundColor Cyan
Write-Host "1. Close unnecessary Microsoft Edge tabs/windows" -ForegroundColor White
Write-Host "2. Check Windows Update settings - disable 'Wake to install updates'" -ForegroundColor White
Write-Host "3. In Device Manager, for each network adapter:" -ForegroundColor White
Write-Host "   - Right-click -> Properties -> Power Management tab" -ForegroundColor Gray
Write-Host "   - Uncheck 'Allow this device to wake the computer'" -ForegroundColor Gray
Write-Host ""
Write-Host "Sleep issues should now be fixed!" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"