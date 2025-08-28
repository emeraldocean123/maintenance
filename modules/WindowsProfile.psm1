Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSCommandPath) 'Logging.psm1') -Force

function Is-ReparsePoint {
  param([System.IO.FileSystemInfo]$Item)
  return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Flatten-Downloads {
  param(
    [switch]$DryRun = $true,
    [pscustomobject]$Config
  )
  $downloads = Join-Path $env:USERPROFILE 'Downloads'
  if (-not (Test-Path $downloads)) {
    Write-Log -Level WARN -Message "Downloads folder not found: $downloads"
    return
  }
  Write-Log -Message "Flattening Downloads at $downloads (DryRun=$($DryRun.IsPresent))"
  $exclusions = @()
  if ($Config -and $Config.excludePaths) { $exclusions = $Config.excludePaths }

  $moved = 0; $skipped = 0
  $subdirs = Get-ChildItem -LiteralPath $downloads -Directory -Force -ErrorAction SilentlyContinue
  foreach ($dir in $subdirs) {
    if (Is-ReparsePoint $dir) { Write-Log -Level INFO -Message "Skip reparse directory: $($dir.FullName)"; $skipped++; continue }
    if ($exclusions -contains $dir.Name) { Write-Log -Level INFO -Message "Skip excluded directory: $($dir.FullName)"; $skipped++; continue }
    $files = Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
    foreach ($file in $files) {
      $target = Join-Path $downloads $file.Name
      $base = [IO.Path]::GetFileNameWithoutExtension($file.Name)
      $ext = [IO.Path]::GetExtension($file.Name)
      $i = 1
      while (Test-Path $target) {
        $target = Join-Path $downloads ("{0} ({1}){2}" -f $base, $i, $ext)
        $i++
      }
      if ($DryRun) {
        Write-Log -Message "Would move $($file.FullName) -> $target"
      } else {
        try {
          Move-Item -LiteralPath $file.FullName -Destination $target -Force
          Write-Log -Message "Moved $($file.FullName) -> $target"
        } catch {
          Write-Log -Level WARN -Message "Failed to move $($file.FullName): $($_.Exception.Message)"
        }
      }
      $moved++
    }
  }
  # Remove empty directories
  $empties = Get-ChildItem -LiteralPath $downloads -Directory -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue) }
  foreach ($d in $empties) {
    if ($DryRun) { Write-Log -Message "Would remove empty folder $($d.FullName)" }
    else {
      try { Remove-Item -LiteralPath $d.FullName -Recurse -Force; Write-Log -Message "Removed empty folder $($d.FullName)" }
      catch { Write-Log -Level WARN -Message "Failed to remove $($d.FullName): $($_.Exception.Message)" }
    }
  }
  $summary = [pscustomobject]@{ MovedFiles = $moved; SkippedDirs = $skipped; EmptyDirs = ($empties.Count) }
  Write-Log -Message "Flattened Downloads complete" -Data ($summary | ConvertTo-Json | ConvertFrom-Json)
  return $summary
}

function Get-UserProfileConfig {
  $modulesDir = Split-Path -Parent $PSCommandPath
  $root = Split-Path -Parent $modulesDir
  $cfgPath = Join-Path $root 'config.json'
  if (Test-Path $cfgPath) {
    try { return (Get-Content $cfgPath -Raw | ConvertFrom-Json).profileAudit } catch { return $null }
  }
  return $null
}

function Audit-UserProfile {
  param([switch]$DryRun = $true)
  $cfg = Get-UserProfileConfig
  if (-not $cfg -or -not $cfg.enable) { Write-Log -Message 'Profile audit disabled in config'; return $null }
  $root = $env:USERPROFILE
  $logsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'logs'
  $repDir = Join-Path $logsDir 'reports'
  New-Item -ItemType Directory -Path $repDir -Force | Out-Null
  $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
  $csv = Join-Path $repDir ("user_profile_audit_$ts.csv")
  $json = Join-Path $repDir ("user_profile_audit_$ts.json")

  $keep = @($cfg.keepRoot)
  $preserve = @($cfg.preserveNames)
  $delete = @($cfg.deleteNames)
  $rules = @{}
  if ($cfg.moveRules) { $cfg.moveRules.PSObject.Properties | ForEach-Object { $rules[$_.Name] = $_.Value } }

  $entries = @()
  $items = Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('.', '..') }
  foreach ($it in $items) {
    if ($it.PSIsContainer) {
      $name = $it.Name
      $isReparse = Is-ReparsePoint $it
      $action = 'Unknown'
      $target = $null
      if ($keep -contains $name) { $action = 'Keep' }
      elseif ($preserve -contains $name) { $action = 'Preserve' }
      elseif ($delete -contains $name) { $action = 'Delete' }
      else {
        # rule matching: exact, then wildcard
        if ($rules.ContainsKey($name)) { $action = 'Move'; $target = $rules[$name] }
        else {
          foreach ($key in $rules.Keys) {
            if ($key -like '*?*' -or $key -like '*[*' -or $key -like '*]*' -or $key.Contains('*') -or $key.Contains('?')) {
              if ($name -like $key) { $action = 'Move'; $target = $rules[$key]; break }
            }
          }
        }
      }
      # Reparse points should not be deleted; override to Preserve
      if ($isReparse -and $action -eq 'Delete') { $action = 'Preserve' }
      $size = 0
      try { $size = (Get-ChildItem -LiteralPath $it.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } catch {}
      $entries += [pscustomobject]@{
        Name = $name; FullName = $it.FullName; Type = 'Directory'; IsReparse = $isReparse; SizeBytes = $size; Action = $action; Target = $target
      }
    } else {
      $entries += [pscustomobject]@{ Name = $it.Name; FullName = $it.FullName; Type = 'File'; IsReparse = $false; SizeBytes = $it.Length; Action = 'Keep'; Target = $null }
    }
  }

  $entries | Export-Csv -Path $csv -NoTypeInformation -Encoding utf8
  $entries | ConvertTo-Json -Depth 4 | Out-File -FilePath $json -Encoding utf8
  Write-Log -Message 'User profile audit written' -Data @{ csv = $csv; json = $json }
  return $entries
}

function Apply-UserProfileMoves {
  param(
    [Parameter(Mandatory)][array]$AuditEntries,
    [switch]$DryRun = $true
  )
  $moves = $AuditEntries | Where-Object { $_.Action -eq 'Move' -and $_.Target }
  $deletes = $AuditEntries | Where-Object { $_.Action -eq 'Delete' }
  $moved = 0; $deleted = 0; $skipped = 0
  # Moves
  foreach ($m in $moves) {
    $src = $m.FullName
    $destRel = $m.Target
    $base = Join-Path $env:USERPROFILE $destRel
    if (Test-Path $base -and (Get-Item $base).PSIsContainer) {
      $dest = Join-Path $base ([IO.Path]::GetFileName($src))
    } else {
      $dest = $base
    }
    $target = $dest
    $i = 1
    while (Test-Path $target) { $target = "$dest ($i)"; $i++ }
    if ($DryRun) { Write-Log -Message "Would move $src -> $target"; $skipped++; continue }
    try {
      New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
      Move-Item -LiteralPath $src -Destination $target -Force
      $moved++
      Write-Log -Message "Moved $src -> $target"
    } catch {
      Write-Log -Level WARN -Message "Failed to move $src: $($_.Exception.Message)"; $skipped++
    }
  }
  # Deletes
  foreach ($d in $deletes) {
    $src = $d.FullName
    if ($DryRun) { Write-Log -Message "Would delete $src"; $skipped++; continue }
    try {
      # Safety: skip if npm global root points here
      $isNpmRoot = $false
      try {
        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
        if ($npmCmd) {
          $npmRoot = & npm root -g 2>$null
          if ($npmRoot) { $npmRoot = $npmRoot.Trim() }
          if ($npmRoot -and ($npmRoot -eq $src)) { $isNpmRoot = $true }
        }
      } catch {}
      if ($isNpmRoot) { Write-Log -Level WARN -Message "Skipping delete of npm global root: $src"; $skipped++; continue }
      Remove-Item -LiteralPath $src -Recurse -Force
      $deleted++
      Write-Log -Message "Deleted $src"
    } catch {
      Write-Log -Level WARN -Message "Failed to delete $src: $($_.Exception.Message)"; $skipped++
    }
  }
  return [pscustomobject]@{ Moved = $moved; Deleted = $deleted; Skipped = $skipped }
}

function Consolidate-Documents {
  param([switch]$DryRun = $true)
  $cfg = Get-UserProfileConfig
  $docs = Join-Path $env:USERPROFILE 'Documents'
  if (-not (Test-Path $docs)) { return [pscustomobject]@{ Consolidated = 0 } }
  $aliases = @(); $projects = @(); $notes = @()
  if ($cfg -and $cfg.documentsConsolidation) {
    $aliases = @($cfg.documentsConsolidation.aliasesToRoot)
    $projects = @($cfg.documentsConsolidation.projects)
    $notes = @($cfg.documentsConsolidation.notes)
  }
  $done = 0
  # Merge aliases to root
  foreach ($name in $aliases) {
    $src = Join-Path $docs $name
    if (Test-Path $src) {
      Get-ChildItem -LiteralPath $src -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $target = Join-Path $docs $_.Name
        if ($DryRun) { Write-Log -Message "Would move $($_.FullName) -> $target" }
        else { try { Move-Item -LiteralPath $_.FullName -Destination $target -Force; $done++ } catch { Write-Log -Level WARN -Message $_.Exception.Message } }
      }
      if (-not $DryRun) { try { Remove-Item -LiteralPath $src -Recurse -Force } catch {} }
    }
  }
  # Normalize projects into Documents\Projects
  $projTarget = Join-Path $docs 'Projects'
  foreach ($name in $projects) {
    Get-ChildItem -LiteralPath $docs -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $name } | ForEach-Object {
      $src = $_.FullName
      $dest = $projTarget
      if ($DryRun) { Write-Log -Message "Would move $src -> $dest" }
      else { try { New-Item -ItemType Directory -Path $dest -Force | Out-Null; Move-Item -LiteralPath $src -Destination $dest -Force; $done++ } catch { Write-Log -Level WARN -Message $_.Exception.Message } }
    }
  }
  # Normalize notes into Documents\Notes
  $notesTarget = Join-Path $docs 'Notes'
  foreach ($name in $notes) {
    Get-ChildItem -LiteralPath $docs -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $name } | ForEach-Object {
      $src = $_.FullName
      $dest = $notesTarget
      if ($DryRun) { Write-Log -Message "Would move $src -> $dest" }
      else { try { New-Item -ItemType Directory -Path $dest -Force | Out-Null; Move-Item -LiteralPath $src -Destination $dest -Force; $done++ } catch { Write-Log -Level WARN -Message $_.Exception.Message } }
    }
  }
  return [pscustomobject]@{ Consolidated = $done }
}

function Find-CandidateProjectDirs {
  $cfg = Get-UserProfileConfig
  if (-not $cfg -or -not $cfg.projectsMove.enable) { return @() }
  $root = $env:USERPROFILE
  $keep = @($cfg.keepRoot) + @('AppData')
  $preserve = @($cfg.preserveNames)
  $detectFiles = @($cfg.projectsMove.detectFiles)
  $detectDirs = @($cfg.projectsMove.detectDirs)
  $dirs = Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin $keep -and $_.Name -notin $preserve }
  $candidates = @()
  foreach ($d in $dirs) {
    if (Is-ReparsePoint $d) { continue }
    $has = $false
    foreach ($fn in $detectFiles) { if (Test-Path (Join-Path $d.FullName $fn)) { $has = $true; break } }
    if (-not $has) {
      foreach ($dn in $detectDirs) { if (Test-Path (Join-Path $d.FullName $dn)) { $has = $true; break } }
    }
    if ($has) { $candidates += $d }
  }
  return $candidates
}

function Move-ProjectsToDocuments {
  param([switch]$DryRun = $true)
  $cfg = Get-UserProfileConfig
  if (-not $cfg -or -not $cfg.projectsMove.enable) { return [pscustomobject]@{ Moved = 0; Skipped = 0; Count = 0 } }
  $destRel = $cfg.projectsMove.destRel
  $destBase = Join-Path $env:USERPROFILE $destRel
  $cands = Find-CandidateProjectDirs
  $moved = 0; $skipped = 0
  foreach ($d in $cands) {
    $name = $d.Name
    $dest = Join-Path $destBase $name
    $target = $dest
    $i = 1
    while (Test-Path $target) { $target = "$dest ($i)"; $i++ }
    if ($DryRun) { Write-Log -Message "Would move project $($d.FullName) -> $target"; $skipped++ }
    else {
      try { New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null; Move-Item -LiteralPath $d.FullName -Destination $target -Force; $moved++; Write-Log -Message "Moved project $($d.FullName) -> $target" }
      catch { Write-Log -Level WARN -Message "Failed to move $($d.FullName): $($_.Exception.Message)"; $skipped++ }
    }
  }
  return [pscustomobject]@{ Moved = $moved; Skipped = $skipped; Count = ($cands | Measure-Object).Count }
}

function Remove-EmptyProfileDirs {
  param([switch]$DryRun = $true)
  $cfg = Get-UserProfileConfig
  if (-not $cfg -or -not $cfg.removeEmptyDirs) { return [pscustomobject]@{ Removed = 0; Skipped = 0; Planned = 0 } }
  $root = $env:USERPROFILE
  $keep = @($cfg.keepRoot)
  $preserve = @($cfg.preserveNames)
  $delete = @($cfg.deleteNames)
  $ignoreFiles = @($cfg.emptyDirsIgnoreFiles)
  $removed = 0; $skipped = 0; $planned = 0
  $dirs = Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue
  foreach ($d in $dirs) {
    if ($keep -contains $d.Name) { continue }
    if ($preserve -contains $d.Name) { continue }
    if (Is-ReparsePoint $d) { continue }
    # Determine emptiness ignoring common system files
    $children = Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue
    $children = $children | Where-Object { -not ($ignoreFiles -contains $_.Name) }
    if (-not $children -or ($children.Count -eq 0)) {
      $planned++
      if ($DryRun) { Write-Log -Message "Would remove empty directory $($d.FullName)"; $skipped++ }
      else {
        try { Remove-Item -LiteralPath $d.FullName -Recurse -Force; $removed++; Write-Log -Message "Removed empty directory $($d.FullName)" } catch { Write-Log -Level WARN -Message "Failed to remove $($d.FullName): $($_.Exception.Message)"; $skipped++ }
      }
    }
  }
  return [pscustomobject]@{ Removed = $removed; Skipped = $skipped; Planned = $planned }
}

function Restore-MouseWithoutBorders {
  param(
    [switch]$DryRun = $true
  )
  $desktop = Join-Path $env:USERPROFILE 'Desktop'
  $documents = Join-Path $env:USERPROFILE 'Documents'
  $legacy = Join-Path $documents 'Mouse Without Borders\ScreenCaptures'
  $target = Join-Path $desktop 'MouseWithoutBorders\ScreenCaptures'
  if (-not (Test-Path $legacy)) { Write-Log -Message "No legacy ScreenCaptures found at $legacy"; return [pscustomobject]@{ Found = 0; Moved = 0 } }
  if ($DryRun) {
    $total = (Get-ChildItem -LiteralPath $legacy -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Log -Message "Would ensure $target exists and move contents from $legacy (files=$total)"
    return [pscustomobject]@{ Found = $total; Moved = 0 }
  } else {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $moved = 0
    Get-ChildItem -LiteralPath $legacy -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
      $rel = $_.FullName.Substring($legacy.Length).TrimStart('\\','/')
      $dest = Join-Path $target $rel
      $destDir = Split-Path -Parent $dest
      New-Item -ItemType Directory -Path $destDir -Force | Out-Null
      try { Move-Item -LiteralPath $_.FullName -Destination $dest -Force; $moved++; Write-Log -Message "Moved $($_.FullName) -> $dest" }
      catch { Write-Log -Level WARN -Message "Failed to move $($_.FullName): $($_.Exception.Message)" }
    }
    return [pscustomobject]@{ Found = $moved; Moved = $moved }
  }
}

function Remove-ObsoleteDirs {
  param(
    [switch]$DryRun = $true,
    [pscustomobject]$Config
  )
  $docs = Join-Path $env:USERPROFILE 'Documents'
  $cleanupReports = Join-Path $docs 'cleanup_reports'
  $removed = 0; $wouldRemove = 0
  if ($Config.deleteCleanupReports -and (Test-Path $cleanupReports)) {
    if ($DryRun) { Write-Log -Message "Would remove $cleanupReports"; $wouldRemove++ } else { Remove-Item -LiteralPath $cleanupReports -Recurse -Force; $removed++; Write-Log -Message "Removed $cleanupReports" }
  }

  if ($Config.deleteOBSBackups) {
    $candidates = Get-ChildItem -LiteralPath $env:USERPROFILE -Recurse -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'OBS_Backups' }
    foreach ($d in $candidates) {
      if ($DryRun) { Write-Log -Message "Would remove $($d.FullName)"; $wouldRemove++ } else { try { Remove-Item -LiteralPath $d.FullName -Recurse -Force; $removed++; Write-Log -Message "Removed $($d.FullName)" } catch { Write-Log -Level WARN -Message "Failed to remove $($d.FullName): $($_.Exception.Message)" } }
    }
  }
  $summary = [pscustomobject]@{ Removed = $removed; WouldRemove = $wouldRemove }
  Write-Log -Message "Obsolete dirs cleanup complete" -Data ($summary | ConvertTo-Json | ConvertFrom-Json)
  return $summary
}

function Inventory-InstalledApps {
  param(
    [switch]$DryRun = $true
  )
  # Always safe to inventory
  $modulesDir = Split-Path -Parent $PSCommandPath
  $logsDir = Join-Path (Split-Path -Parent $modulesDir) 'logs'
  $appsDir = Join-Path $logsDir 'apps'
  New-Item -ItemType Directory -Path $appsDir -Force | Out-Null

  Write-Log -Message "Capturing installed apps inventory"

  # Registry uninstall entries
  $regPaths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
  )
  $entries = foreach ($rp in $regPaths) {
    if (Test-Path $rp) {
      Get-ChildItem $rp -ErrorAction SilentlyContinue | ForEach-Object {
        try { Get-ItemProperty $_.PSPath | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, PSPath } catch {}
      }
    }
  }
  $entries | Where-Object { $_.DisplayName } | Sort-Object DisplayName | Format-Table -AutoSize | Out-String | Out-File -FilePath (Join-Path $appsDir 'registry_uninstall.txt') -Encoding utf8

  # Appx packages
  try {
    Get-AppxPackage | Select-Object Name, PackageFullName, Version | Sort-Object Name | Format-Table -AutoSize | Out-String | Out-File -FilePath (Join-Path $appsDir 'appx_packages.txt') -Encoding utf8
  } catch {
    Write-Log -Level WARN -Message "Get-AppxPackage unavailable: $($_.Exception.Message)"
  }

  # winget list
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget list | Out-File -FilePath (Join-Path $appsDir 'winget_list.txt') -Encoding utf8
  } else {
    Write-Log -Level INFO -Message 'winget not found; skipping winget list'
  }

  # Program Files snapshot
  $pf = 'C:\\Program Files'; $pf86 = 'C:\\Program Files (x86)'
  foreach ($p in @($pf, $pf86)) {
    if (Test-Path $p) {
      Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue | Select-Object FullName | Out-File -FilePath (Join-Path $appsDir ("program_files_" + ($p -replace ":\\\\","_").Replace('\\\\','_') + '.txt')) -Encoding utf8
    }
  }

  # Start Menu shortcuts snapshot
  $startMenu = 'C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs'
  if (Test-Path $startMenu) {
    Get-ChildItem -LiteralPath $startMenu -Recurse -Filter *.lnk -ErrorAction SilentlyContinue | Select-Object FullName | Out-File -FilePath (Join-Path $appsDir 'start_menu_shortcuts.txt') -Encoding utf8
  }

  Write-Log -Message "Installed apps inventory written" -Data @{ path = $appsDir }
  return [pscustomobject]@{ Path = $appsDir }
}

Export-ModuleMember -Function Flatten-Downloads, Restore-MouseWithoutBorders, Remove-ObsoleteDirs, Inventory-InstalledApps
Export-ModuleMember -Function Audit-UserProfile, Apply-UserProfileMoves, Consolidate-Documents, Move-ProjectsToDocuments, Remove-EmptyProfileDirs
