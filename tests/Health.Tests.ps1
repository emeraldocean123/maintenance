Import-Module "$PSScriptRoot/../modules/Logging.psm1" -Force
Import-Module "$PSScriptRoot/../modules/Health.psm1" -Force

Describe 'Health module' {
  It 'Scheduled tasks health returns Supported flag' {
    $res = Check-ScheduledTasksHealth
    $res | Should -Not -BeNullOrEmpty
    $res.PSObject.Properties.Name | Should -Contain 'Supported'
  }

  It 'Launcher health reports PATH and shortcut details' {
    $res = Check-LauncherHealth
    $res | Should -Not -BeNullOrEmpty
    $res.PSObject.Properties.Name | Should -Contain 'BinPath'
    $res.PSObject.Properties.Name | Should -Contain 'OnUserPath'
    $res.PSObject.Properties.Name | Should -Contain 'ShortcutExists'
  }

  It 'Launcher self-test (manual enable)' -Skip:($env:MAINT_ENABLE_SELFTEST -ne '1') {
    $res = Test-LauncherExecution -Args @('-Scope','WindowsProfile','-DryRun:$true')
    $res | Should -Not -BeNullOrEmpty
    $res.PSObject.Properties.Name | Should -Contain 'ExitCode'
  }
}

