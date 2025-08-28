param([switch]$SelfTest)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
Import-Module (Join-Path $root 'modules/Health.psm1') -Force

Start-Log -Name 'health_check' | Out-Null
try {
  $tasks = Check-ScheduledTasksHealth
  if ($tasks.Supported) {
    Write-Host 'Scheduled tasks:' -ForegroundColor Cyan
    foreach ($k in $tasks.Tasks.Keys) {
      $t = $tasks.Tasks[$k]
      $nr = if ($t.NextRunTime) { (Get-Date $t.NextRunTime).ToString('yyyy-MM-dd HH:mm') } else { 'n/a' }
      Write-Host ("- {0}: present={1}, state={2}, next={3}" -f $k, $t.Present, $t.State, $nr)
    }
  } else {
    Write-Host 'ScheduledTasks cmdlets not available.' -ForegroundColor Yellow
  }

  $launch = Check-LauncherHealth
  Write-Host "Launcher:" -ForegroundColor Cyan
  Write-Host ("- bin: {0}" -f $launch.BinPath)
  Write-Host ("- on user PATH: {0}" -f $launch.OnUserPath)
  Write-Host ("- on process PATH: {0}" -f $launch.OnProcessPath)
  Write-Host ("- command resolved: {0}" -f $launch.CommandResolved)
  Write-Host ("- shortcut exists: {0}" -f $launch.ShortcutExists)
  if ($SelfTest) {
    Write-Host "Running launcher self-test..." -ForegroundColor Cyan
    $res = Test-LauncherExecution -Args @('-Scope','WindowsProfile','-DryRun')
    Write-Host ("- self-test success: {0} (exit={1}, used={2})" -f $res.Success, $res.ExitCode, $res.Used)
    if ($res.LogFile) { Write-Host ("- latest log: {0}" -f $res.LogFile) }
    if ($res.ErrorMessage) { Write-Host ("- error: {0}" -f $res.ErrorMessage) }
  }
}
finally {
  Stop-Log
}
