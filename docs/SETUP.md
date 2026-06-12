# 0 → 1 따라하기

전제: macOS, 터미널 사용 가능, AI 코딩 에이전트 구독 1개 이상 (Claude Code 또는 Codex CLI — 둘 다면 더 좋음).

핵심: **한 번에 다 만들지 마세요.** 각 단계가 그 자체로 쓸모 있고, 다음 단계는 전 단계가 답답해질 때 올리면 됩니다.

## 1단계 — aoe + 세션 2개 (10분)

```bash
# aoe 설치 (https://github.com/njbrake/agent-of-empires 참조)
brew install njbrake/tap/agent-of-empires   # 또는 cargo install agent-of-empires

# 프로젝트 두 개를 세션으로
cd ~/work/project-a && aoe add --title project-a --tool claude --structured-view
cd ~/work/project-b && aoe add --title project-b --tool codex --structured-view
aoe   # TUI 대시보드
```

이 단계의 가치: 세션이 죽지 않고, 한 화면에서 전환됩니다. 워커가 4개 이하면 여기서 멈춰도 충분합니다.

## 2단계 — 오케스트레이터(HQ) 세션 (15분)

워커가 5개를 넘어 "어디가 끝났지?"를 자주 묻게 되면:

```bash
# 이 레포 클론
git clone https://github.com/twsftrp-arch/aoe-orchestrator-skill
cd aoe-orchestrator-skill

# 스킬 설치 (Claude Code 기준)
mkdir -p ~/.claude/skills/aoe-orchestrator
cp SKILL.md ~/.claude/skills/aoe-orchestrator/
cp templates/ORCHESTRATOR-STATE.md ~/.claude/skills/aoe-orchestrator/
mkdir -p ~/.agent-of-empires/orchestrator
cp templates/report-queue.md ~/.agent-of-empires/orchestrator/

# HQ 세션 생성 — 타이틀에 (HQ) 필수 (감시기가 알림에서 제외하는 표식)
cd ~ && aoe add --title "Claude(HQ)" --tool claude --structured-view
```

HQ 세션에 첫 지시:

> 오케스트레이터 모드. ~/.claude/skills/aoe-orchestrator/SKILL.md 읽고, 함대 순찰 한 바퀴 돌고 보고해.

이 단계의 가치: 워커 상태 파악이 "내가 8개 창을 돌며 읽기"에서 "HQ에게 순찰 시키기"로 바뀝니다.

## 3단계 — 이벤트 감시기 + 헬스체크 (15분)

HQ가 매번 전 세션을 읽는 대신, 변화가 있는 세션만 보게 만듭니다:

```bash
cp scripts/aoe-watch.py scripts/aoe-doctor.sh ~/.agent-of-empires/orchestrator/
chmod +x ~/.agent-of-empires/orchestrator/aoe-doctor.sh

# launchd 등록 (로그인 시 자동 시작, 죽으면 재기동)
sed "s/YOUR_USERNAME/$(whoami)/g" launchd/com.example.aoe-watch.plist \
  > ~/Library/LaunchAgents/com.example.aoe-watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.aoe-watch.plist

# 확인 — 전 항목 OK가 나와야 함
~/.agent-of-empires/orchestrator/aoe-doctor.sh
```

HQ에게는 "매 턴 시작 시 `tail ~/.agent-of-empires/orchestrator/events.log` 신규분 확인 + 30분마다 순찰"을 시키면 됩니다 (SKILL.md에 이미 규칙으로 들어 있음).

## 4단계 — 모바일 관제 (tailscale, 20분)

외출 중에도 함대를 보고 싶어지면:

```bash
# tailscale 설치 + 로그인 (App Store 또는 https://tailscale.com)
# aoe 웹 대시보드를 로컬에만 띄우고
aoe serve   # 인증 옵션은 aoe 문서 참조 — 반드시 인증을 켜세요

# tailnet 안에서만 접근 가능한 HTTPS로 노출
tailscale serve --bg 8080
tailscale serve status   # 접속 URL 확인
```

폰에 tailscale 앱을 깔면 그 URL로 어디서든 대시보드에 들어옵니다. **공인 포트포워딩·외부 터널은 쓰지 마세요** — 에이전트 세션은 곧 쉘 접근입니다.

선택: `aoe serve`가 죽으면 살리는 launchd watchdog을 하나 두면 무인 운영이 됩니다 (3단계 plist를 본떠 작성).

## 5단계 — 구독 추가 = 워커 확장

- 두 번째 구독이 생기면 워커를 나눠 깝니다 (예: HQ는 Claude, 대량 워커는 Codex). 이유는 [WORKFLOW.md](WORKFLOW.md)의 강점 라우팅 표 참조.
- `~/.agent-of-empires/config.toml`의 `[acp] max_concurrent_workers`가 워커 수보다 크게 잡혀 있는지 확인하세요 (기본값이 작으면 슬롯 부족으로 세션이 안 붙습니다).
- 한 구독의 한도가 막히면: 워커에게 인수인계 문서(레포의 docs/SESSION-HANDOFF.md 등)를 쓰게 한 뒤, 다른 런타임 세션이 그 문서를 읽고 이어받게 합니다.

## 트러블슈팅 (우리가 실제로 겪은 것)

| 증상 | 원인/처방 |
|---|---|
| 감시기 첫 기동에 과거 이벤트가 쏟아짐 | 이 레포 스크립트엔 베이스라인 처리가 있어 발생 안 함. 직접 짠 감시기라면 첫 기동 시 max(rowid)를 베이스라인으로 |
| 큰 세션의 `/compact`가 "Request was aborted"로 실패 | aoe의 silent-orphan watchdog(기본 120초)이 끊은 것. 해당 CLI로 세션을 직접 resume해 compact 후 `aoe acp restart <ID>` |
| HQ가 백그라운드 감시 도구를 켜자 워커가 orphan됨 | structured 화신에서 턴을 점유하는 블로킹 도구 금지 — 짧은 폴링+cron으로 |
| serve 재시작 후 일부 워커 턴이 orphan | 데몬 재시작은 함대 유휴 때만. 워커 자체는 재접속으로 생존 |
| 워커가 추가로 안 붙음 | `max_concurrent_workers` 슬롯 부족 — config에서 증설 |

## 흔한 질문

**Q. 구독 1개로도 되나?** 됩니다. 2단계까지가 구독 1개 기준이고, 패턴(보고 큐, decision readiness)은 동일하게 작동합니다.

**Q. Linux는?** aoe는 돌지만 이 레포의 launchd 부분은 systemd user unit으로 바꿔야 합니다 (스크립트 자체는 그대로 동작).

**Q. 워커가 멋대로 커밋/배포하지 않게 하려면?** SKILL.md의 권한 티어 절을 자기 기준으로 고치고, 워커들의 글로벌 설정(CLAUDE.md / AGENTS.md)에도 같은 계약을 넣으세요. 문서 계약이 전부입니다 — 기술적 강제가 아니므로, 파괴적 권한(프로덕션 접근 등)은 애초에 워커 환경에 주지 않는 게 원칙입니다.
