Import-Module "$PSScriptRoot/../modules/Logging.psm1" -Force
Import-Module "$PSScriptRoot/../modules/GitHubCleanup.psm1" -Force

Describe 'GitHubCleanup module (no network)' {
  It 'Exports expected functions' {
    (Get-Command Close-AllIssues -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    (Get-Command Disable-Workflows -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    (Get-Command Get-GitHubRepos -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
  }
}

