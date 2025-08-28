param(
  [switch]$AddToPath,
  [switch]$CreateShortcut
)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$bin = Join-Path $root 'bin'
$cmd = Join-Path $bin 'maintenance.cmd'

if (-not (Test-Path $cmd)) { throw "Launcher not found at $cmd" }

if ($AddToPath) {
  $current = [Environment]::GetEnvironmentVariable('Path','User')
  $paths = ($current -split ';') | Where-Object { $_ }
  if ($paths -notcontains $bin) {
    $new = if ($current) { $current + ';' + $bin } else { $bin }
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
    Write-Host "Added to PATH (User): $bin"
  } else {
    Write-Host "PATH already contains: $bin"
  }
}

if ($CreateShortcut) {
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  $lnkPath = Join-Path $startMenu 'Maintenance Toolkit.lnk'
  $wsh = New-Object -ComObject WScript.Shell
  $sc = $wsh.CreateShortcut($lnkPath)
  $sc.TargetPath = $cmd
  $sc.WorkingDirectory = $root
  $sc.IconLocation = '%SystemRoot%\System32\shell32.dll,70'
  $sc.Description = 'Run Personal Maintenance Toolkit'
  $sc.Save()
  Write-Host "Created Start Menu shortcut: $lnkPath"
}

Write-Host 'Done.'

