param(
  [switch]$IncludeDiskUsage,
  [switch]$IncludeTests,
  [string]$Output
)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$logs = Join-Path $root 'logs'
$repDir = Join-Path $logs 'reports'
New-Item -ItemType Directory -Path $repDir -Force | Out-Null

Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
Import-Module (Join-Path $root 'modules/Reports.psm1') -Force

Start-Log -Name 'export_report' | Out-Null
try {
  $attachments = @()
  $latestMaint = Get-ChildItem -LiteralPath $logs -Filter 'maintenance_*.log' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $latestMaintJson = Get-ChildItem -LiteralPath $logs -Filter 'maintenance_*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($latestMaint) { $attachments += $latestMaint.FullName }
  if ($latestMaintJson) { $attachments += $latestMaintJson.FullName }

  if ($IncludeTests) {
    $latestTests = Get-ChildItem -LiteralPath $logs -Filter 'test_results_*.txt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestTests) { $attachments += $latestTests.FullName }
  }

  if ($IncludeDiskUsage) {
    $disk = New-DiskUsageSnapshot
    if ($disk.SummaryCsv) { $attachments += $disk.SummaryCsv }
    if ($disk.TopFilesCsv) { $attachments += $disk.TopFilesCsv }
    if ($disk.Json) { $attachments += $disk.Json }
  }

  $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
  if (-not $Output) { $Output = Join-Path $repDir ("report_$ts.zip") }

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if (Test-Path $Output) { Remove-Item -LiteralPath $Output -Force }
  $zip = [System.IO.Compression.ZipFile]::Open($Output, 'Create')
  foreach ($f in ($attachments | Sort-Object -Unique)) {
    try {
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f, (Split-Path -Leaf $f)) | Out-Null
    } catch {}
  }
  $zip.Dispose()
  Write-Host ("Report written: {0}" -f $Output)
  Write-Log -Message 'Exported report' -Data @{ path = $Output; files = $attachments }
}
finally {
  Stop-Log
}

