param(
  [switch]$InstallLauncher,
  [switch]$SetupSchedule,
  [switch]$DailyApply,
  [switch]$ScheduleWithTests,
  [switch]$ScheduleWithAnalysis
)

Set-StrictMode -Version Latest
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here

Write-Host "Starting first dry-run..." -ForegroundColor Cyan
& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'maintain.ps1') -Scope All -DryRun:$true -Init

Write-Host "Generating summary..." -ForegroundColor Cyan
& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Summarize-Logs.ps1')

if ($InstallLauncher) {
  Write-Host "Installing launcher (PATH + Start Menu)..." -ForegroundColor Cyan
  & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Install-ToolkitLauncher.ps1') -AddToPath -CreateShortcut
}

if ($SetupSchedule) {
  Write-Host "Registering weekly dry-run scheduled task (Mon 03:00)..." -ForegroundColor Cyan
  $args = @('-Trigger','Weekly','-Time','03:00','-DryRun','-TaskName','PersonalMaintenanceToolkit (DryRun)')
  if ($ScheduleWithTests) { $args += '-WithTests' }
  if ($ScheduleWithAnalysis) { $args += '-WithAnalysis' }
  & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Register-MaintenanceTask.ps1') @args
  if ($DailyApply) {
    Write-Host "Registering daily apply scheduled task (03:05)..." -ForegroundColor Cyan
    $args2 = @('-Trigger','Daily','-Time','03:05','-Apply','-TaskName','PersonalMaintenanceToolkit (Apply)')
    if ($ScheduleWithTests) { $args2 += '-WithTests' }
    if ($ScheduleWithAnalysis) { $args2 += '-WithAnalysis' }
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Register-MaintenanceTask.ps1') @args2
  }
}

Write-Host "First run complete. Review logs in 'logs' and journal.md." -ForegroundColor Green
