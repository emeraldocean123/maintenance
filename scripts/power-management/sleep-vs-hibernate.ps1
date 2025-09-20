# Sleep vs Hibernate Comparison and Configuration Script
Write-Host "=== Sleep vs Hibernate for Your System ===" -ForegroundColor Cyan
Write-Host ""

# System specs
Write-Host "Your System:" -ForegroundColor Yellow
Write-Host "  • Alienware 18 Area-51 with 64GB RAM" -ForegroundColor White
Write-Host "  • Modern Standby (S0) - No traditional S3 sleep" -ForegroundColor White
Write-Host "  • Fast NVMe SSDs" -ForegroundColor White
Write-Host ""

Write-Host "=== MODERN STANDBY (S0 Sleep) ===" -ForegroundColor Green
Write-Host "What it does:" -ForegroundColor Yellow
Write-Host "  • Keeps RAM powered, system in ultra-low power state"
Write-Host "  • Instant wake (< 1 second)"
Write-Host "  • Can maintain network connections"
Write-Host "  • Battery drain: ~1-2% per hour"
Write-Host ""
Write-Host "PROS:" -ForegroundColor Green
Write-Host "  ✓ Instant resume"
Write-Host "  ✓ Background tasks can run (updates, emails)"
Write-Host "  ✓ Wake-on-LAN works"
Write-Host ""
Write-Host "CONS:" -ForegroundColor Red
Write-Host "  × Uses battery/power continuously"
Write-Host "  × Can wake unexpectedly"
Write-Host "  × Your issue: Requires 2 attempts to sleep"
Write-Host ""

Write-Host "=== HIBERNATE ===" -ForegroundColor Blue
Write-Host "What it does:" -ForegroundColor Yellow
Write-Host "  • Saves RAM contents to disk (hibernation file)"
Write-Host "  • Completely powers off"
Write-Host "  • Resume time: 10-20 seconds with NVMe"
Write-Host "  • Zero power consumption"
Write-Host ""
Write-Host "PROS:" -ForegroundColor Green
Write-Host "  ✓ Zero power consumption"
Write-Host "  ✓ Can't wake unexpectedly"
Write-Host "  ✓ Perfect for overnight/long periods"
Write-Host "  ✓ Wake-on-LAN still works (if enabled)"
Write-Host ""
Write-Host "CONS:" -ForegroundColor Red
Write-Host "  × Slower resume (10-20 seconds)"
Write-Host "  × Uses 64GB disk space (hiberfil.sys)"
Write-Host "  × More SSD writes over time"
Write-Host ""

Write-Host "=== RECOMMENDATION FOR YOU ===" -ForegroundColor Cyan
Write-Host "Given your issues with Modern Standby requiring 2 attempts," -ForegroundColor Yellow
Write-Host "HIBERNATE might be better because:" -ForegroundColor Yellow
Write-Host "  1. More reliable - works first time"
Write-Host "  2. Zero power consumption"
Write-Host "  3. With your fast NVMe, resume is still quick (10-20 sec)"
Write-Host "  4. Wake-on-LAN still works for remote access"
Write-Host ""

# Check current hibernate status
Write-Host "=== Current Hibernate Status ===" -ForegroundColor Cyan
$hibernateSize = Get-CimInstance Win32_PageFileUsage | Where-Object {$_.Name -like "*hiberfil.sys"}
if (Test-Path "C:\hiberfil.sys") {
    $size = (Get-Item "C:\hiberfil.sys" -Force).Length / 1GB
    Write-Host "Hibernate is ENABLED" -ForegroundColor Green
    Write-Host "Hibernation file size: $([math]::Round($size, 2)) GB" -ForegroundColor Gray
} else {
    Write-Host "Hibernate is DISABLED" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Quick Actions ===" -ForegroundColor Cyan
Write-Host "1. To add Hibernate to Start Menu power options:" -ForegroundColor Yellow
Write-Host "   powercfg /hibernate on" -ForegroundColor White
Write-Host "   Then: Settings > System > Power & battery > Power button settings" -ForegroundColor Gray
Write-Host "   Check 'Hibernate' under Shutdown settings" -ForegroundColor Gray
Write-Host ""
Write-Host "2. To set power button to Hibernate:" -ForegroundColor Yellow
Write-Host "   Control Panel > Power Options > Choose what power buttons do" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Create desktop shortcuts:" -ForegroundColor Yellow
Write-Host "   • Sleep:     shutdown /h /t 0  (for hibernate)" -ForegroundColor White
Write-Host "   • Hibernate: rundll32.exe powrprof.dll,SetSuspendState Hibernate" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to continue"