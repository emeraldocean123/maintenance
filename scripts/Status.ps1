param(
  [int]$Runs = 5
)

Set-StrictMode -Version Latest
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$logs = Join-Path $root 'logs'

function Read-Jsonl([string]$path) {
  if (-not (Test-Path $path)) { return @() }
  $items = @()
  foreach ($line in (Get-Content -LiteralPath $path)) {
    try { $items += ($line | ConvertFrom-Json) } catch {}
  }
  return $items
}

$files = Get-ChildItem -LiteralPath $logs -Filter 'maintenance_*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First $Runs
if (-not $files) { Write-Host 'No maintenance runs found yet.' -ForegroundColor Yellow; exit 0 }

Write-Host ("Last {0} maintenance run(s):" -f $files.Count) -ForegroundColor Cyan
foreach ($f in $files) {
  $items = Read-Jsonl $f.FullName
  $start = $items | Where-Object { $_.event -eq 'log_start' } | Select-Object -First 1
  $end = $items | Where-Object { $_.message -like 'Maintenance completed*' } | Select-Object -Last 1
  $when = if ($start) { $start.ts } else { $f.LastWriteTime.ToString('o') }
  $mode = 'n/a'
  $tests = 'SKIPPED'
  $analysis = 'SKIPPED'
  if ($end -and $end.data) {
    if ($end.data.GitHub -and $end.data.GitHub.Skipped) { $mode = 'DryRun' } else { $mode = 'Apply/DryRun' }
  }
  Write-Host ("- {0} | mode={1}" -f $when, $mode)
}

