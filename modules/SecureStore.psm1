Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSCommandPath) 'Logging.psm1') -Force

$Script:ModuleDir = Split-Path -Parent $PSCommandPath
$Script:RootDir = Split-Path -Parent $Script:ModuleDir
$Script:SecretsDir = Join-Path $Script:RootDir 'secrets'
New-Item -ItemType Directory -Path $Script:SecretsDir -Force | Out-Null

function Save-Secret {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.-]+$')] [string]$Name,
    [Parameter(ParameterSetName='Secure', Mandatory)][securestring]$Secret,
    [Parameter(ParameterSetName='Plain', Mandatory)][string]$SecretText
  )
  if ($PSCmdlet.ParameterSetName -eq 'Plain') {
    $Secret = ConvertTo-SecureString -String $SecretText -AsPlainText -Force
  }
  $enc = ConvertFrom-SecureString -SecureString $Secret
  $path = Join-Path $Script:SecretsDir "$Name.dat"
  $enc | Out-File -FilePath $path -Encoding utf8 -Force
  Write-Log -Message "Saved secret $Name to $path (DPAPI user scope)"
  return $path
}

function Get-SecretValue {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.-]+$')] [string]$Name,
    [switch]$AsSecureString
  )
  $path = Join-Path $Script:SecretsDir "$Name.dat"
  if (-not (Test-Path $path)) { return $null }
  $enc = Get-Content -LiteralPath $path -Raw
  $sec = ConvertTo-SecureString -String $enc
  if ($AsSecureString) { return $sec }
  $plain = (New-Object System.Net.NetworkCredential('', $sec)).Password
  return $plain
}

Export-ModuleMember -Function Save-Secret, Get-SecretValue

