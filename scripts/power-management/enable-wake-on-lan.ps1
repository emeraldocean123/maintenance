# Re-enable Wake-on-LAN Script - Run as Administrator
Write-Host "=== Re-enabling Wake-on-LAN ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Not running as Administrator!" -ForegroundColor Red
    Write-Host "Please run this script as Administrator" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "Re-enabling Wake-on-LAN for network adapters..." -ForegroundColor Yellow
Write-Host ""

# Re-enable wake for Ethernet adapter
try {
    powercfg /deviceenablewake "Killer E5000 5 Gigabit Ethernet Controller"
    Write-Host "✓ Enabled wake for Killer Ethernet (Wake-on-LAN)" -ForegroundColor Green
} catch {
    Write-Host "× Error enabling Killer Ethernet wake" -ForegroundColor Red
}

# Keep Wi-Fi wake disabled (usually not needed for Wake-on-LAN)
Write-Host "• Keeping Wi-Fi wake disabled (not needed for Wake-on-LAN)" -ForegroundColor Gray

# Verify current wake devices
Write-Host ""
Write-Host "Current devices that can wake the system:" -ForegroundColor Yellow
powercfg /devicequery wake_armed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }

Write-Host ""
Write-Host "Wake-on-LAN has been re-enabled for Ethernet!" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"