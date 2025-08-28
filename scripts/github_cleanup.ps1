param(
  [switch]$DryRun = $false,
  [string]$Owner = ''
)

# Requires: GitHub PAT with scopes: repo, workflow
# Uses: $env:GITHUB_TOKEN if set; otherwise prompts.

function Get-GitHubToken {
  if ($env:GITHUB_TOKEN -and $env:GITHUB_TOKEN.Trim().Length -gt 0) { return $env:GITHUB_TOKEN }
  $sec = Read-Host -AsSecureString -Prompt 'Enter GitHub Personal Access Token (scopes: repo, workflow)'
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  return $plain
}

function Invoke-GHApi {
  param(
    [Parameter(Mandatory=$true)][string]$Method,
    [Parameter(Mandatory=$true)][string]$Url,
    [object]$Body = $null,
    [hashtable]$Headers = @{}
  )
  $token = $script:GitHubToken
  $hdrs = @{
    Authorization = "Bearer $token"
    Accept        = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'cleanup-script'
  } + $Headers
  if ($DryRun -and $Method -in @('PUT','PATCH','POST','DELETE')) {
    Write-Host "[DRY-RUN] $Method $Url" -ForegroundColor Yellow
    if ($Body) { Write-Host "[DRY-RUN] Body: $($Body | ConvertTo-Json -Depth 10)" -ForegroundColor Yellow }
    return $null
  }
  if ($Body -ne $null) {
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $hdrs -Body ($Body | ConvertTo-Json -Depth 10) -ContentType 'application/json'
  } else {
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $hdrs
  }
}

function Get-AllPages {
  param([string]$Url)
  $page = 1
  $results = @()
  while ($true) {
    $pagedUrl = if ($Url -match '\?') { "$Url&per_page=100&page=$page" } else { "$Url?per_page=100&page=$page" }
    $chunk = Invoke-GHApi -Method GET -Url $pagedUrl
    if (-not $chunk -or $chunk.Count -eq 0) { break }
    $results += $chunk
    if ($chunk.Count -lt 100) { break }
    $page++
  }
  return $results
}

Write-Host "Preparing to disable Actions, close issues across owned repos..." -ForegroundColor Cyan
$script:GitHubToken = Get-GitHubToken

# Identify user/owner
if (-not $Owner) {
  try {
    $me = Invoke-GHApi -Method GET -Url 'https://api.github.com/user'
    $Owner = $me.login
  } catch {
    throw "Failed to identify user. Ensure the token is valid. $_"
  }
}
Write-Host "Target owner: $Owner" -ForegroundColor Green

# Enumerate repos (owner affiliation)
$repos = Get-AllPages -Url 'https://api.github.com/user/repos?type=owner&sort=full_name'
if (-not $repos) { Write-Host 'No repositories found for owner.'; exit 0 }

$summary = @()
foreach ($r in $repos) {
  $full = $r.full_name
  $archived = [bool]$r.archived
  $private = [bool]$r.private
  Write-Host "\n=== $full (private=$private archived=$archived) ===" -ForegroundColor Cyan

  # 1) Close open issues (skip PRs)
  $closedCount = 0
  try {
    $openIssues = Get-AllPages -Url "https://api.github.com/repos/$full/issues?state=open"
    foreach ($issue in $openIssues) {
      if ($issue.PSObject.Properties.Name -contains 'pull_request') { continue }
      Invoke-GHApi -Method PATCH -Url "https://api.github.com/repos/$full/issues/$($issue.number)" -Body @{ state = 'closed' } | Out-Null
      $closedCount++
    }
    Write-Host "Closed issues: $closedCount" -ForegroundColor Gray
  } catch {
    Write-Warning "Issues close failed for $($full): $_"
  }

  # 2) Disable all workflows in repo
  $disabled = 0
  try {
    $wfs = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full/actions/workflows"
    foreach ($wf in ($wfs.workflows | Where-Object { $_ })) {
      Invoke-GHApi -Method PUT -Url "https://api.github.com/repos/$full/actions/workflows/$($wf.id)/disable" | Out-Null
      $disabled++
    }
    Write-Host "Disabled workflows: $disabled" -ForegroundColor Gray
  } catch {
    Write-Warning "Workflow disable failed for $($full): $_"
  }

  # 3) Attempt to disable Actions at repo level (best-effort; may require specific permissions)
  try {
    Invoke-GHApi -Method PUT -Url "https://api.github.com/repos/$full/actions/permissions" -Body @{ enabled = $false } | Out-Null
    Write-Host "Repo-level Actions: disabled" -ForegroundColor Gray
  } catch {
    Write-Warning "Repo-level Actions disable may not be supported or permitted for $full"
  }

  # 4) Disable security-and-analysis features that trigger Actions (CodeQL, Dependabot updates, secret scanning)
  try {
    $body = @{ security_and_analysis = @{ 
        advanced_security = @{ status = 'disabled' }
        dependabot_security_updates = @{ status = 'disabled' }
        secret_scanning = @{ status = 'disabled' }
        secret_scanning_push_protection = @{ status = 'disabled' }
      } }
    Invoke-GHApi -Method PATCH -Url "https://api.github.com/repos/$full" -Body $body | Out-Null
    # Disable vulnerability alerts (Dependabot alerts)
    Invoke-GHApi -Method DELETE -Url "https://api.github.com/repos/$full/vulnerability-alerts" | Out-Null
    Write-Host "Security & analysis disabled (where supported)" -ForegroundColor Gray
  } catch {
    Write-Warning "Security/analysis disable failed for $($full): $_"
  }

  # 4b) Attempt to disable Code Scanning default setup (if enabled)
  try {
    Invoke-GHApi -Method DELETE -Url "https://api.github.com/repos/$full/code-scanning/default-setup" | Out-Null
    Write-Host "Code scanning default setup: disabled" -ForegroundColor Gray
  } catch {
    Write-Host "Code scanning default setup not active or cannot be disabled" -ForegroundColor DarkGray
  }

  # 5) Permanently remove workflow and related bot/config files on default branch
  try {
    # Identify default branch
    $repoMeta = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full"
    $defaultBranch = $repoMeta.default_branch
    if (-not $defaultBranch) { throw "No default branch found" }

    $deleted = 0
    function Remove-FileIfExists([string]$path) {
      try {
        $meta = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full/contents/$path?ref=$defaultBranch"
        if ($meta) {
          Invoke-GHApi -Method DELETE -Url "https://api.github.com/repos/$full/contents/$path" -Body @{ message = "chore: remove $path (GitHub Actions/bots)"; sha = $meta.sha; committer = @{ name = $env:USERNAME; email = "$($env:USERNAME)@users.noreply.github.com" } } | Out-Null
          $script:deleted++
        }
      } catch { }
    }

    # Remove workflow files in .github/workflows
    try {
      $wfDir = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full/contents/.github/workflows?ref=$defaultBranch"
      foreach ($f in ($wfDir | Where-Object { $_.type -eq 'file' })) { Remove-FileIfExists $f.path }
    } catch { }

    # Remove related config files
    foreach ($p in @(
      '.github/dependabot.yml', '.github/dependabot.yaml',
      '.github/renovate.json', '.github/renovate.json5', 'renovate.json', 'renovate.json5',
      '.mergify.yml', '.mergify.yaml'
    )) { Remove-FileIfExists $p }

    # Remove codeql directory files
    try {
      $cq = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full/contents/.github/codeql?ref=$defaultBranch"
      foreach ($f in ($cq | Where-Object { $_.type -eq 'file' })) { Remove-FileIfExists $f.path }
    } catch { }

    # Scrub Actions badges from README
    $badgesRemoved = 0
    foreach ($rp in @('README.md','Readme.md','readme.md','README','README.rst','README.MD')) {
      try {
        $rm = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full/contents/$rp?ref=$defaultBranch"
        if ($rm) {
          $content = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($rm.content -replace "\n",""))
          $orig = $content
          $content = ($content -split "\r?\n") | Where-Object { $_ -notmatch 'github\.com/.*/workflows/.*/badge\.svg' -and $_ -notmatch 'img\.shields\.io/(github/actions|github/workflow)/' -and $_ -notmatch 'github/actions/workflow/status' } | ForEach-Object { $_ } | Out-String
          if ($content -ne $orig) {
            $newb64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($content))
            Invoke-GHApi -Method PUT -Url "https://api.github.com/repos/$full/contents/$rp" -Body @{ message = "chore: remove GitHub Actions badges"; content = $newb64; sha = $rm.sha; committer = @{ name = $env:USERNAME; email = "$($env:USERNAME)@users.noreply.github.com" } } | Out-Null
            $badgesRemoved++
          }
        }
      } catch { }
    }

    if ($deleted -gt 0 -or $badgesRemoved -gt 0) {
      Write-Host "Removed files: $deleted; Badges updated: $badgesRemoved" -ForegroundColor Gray
    } else {
      Write-Host "No workflow/bot files detected" -ForegroundColor Gray
    }
  } catch {
    Write-Warning "Direct file removal skipped for $($full): $_"
  }

  # 6) Create Repository Ruleset to block pushes adding/modifying workflows/bot configs
  try {
    $ruleset = @{ 
      name = 'Block workflows and bots';
      target = 'push';
      enforcement = 'active';
      bypass_actors = @();
      conditions = @{ ref_name = @{ include = @('~DEFAULT_BRANCH'); exclude = @() };
                      file_path = @{ include = @('.github/workflows/**', '.github/actions/**', '.github/dependabot.yml', '.github/dependabot.yaml', '.mergify.yml', '.mergify.yaml', '.github/codeql/**', 'renovate.json', 'renovate.json5', '.github/renovate.json', '.github/renovate.json5'); exclude = @() } };
      rules = @(
        @{ type = 'update'; parameters = @{ required_status_checks = @() } }
      )
    }
    Invoke-GHApi -Method POST -Url "https://api.github.com/repos/$full/rulesets" -Body $ruleset | Out-Null
    Write-Host "Ruleset created to block workflow/bot changes" -ForegroundColor Gray
  } catch {
    Write-Host "Ruleset creation not supported or insufficient permissions" -ForegroundColor DarkGray
  }

  # 7) Ensure CODEOWNERS exists to protect .github/** via code owner review
  try {
    $repoMeta = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full"
    $defaultBranch = $repoMeta.default_branch
    $codeOwnersPath = '.github/CODEOWNERS'
    $exists = $false
    try {
      $co = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full/contents/$codeOwnersPath?ref=$defaultBranch"
      if ($co) { $exists = $true }
    } catch { $exists = $false }
    if (-not $exists) {
      $ownerLogin = $repoMeta.owner.login
      $content = ".github/** @$ownerLogin"
      $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($content))
      Invoke-GHApi -Method PUT -Url "https://api.github.com/repos/$full/contents/$codeOwnersPath" -Body @{ message = 'chore: add CODEOWNERS for .github/**'; content = $b64; branch = $defaultBranch; committer = @{ name = $env:USERNAME; email = "$($env:USERNAME)@users.noreply.github.com" } } | Out-Null
      Write-Host "Added CODEOWNERS for .github/**" -ForegroundColor Gray
    } else {
      Write-Host "CODEOWNERS already present" -ForegroundColor DarkGray
    }
  } catch {
    Write-Host "CODEOWNERS step skipped" -ForegroundColor DarkGray
  }

  # 8) Apply branch protection requiring code owner review (guards .github/** if CODEOWNERS exists)
  try {
    $repoMeta = Invoke-GHApi -Method GET -Url "https://api.github.com/repos/$full"
    $defaultBranch = $repoMeta.default_branch
    $bpBody = @{ 
      required_status_checks = $null; 
      enforce_admins = $false; 
      required_pull_request_reviews = @{ 
        dismissal_restrictions = $null; 
        dismiss_stale_reviews = $true; 
        require_code_owner_reviews = $true; 
        required_approving_review_count = 1 
      }; 
      restrictions = $null; 
      required_linear_history = $false; 
      allow_force_pushes = $false; 
      allow_deletions = $false; 
      block_creations = $false; 
      required_conversation_resolution = $true 
    }
    Invoke-GHApi -Method PUT -Url "https://api.github.com/repos/$full/branches/$defaultBranch/protection" -Body $bpBody | Out-Null
    Write-Host "Branch protection applied (requires CODEOWNERS review)" -ForegroundColor Gray
  } catch {
    Write-Host "Branch protection not supported or insufficient permissions" -ForegroundColor DarkGray
  }

  $summary += [pscustomobject]@{
    Repository = $full
    ClosedIssues = $closedCount
    DisabledWorkflows = $disabled
  }
}

Write-Host "\nDone. Summary:" -ForegroundColor Green
$summary | Format-Table -AutoSize
