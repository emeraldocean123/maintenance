param(
  [ValidateSet('DryRun','Apply')] [string]$Mode = 'DryRun',
  [switch]$WithTests,
  [switch]$WithAnalysis
)

Set-StrictMode -Version Latest
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here

Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
Import-Module (Join-Path $root 'modules/Notifications.psm1') -Force
Import-Module (Join-Path $root 'modules/Reports.psm1') -Force

Start-Log -Name 'scheduled_run' | Out-Null
$summaryLines = @()
try {
  $isDry = ($Mode -eq 'DryRun')
  Write-Log -Message ("Scheduled maintenance starting (Mode={0}, WithTests={1})" -f $Mode, $WithTests.IsPresent)
  if ($isDry) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'maintain.ps1') -Scope All -DryRun
  } else {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'maintain.ps1') -Scope All
  }
  if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-Log -Level WARN -Message ("maintain.ps1 exited with code {0}" -f $LASTEXITCODE) }
  $summaryLines += ("Maintenance: mode={0}" -f $Mode)

  if ($WithTests) {
    Write-Log -Message 'Running test suite (Pester)'
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Run-Tests.ps1')
    $code = $LASTEXITCODE
    if ($code -and $code -ne 0) {
      Write-Log -Level WARN -Message ("Tests reported failures (exit={0})" -f $code)
      $summaryLines += 'Tests: FAILED'
    } else {
      $summaryLines += 'Tests: PASSED'
    }
  }

  if ($WithAnalysis) {
    Write-Log -Message 'Running PSScriptAnalyzer'
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Run-Analyzer.ps1')
    $pssaExit = $LASTEXITCODE
    if ($pssaExit -and $pssaExit -ne 0) { $summaryLines += 'Analysis: ISSUES'; Write-Log -Level WARN -Message ("PSSA flagged issues (exit={0})" -f $pssaExit) } else { $summaryLines += 'Analysis: OK' }
  }

  # Disk usage snapshot and bundled report if enabled in config
  try {
    $cfg = Get-Content (Join-Path $root 'config.json') -Raw | ConvertFrom-Json
    if ($cfg.reports.enabled) {
      $du = New-DiskUsageSnapshot
      if ($du -and $du.SummaryCsv) { $summaryLines += ("Reports: disk usage -> {0}" -f $du.SummaryCsv) }
      if ($cfg.reports.attachZip) {
        # Build a full report ZIP (include tests if they ran)
        & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'Export-Report.ps1') -IncludeDiskUsage $(if ($WithTests) { '-IncludeTests' }) | Out-Null
        $repDir = Join-Path (Join-Path $root 'logs') 'reports'
        $latestZip = Get-ChildItem -LiteralPath $repDir -Filter 'report_*.zip' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestZip) { $reportZip = $latestZip.FullName; $summaryLines += ("Reports: zip -> {0}" -f $reportZip) }
      }
    }
  } catch {}
}
catch {
  Write-Log -Level ERROR -Message $_.Exception.Message
  $summaryLines += ("Error: {0}" -f $_.Exception.Message)
  throw
}
finally {
  Add-JournalEntry -Title ("Scheduled run (Mode={0}, WithTests={1})" -f $Mode, $WithTests.IsPresent) -Lines $summaryLines
  Stop-Log
}

# Notification summary (best-effort, does not fail the script)
try {
  # Determine statuses
  $testsStatus = if ($WithTests) { if ($code -and $code -ne 0) { 'FAILED' } else { 'PASSED' } } else { 'SKIPPED' }
  $analysisStatus = if ($WithAnalysis) { if ($pssaExit -and $pssaExit -ne 0) { 'ISSUES' } else { 'OK' } } else { 'SKIPPED' }
  $subject = "Scheduled $Mode: maintenance complete, tests $testsStatus, analysis $analysisStatus"
  # Locate latest logs
  $logs = Join-Path $root 'logs'
  $maintJsonl = Get-ChildItem -LiteralPath $logs -Filter 'maintenance_*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $testTxt = Get-ChildItem -LiteralPath $logs -Filter 'test_results_*.txt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $attachments = @()
  if ($maintJsonl) { $attachments += $maintJsonl.FullName }
  if ($testTxt) { $attachments += $testTxt.FullName }
  if ($reportZip) { $attachments += $reportZip }
  $body = @(
    ("Mode: {0}" -f $Mode),
    ("Tests: {0}" -f $testsStatus),
    ("Summary: {0}" -f ($summaryLines -join '; ')),
    ("Latest maintenance log: {0}" -f ($maintJsonl?.FullName)),
    ("Latest tests log: {0}" -f ($testTxt?.FullName))
  ) -join "`r`n"
  # For DryRun mode, embed a short journal snippet in the email body
  if ($Mode -eq 'DryRun') {
    $count = 10
    try {
      $cfgPath = Join-Path $root 'config.json'
      if (Test-Path $cfgPath) {
        $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
        if ($cfg.notifications.email.journalLines) { $count = [int]$cfg.notifications.email.journalLines }
      }
    } catch {}
    $snippet = Get-LatestJournalSnippet -Count $count
    if ($snippet) {
      $body += "`r`nJournal (last $count line(s)):" + "`r`n" + ($snippet -join "`r`n")
    }
  }
  # Include compact log digest (levels and count from config)
  try {
    $cfg = Get-Content (Join-Path $root 'config.json') -Raw | ConvertFrom-Json
    $ldCount = 5
    $ldLevels = @('ERROR','WARN')
    if ($cfg.notifications.email.logDigestLines) { $ldCount = [int]$cfg.notifications.email.logDigestLines }
    if ($cfg.notifications.email.logDigestLevels) { $ldLevels = @($cfg.notifications.email.logDigestLevels) }
    $digest = Get-LogDigest -Lines $ldCount -Levels $ldLevels
    if ($digest) {
      $body += "`r`nLog digest (last $ldCount ${ldLevels} line(s)):" + "`r`n" + ($digest -join "`r`n")
    }
  } catch {}
  # Send toast for failures or on apply mode
  if ($testsStatus -eq 'FAILED' -or $Mode -eq 'Apply') {
    Send-ToastNotification -Title $subject -Body 'Check logs for details.'
  }
  # Email if configured
  Send-EmailNotification -Subject $subject -Body $body -Attachments $attachments
} catch {
  Write-Log -Level WARN -Message ("Notifications failed: {0}" -f $_.Exception.Message)
}
