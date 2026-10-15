<#
.SYNOPSIS
  Published/의 승인본 노트마다 같은 이름의 .docx 쌍을 만듭니다.

.DESCRIPTION
  Copilot Studio의 SharePoint 지식은 지금 .md 본문을 읽지 못하고 .docx는 읽습니다.
  이 스크립트는 Windows의 Word를 이용해 머리말은 2열 표로, # 제목은 Word 제목 스타일로, 나머지 줄은 문단으로 옮깁니다.
  [[위키링크]]는 대괄호를 벗긴 이름만 남깁니다.

  Published/만 대상으로 합니다. Sources/의 초안에 .docx를 만들면 승인 관문이 무너집니다.

.PARAMETER Root
  볼트 폴더. 기본값은 이 스크립트가 들어 있는 scripts 폴더의 상위 폴더입니다.

.PARAMETER Force
  짝이 되는 .md보다 새 .docx가 있어도 다시 만듭니다.

.PARAMETER Prune
  짝이 되는 .md가 없어진 .docx를 지웁니다. 승인본에서 뺀 노트를 에이전트가 계속 인용하지 않게 합니다.

.EXAMPLE
  .\scripts\Export-WikiDocx.ps1 -Prune
.NOTES
  GM-Social 라이선스 v2.0 · Copyright (c) 2026 이인희 (LEE Inhee), 파란두루미 (Parandurume Inc.)
  출처: https://github.com/parandurume-labs/llm-wiki-template
  복사하거나 고쳐 쓸 때는 이 표시와 라이선스 파일을 남겨 주세요.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Root,
    [switch]$Force,
    [switch]$Prune
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# Windows PowerShell 5.1에서는 param 기본값 안에서 $PSScriptRoot가 비어 있으므로 본문에서 정합니다.
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }

$pub = Join-Path (Resolve-Path -LiteralPath $Root).Path 'Published'
if (-not (Test-Path -LiteralPath $pub)) { throw "Published 폴더가 없습니다: $pub" }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Remove-WikiLink([string]$s) {
    return [regex]::Replace($s, '\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]', { param($m) if ($m.Groups[2].Success) { $m.Groups[2].Value } else { $m.Groups[1].Value } })
}

$mdFiles = @(Get-ChildItem -LiteralPath $pub -Recurse -File -Filter *.md)
$todo = @($mdFiles | Where-Object {
        $docx = [IO.Path]::ChangeExtension($_.FullName, '.docx')
        $Force -or -not (Test-Path -LiteralPath $docx) -or ((Get-Item -LiteralPath $docx).LastWriteTime -lt $_.LastWriteTime)
    })
Write-Output ("승인본 {0}개 중 {1}개를 .docx로 만듭니다." -f $mdFiles.Count, $todo.Count)

if ($todo.Count -gt 0 -and $PSCmdlet.ShouldProcess("$($todo.Count)개 노트", 'Word로 .docx 만들기')) {
    try { $word = New-Object -ComObject Word.Application }
    catch { throw 'Word를 찾지 못했습니다. Word가 설치된 Windows PC에서 실행하거나, 노트를 Word에 붙여 넣고 같은 이름의 .docx로 저장하세요.' }
    $word.Visible = $false
    $word.DisplayAlerts = 0
    try {
        foreach ($md in $todo) {
            $text = [IO.File]::ReadAllText($md.FullName, $utf8).TrimStart([char]0xFEFF)
            $lines = $text -split "`r?`n"
            $fm = New-Object System.Collections.Generic.List[object]
            $start = 0
            if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
                for ($i = 1; $i -lt $lines.Count; $i++) {
                    if ($lines[$i].Trim() -eq '---') { $start = $i + 1; break }
                    if ($lines[$i] -match '^([A-Za-z_][\w-]*)\s*:\s*(.*)$') { $fm.Add(@($Matches[1], (Remove-WikiLink ($Matches[2].Trim().Trim('"'))))) }
                }
            }
            $doc = $word.Documents.Add()
            $sel = $word.Selection
            if ($fm.Count -gt 0) {
                $table = $doc.Tables.Add($sel.Range, $fm.Count, 2)
                $table.Borders.Enable = $true
                for ($r = 0; $r -lt $fm.Count; $r++) {
                    $table.Cell($r + 1, 1).Range.Text = $fm[$r][0]
                    $table.Cell($r + 1, 2).Range.Text = $fm[$r][1]
                }
                $sel.EndKey(6) | Out-Null   # 문서 끝으로
                $sel.TypeParagraph()
            }
            for ($i = $start; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                if ($line -match '^(#{1,3})\s+(.*)$') {
                    $sel.Style = $doc.Styles.Item(-1 - $Matches[1].Length)   # wdStyleHeading1..3
                    $sel.TypeText((Remove-WikiLink $Matches[2]))
                }
                else {
                    $sel.Style = $doc.Styles.Item(-1)                        # wdStyleNormal
                    $sel.TypeText((Remove-WikiLink ($line -replace '\*\*', '')))
                }
                $sel.TypeParagraph()
            }
            $out = [IO.Path]::ChangeExtension($md.FullName, '.docx')
            $doc.SaveAs2($out, 16)   # wdFormatDocumentDefault
            $doc.Close(0)
            Write-Output ("  만듦  {0}" -f ($out.Substring($pub.Length).TrimStart('\') -replace '\\', '/'))
        }
    }
    finally {
        $word.Quit()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
    }
}

if ($Prune) {
    foreach ($d in Get-ChildItem -LiteralPath $pub -Recurse -File -Filter *.docx) {
        if ($d.Name.StartsWith('~$')) { continue }
        if (-not (Test-Path -LiteralPath ([IO.Path]::ChangeExtension($d.FullName, '.md')))) {
            if ($PSCmdlet.ShouldProcess($d.FullName, '짝 없는 .docx 지우기')) {
                Remove-Item -LiteralPath $d.FullName
                Write-Output ("  지움  {0}" -f $d.Name)
            }
        }
    }
}
Write-Output '끝났습니다. SharePoint의 Published/ 폴더에 .md와 .docx가 함께 있으면 Copilot Studio가 .docx를 인용합니다.'
