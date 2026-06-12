# aoe-orchestrator-skill

멀티 AI 에이전트 "함대"를 한 명이 운영하기 위한 오케스트레이션 스킬 + 감시 인프라.

[agent-of-empires(aoe)](https://github.com/njbrake/agent-of-empires) 위에서 Claude Code / Codex CLI 세션 여러 개를 굴릴 때, **오케스트레이터 세션 1개가 워커 세션들을 감시·중계**하도록 만드는 운용 규칙(SKILL.md)과 스크립트 모음입니다. [steipete의 maintainer-orchestrator](https://github.com/steipete/agent-scripts) 패턴을 개인 멀티-구독 환경에 맞게 이식·진화시킨 것입니다.

> One-person fleet orchestration for AI coding agents on top of
> [agent-of-empires](https://github.com/njbrake/agent-of-empires):
> a Claude Code skill (operating rules) + a tiny event watcher + a health check,
> adapted from steipete's maintainer-orchestrator pattern. Docs are in Korean.

## 누구에게 맞나

- Claude / ChatGPT(Codex) 구독을 **둘 이상** 굴리는 사람
- macOS + 터미널에서 에이전트 세션을 5개 이상 동시 운영하는(하고 싶은) 사람
- "어느 세션이 끝났지? 어디가 막혔지? 보고가 홍수다" 문제를 겪는 사람

세션 1~2개만 쓴다면 과합니다. 그 경우 steipete 원본 레포의 개념 글만 읽어도 충분합니다.

## 구성

```
SKILL.md                      오케스트레이터 운용 규칙 (Claude Code 스킬)
scripts/aoe-watch.py          이벤트 감시기 — aoe의 ACP 이벤트 DB를 폴링해
                              TURN_DONE/STOPPED/ERROR/LONG_RUN을 events.log에 기록
scripts/aoe-doctor.sh         1분 헬스체크 — 데몬·감시기·워커수·DB신선도·큐 정합을
                              일괄 점검, FAIL 항목엔 복구 명령 동반 (읽기 전용)
launchd/com.example.aoe-watch.plist   감시기 launchd 등록 예시
templates/ORCHESTRATOR-STATE.md       인수인계 문서 빈 틀
templates/report-queue.md             보고 큐 빈 틀
```

## 핵심 운용 규칙 (SKILL.md 요약)

1. **오케스트레이터는 구현하지 않는다** — 감시·분류·중계·보고만. 구현은 워커가.
2. **읽기 전 판단 금지** — 이벤트 로그·세션 목록·큐를 읽기 전에는 어떤 메시지도 만들지 않는다.
3. **보고 큐: 사람 앞에는 열린 결정 1건만** — 나머지는 큐에 적고 "대기 N건" 한 줄.
4. **Decision Readiness** — 미완성 상태로 사람에게 선택을 묻지 않는다. 증거(테스트·실행 확인)+트레이드오프+정확한 선택지를 갖춘 뒤에만.
5. **게이트 문서화 유휴 규칙** — 유휴 워커는 "왜 유휴인지"(사람 손작업 대기 등)가 문서화돼 있으면 정상. 사유 없는 유휴만 다음 작업을 할당.
6. **개입 최소화** — working이고 일관된 진행이면 침묵. 블로커·소진·반복실패·위험 행동에만 개입.
7. **워커 하위위임 금지** — 세션 생성·할당은 오케스트레이터(사람 경유)만.

## 설치

전제: macOS, [aoe](https://github.com/njbrake/agent-of-empires) 1.11+ (structured/ACP 워커), Claude Code 또는 Codex CLI.

```bash
git clone https://github.com/twsftrp-arch/aoe-orchestrator-skill
cd aoe-orchestrator-skill

# 1. 스킬 설치 (Claude Code 기준)
mkdir -p ~/.claude/skills/aoe-orchestrator
cp SKILL.md ~/.claude/skills/aoe-orchestrator/
cp templates/ORCHESTRATOR-STATE.md ~/.claude/skills/aoe-orchestrator/

# 2. 감시기 + 닥터
mkdir -p ~/.agent-of-empires/orchestrator
cp scripts/aoe-watch.py scripts/aoe-doctor.sh ~/.agent-of-empires/orchestrator/
chmod +x ~/.agent-of-empires/orchestrator/aoe-doctor.sh
cp templates/report-queue.md ~/.agent-of-empires/orchestrator/

# 3. 감시기 launchd 등록 (plist 안의 YOUR_USERNAME을 자기 것으로 바꾼 뒤)
sed "s/YOUR_USERNAME/$(whoami)/g" launchd/com.example.aoe-watch.plist \
  > ~/Library/LaunchAgents/com.example.aoe-watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.aoe-watch.plist

# 4. 확인
~/.agent-of-empires/orchestrator/aoe-doctor.sh
```

오케스트레이터로 쓸 aoe 세션의 타이틀에 `(HQ)`를 붙이세요 — 감시기가 HQ 세션의 이벤트는 알림에서 제외합니다. 그 세션에서 "오케스트레이터 모드로, SKILL.md 읽고 시작해" 라고 하면 됩니다.

## 운영하며 배운 것 (하드코딩된 교훈들)

- **대형 컨텍스트 compact는 aoe UI 밖에서**: aoe의 silent-orphan watchdog(기본 120초)이 장시간 무출력 compact를 끊어버립니다. 컨텍스트가 큰 세션의 `/compact`는 direct CLI resume으로 돌리고, 끝나면 `aoe acp restart`로 재접속하세요.
- **structured 화신에서 장시간 블로킹 도구 금지**: 오케스트레이터 자신이 aoe structured 세션이라면, 턴을 오래 점유하는 백그라운드 감시 도구가 어댑터의 턴 완료 신호를 막아 orphan을 유발할 수 있습니다. 짧은 폴링 + cron으로 대체.
- **감시기 첫 기동 시 베이스라인**: 상태 파일이 없으면 DB의 max(rowid)를 베이스라인으로 — 과거 이벤트 일괄 재방출을 막습니다 (스크립트에 반영돼 있음).
- **데몬 재시작은 함대 유휴 때만**: ACP 워커는 serve 재시작에서 생존하지만, 턴 진행 중인 워커는 그 턴이 orphan될 수 있습니다.
- **두 HQ 상호평가(티키타카)**: 오케스트레이터 외에 standby 세션을 하나 두고 서로의 스킬/인프라를 평가시키면 빠르게 수렴합니다. 단 "90점+ 또는 잔가지만 남으면 종료" 같은 수렴 캡을 반드시 거세요 — 안 그러면 서로 칭찬하며 토큰을 태웁니다.

## 크레딧

- 오케스트레이션 패턴 원형: [steipete/agent-scripts](https://github.com/steipete/agent-scripts)의 maintainer-orchestrator
- 세션 매니저: [njbrake/agent-of-empires](https://github.com/njbrake/agent-of-empires)

## License

MIT
