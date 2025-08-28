param(
  [switch]$PersistEnv
)

Set-StrictMode -Version Latest
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here '../modules/SecureStore.psm1') -Force
Import-Module (Join-Path $here '../modules/Logging.psm1') -Force

Start-Log -Name 'set_github_token' | Out-Null
try {
  $token = Read-Host -AsSecureString -Prompt 'Enter GitHub Personal Access Token (PAT)'
  if (-not $token) { throw 'No token provided.' }
  $path = Save-Secret -Name 'github_token' -Secret $token
  Write-Log -Message "Token stored at $path"

  if ($PersistEnv) {
    $plain = (New-Object System.Net.NetworkCredential('', $token)).Password
    [Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $plain, 'User')
    Write-Log -Message 'Set user environment variable GITHUB_TOKEN'
  } else {
    Write-Log -Message 'Skipped setting user env var GITHUB_TOKEN (use -PersistEnv to set)'
  }
  Add-JournalEntry -Title 'Stored GitHub token' -Lines @('Saved encrypted token to secrets store', $(if($PersistEnv){'Set user env var GITHUB_TOKEN'}else{'Env var not persisted'}))
}
catch {
  Write-Log -Level ERROR -Message $_.Exception.Message
  throw
}
finally {
  Stop-Log
}

