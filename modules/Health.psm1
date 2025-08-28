Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSCommandPath) 'Logging.psm1') -Force

function Check-ScheduledTasksHealth {
  param(
    [string]$DryRunTaskName = 'PersonalMaintenanceToolkit (DryRun)',
    [string]$ApplyTaskName = 'PersonalMaintenanceToolkit (Apply)'
  )
  $haveCmd = Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue
  if (-not $haveCmd) {
    Write-Log -Level WARN -Message 'ScheduledTasks cmdlets not available; skipping tasks health check'
    return [pscustomobject]@{ Supported = $false }
  }
  $result = [ordered]@{}
  foreach ($name in @($DryRunTaskName, $ApplyTaskName)) {
    $present = $false; $next = $null; $last = $null; $lastRes = $null; $state = $null
    try {
      $t = Get-ScheduledTask -TaskName $name -ErrorAction Stop
      $present = $true
      $state = $t.State
      $info = Get-ScheduledTaskInfo -TaskName $name -ErrorAction SilentlyContinue
      if ($info) { $next = $info.NextRunTime; $last = $info.LastRunTime; $lastRes = $info.LastTaskResult }
    } catch {
      $present = $false
    }
    $result[$name] = [pscustomobject]@{ Present = $present; State = $state; NextRunTime = $next; LastRunTime = $last; LastTaskResult = $lastRes }
  }
  $summary = [pscustomobject]@{ Supported = $true; Tasks = $result }
  Write-Log -Message 'Scheduled tasks health' -Data ($summary | ConvertTo-Json | ConvertFrom-Json)
  return $summary
}

function Check-LauncherHealth {
  $moduleDir = Split-Path -Parent $PSCommandPath
  $root = Split-Path -Parent $moduleDir
  $bin = Join-Path $root 'bin'
  $cmdPath = Join-Path $bin 'maintenance.cmd'
  $ps1Path = Join-Path $bin 'maintenance.ps1'

  # PATH checks
  $userPath = [Environment]::GetEnvironmentVariable('Path','User')
  $procPath = $env:Path
  function Split-Paths([string]$p) { if (-not $p) { @() } else { ($p -split ';') | ForEach-Object { $_.Trim().TrimEnd('\') } | Where-Object { $_ } }
  $userPaths = Split-Paths $userPath
  $procPaths = Split-Paths $procPath
  $binNorm = $bin.TrimEnd('\\')
  $onUserPath = $userPaths -contains $binNorm
  $onProcPath = $procPaths -contains $binNorm

  # Command resolution
  $cmd = Get-Command maintenance -ErrorAction SilentlyContinue
  $resolved = $false; $resolvedPath = $null
  if ($cmd) { $resolved = $true; $resolvedPath = $cmd.Source }

  # Start Menu shortcut
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  $lnk = Join-Path $startMenu 'Maintenance Toolkit.lnk'
  $shortcutExists = Test-Path $lnk

  $summary = [pscustomobject]@{
    BinPath        = $bin
    OnUserPath     = $onUserPath
    OnProcessPath  = $onProcPath
    CommandResolved= $resolved
    ResolvedPath   = $resolvedPath
    ShortcutPath   = $lnk
    ShortcutExists = $shortcutExists
  }
  Write-Log -Message 'Launcher health' -Data ($summary | ConvertTo-Json | ConvertFrom-Json)
  return $summary
}

Export-ModuleMember -Function Check-ScheduledTasksHealth
Export-ModuleMember -Function Check-LauncherHealth

function Test-LauncherExecution {
  param(
    [string[]]$Args = @('-Scope','WindowsProfile','-DryRun'),
    [int]$TimeoutSeconds = 180
  )
  $moduleDir = Split-Path -Parent $PSCommandPath
  $root = Split-Path -Parent $moduleDir
  $bin = Join-Path $root 'bin'
  $cmdPath = Join-Path $bin 'maintenance.cmd'
  $maintPath = Join-Path $root 'maintain.ps1'

  $result = [ordered]@{
    Started      = $false
    ExitCode     = $null
    DurationMs   = $null
    Used         = $null
    LogFile      = $null
    Success      = $false
    ErrorMessage = $null
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    if (Test-Path $cmdPath) {
      $result.Used = $cmdPath
      $proc = Start-Process -FilePath $cmdPath -ArgumentList ($Args -join ' ') -PassThru -WindowStyle Hidden -Wait
      $result.ExitCode = $proc.ExitCode
      $result.Started = $true
    } elseif (Get-Command pwsh -ErrorAction SilentlyContinue) {
      $pwsh = (Get-Command pwsh).Source
      $result.Used = $pwsh
      $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$maintPath`" " + ($Args -join ' ')
      $proc = Start-Process -FilePath $pwsh -ArgumentList $argLine -PassThru -WindowStyle Hidden -Wait
      $result.ExitCode = $proc.ExitCode
      $result.Started = $true
    } else {
      throw 'No launcher (.cmd) or pwsh found to run self-test.'
    }
  } catch {
    $result.ErrorMessage = $_.Exception.Message
  } finally {
    $sw.Stop(); $result.DurationMs = $sw.ElapsedMilliseconds
  }

  # try to locate the latest maintenance log
  try {
    $logsDir = Join-Path $root 'logs'
    $latest = Get-ChildItem -LiteralPath $logsDir -Filter 'maintenance_*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) { $result.LogFile = $latest.FullName }
  } catch {}

  $result.Success = ($result.Started -and ($result.ExitCode -eq 0))
  Write-Log -Message 'Launcher self-test' -Data ($result | ConvertTo-Json | ConvertFrom-Json)
  return [pscustomobject]$result
}

Export-ModuleMember -Function Test-LauncherExecution
