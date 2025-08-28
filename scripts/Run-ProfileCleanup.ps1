param(
  [switch]$Apply
)

Set-StrictMode -Version Latest

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$root = Split-Path -Parent $scriptRoot

Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
$modulesDir = Join-Path $root 'modules'
$wp = Join-Path $modulesDir 'WindowsProfile.psm1'
if (-not (Test-Path $wp)) {
  Write-Host "WindowsProfile module not found at: $wp" -ForegroundColor Red
  Write-Host "Check that the file exists. If not, pull/sync the toolkit files." -ForegroundColor Yellow
  throw "Missing module: $wp"
}
# Prefer dot-sourcing to ensure functions are in scope even if module import is blocked
try { . $wp } catch { Write-Host "Dot-sourcing failed: $($_.Exception.Message)" -ForegroundColor Red; throw }

Start-Log -Name 'profile_cleanup' | Out-Null
try {
  Write-Host ("Running user profile audit (Apply={0})..." -f $Apply.IsPresent) -ForegroundColor Cyan
  $audit = Audit-UserProfile -DryRun
  if (-not $audit) { Write-Host 'No audit entries found or audit disabled.' -ForegroundColor Yellow; return }

  $toDelete = $audit | Where-Object { $_.Action -eq 'Delete' }
  $toMove = $audit | Where-Object { $_.Action -eq 'Move' }

  Write-Host ("Planned deletes: {0}" -f (($toDelete | Measure-Object).Count)) -ForegroundColor Yellow
  foreach ($d in $toDelete) { Write-Host ("- DELETE {0}" -f $d.FullName) }
  Write-Host ("Planned moves: {0}" -f (($toMove | Measure-Object).Count)) -ForegroundColor Yellow
  foreach ($m in $toMove) { Write-Host ("- MOVE   {0} -> {1}" -f $m.FullName, (Join-Path $env:USERPROFILE $m.Target)) }
  # Empty dirs planned
  $edPreview = Remove-EmptyProfileDirs -DryRun:$true
  if ($edPreview.Planned -gt 0) {
    Write-Host ("Planned empty-dir deletes: {0}" -f $edPreview.Planned) -ForegroundColor Yellow
  }

  if ($Apply) {
    Write-Host 'Applying profile moves/deletes...' -ForegroundColor Cyan
    $res = Apply-UserProfileMoves -AuditEntries $audit
    Write-Host ("Profile moves: moved={0}, deleted={1}, skipped={2}" -f $res.Moved, $res.Deleted, $res.Skipped) -ForegroundColor Green
    $dc = Consolidate-Documents
    Write-Host ("Documents consolidation: {0}" -f $dc.Consolidated) -ForegroundColor Green
    $pj = Move-ProjectsToDocuments
    Write-Host ("Projects moved: {0} (out of {1})" -f $pj.Moved, $pj.Count) -ForegroundColor Green
    $ed = Remove-EmptyProfileDirs -DryRun:$false
    Write-Host ("Empty dirs: removed={0}, planned={1}" -f $ed.Removed, $ed.Planned) -ForegroundColor Green
  } else {
    Write-Host 'Preview mode: logging planned actions...' -ForegroundColor Cyan
    [void](Apply-UserProfileMoves -AuditEntries $audit -DryRun)
    [void](Consolidate-Documents -DryRun)
    [void](Move-ProjectsToDocuments -DryRun)
    [void](Remove-EmptyProfileDirs -DryRun:$true)
    Write-Host 'See logs/profile_cleanup_*.log and journal for details.' -ForegroundColor Green
  }
}
catch {
  Write-Log -Level ERROR -Message $_.Exception.Message
  throw
}
finally { Stop-Log }
