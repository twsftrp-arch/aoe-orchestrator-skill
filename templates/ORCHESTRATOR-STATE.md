# 오케스트레이터 인수인계 상태 (갱신: YYYY-MM-DD)

> 이 파일은 오케스트레이터 세션 교대 시 첫 번째로 읽는 문서.
> 의미 있는 상태 변화마다, 그리고 유휴 전환 전에 갱신한다.
> 열린 결정의 정본은 report-queue.md — 불일치 시 큐를 따른다.

## 함대 구성

- 활성 오케스트레이터: <세션 타이틀> (활성은 항상 1개)
- standby HQ: <있으면 기재 — 역할: 정비·상호평가. 이중 중계 금지>
- 워커: <N>개 — <도구/모델/권한 요약>

## 즉시 재무장할 인프라 (교대 후 첫 행동)

0. `~/.agent-of-empires/orchestrator/aoe-doctor.sh` 실행 — 일괄 점검 (읽기 전용).
1. SKILL.md(aoe-orchestrator) 읽기 — 모든 운용 규칙의 정본.
2. 감시기 생존 확인: `launchctl print gui/$(id -u)/<watcher 라벨>` (죽었으면 bootstrap).
3. 이벤트 구독: 매 턴 시작 시 `tail ~/.agent-of-empires/orchestrator/events.log` + 순찰 cron 재등록.
4. 보고 큐 확인: `~/.agent-of-empires/orchestrator/report-queue.md`. 활성 오케스트레이터 표기를 자신으로 갱신.

## 열린 결정 (오너 답 대기)

- 정본은 report-queue.md — 이 섹션은 스냅샷일 뿐.
- (현재 없음)

## 워커 스냅샷 (요점)

- <워커>: <상태 한 줄 — working/blocked/idle + 게이트 사유>

## 환경 메모

- aoe 버전·serve 포트·인증 방식 등 (⚠️ 시크릿 값·외부 접속 주소는 적지 않는다)
