param(
  [switch]$FixFormat,
  [string]$Severity,
  [string[]]$TreatAsErrorRules
)

Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null

function Ensure-PSScriptAnalyzer {
  try { Import-Module PSScriptAnalyzer -MinimumVersion 1.20 -ErrorAction Stop; return $true }
  catch {
    Write-Host 'PSScriptAnalyzer not found. Installing to CurrentUser...' -ForegroundColor Yellow
    try {
      Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop
      Import-Module PSScriptAnalyzer -MinimumVersion 1.20 -ErrorAction Stop
      return $true
    } catch {
      Write-Host "Failed to install PSScriptAnalyzer: $($_.Exception.Message)" -ForegroundColor Red
      return $false
    }
  }
}

if (-not (Ensure-PSScriptAnalyzer)) { exit 1 }

$cfgPath = Join-Path $root 'config.json'
if (Test-Path $cfgPath) {
  $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
  if (-not $PSBoundParameters.ContainsKey('FixFormat')) { $FixFormat = [bool]$cfg.pssa.fixFormat }
  if (-not $PSBoundParameters.ContainsKey('Severity') -and $cfg.pssa.severity) { $Severity = $cfg.pssa.severity }
  if (-not $PSBoundParameters.ContainsKey('TreatAsErrorRules') -and $cfg.pssa.treatAsErrorRules) { $TreatAsErrorRules = @($cfg.pssa.treatAsErrorRules) }
}

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$txt = Join-Path $logs ("pssa_$ts.txt")
$json = Join-Path $logs ("pssa_$ts.json")

$paths = @(
  Join-Path $root 'modules',
  Join-Path $root 'scripts',
  Join-Path $root 'tests'
)

Write-Host 'Running PSScriptAnalyzer...' -ForegroundColor Cyan
if ($FixFormat) {
  Write-Host 'Applying code formatting using Invoke-Formatter...' -ForegroundColor DarkCyan
  Get-ChildItem -Path $paths -Recurse -Include *.ps1,*.psm1,*.psd1 -File | ForEach-Object {
    try { $formatted = Invoke-Formatter -ScriptDefinition (Get-Content $_.FullName -Raw); if ($formatted) { Set-Content -Path $_.FullName -Value $formatted -Encoding UTF8 } } catch {}
  }
}

$severity = if ($Severity) { $Severity } else { 'Warning' }
$results = Invoke-ScriptAnalyzer -Path $paths -Severity $severity -Recurse -ErrorAction SilentlyContinue
$results | Out-String | Out-File -FilePath $txt -Encoding utf8
$results | ConvertTo-Json -Depth 5 | Out-File -FilePath $json -Encoding utf8

# Exit non-zero if treat-as-error rules found
$fail = $false
if ($TreatAsErrorRules -and $results) {
  foreach ($r in $results) {
    if ($TreatAsErrorRules -contains $r.RuleName) { $fail = $true; break }
  }
}

if ($fail) { Write-Host 'Analyzer found violations of error rules.' -ForegroundColor Red; exit 2 } else { Write-Host 'Analyzer completed.' -ForegroundColor Green }

