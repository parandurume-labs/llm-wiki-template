<#
.SYNOPSIS
  Microsoft 365에 로그인해 볼트를 SharePoint 문서 라이브러리(Teams 채널 파일)에 올립니다.

.DESCRIPTION
  1. Microsoft Graph PowerShell 인증 모듈이 없으면 현재 사용자 범위로 설치합니다.
  2. Connect-MgGraph로 로그인합니다. 사람이 브라우저 창에서 직접 로그인하고 동의합니다.
  3. 사이트와 문서 라이브러리를 찾아 볼트 폴더를 그대로 올립니다. .git, .github, .obsidian은 올리지 않습니다.
  4. Copilot Studio 지식에 넣을 Published/ 폴더 주소를 알려 줍니다.

  폴더 권한(Published/는 승인자만 편집)과 Copilot Studio 에이전트 설정은 화면에서 직접 합니다.
  끝에 그 순서를 출력합니다.

  더 간단한 방법도 있습니다. Teams 채널 파일 탭에서 "동기화" 또는 "OneDrive에 바로 가기 추가"를 누르고,
  New-LlmWiki.ps1의 -Path를 그 동기화 폴더로 주면 이 스크립트 없이 OneDrive가 올려 줍니다.

  -WhatIf를 붙이면 로그인하지 않고 올릴 파일 목록만 보여 줍니다.

.PARAMETER Path
  볼트 폴더.

.PARAMETER SiteUrl
  SharePoint 사이트 주소. 예: https://contoso.sharepoint.com/sites/wiki-team
  Teams 채널의 파일 탭에서 "SharePoint에서 열기"를 누르면 주소창에서 볼 수 있습니다.

.PARAMETER Folder
  라이브러리 안에서 볼트를 둘 폴더 경로. Teams 표준 채널이면 "채널 이름/볼트 이름"입니다. 기본값은 볼트 폴더 이름입니다.

.PARAMETER Library
  문서 라이브러리 이름. 기본값은 사이트의 기본 라이브러리(문서, Shared Documents)입니다.

.PARAMETER ExportDocx
  올리기 전에 Export-WikiDocx.ps1로 승인본의 .docx 쌍을 만듭니다.

.EXAMPLE
  .\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl https://contoso.sharepoint.com/sites/wiki-team -Folder "위키/our-llm-wiki" -WhatIf

.EXAMPLE
  .\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl https://contoso.sharepoint.com/sites/wiki-team -Folder "위키/our-llm-wiki" -ExportDocx
.NOTES
  GM-Social 라이선스 v2.0 · Copyright (c) 2026 이인희 (LEE Inhee), 파란두루미 (Parandurume Inc.)
  출처: https://github.com/parandurume-labs/llm-wiki-template
  복사하거나 고쳐 쓸 때는 이 표시와 라이선스 파일을 남겨 주세요.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$SiteUrl,
    [string]$Folder,
    [string]$Library,
    [switch]$ExportDocx
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
function Step([string]$msg) { Write-Output ''; Write-Output "== $msg" }
function Get-EncodedPath([string]$p) { return (($p -replace '\\', '/').Trim('/').Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/' }

$Path = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $Path 'ontology.md'))) { throw "볼트 폴더가 아닙니다(ontology.md 없음): $Path" }
if (-not $Folder) { $Folder = Split-Path -Leaf $Path }
$site = [uri]$SiteUrl
$graph = 'https://graph.microsoft.com/v1.0'

# ---------- 0. .docx 쌍 ----------
if ($ExportDocx) {
    Step '0. 승인본의 .docx 쌍 만들기'
    $exporter = Join-Path $Path 'scripts\Export-WikiDocx.ps1'
    if ($PSCmdlet.ShouldProcess($Path, 'Export-WikiDocx.ps1 실행')) { & $exporter -Root $Path -Prune }
}

# ---------- 1. 올릴 파일 ----------
Step '1. 올릴 파일 고르기'
$skip = '\\(\.git|\.github|\.obsidian|\.vscode)(\\|$)'
$files = @(Get-ChildItem -LiteralPath $Path -Recurse -File | Where-Object { $_.FullName -notmatch $skip -and -not $_.Name.StartsWith('~$') -and $_.Name -ne '.gitkeep' })
$big = @($files | Where-Object { $_.Length -gt 250MB })
if ($big.Count -gt 0) { throw "250MB가 넘는 파일은 올리지 않습니다: $($big.Name -join ', ')" }
Write-Output ("   {0}개 파일 → {1} 의 '{2}' 폴더" -f $files.Count, $SiteUrl, $Folder)

if ($WhatIfPreference) {
    $files | Select-Object -First 15 | ForEach-Object { Write-Output ('   ' + ($_.FullName.Substring($Path.Length + 1) -replace '\\', '/')) }
    if ($files.Count -gt 15) { Write-Output "   … 외 $($files.Count - 15)개" }
    Write-Output ''
    Write-Output '   -WhatIf: 로그인하지 않았고 아무것도 올리지 않았습니다.'
    return
}

# ---------- 2. 로그인 ----------
Step '2. Microsoft 365 로그인'
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Output '   Microsoft.Graph.Authentication 모듈을 현재 사용자 범위로 설치합니다.'
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication
Write-Output '   브라우저 창이 열리면 회사 계정으로 직접 로그인하세요. 처음이면 권한 동의 화면이 나옵니다.'
Connect-MgGraph -Scopes 'Sites.ReadWrite.All' -NoWelcome
Write-Output ("   로그인: {0}" -f (Get-MgContext).Account)

# ---------- 3. 사이트와 라이브러리 ----------
Step '3. 사이트와 문서 라이브러리 찾기'
$siteObj = Invoke-MgGraphRequest -Method GET -Uri ("$graph/sites/{0}:{1}" -f $site.Host, $site.AbsolutePath.TrimEnd('/'))
if ($Library) {
    $drives = (Invoke-MgGraphRequest -Method GET -Uri "$graph/sites/$($siteObj.id)/drives").value
    $drive = $drives | Where-Object { $_.name -eq $Library } | Select-Object -First 1
    if (-not $drive) { throw "라이브러리 '$Library'를 찾지 못했습니다. 있는 라이브러리: $(($drives | ForEach-Object name) -join ', ')" }
}
else { $drive = Invoke-MgGraphRequest -Method GET -Uri "$graph/sites/$($siteObj.id)/drive" }
Write-Output ("   사이트: {0} · 라이브러리: {1}" -f $siteObj.displayName, $drive.name)

# ---------- 4. 올리기 ----------
Step '4. 올리기'
$i = 0
foreach ($f in $files) {
    $i++
    $rel = $f.FullName.Substring($Path.Length + 1)
    $target = Get-EncodedPath ("$Folder/$rel")
    Invoke-MgGraphRequest -Method PUT -Uri "$graph/drives/$($drive.id)/root:/${target}:/content" -InputFilePath $f.FullName -ContentType 'application/octet-stream' | Out-Null
    Write-Progress -Activity 'SharePoint에 올리는 중' -Status $rel -PercentComplete ($i * 100 / $files.Count)
}
Write-Progress -Activity 'SharePoint에 올리는 중' -Completed
Write-Output "   ${i}개 파일을 올렸습니다."

$pubItem = Invoke-MgGraphRequest -Method GET -Uri ("$graph/drives/$($drive.id)/root:/{0}" -f (Get-EncodedPath "$Folder/Published"))
$pubUrl = $pubItem.webUrl

Step '끝: 화면에서 할 일 세 가지'
Write-Output "   Published/ 폴더 주소: $pubUrl"
Write-Output '   1) 권한: Published 폴더 → 액세스 관리 → 상속 중지 → 편집은 승인자만, 나머지는 읽기만 남깁니다.'
Write-Output '   2) Copilot Studio: 새 에이전트 → 지시문 다섯 줄 → 지식의 "모든 웹 사이트 검색" 삭제 → 지식 추가 → SharePoint → 위 주소 하나만 등록.'
Write-Output '   3) 시험: questions.md의 열 문항을 미리 보기 창에서 묻고, 모른다고 답해야 하는 여섯 문항까지 통과하면 Teams에 게시합니다.'
