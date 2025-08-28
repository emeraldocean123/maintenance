param(
  [switch]$RemoveScheduledTasks,
  [switch]$RemovePath,
  [switch]$RemoveShortcut,
  [switch]$RemoveLogs,
  [switch]$RemoveSecrets
)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$bin = Join-Path $root 'bin'

Import-Module (Join-Path $root 'modules/Logging.psm1') -Force

Start-Log -Name 'uninstall_toolkit' | Out-Null
try {
  if ($RemoveScheduledTasks) {
    try {
      Unregister-ScheduledTask -TaskName 'PersonalMaintenanceToolkit (DryRun)' -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
      Unregister-ScheduledTask -TaskName 'PersonalMaintenanceToolkit (Apply)' -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
      Write-Host 'Removed scheduled tasks.' -ForegroundColor Green
      Write-Log -Message 'Removed scheduled tasks'
    } catch { Write-Log -Level WARN -Message ("Failed removing tasks: {0}" -f $_.Exception.Message) }
  }

  if ($RemovePath) {
    try {
      $current = [Environment]::GetEnvironmentVariable('Path','User')
      $paths = ($current -split ';') | Where-Object { $_ }
      $norm = $bin.TrimEnd('\\')
      $new = ($paths | Where-Object { $_.TrimEnd('\\') -ne $norm }) -join ';'
      [Environment]::SetEnvironmentVariable('Path',$new,'User')
      Write-Host "Removed from PATH: $bin" -ForegroundColor Green
      Write-Log -Message 'Removed bin from PATH'
    } catch { Write-Log -Level WARN -Message ("Failed PATH cleanup: {0}" -f $_.Exception.Message) }
  }

  if ($RemoveShortcut) {
    try {
      $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
      $lnk = Join-Path $startMenu 'Maintenance Toolkit.lnk'
      if (Test-Path $lnk) { Remove-Item -LiteralPath $lnk -Force }
      Write-Host 'Removed Start Menu shortcut.' -ForegroundColor Green
      Write-Log -Message 'Removed Start Menu shortcut'
    } catch { Write-Log -Level WARN -Message ("Failed shortcut removal: {0}" -f $_.Exception.Message) }
  }

  if ($RemoveLogs) {
    try {
      $logs = Join-Path $root 'logs'
      if (Test-Path $logs) { Remove-Item -LiteralPath $logs -Recurse -Force }
      Write-Host 'Removed logs.' -ForegroundColor Green
      Write-Log -Message 'Removed logs'
    } catch { Write-Log -Level WARN -Message ("Failed logs removal: {0}" -f $_.Exception.Message) }
  }

  if ($RemoveSecrets) {
    try {
      $secrets = Join-Path $root 'secrets'
      if (Test-Path $secrets) { Remove-Item -LiteralPath $secrets -Recurse -Force }
      Write-Host 'Removed secrets store.' -ForegroundColor Yellow
      Write-Log -Message 'Removed secrets store'
    } catch { Write-Log -Level WARN -Message ("Failed secrets removal: {0}" -f $_.Exception.Message) }
  }
}
finally {
  Stop-Log
}

