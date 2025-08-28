Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSCommandPath) 'Logging.psm1') -Force

function Invoke-GitHubApi {
  param(
    [Parameter(Mandatory)] [string]$Method,
    [Parameter(Mandatory)] [string]$Uri,
    [Parameter()] $Body,
    [Parameter(Mandatory)] [string]$Token
  )
  $headers = @{ Authorization = "token $Token"; 'User-Agent' = 'maintenance-toolkit' }
  $params = @{ Method = $Method; Uri = $Uri; Headers = $headers; ErrorAction = 'Stop' }
  if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 5) ; $params.ContentType = 'application/json' }
  try { return Invoke-RestMethod @params } catch { Write-Log -Level WARN -Message "GitHub API $Method $Uri failed: $($_.Exception.Message)" }
}

function Get-GitHubRepos {
  param(
    [Parameter(Mandatory)] [string]$Owner,
    [Parameter(Mandatory)] [string]$Token
  )
  $repos = @()
  $page = 1
  while ($true) {
    $uri = "https://api.github.com/users/$Owner/repos?per_page=100&page=$page&type=owner"
    $batch = Invoke-GitHubApi -Method GET -Uri $uri -Token $Token
    if (-not $batch -or $batch.Count -eq 0) { break }
    $repos += $batch
    $page++
    if ($page -gt 10) { break } # safety
  }
  return $repos
}

function Close-AllIssues {
  param(
    [Parameter(Mandatory)] [string]$Owner,
    [Parameter(Mandatory)] [string]$Token
  )
  $repos = Get-GitHubRepos -Owner $Owner -Token $Token
  $closed = 0; $reposCount = 0
  foreach ($r in $repos) {
    $reposCount++
    $issuesUri = "https://api.github.com/repos/$Owner/$($r.name)/issues?state=open&per_page=100"
    $issues = Invoke-GitHubApi -Method GET -Uri $issuesUri -Token $Token
    foreach ($i in ($issues | Where-Object { -not $_.pull_request })) {
      $patchUri = "https://api.github.com/repos/$Owner/$($r.name)/issues/$($i.number)"
      Invoke-GitHubApi -Method PATCH -Uri $patchUri -Token $Token -Body @{ state = 'closed' } | Out-Null
      $closed++
      Write-Log -Message "Closed issue #$($i.number) in $($r.name): $($i.title)"
    }
  }
  $summary = [pscustomobject]@{ Repos = $reposCount; IssuesClosed = $closed }
  Write-Log -Message "Closed issues summary" -Data ($summary | ConvertTo-Json | ConvertFrom-Json)
  return $summary
}

function Disable-Workflows {
  param(
    [Parameter(Mandatory)] [string]$Owner,
    [Parameter(Mandatory)] [string]$Token
  )
  $repos = Get-GitHubRepos -Owner $Owner -Token $Token
  $attempted = 0; $disabled = 0; $reposCount = 0
  foreach ($r in $repos) {
    $reposCount++
    $wfUri = "https://api.github.com/repos/$Owner/$($r.name)/actions/workflows"
    $wfs = Invoke-GitHubApi -Method GET -Uri $wfUri -Token $Token
    if ($wfs -and $wfs.workflows) {
      foreach ($wf in $wfs.workflows) {
        $disableUri = "https://api.github.com/repos/$Owner/$($r.name)/actions/workflows/$($wf.id)/disable"
        $res = Invoke-GitHubApi -Method PUT -Uri $disableUri -Token $Token
        if ($res) { $disabled++ }
        $attempted++
        Write-Log -Message "Attempted to disable workflow $($wf.name) in $($r.name)"
      }
    }
  }
  $summary = [pscustomobject]@{ Repos = $reposCount; WorkflowsAttempted = $attempted; WorkflowsDisabled = $disabled }
  Write-Log -Message "Workflow disable summary" -Data ($summary | ConvertTo-Json | ConvertFrom-Json)
  return $summary
}

Export-ModuleMember -Function Invoke-GitHubApi, Get-GitHubRepos, Close-AllIssues, Disable-Workflows

