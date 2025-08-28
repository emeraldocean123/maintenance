Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$logs = Join-Path $root 'logs'
$out = Join-Path $logs 'summary.md'

Filter Get-Jsonl {
  param([string]$Path)
  Get-Content -LiteralPath $Path | ForEach-Object {
    try { $_ | ConvertFrom-Json } catch { $null }
  } | Where-Object { $_ -ne $null }
}

$jsonls = Get-ChildItem -LiteralPath $logs -Filter maintenance_*.jsonl -ErrorAction SilentlyContinue | Sort-Object LastWriteTime

"# Maintenance Summaries`n" | Out-File -FilePath $out -Encoding utf8
foreach ($jl in $jsonls) {
  $records = Get-Jsonl -Path $jl.FullName
  $runStart = $records | Where-Object { $_.event -eq 'log_start' } | Select-Object -First 1
  $done = $records | Where-Object { $_.message -eq 'Maintenance completed for scope=All' -or $_.message -like 'Maintenance completed*' } | Select-Object -Last 1
  $ts = if ($runStart) { $runStart.ts } else { (Get-Date -Format o) }
  "## $ts`n" | Out-File -FilePath $out -Append -Encoding utf8
  if ($done -and $done.data) {
    $d = $done.data
    if ($d.Windows -and $d.Windows.FlattenDownloads) { $fd = $d.Windows.FlattenDownloads; "- Downloads: moved $($fd.MovedFiles), empties $($fd.EmptyDirs)" | Out-File -FilePath $out -Append -Encoding utf8 }
    if ($d.Windows -and $d.Windows.Obsolete) { $ob = $d.Windows.Obsolete; "- Obsolete: removed $($ob.Removed) (would remove $($ob.WouldRemove))" | Out-File -FilePath $out -Append -Encoding utf8 }
    if ($d.Windows -and $d.Windows.MouseWithoutBorders) { $mw = $d.Windows.MouseWithoutBorders; "- MWB: moved $($mw.Moved) of $($mw.Found)" | Out-File -FilePath $out -Append -Encoding utf8 }
    if ($d.GitHub -and $d.GitHub.ClosedIssues) { $ci = $d.GitHub.ClosedIssues; "- GitHub Issues: closed $($ci.IssuesClosed) across $($ci.Repos) repos" | Out-File -FilePath $out -Append -Encoding utf8 }
    if ($d.GitHub -and $d.GitHub.Workflows) { $wf = $d.GitHub.Workflows; "- GitHub WF: attempted $($wf.WorkflowsAttempted), disabled $($wf.WorkflowsDisabled) across $($wf.Repos) repos" | Out-File -FilePath $out -Append -Encoding utf8 }
    if ($d.Nix) { "- Nix: invoked=$($d.Nix.Invoked)" | Out-File -FilePath $out -Append -Encoding utf8 }
  }
  "`n" | Out-File -FilePath $out -Append -Encoding utf8
}

Write-Host "Summary written to $out"

