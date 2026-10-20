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
| Meeting | 40-Worklog | owner, held_on, with_org, attendees, recording, source | 바깥 조직과 한 회의 |
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
| Meeting | recording | 고지함, 거절, 없음 |
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
| source | 이 결정이나 회의의 원문 | Decision, Meeting → Sources/raw/ 또는 회의원문 보관함의 위치 | 왜 그렇게 정했나요? |
| with_org | 회의 상대 조직 | Meeting → Org | 이 고객과 언제 무엇을 이야기했나요? |
| attendees | 회의 참석자 (양쪽 모두) | Meeting → Person | 그 회의에는 누가 있었나요? |
| about | 회의에서 다룬 수주나 제품 | Meeting → Order, Product | 이 수주를 두고 고객과 무슨 이야기를 했나요? |
| decisions | 회의에서 나온 결정 | Meeting → Decision | 이 결정은 어느 회의에서 나왔나요? |

회의 노트의 규칙(녹음 고지, 전사본 보관, 참석자 기록)은 `guides/회의-녹음과-회의-노트.md`에 있다.
`recording`에는 녹음을 고지했는지를 적는다. `고지함`은 회의를 시작할 때 녹음한다고 알렸다는 뜻이고, `거절`은 상대가 녹음을 원하지 않아 메모로 대신했다는 뜻, `없음`은 처음부터 녹음하지 않았다는 뜻이다.

## 고치는 법

1. 우리 조직이 자주 받는 질문 열 개를 적는다.
2. 질문 속 명사는 클래스, 동사는 관계, 상태를 나타내는 말은 허용 값으로 옮긴다.
3. 위 세 표를 고치고 `templates/`를 맞춘다. `prompts.md`의 1~3번 프롬프트를 쓰면 에이전트가 초안을 만든다.
4. `scripts/Test-LlmWiki.ps1`을 돌려 ERROR가 0인지 확인한다.