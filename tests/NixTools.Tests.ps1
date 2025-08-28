Import-Module "$PSScriptRoot/../modules/Logging.psm1" -Force
Import-Module "$PSScriptRoot/../modules/NixTools.psm1" -Force

Describe 'NixTools module' {
  It 'Run-NixMaintenance does not throw' {
    { Run-NixMaintenance } | Should -Not -Throw
  }
}

