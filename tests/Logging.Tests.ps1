Import-Module "$PSScriptRoot/../modules/Logging.psm1" -Force

Describe 'Logging module' {
  It 'Start-Log returns files and write/stop works' {
    $info = Start-Log -Name 'pester_logging'
    $info | Should -Not -BeNullOrEmpty
    $info.LogFile | Should -Not -BeNullOrEmpty
    $info.JsonLogFile | Should -Not -BeNullOrEmpty
    { Write-Log -Message 'hello from pester' } | Should -Not -Throw
    { Stop-Log } | Should -Not -Throw
    Test-Path $info.LogFile | Should -BeTrue
    Test-Path $info.JsonLogFile | Should -BeTrue
  }
}

