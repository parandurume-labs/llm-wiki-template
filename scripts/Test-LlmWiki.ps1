<#
.SYNOPSIS
  LLM Wiki 볼트를 ontology.md 기준으로 검사합니다. 파일은 고치지 않습니다.

.DESCRIPTION
  머리말, 클래스, 필수 필드, 허용 값, 승인 필드, 위키링크, 기밀 의심 단어를 확인합니다.
  ERROR가 하나라도 있으면 종료 코드 1을 돌려주므로 GitHub Actions의 필수 검사로 쓸 수 있습니다.

  이 스크립트가 보지 못하는 것도 있습니다.
  원문이 바뀌었는지, approved_by의 이름이 진짜 승인자인지, 문장이 원문에 있는 내용인지는 사람이 확인합니다.

.PARAMETER Root
  볼트 폴더. 기본값은 이 스크립트가 들어 있는 scripts 폴더의 상위 폴더입니다.

.PARAMETER ShowInfo
  검사하지 않은 원문 목록(INFO)도 보여 줍니다.

.EXAMPLE
  .\scripts\Test-LlmWiki.ps1

.EXAMPLE
  .\scripts\Test-LlmWiki.ps1 -Root D:\wiki\our-llm-wiki -ShowInfo
.NOTES
  GM-Social 라이선스 v2.0 · Copyright (c) 2026 이인희 (LEE Inhee), 파란두루미 (Parandurume Inc.)
  출처: https://github.com/parandurume-labs/llm-wiki-template
  복사하거나 고쳐 쓸 때는 이 표시와 라이선스 파일을 남겨 주세요.
#>
[CmdletBinding()]
param(
    [string]$Root,
    [switch]$ShowInfo
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# Windows PowerShell 5.1에서는 param 기본값 안에서 $PSScriptRoot가 비어 있으므로 본문에서 정합니다.
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }

$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\', '/')
$utf8 = New-Object System.Text.UTF8Encoding($false)
$findings = New-Object System.Collections.Generic.List[object]

function Get-RelPath([string]$full) {
    return ($full.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/')
}
function Add-Finding([string]$level, [string]$full, [string]$msg) {
    $findings.Add([pscustomobject]@{ Level = $level; Path = (Get-RelPath $full); Message = $msg })
}
function Read-Text([string]$full) {
    return [System.IO.File]::ReadAllText($full, $utf8).TrimStart([char]0xFEFF)
}
function Get-Table([string]$text, [string]$heading) {
    # "## heading" 아래의 마크다운 표를 행 객체 목록으로 돌려줍니다.
    $rows = New-Object System.Collections.Generic.List[object]
    $inSection = $false
    $header = $null
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^##\s+(.+?)\s*$') { $inSection = ($Matches[1].Trim() -eq $heading); $header = $null; continue }
        if (-not $inSection -or $line -notmatch '^\s*\|') { continue }
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells[0] -match '^:?-{2,}:?$') { continue }
        if ($null -eq $header) { $header = $cells; continue }
        $row = [ordered]@{}
        for ($i = 0; $i -lt $header.Count; $i++) { $row[$header[$i]] = if ($i -lt $cells.Count) { $cells[$i] } else { '' } }
        $rows.Add([pscustomobject]$row)
    }
    return , $rows
}
function Split-List([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return @() }
    return @($value -split '[,·、]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
function Read-Note([string]$full) {
    $text = Read-Text $full
    $note = [ordered]@{ Text = $text; HasFm = $false; Broken = $false; Fm = [ordered]@{}; Body = $text }
    if (-not $text.StartsWith('---')) { return [pscustomobject]$note }
    $note.HasFm = $true
    $lines = $text -split "`r?`n"
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
    if ($end -lt 0) { $note.Broken = $true; return [pscustomobject]$note }
    for ($i = 1; $i -lt $end; $i++) {
        if ($lines[$i] -match '^([A-Za-z_][\w-]*)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $v = ($Matches[2] -replace '\s+#.*$', '').Trim()
            if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[-1] -eq '"') -or ($v[0] -eq "'" -and $v[-1] -eq "'"))) { $v = $v.Substring(1, $v.Length - 2) }
            $note.Fm[$key] = $v
        }
    }
    $note.Body = if ($end + 1 -lt $lines.Count) { ($lines[($end + 1)..($lines.Count - 1)] -join "`n") } else { '' }
    return [pscustomobject]$note
}

# ---------- 1. 설계서 읽기 ----------
$ontologyPath = Join-Path $Root 'ontology.md'
if (-not (Test-Path -LiteralPath $ontologyPath)) {
    Write-Output "ERROR ontology.md: 설계서가 없습니다. 볼트 루트에 ontology.md를 두세요."
    Write-Output 'SUMMARY error=1 warn=0 info=0'
    exit 1
}
$ontologyText = Read-Text $ontologyPath
$classes = @{}
foreach ($r in (Get-Table $ontologyText '클래스')) {
    $name = $r.'클래스'
    if (-not $name) { continue }
    $classes[$name] = [pscustomobject]@{ Folder = $r.'폴더'; Required = (Split-List $r.'필수 필드') }
}
$allowed = Get-Table $ontologyText '허용 값'
if ($classes.Count -eq 0) {
    Write-Output "ERROR ontology.md: '## 클래스' 표를 읽지 못했습니다. 열 이름은 클래스 | 폴더 | 필수 필드 | 설명 입니다."
    Write-Output 'SUMMARY error=1 warn=0 info=0'
    exit 1
}

# ---------- 2. 노트 목록과 색인 ----------
$areas = 'Sources', 'Published', 'hubs'
$files = foreach ($a in $areas) {
    $dir = Join-Path $Root $a
    if (Test-Path -LiteralPath $dir) { Get-ChildItem -LiteralPath $dir -Recurse -File -Filter *.md }
}
$notes = @{}
$index = @{}
foreach ($f in $files) {
    $n = Read-Note $f.FullName
    $rel = Get-RelPath $f.FullName
    $area = $rel.Split('/')[0]
    $isDraft = ($area -eq 'Sources' -and $n.HasFm -and $n.Fm['reviewed'] -ne 'true')
    $entry = [pscustomobject]@{ File = $f; Note = $n; Rel = $rel; Area = $area; IsDraft = $isDraft }
    $notes[$f.FullName] = $entry
    $keys = @($f.BaseName)
    if ($n.Fm['id']) { $keys += $n.Fm['id'] }
    foreach ($k in $keys) {
        $lk = $k.ToLowerInvariant()
        if (-not $index.ContainsKey($lk) -or $area -eq 'Published') { $index[$lk] = $entry }
    }
}

# ---------- 3. 노트별 검사 ----------
$secret = '급여|연봉|단가|주민등록|계좌|연락처|전화번호'
$secretOk = '쓰지 않|적지 않|기록하지 않|금지|답하지 않'
$today = Get-Date

foreach ($e in $notes.Values | Sort-Object Rel) {
    $f = $e.File; $n = $e.Note; $area = $e.Area

    if (-not $n.HasFm) {
        if ($area -eq 'Published') { Add-Finding 'ERROR' $f.FullName '머리말이 없습니다. 승인본에는 머리말이 있어야 합니다.' }
        elseif ($area -eq 'Sources') { Add-Finding 'INFO' $f.FullName '원문입니다. 검사하지 않습니다.' }
    }
    elseif ($n.Broken) { Add-Finding 'ERROR' $f.FullName "머리말이 '---'로 닫히지 않았습니다." }
    elseif ($area -ne 'hubs') {
        $fm = $n.Fm
        $cls = $fm['class']
        if (-not $cls) { Add-Finding 'ERROR' $f.FullName 'class가 없습니다.' }
        elseif (-not $classes.ContainsKey($cls)) { Add-Finding 'ERROR' $f.FullName "class '$cls'는 ontology.md에 없습니다." }
        else {
            $def = $classes[$cls]
            foreach ($req in (@('id', 'reviewed', 'updated') + $def.Required | Select-Object -Unique)) {
                if (-not $fm.Contains($req) -or [string]::IsNullOrWhiteSpace($fm[$req])) { Add-Finding 'ERROR' $f.FullName "필수 필드 '$req'가 비어 있습니다." }
            }
            foreach ($r in $allowed) {
                if ($r.'클래스' -ne '*' -and $r.'클래스' -ne $cls) { continue }
                $field = $r.'필드'
                if (-not $fm.Contains($field) -or [string]::IsNullOrWhiteSpace($fm[$field])) { continue }
                $ok = Split-List $r.'허용 값'
                if ($ok -notcontains $fm[$field]) { Add-Finding 'ERROR' $f.FullName "$field '$($fm[$field])'는 허용 값이 아닙니다. 허용 값: $($ok -join ', ')" }
            }
            $parent = Split-Path -Leaf (Split-Path -Parent $f.FullName)
            if ($def.Folder -and $parent -ne $def.Folder) { Add-Finding 'WARN' $f.FullName "$cls 노트는 $($def.Folder) 폴더에 둡니다. 지금 폴더: $parent" }
        }
        if ($fm['id'] -and $fm['id'] -ne $f.BaseName) { Add-Finding 'WARN' $f.FullName "id '$($fm['id'])'와 파일 이름이 다릅니다." }

        if ($area -eq 'Published') {
            if ($fm['reviewed'] -ne 'true') { Add-Finding 'ERROR' $f.FullName '승인본인데 reviewed가 true가 아닙니다.' }
            foreach ($k in 'approved_by', 'approved_on') {
                if ([string]::IsNullOrWhiteSpace($fm[$k])) { Add-Finding 'ERROR' $f.FullName "승인본에 ${k}가 없습니다." }
            }
        }
        elseif ($area -eq 'Sources') {
            if ($fm['reviewed'] -eq 'true') { Add-Finding 'WARN' $f.FullName 'reviewed가 true인데 Sources/에 있습니다. 승인했다면 Published/로 옮기세요.' }
            $d = [datetime]::MinValue
            if ($fm['updated'] -and [datetime]::TryParse($fm['updated'], [ref]$d) -and ($today - $d).TotalDays -gt 30) {
                Add-Finding 'WARN' $f.FullName "30일 넘게 승인을 기다리는 초안입니다. (updated: $($fm['updated']))"
            }
        }
    }

    # 위키링크
    if ($n.HasFm -or $area -eq 'hubs') {
        $seen = @{}
        foreach ($m in [regex]::Matches($n.Text, '\[\[([^\]\|#]+)(?:[#\|][^\]]*)?\]\]')) {
            $target = $m.Groups[1].Value.Trim()
            if (-not $target -or $seen.ContainsKey($target)) { continue }
            $seen[$target] = $true
            $hit = $index[$target.ToLowerInvariant()]
            if (-not $hit) {
                $lvl = if ($area -eq 'Published') { 'ERROR' } else { 'WARN' }
                Add-Finding $lvl $f.FullName "[[${target}]] 노트를 찾지 못했습니다."
            }
            elseif ($hit.IsDraft -and $area -eq 'Published') { Add-Finding 'ERROR' $f.FullName "승인본이 초안 [[${target}]]을 가리킵니다." }
            elseif ($hit.IsDraft -and $area -eq 'hubs') { Add-Finding 'WARN' $f.FullName "허브가 초안 [[${target}]]을 가리킵니다. 허브는 승인본만 가리킵니다." }
        }
    }

    # 기밀 의심 단어
    if ($n.HasFm) {
        foreach ($line in ($n.Text -split "`r?`n")) {
            if ($line -match $secret -and $line -notmatch $secretOk) {
                Add-Finding 'WARN' $f.FullName "기밀 의심 단어가 있습니다: $($line.Trim())"
                break
            }
        }
    }
}

# ---------- 4. 출력 ----------
$order = @{ ERROR = 0; WARN = 1; INFO = 2 }
foreach ($x in ($findings | Sort-Object { $order[$_.Level] }, Path)) {
    if ($x.Level -eq 'INFO' -and -not $ShowInfo) { continue }
    Write-Output ('{0,-5} {1}: {2}' -f $x.Level, $x.Path, $x.Message)
}
$err = @($findings | Where-Object Level -eq 'ERROR').Count
$warn = @($findings | Where-Object Level -eq 'WARN').Count
$info = @($findings | Where-Object Level -eq 'INFO').Count
Write-Output ("SUMMARY error={0} warn={1} info={2} notes={3}" -f $err, $warn, $info, $notes.Count)
if ($err -gt 0) { exit 1 }
exit 0
