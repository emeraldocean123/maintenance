Import-Module "$PSScriptRoot/../modules/Logging.psm1" -Force
Import-Module "$PSScriptRoot/../modules/Reports.psm1" -Force

Describe 'Reports module' {
  It 'Creates disk usage snapshot and returns paths' {
    $res = New-DiskUsageSnapshot -Paths @($env:TEMP) -TopFiles 1
    $res | Should -Not -BeNullOrEmpty
    $res.PSObject.Properties.Name | Should -Contain 'SummaryCsv'
  }
}

