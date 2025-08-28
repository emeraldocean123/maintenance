Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSCommandPath) 'Logging.psm1') -Force

function Run-NixMaintenance {
  param(
    [string]$RepoRoot = (Resolve-Path '.').Path
  )
  $moduleDir = Split-Path -Parent $PSCommandPath
  $rootDir = Split-Path -Parent $moduleDir
  $nixScript = Join-Path $rootDir 'scripts/nix/run_all.sh'
  if (-not (Test-Path $nixScript)) { Write-Log -Level WARN -Message "Nix script not found: $nixScript"; return }
  if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    Write-Log -Message "Invoking Nix maintenance via WSL"
    & wsl.exe bash -lc "cd `"$RepoRoot`" && bash `"$nixScript`"" | Out-Null
  } else {
    Write-Log -Level INFO -Message "WSL not found. You can run: bash $nixScript"
  }
}

Export-ModuleMember -Function Run-NixMaintenance

