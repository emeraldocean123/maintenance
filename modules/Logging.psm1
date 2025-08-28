Set-StrictMode -Version Latest

$Script:ModulesDir = Split-Path -Parent $PSCommandPath
$Script:MaintenanceRoot = Split-Path -Parent $Script:ModulesDir
$Script:LogsDir = Join-Path $Script:MaintenanceRoot 'logs'
New-Item -ItemType Directory -Path $Script:LogsDir -Force | Out-Null

$Script:LogFile = $null
$Script:JsonLogFile = $null
$Script:Config = $null

function Get-MaintenanceConfig {
  if ($Script:Config) { return $Script:Config }
  try {
    $cfgPath = Join-Path $Script:MaintenanceRoot 'config.json'
    if (Test-Path $cfgPath) {
      $Script:Config = Get-Content $cfgPath -Raw | ConvertFrom-Json
    }
  } catch {}
  return $Script:Config
}

function Invoke-LogRetention {
  $cfg = Get-MaintenanceConfig
  $retDays = 90; $maxFiles = 500
  if ($cfg -and $cfg.logging) {
    if ($cfg.logging.retentionDays) { $retDays = [int]$cfg.logging.retentionDays }
    if ($cfg.logging.maxFiles) { $maxFiles = [int]$cfg.logging.maxFiles }
  }
  $cutoff = (Get-Date).AddDays(-$retDays)
  $removed = 0
  $patterns = @('*.log','*.jsonl')
  foreach ($pat in $patterns) {
    $files = Get-ChildItem -LiteralPath $Script:LogsDir -Filter $pat -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime
    # Remove by date first
    foreach ($f in $files) {
      if ($f.LastWriteTime -lt $cutoff -and $f.FullName -ne $Script:LogFile -and $f.FullName -ne $Script:JsonLogFile) {
        try { Remove-Item -LiteralPath $f.FullName -Force; $removed++ } catch {}
      }
    }
    # Enforce max files per pattern
    $files = Get-ChildItem -LiteralPath $Script:LogsDir -Filter $pat -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    $toKeep = $maxFiles
    for ($i = $toKeep; $i -lt $files.Count; $i++) {
      $f = $files[$i]
      if ($f.FullName -ne $Script:LogFile -and $f.FullName -ne $Script:JsonLogFile) {
        try { Remove-Item -LiteralPath $f.FullName -Force; $removed++ } catch {}
      }
    }
  }
  if ($removed -gt 0) {
    Write-Log -Message "Log retention pruned $removed file(s)" -Level INFO
  }
}

function Get-Timestamp {
  (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffK')
}

function Start-Log {
  param(
    [string]$Name = "run"
  )
  $ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
  $Script:LogFile = Join-Path $Script:LogsDir "$Name`_$ts.log"
  $Script:JsonLogFile = Join-Path $Script:LogsDir "$Name`_$ts.jsonl"
  "# Log start: $(Get-Timestamp) - $Name" | Out-File -FilePath $Script:LogFile -Encoding utf8 -Append
  '{"ts":"' + (Get-Timestamp) + '","event":"log_start","name":"' + $Name + '"}' | Out-File -FilePath $Script:JsonLogFile -Encoding utf8 -Append
  Invoke-LogRetention
  return @{ LogFile = $Script:LogFile; JsonLogFile = $Script:JsonLogFile }
}

function Write-Log {
  param(
    [ValidateSet('INFO','WARN','ERROR','DEBUG')] [string]$Level = 'INFO',
    [Parameter(Mandatory)] [string]$Message,
    [hashtable]$Data
  )
  if (-not $Script:LogFile) { Start-Log | Out-Null }
  $ts = Get-Timestamp
  $line = "[$ts] [$Level] $Message"
  $line | Out-File -FilePath $Script:LogFile -Encoding utf8 -Append
  if ($Script:JsonLogFile) {
    $payload = @{ ts = $ts; level = $Level; message = $Message }
    if ($Data) { $payload.data = $Data }
    ($payload | ConvertTo-Json -Compress) | Out-File -FilePath $Script:JsonLogFile -Encoding utf8 -Append
  }
}

function Stop-Log {
  if ($Script:LogFile) {
    $ts = Get-Timestamp
    "# Log end: $ts" | Out-File -FilePath $Script:LogFile -Encoding utf8 -Append
    if ($Script:JsonLogFile) {
      '{"ts":"' + $ts + '","event":"log_end"}' | Out-File -FilePath $Script:JsonLogFile -Encoding utf8 -Append
    }
    $Script:LogFile = $null
    $Script:JsonLogFile = $null
  }
}

function Add-JournalEntry {
  param(
    [Parameter(Mandatory)] [string]$Title,
    [string[]]$Lines
  )
  $journal = Join-Path $Script:LogsDir 'journal.md'
  if (-not (Test-Path $journal)) {
    "# Maintenance Journal`n" | Out-File -FilePath $journal -Encoding utf8
  }
  $ts = Get-Date
  "## $($ts.ToString('yyyy-MM-dd HH:mm:ss K')) - $Title`n" | Out-File -FilePath $journal -Append -Encoding utf8
  if ($Lines) {
    foreach ($l in $Lines) { "- $l" | Out-File -FilePath $journal -Append -Encoding utf8 }
  }
  "`n" | Out-File -FilePath $journal -Append -Encoding utf8
}

Export-ModuleMember -Function Start-Log, Write-Log, Stop-Log, Add-JournalEntry
