Param(
  [string]$DriveLetter,
  [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-UsbVolumesByDiskName {
  param([string[]]$NamePatterns)
  $result = @()
  try {
    $disks = Get-Disk | Where-Object { $_.BusType -eq 'USB' -or $_.BusType -eq 7 }
    foreach($d in $disks){
      $name = $d.FriendlyName
      if(-not $name){ $name = $d.Model }
      $match = $false
      foreach($p in $NamePatterns){ if($name -match $p){ $match = $true; break } }
      if($match){
        $parts = Get-Partition -DiskNumber $d.Number | Where-Object DriveLetter
        foreach($p in $parts){
          $vol = Get-Volume -Partition $p
          if($vol.DriveLetter){ $result += $vol }
        }
      }
    }
  } catch {}
  return $result
}

function Get-AllUsbVolumes {
  $result = @()
  try {
    $disks = Get-Disk | Where-Object { $_.BusType -eq 'USB' -or $_.BusType -eq 7 }
    foreach($d in $disks){
      $parts = Get-Partition -DiskNumber $d.Number | Where-Object DriveLetter
      foreach($p in $parts){
        $vol = Get-Volume -Partition $p
        if($vol.DriveLetter){ $result += $vol }
      }
    }
  } catch {}
  return $result
}

function Invoke-WakeVolume {
  param([char]$Letter)
  $root = "$Letter:\\"
  try {
    # Directory enumeration usually wakes USB/UASP devices
    Get-ChildItem -Path $root -Force -ErrorAction Stop | Out-Null
    return $true
  } catch {
    # Try a harmless temp file create/delete (may fail due to permissions)
    try {
      $tmp = Join-Path $root (".wake-{0}.tmp" -f [System.Guid]::NewGuid().ToString('N'))
      New-Item -Path $tmp -ItemType File -Force -ErrorAction Stop | Out-Null
      Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
      return $true
    } catch {
      return $false
    }
  }
}

function Wait-ForWake {
  param([char]$Letter, [int]$TimeoutSeconds)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds){
    if(Invoke-WakeVolume -Letter $Letter){ return $true }
    Start-Sleep -Milliseconds 500
  }
  return $false
}

$targets = @()
if($DriveLetter){
  $targets = @([char]$DriveLetter.TrimEnd(':'))
} else {
  # Prefer Samsung T9 if present, else all USB volumes
  $t9 = Get-UsbVolumesByDiskName -NamePatterns @('Samsung.*PSSD.*T9','T9','Samsung.*T9')
  if(-not $t9 -or -not $t9.Count){ $t9 = Get-AllUsbVolumes }
  $targets = $t9 | Where-Object DriveLetter | Select-Object -ExpandProperty DriveLetter -Unique
}

if(-not $targets -or $targets.Count -eq 0){
  Write-Output 'No USB volumes found to wake.'
  exit 0
}

foreach($t in $targets){
  $ok = Wait-ForWake -Letter $t -TimeoutSeconds $TimeoutSeconds
  if($ok){ Write-Output ("Woke USB volume {0}:\\" -f $t) } else { Write-Warning ("Failed to wake USB volume {0}:\\ within {1}s" -f $t, $TimeoutSeconds) }
}

