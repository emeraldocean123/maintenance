param(
  [ValidateSet('Daily','Weekly','AtLogon')] [string]$Trigger = 'Weekly',
  [string]$Time = '03:00',
  [switch]$Apply,
  [switch]$DryRun,
  [switch]$WithTests,
  [switch]$WithAnalysis,
  [string]$TaskName,
  [string]$Description = 'Runs the maintenance toolkit'
)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$sched = Join-Path $root 'scripts/Scheduled-Run.ps1'
$maint = Join-Path $root 'maintain.ps1'

if (-not (Test-Path $sched)) { throw "Scheduled-Run.ps1 not found at $sched" }

$exec = (Get-Command pwsh -ErrorAction SilentlyContinue) ?? (Get-Command powershell -ErrorAction SilentlyContinue)
if (-not $exec) { throw 'PowerShell executable not found' }

if ($Apply -and $DryRun) { throw 'Choose either -Apply or -DryRun, not both.' }

$dry = $true
if ($Apply) { $dry = $false } elseif ($PSBoundParameters.ContainsKey('DryRun')) { $dry = $DryRun.IsPresent } else { $dry = $true }

if (-not $TaskName) { $TaskName = 'PersonalMaintenanceToolkit' + ($dry ? ' (DryRun)' : ' (Apply)') }

$mode = if ($dry) { 'DryRun' } else { 'Apply' }
$args = "-NoProfile -ExecutionPolicy Bypass -File `"$sched`" -Mode $mode" + ($(if($WithTests){' -WithTests'}else{''})) + ($(if($WithAnalysis){' -WithAnalysis'}else{''}))
$action = New-ScheduledTaskAction -Execute $exec.Source -Argument $args

switch ($Trigger) {
  'Daily' { $trig = New-ScheduledTaskTrigger -Daily -At $Time }
  'Weekly' { $trig = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $Time }
  'AtLogon' { $trig = New-ScheduledTaskTrigger -AtLogOn }
}

$task = New-ScheduledTask -Action $action -Trigger $trig -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries)

Register-ScheduledTask -TaskName $TaskName -InputObject $task -Description $Description -User $env:UserName -Force
Write-Host "Registered scheduled task '$TaskName' with $Trigger trigger (Mode=$mode, WithTests=$WithTests, WithAnalysis=$WithAnalysis)"
