Import-Module "$PSScriptRoot/../modules/Logging.psm1" -Force
Import-Module "$PSScriptRoot/../modules/WindowsProfile.psm1" -Force

Describe 'WindowsProfile module (non-destructive)' {
  It 'Flatten-Downloads dry-run does not throw' {
    { Flatten-Downloads -DryRun -Config ([pscustomobject]@{}) } | Should -Not -Throw
  }

  It 'Remove-ObsoleteDirs dry-run returns summary object' {
    $res = Remove-ObsoleteDirs -DryRun -Config ([pscustomobject]@{ deleteCleanupReports=$true; deleteOBSBackups=$true })
    $res | Should -Not -BeNullOrEmpty
    $res.PSObject.Properties.Name | Should -Contain 'Removed'
  }

  It 'Inventory-InstalledApps returns path' {
    $res = Inventory-InstalledApps -DryRun
    $res | Should -Not -BeNullOrEmpty
    $res.PSObject.Properties.Name | Should -Contain 'Path'
  }
}

