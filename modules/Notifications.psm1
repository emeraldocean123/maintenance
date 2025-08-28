Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSCommandPath) 'Logging.psm1') -Force
Import-Module (Join-Path (Split-Path -Parent $PSCommandPath) 'SecureStore.psm1') -Force

function Get-NotificationsConfig {
  $root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
  $cfgPath = Join-Path $root 'config.json'
  if (-not (Test-Path $cfgPath)) { return $null }
  try { return (Get-Content $cfgPath -Raw | ConvertFrom-Json).notifications } catch { return $null }
}

function Send-ToastNotification {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Body
  )
  $cfg = Get-NotificationsConfig
  if (-not $cfg -or -not $cfg.toast -or -not $cfg.toast.enabled) { return }
  try {
    if (Get-Module -ListAvailable -Name BurntToast) {
      Import-Module BurntToast -ErrorAction SilentlyContinue
      New-BurntToastNotification -Text $Title, $Body | Out-Null
      Write-Log -Message "Sent toast via BurntToast"
      return
    }
  } catch {}
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipTitle = $Title
    $notify.BalloonTipText = $Body
    $notify.Visible = $true
    $notify.ShowBalloonTip(5000)
    Start-Sleep -Seconds 6
    $notify.Dispose()
    Write-Log -Message "Sent toast via NotifyIcon"
  } catch {
    Write-Log -Level WARN -Message ("Toast notification failed: {0}" -f $_.Exception.Message)
  }
}

function Resolve-EmailCredentials {
  param($EmailCfg)
  $user = $null; $pass = $null
  if ($EmailCfg.usernameEnv) { $user = [Environment]::GetEnvironmentVariable($EmailCfg.usernameEnv, 'User') }
  if (-not $user -and $EmailCfg.username) { $user = $EmailCfg.username }
  if ($EmailCfg.passwordEnv) { $pass = [Environment]::GetEnvironmentVariable($EmailCfg.passwordEnv, 'User') }
  if (-not $pass -and $EmailCfg.passwordSecret) { $pass = Get-SecretValue -Name $EmailCfg.passwordSecret }
  return @{ Username = $user; Password = $pass }
}

function Send-EmailNotification {
  param(
    [Parameter(Mandatory)][string]$Subject,
    [Parameter(Mandatory)][string]$Body,
    [string[]]$Attachments
  )
  $cfg = Get-NotificationsConfig
  if (-not $cfg -or -not $cfg.email -or -not $cfg.email.enabled) { return }
  $email = $cfg.email
  if (-not $email.smtpServer -or -not $email.from -or -not $email.to) { Write-Log -Level WARN -Message 'Email config incomplete; skipping email'; return }

  try {
    $client = New-Object System.Net.Mail.SmtpClient($email.smtpServer, [int]$email.smtpPort)
    $client.EnableSsl = [bool]$email.useSsl
    $creds = Resolve-EmailCredentials -EmailCfg $email
    if ($creds.Username -and $creds.Password) {
      $client.Credentials = New-Object System.Net.NetworkCredential($creds.Username, $creds.Password)
    }
    $msg = New-Object System.Net.Mail.MailMessage
    $msg.From = $email.from
    foreach ($t in $email.to) { if ($t) { [void]$msg.To.Add($t) } }
    $prefix = if ($email.subjectPrefix) { $email.subjectPrefix + ' ' } else { '' }
    $msg.Subject = $prefix + $Subject
    $msg.Body = $Body
    $msg.IsBodyHtml = $false
    if ($Attachments) {
      foreach ($a in $Attachments) { if ($a -and (Test-Path $a)) { $att = New-Object System.Net.Mail.Attachment($a); $msg.Attachments.Add($att) | Out-Null } }
    }
    $client.Send($msg)
    Write-Log -Message 'Sent email notification'
  } catch {
    Write-Log -Level WARN -Message ("Email notification failed: {0}" -f $_.Exception.Message)
  }
}

Export-ModuleMember -Function Send-ToastNotification, Send-EmailNotification

function Get-LatestJournalSnippet {
  param([int]$Count = 10)
  $root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
  $journal = Join-Path $root 'logs/journal.md'
  if (-not (Test-Path $journal)) { return $null }
  try {
    $lines = Get-Content -LiteralPath $journal -ErrorAction Stop
    # Find last heading starting with '## '
    $idxs = for ($i=0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^## ') { $i } }
    if (-not $idxs -or $idxs.Count -eq 0) { return $null }
    $start = $idxs[-1]
    $block = @()
    for ($j=$start+1; $j -lt $lines.Count; $j++) {
      if ($lines[$j] -match '^## ') { break }
      if ($lines[$j] -match '^- ') { $block += $lines[$j] }
    }
    if (-not $block -or $block.Count -eq 0) { return $null }
    return ($block | Select-Object -First $Count)
  } catch {
    Write-Log -Level WARN -Message ("Failed to get journal snippet: {0}" -f $_.Exception.Message)
    return $null
  }
}

Export-ModuleMember -Function Get-LatestJournalSnippet

function Get-LogDigest {
  param(
    [int]$Lines,
    [string[]]$Levels
  )
  $root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
  $logs = Join-Path $root 'logs'
  $cfg = $null
  try {
    $cfg = (Get-Content (Join-Path $root 'config.json') -Raw | ConvertFrom-Json)
  } catch {}
  if (-not $Levels -or $Levels.Count -eq 0) {
    $Levels = @('ERROR','WARN')
    try { if ($cfg.notifications.email.logDigestLevels) { $Levels = @($cfg.notifications.email.logDigestLevels) } } catch {}
  }
  if (-not $Lines -or $Lines -le 0) {
    $Lines = 5
    try { if ($cfg.notifications.email.logDigestLines) { $Lines = [int]$cfg.notifications.email.logDigestLines } } catch {}
  }
  $latest = Get-ChildItem -LiteralPath $logs -Filter 'maintenance_*.log' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { return $null }
  $levelsSet = @{}; foreach ($l in $Levels) { $levelsSet[$l.ToUpperInvariant()] = $true }
  $pattern = '^[[](?<ts>[^\]]+)[]] \[(?<lvl>[^\]]+)\] (?<msg>.*)$'
  $matches = @()
  try {
    Get-Content -LiteralPath $latest.FullName | ForEach-Object {
      $m = [regex]::Match($_, $pattern)
      if ($m.Success) {
        $lvl = $m.Groups['lvl'].Value.ToUpperInvariant()
        if ($levelsSet.ContainsKey($lvl)) { $matches += $_ }
      }
    }
  } catch {}
  if (-not $matches -or $matches.Count -eq 0) { return $null }
  return ($matches | Select-Object -Last $Lines)
}

Export-ModuleMember -Function Get-LogDigest
