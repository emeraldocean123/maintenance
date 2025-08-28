Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$devRoot = Split-Path -Parent $root
$outDir = Join-Path $root 'logs'
$out = Join-Path $outDir 'dev_scripts_index.md'

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$ignoreDirs = @('.git','node_modules','.venv','venv','dist','build','out','.direnv','target','bin')
$scriptExt = @('*.ps1','*.psm1','*.psd1','*.sh','*.bash','*.cmd','*.bat','*.py','*.js','*.ts')

"# Dev Scripts Index`n`nRoot: $devRoot`nGenerated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss K")`n" | Out-File -FilePath $out -Encoding utf8

function Should-SkipPath($p) {
  foreach ($i in $ignoreDirs) { if ($p -like "*\$i\*") { return $true } }
  return $false
}

$files = @()
foreach ($ext in $scriptExt) {
  $files += Get-ChildItem -LiteralPath $devRoot -Recurse -File -Filter $ext -ErrorAction SilentlyContinue
}

$files = $files | Where-Object { $_.FullName -notlike "*$($root)\*" -and -not (Should-SkipPath $_.FullName) } | Sort-Object FullName -Unique

foreach ($f in $files) {
  $rel = $f.FullName.Replace($devRoot, '').TrimStart('\\','/')
  "- `$rel` (size: $([Math]::Round($f.Length/1KB,1)) KB, modified: $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')) )" | Out-File -FilePath $out -Append -Encoding utf8
}

Write-Host "Index written to $out"

