# LLM Wiki 템플릿

우리 조직의 지식으로 에이전트를 척척박사로 만드는 위키의 출발점입니다.
**폴더 + 온톨로지 + 에이전트**로 이루어집니다. 초안은 에이전트가 쓰고, 답의 근거로는 사람이 승인한 노트만 씁니다.

기능은 에이전트가 얼마든지 복제하지만, 우리 조직의 지식은 어떤 에이전트도 복제하지 못합니다. 이 템플릿은 그 지식을 설계하고 담아서 지키는 뼈대입니다.

- 강의: [깃허브로 만드는 LLM Wiki - 에이전트를 척척박사로 만들어 볼까요?](https://power-platform-users-korea.github.io/copilot-dev-days-seoul-2026/llm-wiki/) (GitHub Copilot Dev Days Seoul 2026)
- 더 깊이 배우기: [LLM Wiki & 온톨로지 실전 과정](https://llm-wiki-lecture.paranduru.me/)

## 시작하기

**1. 내 저장소 만들기**

이 페이지 위쪽에서 **Use this template** → **Create a new repository**를 누르고 **Private**을 고릅니다. 명령으로 만들려면 아래처럼 실행합니다.

```powershell
gh repo create my-org/our-llm-wiki --private --template parandurume-labs/llm-wiki-template --clone
cd our-llm-wiki
.\scripts\Test-LlmWiki.ps1
```

`SUMMARY error=0`이 나오면 준비가 끝났습니다.

**2. 승인 관문 규칙 걸기**

템플릿으로 만든 저장소에는 브랜치 규칙이 따라오지 않으므로 아래 스크립트로 겁니다. 스크립트는 PR 필수, 승인 1명, 코드 오너 리뷰, 필수 검사, 원문 보호 규칙을 걸고 `CODEOWNERS`에 승인자를 채워 넣습니다. 실행하기 전에 `-WhatIf`로 할 일부터 확인하세요.

```powershell
.\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Approver <승인자 GitHub 아이디> -WhatIf
.\scripts\Publish-LlmWikiGitHub.ps1 -Path . -Approver <승인자 GitHub 아이디>
```

비공개 저장소에 규칙을 걸려면 개인 계정은 GitHub Pro, 조직은 Team 요금제 이상을 써야 합니다. 규칙을 걸 수 없을 때 스크립트는 경고를 남기고 다음으로 넘어갑니다.

**3. 예시 노트 지우기**

먼저 예시 공장인 한결공장의 노트로 검사와 질문 시험을 해 보세요. 그다음 아래 명령으로 예시 노트를 지우고 우리 조직의 위키를 시작합니다.

```powershell
.\scripts\Clear-Sample.ps1
```

## 저장소 구성

| 경로 | 내용 |
|---|---|
| `ontology.md` | 클래스, 허용 값, 관계를 정한 설계서. 검사 스크립트가 이 표를 기준으로 삼습니다 |
| `AGENTS.md` | 에이전트 작업 규칙. GitHub Copilot과 Claude Code가 일을 시작하기 전에 읽습니다 |
| `prompts.md` | 설계부터 배포, 운영까지 에이전트에게 주는 예시 프롬프트 열한 개 |
| `questions.md` | 에이전트 시험 열 문항 (답 있음 4, 초안만 3, 없음 3) |
| `templates/` | 클래스별 노트 템플릿 일곱 개 |
| `Sources/raw/` | 원문. 고치지 않습니다 |
| `Sources/<클래스 폴더>/` | 에이전트가 만든 초안 (`reviewed: false`) |
| `Published/<클래스 폴더>/` | 사람이 승인한 노트. 에이전트는 이 폴더의 노트만 인용합니다 |
| `hubs/`, `reports/` | 길잡이 노트, 회고와 점검 보고서 |
| `scripts/` | 검사, .docx 내보내기, 깃허브·SharePoint 올리기, 예시 지우기 |
| `.github/` | `CODEOWNERS`, 검사 워크플로, Copilot 지시 파일 |

## 일하는 방식

1. 원문을 `Sources/raw/`에 올립니다.
2. 에이전트에게 `prompts.md`의 "원문 구조화" 프롬프트를 줍니다. 에이전트는 추출표부터 보여 주고, 승인을 받은 뒤에 `Sources/`에 초안을 만듭니다.
3. 에이전트가 승인 요청 PR을 열면 검사 워크플로가 저절로 돌아갑니다. 오류가 있으면 병합 버튼이 잠깁니다.
4. 승인자는 PR에서 원문과 대조한 뒤 병합합니다. 병합 버튼을 누르는 순간이 곧 승인입니다.

준비와 점검, 초안은 에이전트가 맡고 설계와 로그인, 승인은 사람이 맡습니다.

## Microsoft 365에서 쓰기

- Teams 채널의 파일 탭에서 **동기화**를 누르고 이 저장소의 파일을 그 동기화 폴더에 두면 OneDrive가 SharePoint에 올려 줍니다. 가장 쉬운 방법입니다.
- 에이전트에게 맡기려면 `.\scripts\Publish-LlmWikiSharePoint.ps1 -Path . -SiteUrl <사이트 주소> -Folder "<채널 이름>/our-llm-wiki" -WhatIf`를 실행합니다.
- Copilot Studio의 SharePoint 지식은 아직 `.md` 본문을 읽지 못합니다. 그래서 `.\scripts\Export-WikiDocx.ps1 -Prune`으로 승인본마다 `.docx` 쌍을 만들고, 지식에는 `Published/` 주소 하나만 연결합니다. 지시문 다섯 줄은 `prompts.md` 11번에 있습니다.

## 실행 환경

- 스크립트는 Windows PowerShell 5.1과 PowerShell 7에서 모두 돌아갑니다. macOS와 Linux에서는 PowerShell 7을 씁니다.
- `Export-WikiDocx.ps1`은 Word가 설치된 Windows에서만 돌아갑니다.
- GitHub Actions의 검사는 PowerShell 7(`pwsh`)로 돌아가므로 따로 설치할 것이 없습니다.

## 알아 둘 한계

- 검사 스크립트는 원문이 바뀌었는지, 승인자가 진짜인지, 문장이 원문에 있는지 확인하지 못합니다. 이 세 가지는 사람이 확인합니다.
- `AGENTS.md`는 지시일 뿐 강제력이 없습니다. 실제로 막아 주는 장치는 브랜치 규칙과 `CODEOWNERS`, 그리고 사람입니다.
- GitHub 화면은 `[[위키링크]]`를 링크로 바꾸지 않습니다. 그래프와 백링크가 필요하면 같은 폴더를 Obsidian이나 VS Code로 여세요.

## 라이선스

[GM-Social 라이선스 v2.0](LICENSE)을 따릅니다. 라이선스는 한국어와 영어로 되어 있고, 두 글의 내용이 다르면 한국어 원문이 우선합니다.

- 상업적 용도를 포함해 자유롭게 쓰고, 고치고, 나눌 수 있습니다.
- 복사하거나 고쳐 쓸 때는 라이선스 파일과 저작권 표시를 그대로 두고, 원저작자(이인희 / 파란두루미)와 출처를 밝혀 주세요.
- 파생 저작물을 배포하면 직접 덧붙인 부분도 같은 라이선스로 공개해야 합니다.
- 운영 환경에 올리면 90일 안에 경기도 광명시에 감사하는 글과 광명을 소개하는 게시물을 올려 주세요. 교육·학습 목적이나 비영리 단체의 공익 목적으로 쓸 때는 이 의무가 면제됩니다.

예시에 나오는 한결공장, 다온기계, 푸른금속은 모두 가상의 회사입니다.
