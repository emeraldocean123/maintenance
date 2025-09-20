# Fix Double-Click Sleep Issue - Run as Administrator
Write-Host "=== Fixing Double-Click Sleep Issue ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Not running as Administrator!" -ForegroundColor Red
    Write-Host "Please run this script as Administrator" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "This issue where sleep requires 2 attempts is common with Modern Standby." -ForegroundColor Yellow
Write-Host "It happens because the system wakes immediately on the first attempt." -ForegroundColor Yellow
Write-Host ""

Write-Host "Applying fixes..." -ForegroundColor Green
Write-Host ""

# 1. Disable Fast Startup (often causes sleep issues)
Write-Host "1. Disabling Fast Startup (hybrid shutdown)..." -ForegroundColor Yellow
powercfg /hibernate off
powercfg /hibernate on
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
Write-Host "   ✓ Fast Startup disabled" -ForegroundColor Green

# 2. Set system unattended sleep timeout
Write-Host ""
Write-Host "2. Setting system unattended sleep timeout..." -ForegroundColor Yellow
powercfg /SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 7bc4a2f9-d8fc-4469-b07b-33eb785aaca0 120
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 7bc4a2f9-d8fc-4469-b07b-33eb785aaca0 120
Write-Host "   ✓ Unattended sleep timeout set to 2 minutes" -ForegroundColor Green

# 3. Disable away mode
Write-Host ""
Write-Host "3. Disabling Away Mode..." -ForegroundColor Yellow
powercfg /SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 25dfa149-5dd1-4736-b5ab-e8a37b5b8187 0
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 25dfa149-5dd1-4736-b5ab-e8a37b5b8187 0
Write-Host "   ✓ Away Mode disabled" -ForegroundColor Green

# 4. Configure lock screen timeout
Write-Host ""
Write-Host "4. Configuring lock screen behavior..." -ForegroundColor Yellow
powercfg /SETACVALUEINDEX SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 8ec4b3a5-6868-48c2-be75-4f3044be88a7 60
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 8ec4b3a5-6868-48c2-be75-4f3044be88a7 60
Write-Host "   ✓ Console lock display timeout set to 60 seconds" -ForegroundColor Green

# 5. Disable hybrid sleep (incompatible with Modern Standby anyway)
Write-Host ""
Write-Host "5. Ensuring hybrid sleep is disabled..." -ForegroundColor Yellow
powercfg /SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 94ac6d29-73ce-41a6-809f-6363ba21b47e 0
powercfg /SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 94ac6d29-73ce-41a6-809f-6363ba21b47e 0
Write-Host "   ✓ Hybrid sleep disabled" -ForegroundColor Green

# Apply all changes
powercfg /SETACTIVE SCHEME_CURRENT

Write-Host ""
Write-Host "=== Alternative Solutions ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "OPTION 1: Use Hibernate Instead (Recommended)" -ForegroundColor Yellow
Write-Host "Since you're having issues with Modern Standby, hibernate is more reliable:" -ForegroundColor White
Write-Host "  • No double-click issue"
Write-Host "  • Wake-on-LAN still works"
Write-Host "  • Zero power consumption"
Write-Host ""

Write-Host "To enable Hibernate in Start Menu:" -ForegroundColor Green
Write-Host "  1. Run: powercfg /hibernate on"
Write-Host "  2. Go to: Settings > System > Power & battery > Power button and lid"
Write-Host "  3. Click 'Additional power settings'"
Write-Host "  4. Click 'Choose what the power buttons do'"
Write-Host "  5. Click 'Change settings that are currently unavailable'"
Write-Host "  6. Check 'Hibernate' under Shutdown settings"
Write-Host ""

Write-Host "OPTION 2: Create a Sleep Shortcut" -ForegroundColor Yellow
Write-Host "Create a desktop shortcut with this command:" -ForegroundColor White
Write-Host '  rundll32.exe powrprof.dll,SetSuspendState 0,1,0' -ForegroundColor Cyan
Write-Host "This often works better than the Start Menu sleep option" -ForegroundColor Gray
Write-Host ""

Write-Host "OPTION 3: Use Command Line" -ForegroundColor Yellow
Write-Host "Instead of Start Menu, use these commands:" -ForegroundColor White
Write-Host "  • For Sleep:     psshutdown -d -t 0     (download from SysInternals)" -ForegroundColor Cyan
Write-Host "  • For Hibernate: shutdown /h" -ForegroundColor Cyan
Write-Host ""

Write-Host "Changes applied! Restart your computer for best results." -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"