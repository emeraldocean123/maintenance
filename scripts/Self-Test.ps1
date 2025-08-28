Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
Import-Module (Join-Path $root 'modules/Health.psm1') -Force

Start-Log -Name 'self_test' | Out-Null
try {
  $res = Test-LauncherExecution -Args @('-Scope','WindowsProfile','-DryRun')
  if ($res.Success) {
    Write-Host ("Self-test succeeded (used={0}, exit={1}, ms={2})" -f $res.Used, $res.ExitCode, $res.DurationMs) -ForegroundColor Green
  } else {
    Write-Host ("Self-test failed (used={0}, exit={1})" -f $res.Used, $res.ExitCode) -ForegroundColor Red
    if ($res.ErrorMessage) { Write-Host ("Error: {0}" -f $res.ErrorMessage) -ForegroundColor Red }
  }
  if ($res.LogFile) { Write-Host ("Latest log: {0}" -f $res.LogFile) }
}
finally {
  Stop-Log
}
