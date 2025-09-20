# Sleep Diagnostics Script
Write-Host "=== Sleep Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# Check power configuration
Write-Host "1. Available Sleep States:" -ForegroundColor Yellow
powercfg /a | Out-String | Write-Host

# Check wake-armed devices  
Write-Host "2. Devices that can wake the system:" -ForegroundColor Yellow
powercfg /devicequery wake_armed | Out-String | Write-Host

# Check power requests
Write-Host "3. Current Power Requests (apps preventing sleep):" -ForegroundColor Yellow
powercfg /requests | Out-String | Write-Host

# Check last wake source
Write-Host "4. Last Wake Source:" -ForegroundColor Yellow
powercfg /lastwake | Out-String | Write-Host

# Check wake timers
Write-Host "5. Active Wake Timers:" -ForegroundColor Yellow
powercfg /waketimers | Out-String | Write-Host

# Check USB selective suspend
Write-Host "6. USB Selective Suspend Settings:" -ForegroundColor Yellow
$usbSetting = powercfg /query SCHEME_CURRENT 2ed54b1-d7db-11db-b4d1-0050dabc7b8f 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
if ($usbSetting -match "Current AC Power Setting Index: (0x\w+)") {
    $value = [Convert]::ToInt32($matches[1], 16)
    if ($value -eq 0) {
        Write-Host "USB Selective Suspend: DISABLED (may prevent sleep)" -ForegroundColor Red
    } else {
        Write-Host "USB Selective Suspend: ENABLED" -ForegroundColor Green
    }
}

# Check Modern Standby issues
Write-Host ""
Write-Host "7. Checking for common Modern Standby issues:" -ForegroundColor Yellow

# Check for audio streams
$audioProcesses = Get-Process | Where-Object {$_.ProcessName -match "spotify|vlc|chrome|firefox|edge|brave|opera|musicbee|foobar|winamp|itunes|wmplayer"}
if ($audioProcesses) {
    Write-Host "Found potential audio/media processes:" -ForegroundColor Red
    $audioProcesses | Select-Object ProcessName, Id | Format-Table
}

# Check network activity
Write-Host ""
Write-Host "8. Network Adapter Wake Settings:" -ForegroundColor Yellow
Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object {
    $name = $_.Name
    $wakeonmagic = (Get-NetAdapterAdvancedProperty -Name $name -DisplayName "*Wake on Magic*" -ErrorAction SilentlyContinue).DisplayValue
    $wakeonpattern = (Get-NetAdapterAdvancedProperty -Name $name -DisplayName "*Wake on Pattern*" -ErrorAction SilentlyContinue).DisplayValue
    Write-Host "  $name :" -NoNewline
    if ($wakeonmagic -or $wakeonpattern) {
        Write-Host " Wake-on-LAN enabled" -ForegroundColor Yellow
    } else {
        Write-Host " Wake disabled" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Recommendations ===" -ForegroundColor Cyan
Write-Host "To fix sleep issues, run these commands as Administrator:" -ForegroundColor White
Write-Host ""
Write-Host "1. Disable network adapter wake (for Ethernet):" -ForegroundColor Green
Write-Host "   powercfg /devicedisablewake `"Killer E5000 5 Gigabit Ethernet Controller`""
Write-Host ""
Write-Host "2. Disable network adapter wake (for Wi-Fi):" -ForegroundColor Green  
Write-Host "   powercfg /devicedisablewake `"Killer(TM) Wi-Fi 7 BE1750w 320MHz Wireless Network Adapter (BE200D2W)`""
Write-Host ""
Write-Host "3. Enable USB selective suspend:" -ForegroundColor Green
Write-Host "   powercfg /SETACVALUEINDEX SCHEME_CURRENT 2ed54b1-d7db-11db-b4d1-0050dabc7b8f 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1"
Write-Host "   powercfg /SETACTIVE SCHEME_CURRENT"
Write-Host ""