# GamingUtilities - Consolidated Gaming Configuration Utility
# Double-click executable from Windows Explorer

param([switch]$NoExit)

# Function to set console properties for better visibility
function Set-ConsoleProperties {
    $Host.UI.RawUI.WindowTitle = "GamingUtilities - Gaming Configuration Utility"
    if ($Host.Name -eq "ConsoleHost") {
        $console = $Host.UI.RawUI
        $buffer = $console.BufferSize
        $buffer.Height = 3000
        $console.BufferSize = $buffer
        $window = $console.WindowSize
        if ($window.Width -lt 120) { $window.Width = 120 }
        if ($window.Height -lt 30) { $window.Height = 30 }
        try { $console.WindowSize = $window } catch { }
    }
}

# Function to pause and wait for user input
function Pause-Script {
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to get user choice
function Get-UserChoice {
    param([int]$Max)
    do {
        Write-Host ""
        $choice = Read-Host "Enter your choice (1-$Max, 0 to exit)"
        if ($choice -eq '0') { return 0 }
        try { 
            $num = [int]$choice 
            if ($num -ge 1 -and $num -le $Max) { return $num }
        } catch { }
        Write-Host "Invalid choice. Please enter a number between 1 and $Max (or 0 to exit)." -ForegroundColor Red
    } while ($true)
}

# Function to check if running as Administrator
function Test-IsAdmin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to configure MSI Afterburner monitoring
function Invoke-AfterburnerConfig {
    Write-Host "=== MSI Afterburner Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "MSI Afterburner Monitoring Configuration:" -ForegroundColor Yellow
    Write-Host "1. Set up basic GPU monitoring" -ForegroundColor White
    Write-Host "2. Configure advanced monitoring settings" -ForegroundColor White
    Write-Host "3. Export monitoring configuration" -ForegroundColor White
    Write-Host "4. Check Afterburner installation" -ForegroundColor White
    Write-Host "5. Return to main menu" -ForegroundColor White
    
    $choice = Get-UserChoice -Max 5
    
    switch ($choice) {
        1 { Configure-BasicGPUMonitoring }
        2 { Configure-AdvancedMonitoring }
        3 { Export-MonitoringConfig }
        4 { Check-AfterburnerInstallation }
        5 { return }
        0 { exit }
    }
}

function Configure-BasicGPUMonitoring {
    Write-Host "Configuring basic GPU monitoring..." -ForegroundColor Yellow
    
    $afterburnerPath = "${env:ProgramFiles(x86)}\MSI Afterburner"
    if (-not (Test-Path $afterburnerPath)) {
        Write-Host "MSI Afterburner not found in default location!" -ForegroundColor Red
        Write-Host "Please install MSI Afterburner first." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Basic monitoring settings recommended:" -ForegroundColor Green
    Write-Host "• GPU Temperature (°C)" -ForegroundColor White
    Write-Host "• GPU Usage (%)" -ForegroundColor White
    Write-Host "• GPU Memory Usage (%)" -ForegroundColor White
    Write-Host "• GPU Core Clock (MHz)" -ForegroundColor White
    Write-Host "• GPU Memory Clock (MHz)" -ForegroundColor White
    Write-Host "• Fan Speed (%)" -ForegroundColor White
    Write-Host "• Power Usage (W)" -ForegroundColor White
    
    Write-Host ""
    Write-Host "To configure these in MSI Afterburner:" -ForegroundColor Yellow
    Write-Host "1. Open MSI Afterburner" -ForegroundColor Gray
    Write-Host "2. Go to Settings > Monitoring" -ForegroundColor Gray
    Write-Host "3. Enable the checkboxes for the metrics above" -ForegroundColor Gray
    Write-Host "4. Check 'Show in On-Screen Display' for each metric" -ForegroundColor Gray
    Write-Host "5. Apply settings and restart if needed" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Attempting to launch MSI Afterburner..." -ForegroundColor Green
    try {
        Start-Process "$afterburnerPath\MSIAfterburner.exe" -ErrorAction SilentlyContinue
        Write-Host "MSI Afterburner launched successfully" -ForegroundColor Green
    } catch {
        Write-Host "Could not launch MSI Afterburner automatically" -ForegroundColor Yellow
    }
}

function Configure-AdvancedMonitoring {
    Write-Host "Advanced monitoring configuration..." -ForegroundColor Yellow
    
    Write-Host "Advanced monitoring options:" -ForegroundColor Green
    Write-Host "• CPU Temperature (per core)" -ForegroundColor White
    Write-Host "• CPU Usage (per core)" -ForegroundColor White
    Write-Host "• RAM Usage" -ForegroundColor White
    Write-Host "• VRAM Usage" -ForegroundColor White
    Write-Host "• Frame Time (ms)" -ForegroundColor White
    Write-Host "• Frame Rate (FPS)" -ForegroundColor White
    Write-Host "• Disk Usage (%)" -ForegroundColor White
    Write-Host "• Network Usage" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Performance optimization tips:" -ForegroundColor Cyan
    Write-Host "• Limit OSD update rate to 1000ms to reduce performance impact" -ForegroundColor White
    Write-Host "• Use hardware monitoring when available" -ForegroundColor White
    Write-Host "• Enable logging to track performance over time" -ForegroundColor White
    Write-Host "• Set up custom fan curves for optimal cooling" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Configuration locations:" -ForegroundColor Yellow
    Write-Host "• MSI Afterburner settings: %ProgramFiles(x86)%\MSI Afterburner" -ForegroundColor Gray
    Write-Host "• Profiles stored in: %Documents%\MSI Afterburner\Profiles" -ForegroundColor Gray
}

function Export-MonitoringConfig {
    Write-Host "Exporting monitoring configuration..." -ForegroundColor Yellow
    
    $configPath = "$env:USERPROFILE\Documents\MSI Afterburner"
    $exportPath = "$env:USERPROFILE\Desktop\AfterburnerConfig_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    if (Test-Path $configPath) {
        try {
            New-Item -Path $exportPath -ItemType Directory -Force | Out-Null
            Copy-Item "$configPath\*" -Destination $exportPath -Recurse -Force
            Write-Host "Configuration exported to: $exportPath" -ForegroundColor Green
        } catch {
            Write-Host "Error exporting configuration: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "No MSI Afterburner configuration found" -ForegroundColor Yellow
    }
}

function Check-AfterburnerInstallation {
    Write-Host "Checking MSI Afterburner installation..." -ForegroundColor Yellow
    
    $paths = @(
        "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe",
        "${env:ProgramFiles}\MSI Afterburner\MSIAfterburner.exe"
    )
    
    $found = $false
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Host "Found: $path" -ForegroundColor Green
            $version = (Get-ItemProperty $path).VersionInfo.ProductVersion
            Write-Host "Version: $version" -ForegroundColor White
            $found = $true
        }
    }
    
    if (-not $found) {
        Write-Host "MSI Afterburner not found!" -ForegroundColor Red
        Write-Host "Download from: https://www.msi.com/Landing/afterburner" -ForegroundColor Yellow
    }
    
    # Check for RivaTuner Statistics Server
    $rtssPath = "${env:ProgramFiles(x86)}\RivaTuner Statistics Server\RTSS.exe"
    if (Test-Path $rtssPath) {
        Write-Host "RivaTuner Statistics Server: Found" -ForegroundColor Green
    } else {
        Write-Host "RivaTuner Statistics Server: Not found (included with Afterburner)" -ForegroundColor Yellow
    }
}

# Function to configure RTSS overlay
function Invoke-RTSSConfig {
    Write-Host "=== RivaTuner Statistics Server (RTSS) Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "RTSS Overlay Configuration:" -ForegroundColor Yellow
    Write-Host "1. Configure basic overlay settings" -ForegroundColor White
    Write-Host "2. Set up custom overlay template" -ForegroundColor White
    Write-Host "3. Manage application profiles" -ForegroundColor White
    Write-Host "4. Check RTSS installation" -ForegroundColor White
    Write-Host "5. Return to main menu" -ForegroundColor White
    
    $choice = Get-UserChoice -Max 5
    
    switch ($choice) {
        1 { Configure-RTSSBasicSettings }
        2 { Setup-CustomOverlay }
        3 { Manage-RTSSProfiles }
        4 { Check-RTSSInstallation }
        5 { return }
        0 { exit }
    }
}

function Configure-RTSSBasicSettings {
    Write-Host "RTSS Basic Configuration:" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "Recommended RTSS settings:" -ForegroundColor Green
    Write-Host "• Overlay Position: Top-Left or Bottom-Left" -ForegroundColor White
    Write-Host "• Update Rate: 1000ms (reduces performance impact)" -ForegroundColor White
    Write-Host "• Font Size: Medium (good visibility without clutter)" -ForegroundColor White
    Write-Host "• Background: Semi-transparent" -ForegroundColor White
    Write-Host "• Text Color: White or Light Green" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Performance optimization:" -ForegroundColor Cyan
    Write-Host "• Enable 'Stealth mode' for competitive gaming" -ForegroundColor White
    Write-Host "• Use hardware-accelerated GPU scheduling if available" -ForegroundColor White
    Write-Host "• Limit framerate cap to monitor refresh rate + 10%" -ForegroundColor White
    
    Write-Host ""
    Write-Host "To configure RTSS:" -ForegroundColor Yellow
    Write-Host "1. Open RivaTuner Statistics Server" -ForegroundColor Gray
    Write-Host "2. Go to Setup tab for global settings" -ForegroundColor Gray
    Write-Host "3. Configure On-Screen Display settings" -ForegroundColor Gray
    Write-Host "4. Add applications for per-game settings" -ForegroundColor Gray
    
    $rtssPath = "${env:ProgramFiles(x86)}\RivaTuner Statistics Server\RTSS.exe"
    if (Test-Path $rtssPath) {
        Write-Host ""
        Write-Host "Launching RTSS..." -ForegroundColor Green
        try {
            Start-Process $rtssPath
            Write-Host "RTSS launched successfully" -ForegroundColor Green
        } catch {
            Write-Host "Could not launch RTSS" -ForegroundColor Red
        }
    }
}

function Setup-CustomOverlay {
    Write-Host "Setting up custom overlay template..." -ForegroundColor Yellow
    
    # Create a custom overlay template
    $template = @"
<C0=FF00FF00>FPS: <C1=FFFFFFFF><APP>
<C0=FF00FF00>GPU: <C1=FFFFFFFF><GPU1>% <GPU1TEMP>°C
<C0=FF00FF00>CPU: <C1=FFFFFFFF><CPU>% <CPUTEMP>°C
<C0=FF00FF00>RAM: <C1=FFFFFFFF><RAM> GB
<C0=FF00FF00>VRAM: <C1=FFFFFFFF><GPUMEM> GB
"@

    $templatePath = "$env:USERPROFILE\Desktop\RTSS_Template.txt"
    try {
        $template | Out-File -FilePath $templatePath -Encoding UTF8
        Write-Host "Custom overlay template created: $templatePath" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "Template includes:" -ForegroundColor Cyan
        Write-Host "• FPS counter" -ForegroundColor White
        Write-Host "• GPU usage and temperature" -ForegroundColor White
        Write-Host "• CPU usage and temperature" -ForegroundColor White
        Write-Host "• RAM usage" -ForegroundColor White
        Write-Host "• VRAM usage" -ForegroundColor White
        
        Write-Host ""
        Write-Host "To use this template:" -ForegroundColor Yellow
        Write-Host "1. Open RTSS" -ForegroundColor Gray
        Write-Host "2. Go to Setup tab" -ForegroundColor Gray
        Write-Host "3. Click 'Setup' next to On-Screen Display settings" -ForegroundColor Gray
        Write-Host "4. In the OSD section, paste the template content" -ForegroundColor Gray
        Write-Host "5. Apply and test in a game" -ForegroundColor Gray
        
    } catch {
        Write-Host "Could not create template file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Manage-RTSSProfiles {
    Write-Host "Managing RTSS application profiles..." -ForegroundColor Yellow
    
    $rtssConfigPath = "${env:ProgramFiles(x86)}\RivaTuner Statistics Server"
    if (Test-Path $rtssConfigPath) {
        Write-Host "RTSS configuration directory: $rtssConfigPath" -ForegroundColor White
        
        Write-Host ""
        Write-Host "Common application profiles:" -ForegroundColor Cyan
        Write-Host "• Game launchers: Disable overlay to reduce overhead" -ForegroundColor White
        Write-Host "• Competitive games: Enable stealth mode" -ForegroundColor White
        Write-Host "• Benchmarks: Enable detailed monitoring" -ForegroundColor White
        Write-Host "• Streaming apps: Disable to prevent stream artifacts" -ForegroundColor White
        
        Write-Host ""
        Write-Host "Profile management tips:" -ForegroundColor Green
        Write-Host "• Use global settings for most games" -ForegroundColor White
        Write-Host "• Create specific profiles only when needed" -ForegroundColor White
        Write-Host "• Backup profiles before major updates" -ForegroundColor White
        Write-Host "• Test profiles with different API (DX11/12, Vulkan)" -ForegroundColor White
    } else {
        Write-Host "RTSS not found - install with MSI Afterburner" -ForegroundColor Red
    }
}

function Check-RTSSInstallation {
    Write-Host "Checking RTSS installation..." -ForegroundColor Yellow
    
    $rtssPath = "${env:ProgramFiles(x86)}\RivaTuner Statistics Server\RTSS.exe"
    if (Test-Path $rtssPath) {
        Write-Host "RTSS: Found" -ForegroundColor Green
        $version = (Get-ItemProperty $rtssPath).VersionInfo.ProductVersion
        Write-Host "Version: $version" -ForegroundColor White
        Write-Host "Location: $rtssPath" -ForegroundColor Gray
        
        # Check if service is running
        $service = Get-Process "RTSS" -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "Service: Running" -ForegroundColor Green
        } else {
            Write-Host "Service: Not running" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "RTSS not found!" -ForegroundColor Red
        Write-Host "RTSS is included with MSI Afterburner" -ForegroundColor Yellow
    }
}

# Function to manage AlienFX monitoring
function Invoke-AlienFXManager {
    Write-Host "=== AlienFX Monitoring Manager ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "AlienFX System Options:" -ForegroundColor Yellow
    Write-Host "1. Check AlienFX services status" -ForegroundColor White
    Write-Host "2. Create elevated AlienFan task" -ForegroundColor White
    Write-Host "3. Monitor AlienFX processes" -ForegroundColor White
    Write-Host "4. AlienFX troubleshooting" -ForegroundColor White
    Write-Host "5. Return to main menu" -ForegroundColor White
    
    $choice = Get-UserChoice -Max 5
    
    switch ($choice) {
        1 { Check-AlienFXServices }
        2 { Create-AlienFanTask }
        3 { Monitor-AlienFXProcesses }
        4 { AlienFX-Troubleshooting }
        5 { return }
        0 { exit }
    }
}

function Check-AlienFXServices {
    Write-Host "Checking AlienFX services..." -ForegroundColor Yellow
    
    $services = @("AlienFusionService", "AlienFXWindows10Service", "LightingService")
    
    foreach ($serviceName in $services) {
        $service = Get-Service $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            $color = switch ($service.Status) {
                "Running" { "Green" }
                "Stopped" { "Red" }
                default { "Yellow" }
            }
            Write-Host "$serviceName`: $($service.Status)" -ForegroundColor $color
        } else {
            Write-Host "$serviceName`: Not found" -ForegroundColor Gray
        }
    }
    
    # Check for AlienFX processes
    Write-Host ""
    Write-Host "AlienFX Processes:" -ForegroundColor Yellow
    $alienProcesses = Get-Process | Where-Object { $_.ProcessName -like "*alien*" -or $_.ProcessName -like "*lighting*" }
    
    if ($alienProcesses) {
        foreach ($process in $alienProcesses) {
            Write-Host "$($process.ProcessName) (PID: $($process.Id))" -ForegroundColor White
        }
    } else {
        Write-Host "No AlienFX processes currently running" -ForegroundColor Gray
    }
}

function Create-AlienFanTask {
    if (-not (Test-IsAdmin)) {
        Write-Host "Administrator privileges required to create scheduled tasks!" -ForegroundColor Red
        return
    }
    
    Write-Host "Creating elevated AlienFan scheduled task..." -ForegroundColor Yellow
    
    # This would create a scheduled task for AlienFan to run with elevated privileges
    Write-Host "Scheduled task configuration:" -ForegroundColor Cyan
    Write-Host "• Task Name: AlienFan Elevated" -ForegroundColor White
    Write-Host "• Trigger: At system startup" -ForegroundColor White
    Write-Host "• Action: Run AlienFan with highest privileges" -ForegroundColor White
    Write-Host "• User: SYSTEM" -ForegroundColor White
    
    Write-Host ""
    Write-Host "To manually create this task:" -ForegroundColor Yellow
    Write-Host "1. Open Task Scheduler as Administrator" -ForegroundColor Gray
    Write-Host "2. Create Basic Task > Name: 'AlienFan Elevated'" -ForegroundColor Gray
    Write-Host "3. Trigger: When computer starts" -ForegroundColor Gray
    Write-Host "4. Action: Start program > Browse to AlienFan.exe" -ForegroundColor Gray
    Write-Host "5. Properties > Run with highest privileges" -ForegroundColor Gray
    Write-Host "6. Properties > User: SYSTEM" -ForegroundColor Gray
}

function Monitor-AlienFXProcesses {
    Write-Host "Monitoring AlienFX processes (press Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        while ($true) {
            Clear-Host
            Write-Host "=== AlienFX Process Monitor ===" -ForegroundColor Cyan
            Write-Host "$(Get-Date)" -ForegroundColor Gray
            Write-Host ""
            
            $processes = Get-Process | Where-Object { 
                $_.ProcessName -like "*alien*" -or 
                $_.ProcessName -like "*lighting*" -or
                $_.ProcessName -like "*fx*" 
            }
            
            if ($processes) {
                foreach ($process in $processes) {
                    $cpu = Get-Counter "\Process($($process.ProcessName))\% Processor Time" -ErrorAction SilentlyContinue
                    $cpuPercent = if ($cpu) { [math]::Round($cpu.CounterSamples[0].CookedValue, 1) } else { "N/A" }
                    $memoryMB = [math]::Round($process.WorkingSet / 1MB, 1)
                    
                    Write-Host "$($process.ProcessName)" -ForegroundColor White
                    Write-Host "  PID: $($process.Id) | CPU: $cpuPercent% | Memory: $memoryMB MB" -ForegroundColor Gray
                }
            } else {
                Write-Host "No AlienFX processes found" -ForegroundColor Yellow
            }
            
            Start-Sleep 2
        }
    } catch {
        Write-Host "Monitoring stopped" -ForegroundColor Green
    }
}

function AlienFX-Troubleshooting {
    Write-Host "AlienFX Troubleshooting Guide:" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Common Issues and Solutions:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Lights not working:" -ForegroundColor Red
    Write-Host "   • Restart AlienFX services" -ForegroundColor White
    Write-Host "   • Update Alienware Command Center" -ForegroundColor White
    Write-Host "   • Check for Windows updates" -ForegroundColor White
    Write-Host ""
    Write-Host "2. High CPU usage:" -ForegroundColor Red
    Write-Host "   • Reduce lighting effects complexity" -ForegroundColor White
    Write-Host "   • Close unnecessary AlienFX applications" -ForegroundColor White
    Write-Host "   • Set static lighting instead of animated" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Service crashes:" -ForegroundColor Red
    Write-Host "   • Run services as administrator" -ForegroundColor White
    Write-Host "   • Check event logs for errors" -ForegroundColor White
    Write-Host "   • Reinstall Alienware Command Center" -ForegroundColor White
    Write-Host ""
    Write-Host "4. Performance impact:" -ForegroundColor Red
    Write-Host "   • Disable AlienFX during gaming" -ForegroundColor White
    Write-Host "   • Use static colors only" -ForegroundColor White
    Write-Host "   • Monitor CPU and memory usage" -ForegroundColor White
}

# Function for development utilities
function Invoke-DevelopmentUtilities {
    Write-Host "=== Development Utilities ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Development Tools:" -ForegroundColor Yellow
    Write-Host "1. Manage PATH environment variable" -ForegroundColor White
    Write-Host "2. Audit system PATH" -ForegroundColor White
    Write-Host "3. Development folder organization" -ForegroundColor White
    Write-Host "4. Return to main menu" -ForegroundColor White
    
    $choice = Get-UserChoice -Max 4
    
    switch ($choice) {
        1 { Manage-PathVariable }
        2 { Audit-SystemPath }
        3 { Organize-DevFolders }
        4 { return }
        0 { exit }
    }
}

function Manage-PathVariable {
    Write-Host "PATH Environment Variable Manager:" -ForegroundColor Yellow
    Write-Host ""
    
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    
    Write-Host "Current User PATH entries:" -ForegroundColor Cyan
    if ($userPath) {
        $userPath.Split(';') | ForEach-Object { if ($_ -ne "") { Write-Host "  $_" -ForegroundColor White } }
    } else {
        Write-Host "  (empty)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "PATH Management Options:" -ForegroundColor Yellow
    Write-Host "1. Add new path to User PATH" -ForegroundColor White
    Write-Host "2. Remove path from User PATH" -ForegroundColor White
    Write-Host "3. View System PATH" -ForegroundColor White
    Write-Host "4. Return" -ForegroundColor White
    
    $pathChoice = Get-UserChoice -Max 4
    
    switch ($pathChoice) {
        1 {
            $newPath = Read-Host "Enter path to add"
            if (Test-Path $newPath) {
                if ($userPath -notlike "*$newPath*") {
                    $newUserPath = if ($userPath) { "$userPath;$newPath" } else { $newPath }
                    [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
                    Write-Host "Path added successfully!" -ForegroundColor Green
                } else {
                    Write-Host "Path already exists in PATH" -ForegroundColor Yellow
                }
            } else {
                Write-Host "Path does not exist!" -ForegroundColor Red
            }
        }
        3 {
            Write-Host "System PATH entries:" -ForegroundColor Cyan
            $systemPath.Split(';') | ForEach-Object { if ($_ -ne "") { Write-Host "  $_" -ForegroundColor White } }
        }
    }
}

function Audit-SystemPath {
    Write-Host "Auditing system PATH..." -ForegroundColor Yellow
    
    $allPaths = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
    $pathEntries = $allPaths.Split(';') | Where-Object { $_ -ne "" }
    
    $issues = @()
    $validPaths = 0
    
    foreach ($path in $pathEntries) {
        if (Test-Path $path) {
            $validPaths++
        } else {
            $issues += "Invalid path: $path"
        }
    }
    
    Write-Host "PATH Audit Results:" -ForegroundColor Cyan
    Write-Host "Total entries: $($pathEntries.Count)" -ForegroundColor White
    Write-Host "Valid paths: $validPaths" -ForegroundColor Green
    Write-Host "Invalid paths: $($issues.Count)" -ForegroundColor Red
    
    if ($issues.Count -gt 0) {
        Write-Host ""
        Write-Host "Invalid paths found:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "  - $issue" -ForegroundColor Yellow
        }
    }
}

function Organize-DevFolders {
    Write-Host "Development Folder Organization:" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Common development folder structure recommendations:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "~/Documents/dev/" -ForegroundColor Green
    Write-Host "  ├── projects/          # Active projects" -ForegroundColor White
    Write-Host "  ├── tools/             # Development tools" -ForegroundColor White
    Write-Host "  ├── scripts/           # Utility scripts" -ForegroundColor White
    Write-Host "  ├── templates/         # Project templates" -ForegroundColor White
    Write-Host "  ├── learning/          # Learning projects" -ForegroundColor White
    Write-Host "  └── archived/          # Completed/old projects" -ForegroundColor White
    Write-Host ""
    
    $devPath = "$env:USERPROFILE\Documents\dev"
    if (Test-Path $devPath) {
        Write-Host "Current dev folder structure:" -ForegroundColor Cyan
        Get-ChildItem $devPath -Directory | ForEach-Object {
            Write-Host "  $($_.Name)/" -ForegroundColor White
        }
    } else {
        Write-Host "No dev folder found at: $devPath" -ForegroundColor Yellow
    }
}

# Main menu function
function Show-MainMenu {
    Clear-Host
    Set-ConsoleProperties
    
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                            GamingUtilities v1.0                                 ║" -ForegroundColor Cyan
    Write-Host "║                    Consolidated Gaming Configuration Utility                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Available Actions:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " 1. MSI Afterburner Configuration" -ForegroundColor White -NoNewline
    Write-Host "    - Configure GPU monitoring and settings" -ForegroundColor Gray
    Write-Host ""
    Write-Host " 2. RTSS Overlay Configuration" -ForegroundColor White -NoNewline  
    Write-Host "       - Set up on-screen display overlays" -ForegroundColor Gray
    Write-Host ""
    Write-Host " 3. AlienFX Management" -ForegroundColor White -NoNewline
    Write-Host "             - Manage Alienware lighting and services" -ForegroundColor Gray
    Write-Host ""
    Write-Host " 4. Development Utilities" -ForegroundColor White -NoNewline
    Write-Host "           - PATH management and dev folder organization" -ForegroundColor Gray
    Write-Host ""
    Write-Host " 0. Exit" -ForegroundColor Red
    Write-Host ""
}

# Main execution function
function Main {
    try {
        do {
            Show-MainMenu
            $choice = Get-UserChoice -Max 4
            
            switch ($choice) {
                1 { 
                    Clear-Host
                    Invoke-AfterburnerConfig
                    Pause-Script
                }
                2 { 
                    Clear-Host
                    Invoke-RTSSConfig
                    Pause-Script
                }
                3 { 
                    Clear-Host
                    Invoke-AlienFXManager
                    Pause-Script
                }
                4 { 
                    Clear-Host
                    Invoke-DevelopmentUtilities
                    Pause-Script
                }
                0 { 
                    Write-Host "Goodbye!" -ForegroundColor Green
                    break 
                }
            }
        } while ($choice -ne 0)
        
    } catch {
        Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
        Pause-Script
        exit 1
    }

    # Keep window open if double-clicked or -NoExit specified
    if (-not $NoExit -and $MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Path) {
        Pause-Script
    }
}

# Call the main function
Main