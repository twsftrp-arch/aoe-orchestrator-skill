# Local Profile (example)

> **이 파일은 예시 템플릿이다.** 복사해서 자기 환경 값으로 채운 뒤 운영자 로컬에만 둔다 —
> 공개 repo에 실제 세션 ID·계정·내부 경로를 커밋하지 말 것.
> `SKILL.md`는 일반 규칙(어디서나 같음), 이 파일은 그 규칙에 대입하는 **로컬 상수**(사람마다 다름)다.
>
> 권장 위치: `~/.agent-of-empires/orchestrator/local-profile.md` (mutable state 쪽). skill 폴더에 두지 않는다.

## 디렉터리 경계 (헷갈림 방지)

| 위치 | 성격 | 들어가는 것 |
|---|---|---|
| `~/.claude/skills/aoe-orchestrator/` (또는 에이전트별 skill 경로) | **instruction / reference** (대체로 불변) | `SKILL.md`, `references/*` |
| `~/.agent-of-empires/orchestrator/` | **mutable state / events / queue** | `ORCHESTRATOR-STATE.md`(정본), `report-queue.md`, `events.log`, `state/`, `local-profile.md` |

원칙: 교대·업데이트 때 skill 폴더는 갈아끼워도 되지만 orchestrator 디렉터리는 보존한다.
상태의 정본은 항상 orchestrator 디렉터리 쪽이다.

## HQ 배정 (역할 → 실제 세션)

활성 오케스트레이터는 **항상 1개**. 현재 누가 활성인지의 정본은 `ORCHESTRATOR-STATE.md` / `report-queue.md`.

| 역할 | 모델 / 런타임 | aoe 세션 ID | 비고 |
|---|---|---|---|
| 장맥락 HQ (활성 후보) | `<예: 대형 컨텍스트 모델>` | `<hex>` | 1M급 분석·리팩토링 담당 |
| 정비공 HQ | `<예: 코드 에이전트>` | `<hex>` | 인프라·데몬·설정 |
| standby HQ #1 | `<다른 런타임>` | `<hex>` | 이중화 (이중 중계 금지) |
| standby HQ #2 | `<…>` | `<hex>` | |

전환 절차·스크립트 경로는 운영자가 직접 채운다(예: `aoe-hq-switch.sh`).

## 워커 런타임 / 컨텍스트

- 기본 워커 런타임: `<예: codex-acp / claude-agent / gemini-acp>`
- 모델·권한 설정 위치: `<예: 런타임의 글로벌 config 파일>`
- 워커 실효 컨텍스트 상한: `<예: 서버 강제 NNNK>` — 이 값보다 큰 슬라이스는 **장맥락 HQ로 라우팅**
- 동시 워커 슬롯: aoe `config.toml` `[acp] max_concurrent_workers = <N>` (워커 수보다 크게)

## 권한 위임 수준 (운영자가 정한다)

- 워커 git commit/push: `<위임 | 매번 운영자 승인>`
- **위임 밖 (항상 운영자 승인)**: 프로덕션 배포를 트리거하는 push, force-push, 브랜치 정책 변경,
  공개 repo 신규 공개, 스키마·인증·결제·공개 API·의존성·배포 설정·프로덕션 데이터,
  외부·최종 사용자 노출.

## 시스템 라벨 / 경로

- watcher launchd 라벨: `<예: com.example.aoe-watch>`
- watcher 스크립트: `~/.agent-of-empires/orchestrator/aoe-watch.py`
- 헬스체크: `~/.agent-of-empires/orchestrator/aoe-doctor.sh`
- compact / restart / orphan 복구 레시피: `references/recovery.md` + 운영자 로컬 메모(`<경로>`)
