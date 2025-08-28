param(
  [switch]$IncludeJournal,
  [switch]$IncludeDigest,
  [switch]$AttachLatestLogs,
  [int]$JournalLines,
  [int]$DigestLines,
  [string[]]$DigestLevels,
  [string]$Subject,
  [switch]$DryRun
)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here

Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
Import-Module (Join-Path $root 'modules/Notifications.psm1') -Force

Start-Log -Name 'email_test' | Out-Null
try {
  $cfgPath = Join-Path $root 'config.json'
  if (-not (Test-Path $cfgPath)) { throw "Config file not found: $cfgPath" }
  $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
  $email = $cfg.notifications.email

  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
  $hostInfo = "Host=$($env:COMPUTERNAME) User=$($env:USERDOMAIN)\\$($env:USERNAME)"
  $Subject = $Subject ?? ("[Maintenance] Email connectivity test - $ts")

  $bodyLines = @(
    "Connectivity test at $ts",
    $hostInfo,
    "smtpServer=$($email.smtpServer), port=$($email.smtpPort), useSsl=$($email.useSsl)",
    "from=$($email.from)",
    "toCount=$(@($email.to | Where-Object { $_ }).Count)",
    "subjectPrefix=$($email.subjectPrefix)"
  )

  # Optional journal snippet
  $jrCount = if ($JournalLines) { $JournalLines } elseif ($email.journalLines) { [int]$email.journalLines } else { 10 }
  if ($IncludeJournal) {
    $snippet = Get-LatestJournalSnippet -Count $jrCount
    if ($snippet) {
      $bodyLines += ""
      $bodyLines += "Journal (last $jrCount line(s)):" 
      $bodyLines += ($snippet)
    } else {
      $bodyLines += "Journal: no recent bullet lines found"
    }
  }

  # Optional log digest
  $dgCount = if ($DigestLines) { $DigestLines } elseif ($email.logDigestLines) { [int]$email.logDigestLines } else { 5 }
  $dgLevels = if ($DigestLevels) { $DigestLevels } elseif ($email.logDigestLevels) { @($email.logDigestLevels) } else { @('ERROR','WARN') }
  if ($IncludeDigest) {
    $digest = Get-LogDigest -Lines $dgCount -Levels $dgLevels
    if ($digest) {
      $bodyLines += ""
      $bodyLines += "Log digest (last $dgCount $($dgLevels -join ',') line(s)):" 
      $bodyLines += $digest
    } else {
      $bodyLines += "Log digest: no matching lines found"
    }
  }

  # Optional attachments
  $attachments = @()
  if ($AttachLatestLogs) {
    $logs = Join-Path $root 'logs'
    $maintJsonl = Get-ChildItem -LiteralPath $logs -Filter 'maintenance_*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $testTxt = Get-ChildItem -LiteralPath $logs -Filter 'test_results_*.txt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($maintJsonl) { $attachments += $maintJsonl.FullName }
    if ($testTxt) { $attachments += $testTxt.FullName }
  }

  $body = ($bodyLines -join "`r`n")

  if ($DryRun) {
    Write-Log -Message 'Email test dry-run' -Data @{ subject=$Subject; attachments=$attachments; bodyPreview=($body.Substring(0,[Math]::Min($body.Length,200))) }
    Write-Host "[DRY-RUN] Subject: $Subject"
    Write-Host "[DRY-RUN] Attachments: $($attachments -join ', ')"
    Write-Host "[DRY-RUN] Body preview:"; Write-Host ($body -replace "`r`n","`n")
    return
  }

  if (-not $cfg.notifications.email.enabled) {
    Write-Host 'Email notifications are disabled in config.json (notifications.email.enabled=false).' -ForegroundColor Yellow
    Write-Host 'Enable them to send a real test, or run with -DryRun to preview.' -ForegroundColor Yellow
    Write-Log -Level WARN -Message 'Email test skipped: email notifications disabled'
    return
  }

  Send-EmailNotification -Subject $Subject -Body $body -Attachments $attachments
  Write-Host 'Test email sent (check your inbox).' -ForegroundColor Green
}
catch {
  Write-Log -Level ERROR -Message $_.Exception.Message
  throw
}
finally { Stop-Log }

