Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$tests = Join-Path $root 'tests'
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null

function Ensure-Pester {
  try { Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop; return $true }
  catch {
    Write-Host 'Pester not found. Installing to CurrentUser...' -ForegroundColor Yellow
    try {
      Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop
      Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
      return $true
    } catch {
      Write-Host "Failed to install Pester: $($_.Exception.Message)" -ForegroundColor Red
      return $false
    }
  }
}

if (-not (Ensure-Pester)) { exit 1 }

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$txt = Join-Path $logs ("test_results_$ts.txt")
$json = Join-Path $logs ("test_results_$ts.json")

Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
Start-Log -Name 'pester_tests' | Out-Null
try {
  $result = Invoke-Pester -Path $tests -CI -Output Detailed -PassThru -ExcludeTag 'network'
  $result | Out-String | Out-File -FilePath $txt -Encoding utf8
  $result | ConvertTo-Json -Depth 5 | Out-File -FilePath $json -Encoding utf8
  if ($result.FailedCount -gt 0) { Write-Host ("Tests failed: {0}" -f $result.FailedCount) -ForegroundColor Red; exit 1 }
  Write-Host 'All tests passed.' -ForegroundColor Green
}
finally {
  Stop-Log
}

