# 온톨로지 설계서 — 우리 조직

이 문서는 이 위키의 약속이다. 표를 고치면 `scripts/Test-LlmWiki.ps1`의 검사 기준도 함께 바뀐다.
클래스는 같은 질문이 세 번 나올 때 하나씩 늘린다. 표의 열 이름은 바꾸지 않는다.

## 클래스

| 클래스 | 폴더 | 필수 필드 | 설명 |
|---|---|---|---|
| Product | 10-Products | owner, status | 우리가 만들거나 파는 것 |
| Order | 20-Orders | client, product, owner, status, due | 고객이 맡긴 일 |
| Capability | 30-Capabilities | owner | 우리가 할 수 있는 것 |
| Worklog | 40-Worklog | owner, intent_of, evidence | 어느 날 한 일 |
| Decision | 40-Worklog | owner, status, source | 정한 것과 버린 안 |
| Org | 50-Orgs-People | role, owner | 바깥 조직 |
| Person | 50-Orgs-People | role | 사람 |

모든 노트의 공통 필수 필드는 `class`, `id`, `reviewed`, `updated`다.
`Published/`의 노트는 `approved_by`, `approved_on`도 적는다.

## 허용 값

| 클래스 | 필드 | 허용 값 |
|---|---|---|
| Product | status | 아이디어, 시제품, 운영중, 중단 |
| Order | status | 수주, 진행중, 완료, 취소 |
| Decision | status | 검토중, 결정, 철회 |
| Org | role | 고객, 공급사, 기관 |
| * | reviewed | true, false |

## 관계

| 필드 | 뜻 | 어디서 → 어디로 | 없으면 못 하는 질문 |
|---|---|---|---|
| owner | 책임자 한 명 | 모든 노트 → Person | 이 일은 누가 책임지나요? |
| client | 이 수주의 고객 | Order → Org | 이 고객과 진행 중인 일은 무엇인가요? |
| product | 이 수주가 만드는 것 | Order → Product | 이 수주는 무엇을 만드나요? |
| uses | 이 제품에 필요한 역량 | Product → Capability | 이 제품을 만들려면 무엇이 필요한가요? |
| intent_of | 이 작업일지가 이행하는 수주 | Worklog → Order | 계획대로 되었나요? |
| evidence | 근거 원문 | 모든 노트 → Sources/raw/ | 이 사실의 근거는 무엇인가요? |
| source | 이 결정의 원문 | Decision → Sources/raw/ | 왜 그렇게 정했나요? |

## 고치는 법

1. 우리 조직이 자주 받는 질문 열 개를 적는다.
2. 질문 속 명사는 클래스, 동사는 관계, 상태를 나타내는 말은 허용 값으로 옮긴다.
3. 위 세 표를 고치고 `templates/`를 맞춘다. `prompts.md`의 1~3번 프롬프트를 쓰면 에이전트가 초안을 만든다.
4. `scripts/Test-LlmWiki.ps1`을 돌려 ERROR가 0인지 확인한다.