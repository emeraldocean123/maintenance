param(
  [switch]$Schedule,
  [switch]$DailyApply,
  [switch]$WithTests,
  [switch]$SendEmailTest
)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here

Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
Import-Module (Join-Path $root 'modules/Health.psm1') -Force
Import-Module (Join-Path $root 'modules/Notifications.psm1') -Force

Start-Log -Name 'verify_setup' | Out-Null
$summary = [ordered]@{ }
try {
  Write-Host 'Verifying health...' -ForegroundColor Cyan
  $tasks = Check-ScheduledTasksHealth
  $launcher = Check-LauncherHealth
  $self = Test-LauncherExecution -Args @('-Scope','WindowsProfile','-DryRun:$true')
  $summary.Health = @{ Tasks = $tasks; Launcher = $launcher; SelfTest = $self }

  $okLauncher = $launcher.CommandResolved -or $self.Success
  if (-not $okLauncher) { Write-Host 'Launcher not resolved and self-test failed.' -ForegroundColor Yellow }

  Write-Host 'Running tests (Pester)...' -ForegroundColor Cyan
  & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Run-Tests.ps1')
  $testsExit = $LASTEXITCODE
  $summary.Tests = @{ ExitCode = $testsExit }
  if ($testsExit -and $testsExit -ne 0) { Write-Host ("Tests failed (exit={0})." -f $testsExit) -ForegroundColor Red } else { Write-Host 'All tests passed.' -ForegroundColor Green }

  Write-Host 'Previewing email (dry-run)...' -ForegroundColor Cyan
  & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Test-Email.ps1') -DryRun -IncludeJournal -IncludeDigest -AttachLatestLogs

  if ($SendEmailTest) {
    Write-Host 'Sending real test email using current config...' -ForegroundColor Cyan
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Test-Email.ps1') -IncludeJournal -IncludeDigest -AttachLatestLogs
  }

  if ($Schedule) {
    Write-Host 'Registering weekly dry-run scheduled task (Mon 03:00)...' -ForegroundColor Cyan
    $args = @('-Trigger','Weekly','-Time','03:00','-DryRun','-TaskName','PersonalMaintenanceToolkit (DryRun)')
    if ($WithTests) { $args += '-WithTests' }
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Register-MaintenanceTask.ps1') @args
    if ($DailyApply) {
      Write-Host 'Registering daily apply scheduled task (03:05)...' -ForegroundColor Cyan
      $args2 = @('-Trigger','Daily','-Time','03:05','-Apply','-TaskName','PersonalMaintenanceToolkit (Apply)')
      if ($WithTests) { $args2 += '-WithTests' }
      & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Register-MaintenanceTask.ps1') @args2
    }
  }

  $journalLines = @()
  $journalLines += ("Launcher: resolved=$($launcher.CommandResolved), self-test=$($self.Success)")
  $journalLines += ("Tests exit=$testsExit")
  if ($Schedule) { $journalLines += ("Scheduled: weekly DryRun (WithTests=$WithTests), daily Apply=$DailyApply") }
  Add-JournalEntry -Title 'Verify Setup run' -Lines $journalLines
}
catch {
  Write-Log -Level ERROR -Message $_.Exception.Message
  throw
}
finally {
  Stop-Log
}

