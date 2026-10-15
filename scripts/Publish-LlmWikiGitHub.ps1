<#
.SYNOPSIS
  gh CLI로 볼트를 비공개 GitHub 저장소에 올리고, 승인 관문 규칙을 겁니다.

.DESCRIPTION
  1. gh 로그인 상태를 확인합니다. 로그인이 안 되어 있으면 사람이 브라우저에서 로그인합니다.
  2. 볼트 폴더를 git 저장소로 만들고 첫 커밋을 합니다.
  3. 비공개 저장소를 만들고 올립니다.
  4. 기본 브랜치 규칙: PR 필수, 승인 1명, 코드 오너 리뷰 필수, 필수 검사 'check'(vault-check 워크플로).
  5. 푸시 규칙: Sources/raw/ 의 원문 변경을 거부합니다. 관리자만 우회해 새 원문을 올립니다.

  비공개 저장소에 규칙을 걸려면 요금제가 필요합니다. 개인 계정은 GitHub Pro, 조직은 Team 이상입니다.
  푸시 규칙은 조직 계정에서만 쓸 수 있습니다. 쓸 수 없으면 경고만 하고 넘어가며, 원문 보호는 CODEOWNERS 리뷰가 대신합니다.

  -WhatIf 를 붙이면 아무것도 바꾸지 않고 할 일만 보여 줍니다. 에이전트에게 맡길 때는 먼저 -WhatIf로 실행하게 하세요.

.PARAMETER Path
  볼트 폴더 (New-LlmWiki.ps1로 만든 폴더).

.PARAMETER Repo
  저장소 이름. "이름" 또는 "조직/이름". 기본값은 폴더 이름입니다.

.PARAMETER Approver
  승인자의 GitHub 아이디(@ 없이). CODEOWNERS에 들어갑니다. 기본값은 로그인한 계정입니다.

.PARAMETER AllowAdminBypass
  혼자 연습할 때 씁니다. 관리자가 PR 승인 없이 병합할 수 있게 합니다. 팀에서는 쓰지 마세요.

.EXAMPLE
  .\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo our-llm-wiki -WhatIf

.EXAMPLE
  .\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Repo my-org/our-llm-wiki -Approver hong-gildong
.NOTES
  GM-Social 라이선스 v2.0 · Copyright (c) 2026 이인희 (LEE Inhee), 파란두루미 (Parandurume Inc.)
  출처: https://github.com/parandurume-labs/llm-wiki-template
  복사하거나 고쳐 쓸 때는 이 표시와 라이선스 파일을 남겨 주세요.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Repo,
    [string]$Approver,
    [switch]$AllowAdminBypass
)

# gh와 git은 정상 진행 메시지도 stderr로 씁니다. Windows PowerShell 5.1에서 'Stop'이면 그 메시지가 오류로 바뀌므로,
# 'Continue'로 두고 종료 코드($LASTEXITCODE)를 직접 확인합니다.
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Step([string]$msg) { Write-Output ''; Write-Output "== $msg" }
function Show([string]$cmd) { Write-Output "   > $cmd" }
function Invoke-Native([string]$exe, [string[]]$argList) {
    Show ("$exe " + ($argList -join ' '))
    & $exe @argList
    if ($LASTEXITCODE -ne 0) { throw "$exe 명령이 실패했습니다 (종료 코드 $LASTEXITCODE)." }
}
function Invoke-GhApiJson([string]$endpoint, [hashtable]$body) {
    $tmp = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($tmp, ($body | ConvertTo-Json -Depth 10), $utf8)
        Show "gh api --method POST $endpoint --input <규칙 JSON>"
        $out = & gh api --method POST $endpoint --input $tmp 2>&1
        return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Output = ($out -join "`n") }
    }
    finally { Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue }
}

$Path = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath (Join-Path $Path 'ontology.md'))) { throw "볼트 폴더가 아닙니다(ontology.md 없음): $Path" }
if (-not $Repo) { $Repo = Split-Path -Leaf $Path }

# ---------- 1. 도구와 로그인 ----------
Step '1. gh와 git 확인'
foreach ($tool in 'gh', 'git') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        $hint = if ($tool -eq 'gh') { 'winget install --id GitHub.cli' } else { 'winget install --id Git.Git' }
        throw "$tool 이 없습니다. 설치: $hint"
    }
}
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output '   gh에 로그인되어 있지 않습니다. 브라우저 로그인을 시작합니다. 사람이 직접 로그인하세요.'
    if ($PSCmdlet.ShouldProcess('GitHub', 'gh auth login --web')) { Invoke-Native gh @('auth', 'login', '--web', '--git-protocol', 'https') }
}
$me = if ($WhatIfPreference) { (& gh api user --jq .login 2>$null) } else { (& gh api user --jq .login) }
if (-not $me) { $me = '<로그인한 계정>' }
if (-not $Approver) { $Approver = $me }
Write-Output "   로그인 계정: $me · 승인자: @$Approver"

# ---------- 2. CODEOWNERS와 첫 커밋 ----------
Step '2. CODEOWNERS 채우고 첫 커밋'
$co = Join-Path $Path '.github\CODEOWNERS'
if (Test-Path -LiteralPath $co) {
    $txt = [IO.File]::ReadAllText($co, $utf8)
    $new = $txt -replace '@your-github-id', "@$Approver"
    if ($new -ne $txt -and $PSCmdlet.ShouldProcess($co, "승인자 @$Approver 넣기")) { [IO.File]::WriteAllText($co, $new, $utf8) }
}
Push-Location -LiteralPath $Path
try {
    if (-not (Test-Path -LiteralPath (Join-Path $Path '.git'))) {
        if ($PSCmdlet.ShouldProcess($Path, 'git init -b main')) { Invoke-Native git @('init', '-b', 'main') }
    }
    if ($PSCmdlet.ShouldProcess($Path, 'git add, git commit')) {
        Invoke-Native git @('add', '-A')
        & git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) { Invoke-Native git @('commit', '-m', 'LLM Wiki 뼈대: 설계서, 템플릿, 규칙, 검사 스크립트') }
        else { Write-Output '   새로 커밋할 변경이 없습니다.' }
    }

    # ---------- 3. 저장소 만들기 ----------
    Step "3. 비공개 저장소 만들고 올리기: $Repo"
    & git remote get-url origin *> $null
    if ($LASTEXITCODE -eq 0) { Write-Output '   origin이 이미 있습니다. 저장소 만들기는 건너뛰고 올리기만 합니다.'; if ($PSCmdlet.ShouldProcess('origin', 'git push')) { Invoke-Native git @('push', '-u', 'origin', 'main') } }
    elseif ($PSCmdlet.ShouldProcess($Repo, 'gh repo create --private --source . --push')) {
        Invoke-Native gh @('repo', 'create', $Repo, '--private', '--source', '.', '--remote', 'origin', '--push')
    }
    $full = if ($WhatIfPreference) { if ($Repo -match '/') { $Repo } else { "$me/$Repo" } } else { (& gh repo view --json nameWithOwner --jq .nameWithOwner) }
    Write-Output "   저장소: https://github.com/$full"

    # ---------- 4. 브랜치 규칙 ----------
    Step '4. 기본 브랜치 규칙: PR 필수 · 승인 1명 · 코드 오너 리뷰 · 필수 검사'
    $bypass = @()
    if ($AllowAdminBypass) { $bypass = @(@{ actor_id = 5; actor_type = 'RepositoryRole'; bypass_mode = 'pull_request' }) }
    $branchRule = @{
        name          = 'main 보호: PR과 승인'
        target        = 'branch'
        enforcement   = 'active'
        bypass_actors = $bypass
        conditions    = @{ ref_name = @{ include = @('~DEFAULT_BRANCH'); exclude = @() } }
        rules         = @(
            @{ type = 'deletion' },
            @{ type = 'non_fast_forward' },
            @{ type = 'pull_request'; parameters = @{ required_approving_review_count = 1; dismiss_stale_reviews_on_push = $true; require_code_owner_review = $true; require_last_push_approval = $false; required_review_thread_resolution = $false } },
            @{ type = 'required_status_checks'; parameters = @{ strict_required_status_checks_policy = $false; required_status_checks = @(@{ context = 'check' }) } }
        )
    }
    if ($PSCmdlet.ShouldProcess($full, '브랜치 규칙 만들기')) {
        $r = Invoke-GhApiJson "repos/$full/rulesets" $branchRule
        if ($r.Ok) { Write-Output '   브랜치 규칙을 걸었습니다.' }
        else {
            Write-Warning "브랜치 규칙을 걸지 못했습니다. 비공개 저장소는 개인 계정이면 GitHub Pro, 조직이면 Team 이상이 필요합니다.`n$($r.Output)"
        }
    }

    # ---------- 5. 푸시 규칙 ----------
    Step '5. 푸시 규칙: Sources/raw/ 원문 변경 거부 (관리자만 우회)'
    $pushRule = @{
        name          = '원문 보호: Sources/raw/ 변경 금지'
        target        = 'push'
        enforcement   = 'active'
        bypass_actors = @(@{ actor_id = 5; actor_type = 'RepositoryRole'; bypass_mode = 'always' })
        rules         = @(@{ type = 'file_path_restriction'; parameters = @{ restricted_file_paths = @('Sources/raw/**') } })
    }
    if ($PSCmdlet.ShouldProcess($full, '푸시 규칙 만들기')) {
        $r = Invoke-GhApiJson "repos/$full/rulesets" $pushRule
        if ($r.Ok) { Write-Output '   푸시 규칙을 걸었습니다. 새 원문은 관리자가 올립니다.' }
        else {
            Write-Warning "푸시 규칙을 걸지 못했습니다. 조직 계정의 Team 이상 요금제에서 쓸 수 있습니다. 대신 CODEOWNERS의 /Sources/raw/ 줄이 원문 변경에 승인자 리뷰를 요구합니다.`n$($r.Output)"
        }
    }
}
finally { Pop-Location }

Step '끝'
Write-Output "   저장소 열기: gh repo view $full --web"
Write-Output '   다음 순서: VS Code에서 이 폴더를 열고, 에이전트에게 prompts.md의 "원문 구조화" 프롬프트를 주세요.'
Write-Output '   에이전트는 새 브랜치에 초안을 올리고 PR을 엽니다. 병합 버튼은 승인자가 누릅니다.'
