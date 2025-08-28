Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSCommandPath) 'Logging.psm1') -Force

function Resolve-PathVars {
  param([string]$Path)
  if (-not $Path) { return $Path }
  $out = $Path.Replace('${USERPROFILE}', $env:USERPROFILE)
  return $out
}

function New-DiskUsageSnapshot {
  param(
    [string[]]$Paths,
    [string[]]$ExcludeDirNames,
    [int]$TopFiles = 20
  )
  $here = Split-Path -Parent $PSCommandPath
  $root = Split-Path -Parent $here
  $logs = Join-Path $root 'logs'
  $outDir = Join-Path $logs 'reports'
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null

  # Load defaults from config when parameters are not set
  if (-not $Paths -or $Paths.Count -eq 0) {
    try {
      $cfg = Get-Content (Join-Path $root 'config.json') -Raw | ConvertFrom-Json
      $Paths = @($cfg.reports.includePaths)
      $ExcludeDirNames = @($cfg.reports.excludeDirNames)
      if ($cfg.reports.topFiles) { $TopFiles = [int]$cfg.reports.topFiles }
    } catch {}
  }

  $Paths = $Paths | ForEach-Object { Resolve-PathVars $_ } | Where-Object { $_ }
  $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $jsonPath = Join-Path $outDir ("disk_usage_${timestamp}.json")
  $csvPath = Join-Path $outDir ("disk_usage_${timestamp}.csv")
  $topCsvPath = Join-Path $outDir ("disk_topfiles_${timestamp}.csv")

  $results = @()
  $topfiles = @()
  foreach ($p in $Paths) {
    $exists = Test-Path $p
    $item = [ordered]@{ Path = $p; Exists = $exists; Files = 0; SizeBytes = 0 }
    if ($exists) {
      try {
        $filter = { $_.PSIsContainer -and ($ExcludeDirNames -contains $_.Name) }
        $files = Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
        $item.Files = ($files | Measure-Object).Count
        $item.SizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
        $results += [pscustomobject]$item
        # top files per path
        if ($TopFiles -gt 0) {
          $tops = $files | Sort-Object Length -Descending | Select-Object -First $TopFiles | ForEach-Object {
            [pscustomobject]@{ Path = $_.FullName; SizeBytes = $_.Length; BasePath = $p }
          }
          $topfiles += $tops
        }
      } catch {
        Write-Log -Level WARN -Message ("Disk usage scan failed for {0}: {1}" -f $p, $_.Exception.Message)
        $results += [pscustomobject]$item
      }
    } else {
      $results += [pscustomobject]$item
    }
  }

  $results | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonPath -Encoding utf8
  $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
  if ($topfiles.Count -gt 0) { $topfiles | Export-Csv -Path $topCsvPath -NoTypeInformation -Encoding utf8 }

  Write-Log -Message 'Disk usage snapshot written' -Data @{ json = $jsonPath; csv = $csvPath; top = $topCsvPath }
  return [pscustomobject]@{ SummaryCsv = $csvPath; Json = $jsonPath; TopFilesCsv = $topCsvPath }
}

Export-ModuleMember -Function New-DiskUsageSnapshot

