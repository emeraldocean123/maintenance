param(
  [ValidateSet('All','WindowsProfile','GitHub','Nix')] [string]$Scope = 'All',
  [switch]$DryRun = $true,
  [switch]$Init
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here 'modules/Logging.psm1') -Force
Import-Module (Join-Path $here 'modules/WindowsProfile.psm1') -Force
Import-Module (Join-Path $here 'modules/GitHubCleanup.psm1') -Force
Import-Module (Join-Path $here 'modules/NixTools.psm1') -Force
Import-Module (Join-Path $here 'modules/SecureStore.psm1') -Force
Import-Module (Join-Path $here 'modules/Health.psm1') -Force

Start-Log -Name 'maintenance' | Out-Null

try {
  $configPath = Join-Path $here 'config.json'
  if (-not (Test-Path $configPath)) { throw "Config file not found: $configPath" }
  $config = Get-Content $configPath -Raw | ConvertFrom-Json
  Write-Log -Message "Loaded config from $configPath"

  if ($Init) {
    Add-JournalEntry -Title 'Initialized Maintenance Toolkit' -Lines @(
      'Added toolkit structure and logging',
      'Seeded config.json with safe defaults',
      'Use -DryRun to preview, then apply without dry-run'
    )
  }

  $summary = @{ }
  if ($Scope -in @('All','WindowsProfile')) {
    Write-Log -Message "WindowsProfile: starting (DryRun=$($DryRun.IsPresent))"
    $win = @{}
    if ($config.windows.flattenDownloads) {
      if ($DryRun) { $win.FlattenDownloads = (Flatten-Downloads -DryRun -Config $config.windows) }
      else { $win.FlattenDownloads = (Flatten-Downloads -Config $config.windows) }
    }
    if ($DryRun) { $win.Obsolete = (Remove-ObsoleteDirs -DryRun -Config $config.windows) } else { $win.Obsolete = (Remove-ObsoleteDirs -Config $config.windows) }
    if ($config.windows.restoreMouseWithoutBorders) { if ($DryRun) { $win.MouseWithoutBorders = (Restore-MouseWithoutBorders -DryRun) } else { $win.MouseWithoutBorders = (Restore-MouseWithoutBorders) } }
    $win.InstalledApps = (Inventory-InstalledApps -DryRun)
    # Audit and consolidation
    $audit = Audit-UserProfile -DryRun
    $win.ProfileAudit = @{ Entries = ($audit | Measure-Object).Count }
    if (-not $DryRun) {
      $win.ProfileMoves = (Apply-UserProfileMoves -AuditEntries $audit)
      $win.DocumentsConsolidation = (Consolidate-Documents)
      $win.ProjectMoves = (Move-ProjectsToDocuments)
      $win.EmptyDirs = (Remove-EmptyProfileDirs)
    } else {
      $win.ProfileMoves = (Apply-UserProfileMoves -AuditEntries $audit -DryRun)
      $win.DocumentsConsolidation = (Consolidate-Documents -DryRun)
      $win.ProjectMoves = (Move-ProjectsToDocuments -DryRun)
      $win.EmptyDirs = (Remove-EmptyProfileDirs -DryRun)
    }
    $summary.Windows = $win
  }

  if ($Scope -in @('All','GitHub')) {
    if ($DryRun) {
      Write-Log -Message 'GitHub: skipped due to DryRun'
      $summary.GitHub = @{ Skipped = $true }
    } else {
      $owner = $config.github.owner
      $tokenEnv = $config.github.tokenEnvVar
      $token = [Environment]::GetEnvironmentVariable($tokenEnv, 'User')
      if (-not $token) { $token = [Environment]::GetEnvironmentVariable($tokenEnv, 'Process') }
      if (-not $token) {
        $token = Get-SecretValue -Name 'github_token'
        if ($token) { Write-Log -Message 'Loaded GitHub token from secrets store' }
      }
      if (-not $token) {
        Write-Log -Level WARN -Message "GitHub token not found (env var or secrets); skipping GitHub tasks"
      } else {
        Write-Log -Message "GitHub: starting for owner=$owner"
        $gh = @{}
        if ($config.github.closeIssues) { $gh.ClosedIssues = (Close-AllIssues -Owner $owner -Token $token) }
        if ($config.github.disableActions) { $gh.Workflows = (Disable-Workflows -Owner $owner -Token $token) }
        $summary.GitHub = $gh
      }
    }
  }

  if ($Scope -in @('All','Nix')) {
    if ($config.nix.enable) { Run-NixMaintenance; $summary.Nix = @{ Invoked = $true } } else { Write-Log -Message 'Nix: disabled in config'; $summary.Nix = @{ Invoked = $false } }
  }

  # Health checks (non-destructive)
  try {
    $summary.Health = @{ }
    $summary.Health.Tasks = Check-ScheduledTasksHealth
    $summary.Health.Launcher = Check-LauncherHealth
  } catch {
    Write-Log -Level WARN -Message "Health check failed: $($_.Exception.Message)"
  }

  Write-Log -Message "Maintenance completed for scope=$Scope" -Data $summary
  # Journal summary lines
  $lines = @()
  if ($summary.Windows) {
    if ($summary.Windows.FlattenDownloads) { $fd = $summary.Windows.FlattenDownloads; $lines += "Downloads: moved $($fd.MovedFiles), empties $($fd.EmptyDirs)" }
    if ($summary.Windows.Obsolete) { $ob = $summary.Windows.Obsolete; $lines += "Obsolete: removed $($ob.Removed) (would remove $($ob.WouldRemove) in dry-run)" }
    if ($summary.Windows.MouseWithoutBorders) { $mw = $summary.Windows.MouseWithoutBorders; $lines += "MouseWithoutBorders: moved $($mw.Moved) of $($mw.Found)" }
    if ($summary.Windows.ProfileAudit) { $lines += "Profile audit entries: $($summary.Windows.ProfileAudit.Entries)" }
    if ($summary.Windows.ProfileMoves) { $pm = $summary.Windows.ProfileMoves; $lines += "Profile moves: moved=$($pm.Moved), deleted=$($pm.Deleted), skipped=$($pm.Skipped)" }
    if ($summary.Windows.DocumentsConsolidation) { $dc = $summary.Windows.DocumentsConsolidation; $lines += "Documents consolidated: $($dc.Consolidated)" }
    if ($summary.Windows.ProjectMoves) { $pj = $summary.Windows.ProjectMoves; $lines += "Projects moved: $($pj.Moved) of $($pj.Count) (dry-run skips count in DryRun)" }
    if ($summary.Windows.EmptyDirs) { $ed = $summary.Windows.EmptyDirs; $lines += "Empty dirs: planned=$($ed.Planned), removed=$($ed.Removed)" }
  }
  if ($summary.GitHub) {
    if ($summary.GitHub.ClosedIssues) { $ci = $summary.GitHub.ClosedIssues; $lines += "GitHub: closed $($ci.IssuesClosed) issues across $($ci.Repos) repos" }
    if ($summary.GitHub.Workflows) { $wf = $summary.GitHub.Workflows; $lines += "GitHub: attempted $($wf.WorkflowsAttempted), disabled $($wf.WorkflowsDisabled) workflows across $($wf.Repos) repos" }
    if ($summary.GitHub.Skipped) { $lines += 'GitHub: skipped (DryRun)'}
  }
  if ($summary.Nix) {
    $lines += "Nix: invoked=$($summary.Nix.Invoked)"
  }
  if ($summary.Health -and $summary.Health.Tasks -and $summary.Health.Tasks.Supported) {
    foreach ($k in $summary.Health.Tasks.Tasks.Keys) {
      $t = $summary.Health.Tasks.Tasks[$k]
      $nr = if ($t.NextRunTime) { (Get-Date $t.NextRunTime).ToString('yyyy-MM-dd HH:mm') } else { 'n/a' }
      $lines += "Task '$k': present=$($t.Present), state=$($t.State), next=$nr"
    }
  }
  if ($summary.Health -and $summary.Health.Launcher) {
    $lh = $summary.Health.Launcher
    $lines += "Launcher PATH: user=$($lh.OnUserPath), process=$($lh.OnProcessPath)"
    $lines += "Launcher resolved: $($lh.CommandResolved)"
    $lines += "Shortcut exists: $($lh.ShortcutExists)"
  }
  Add-JournalEntry -Title "Maintenance run (Scope=$Scope, DryRun=$($DryRun.IsPresent))" -Lines $lines
}
catch {
  Write-Log -Level ERROR -Message $_.Exception.Message
  throw
}
finally {
  Stop-Log
}
