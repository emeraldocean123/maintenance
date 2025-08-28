param(
  [Parameter(ValueFromRemainingArguments=$true)] [string[]]$Args
)

Set-StrictMode -Version Latest
$bin = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $bin
$script = Join-Path $root 'maintain.ps1'

# Prefer pwsh, fallback to Windows PowerShell
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) {
  & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $script @Args
} else {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $script @Args
}

