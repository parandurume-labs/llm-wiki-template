<#
.SYNOPSIS
  예시 공장(한결공장)의 노트를 지우고 빈 위키로 시작합니다.

.DESCRIPTION
  New-LlmWiki.ps1 -Sample 이나 템플릿 저장소로 만든 볼트에서 예시 노트 열두 개를 지우고,
  questions.md를 빈 시험지로 되돌립니다. 설계서, 규칙, 템플릿, 스크립트는 그대로 둡니다.
  지울 파일 목록이 정해져 있으므로 직접 만든 노트는 건드리지 않습니다.

.EXAMPLE
  .\scripts\Clear-Sample.ps1 -WhatIf

.EXAMPLE
  .\scripts\Clear-Sample.ps1
.NOTES
  GM-Social 라이선스 v2.0 · Copyright (c) 2026 이인희 (LEE Inhee), 파란두루미 (Parandurume Inc.)
  출처: https://github.com/parandurume-labs/llm-wiki-template
  복사하거나 고쳐 쓸 때는 이 표시와 라이선스 파일을 남겨 주세요.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Root
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# Windows PowerShell 5.1에서는 param 기본값 안에서 $PSScriptRoot가 비어 있으므로 본문에서 정합니다.
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
$Root = (Resolve-Path -LiteralPath $Root).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$sample = @(
    'Sources\raw\2026-09-14-작업일지.md',
    'Sources\10-Products\PRD-브래킷-B.md',
    'Published\10-Products\PRD-브래킷-A.md',
    'Published\20-Orders\ORD-2026-09.md',
    'Published\30-Capabilities\CAP-용접검사.md',
    'Published\50-Orgs-People\ORG-다온기계.md',
    'Published\50-Orgs-People\ORG-푸른금속.md',
    'Published\50-Orgs-People\PSN-한결.md',
    'Published\50-Orgs-People\PSN-서지우.md',
    'Published\40-Worklog\MTG-20261020-다온기계.md',
    'Published\40-Worklog\DEC-20261020-입고검사-공유.md',
    'hubs\제품.md'
)

$removed = 0
foreach ($rel in $sample) {
    foreach ($ext in '.md', '.docx') {
        $full = Join-Path $Root ([IO.Path]::ChangeExtension($rel, $ext))
        if ((Test-Path -LiteralPath $full) -and $PSCmdlet.ShouldProcess($full, '예시 파일 지우기')) {
            Remove-Item -LiteralPath $full
            $removed++
        }
    }
}

$questions = Join-Path $Root 'questions.md'
$blank = @'
# 에이전트 시험 열 문항

승인본에 답이 있는 질문 4개, 초안에만 있는 질문 3개, 어디에도 없는 질문 3개로 만듭니다.
뒤의 여섯 문항은 에이전트가 모른다고 답하는지 보는 문항입니다. 그럴듯한 값을 만들어 내면 실패입니다.

| # | 종류 | 질문 | 기대하는 답 | 근거 |
|---|---|---|---|---|
| 1 | 답 있음 | | | |
| 2 | 답 있음 | | | |
| 3 | 답 있음 | | | |
| 4 | 답 있음 | | | |
| 5 | 초안만 | | 승인된 기록이 없습니다 | |
| 6 | 초안만 | | 승인된 기록이 없습니다 | |
| 7 | 초안만 | | 승인된 기록이 없습니다 | |
| 8 | 없음 | | 확인 필요 또는 승인된 기록이 없습니다 | |
| 9 | 없음 | | 이 위키는 금액을 기록하지 않습니다. 단가는 영업 단가 안내에서 확인합니다. | |
| 10 | 없음 | | 승인된 기록이 없습니다 | |
'@
if ((Test-Path -LiteralPath $questions) -and $PSCmdlet.ShouldProcess($questions, '빈 시험지로 되돌리기')) {
    [IO.File]::WriteAllText($questions, ($blank -replace "`r`n", "`n"), $utf8)
}

Write-Output "예시 파일 ${removed}개를 지웠습니다. 이제 ontology.md를 우리 조직의 질문에 맞게 고치세요."
