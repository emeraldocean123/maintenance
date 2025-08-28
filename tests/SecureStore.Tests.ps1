Import-Module "$PSScriptRoot/../modules/Logging.psm1" -Force
Import-Module "$PSScriptRoot/../modules/SecureStore.psm1" -Force

Describe 'SecureStore module' {
  It 'Saves and retrieves a secret (DPAPI user scope)' {
    $name = 'test_secret_' + [Guid]::NewGuid().ToString('N')
    $plain = 'hello-pester'
    { Save-Secret -Name $name -SecretText $plain } | Should -Not -Throw
    $out = Get-SecretValue -Name $name
    $out | Should -Be $plain
    # cleanup
    $root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $path = Join-Path (Join-Path $root 'secrets') ("{0}.dat" -f $name)
    if (Test-Path $path) { Remove-Item -LiteralPath $path -Force }
  }
}

