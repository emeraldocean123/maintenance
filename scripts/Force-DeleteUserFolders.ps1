Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
Import-Module (Join-Path $root 'modules/Logging.psm1') -Force
Import-Module (Join-Path $root 'modules/WindowsProfile.psm1') -Force

Start-Log -Name 'force_delete_user_folders' | Out-Null
try {
  $targets = @(
    (Join-Path $env:USERPROFILE 'maintenance'),
    (Join-Path $env:USERPROFILE 'node_modules')
  )

  foreach ($path in $targets) {
    if (-not (Test-Path $path)) { Write-Host "Absent: $path" -ForegroundColor Green; continue }
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.PSIsContainer -and (Is-ReparsePoint $item)) {
      Write-Host "Skipping reparse point: $path" -ForegroundColor Yellow
      Write-Log -Level WARN -Message "Skipping reparse point $path"
      continue
    }
    if ((Split-Path -Leaf $path) -eq 'node_modules') {
      $isNpmRoot = $false
      try {
        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
        if ($npmCmd) {
          $npmRoot = & npm root -g 2>$null
          if ($npmRoot) { $npmRoot = $npmRoot.Trim() }
          if ($npmRoot -and ($npmRoot -ieq $path)) { $isNpmRoot = $true }
        }
      } catch {}
      if ($isNpmRoot) {
        Write-Host "Skipping npm global root: $path" -ForegroundColor Yellow
        Write-Log -Level WARN -Message "Skipping npm global root $path"
        continue
      }
    }

    Write-Host "Deleting: $path" -ForegroundColor Cyan
    $deleted = $false
    try {
      Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
      $deleted = $true
    } catch {
      Write-Log -Level WARN -Message ("Remove-Item failed for {0}: {1}" -f $path, $_.Exception.Message)
    }
    if (-not $deleted -and (Test-Path $path)) {
      try {
        attrib -r -s -h "$path" /s /d 2>$null | Out-Null
      } catch {}
      try {
        cmd.exe /c "rmdir /s /q \"$path\"" | Out-Null
        $deleted = -not (Test-Path $path)
      } catch {
        Write-Log -Level WARN -Message ("cmd rmdir failed for {0}: {1}" -f $path, $_.Exception.Message)
      }
    }
    if ($deleted) { Write-Host "Deleted: $path" -ForegroundColor Green; Write-Log -Message "Deleted $path" }
    else { Write-Host "Still present: $path" -ForegroundColor Red; Write-Log -Level WARN -Message "Still present $path" }
  }
}
finally { Stop-Log }
