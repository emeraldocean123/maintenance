Import-Module "$PSScriptRoot/../modules/Logging.psm1" -Force
Import-Module "$PSScriptRoot/../modules/WindowsProfile.psm1" -Force

Describe 'User profile audit' {
  It 'Produces entries and does not throw' {
    { $res = Audit-UserProfile -DryRun } | Should -Not -Throw
  }
}

