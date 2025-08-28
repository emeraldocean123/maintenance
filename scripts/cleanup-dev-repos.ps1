<#
.SYNOPSIS
  Cleans common junk and transient files from dev repos under Documents\dev and related folders.

.NOTES
  Safe deletions only: .DS_Store, Thumbs.db, *.tmp, *.bak, *.old, *.orig, .eslintcache, *.tsbuildinfo, *.log in temp dirs.
#>
param(
  [string[]]$Roots = @(
    "$HOME\Documents\dev",
    "$HOME\Documents\PowerShell"
  )
)

$ErrorActionPreference = 'SilentlyContinue'
Write-Host "[cleanup] Starting cleanup at $(Get-Date)" -ForegroundColor Cyan

$patterns = @(
  '*.DS_Store','Thumbs.db','*.tmp','*.bak','*.old','*.orig','.eslintcache','*.tsbuildinfo','*.lcov','*.coverage'
)

$deleted = @()
foreach ($root in $Roots) {
  if (-not (Test-Path $root)) { continue }
  foreach ($pat in $patterns) {
    Get-ChildItem -Path $root -Recurse -Force -File -Filter $pat |
      Where-Object { $_.FullName -notmatch '\\AppData\\' -and $_.FullName -notmatch '\\.git\\' } |
      ForEach-Object {
        try { Remove-Item -Force -LiteralPath $_.FullName; $deleted += $_.FullName }
        catch {}
      }
  }
  # Remove empty directories left behind
  Get-ChildItem -Path $root -Recurse -Force -Directory |
    Where-Object { $_.GetFileSystemInfos().Count -eq 0 } |
    ForEach-Object { try { Remove-Item -Force -Recurse -LiteralPath $_.FullName } catch {} }
}

Write-Host "[cleanup] Deleted $($deleted.Count) files" -ForegroundColor Green
if ($deleted.Count -gt 0) { $deleted | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray } }
Write-Host "[cleanup] Done" -ForegroundColor Cyan
