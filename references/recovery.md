# Recovery

워커·오케스트레이터·데몬이 꼬였을 때 복구 절차. (구체 라벨·경로는 운영자 `local-profile.md` 참조; 예시 틀은 repo의 `templates/local-profile.example.md`.)

## 워커 wedge → restart

- 증상: LONG_RUN인데 `aoe acp status <ID>`의 highest_seq가 안 늘고 정지.
- 처치: history tail로 마지막 이벤트 확인 → 운영자에게 증거+선택지(인터럽트 / `aoe acp restart <ID>` / 대기).
  **인터럽트는 운영자 게이트**(파괴적 동작 진행 중일 때만 예외).
- ⚠️ **restart 직후 바로 prompt 주입 금지** — reconciler 재스폰이 끝나기 전 주입하면 그 턴이
  orphan/restart_pending으로 죽는다. attached 확인 후 30초+ 기다렸다 주입.

## orphan (데몬 재시작 부수효과)

- `STOPPED_orphaned_at_restart`는 serve 재시작의 부수효과. 보통 재접속으로 생존 — 재접속 확인.
- 반복되면 보고. **데몬 재시작은 함대 유휴 때만**(턴 진행 중이면 그 턴만 orphan 위험).

## 대형 compact가 "Request was aborted"로 실패

- 원인: aoe의 silent-orphan watchdog(기본 grace 120초)이 무진행 구간을 끊은 것.
- 처치: **aoe UI 밖에서** — 해당 CLI로 세션을 직접 resume해 `/compact` →
  `aoe acp restart <ID>`로 재접속. (정확한 레시피는 운영자 로컬 복구 메모.)

## 감시기 / 데몬 설정 반영

- `[acp]` 설정(silent_orphan_grace_secs 등)은 **데몬 기동 시에만 로드**.
  config 수정 후 `aoe serve --stop` → 풀 플래그 신규 기동(`--restart`는 데몬을 안 갈아끼움).
- 워커가 추가로 안 붙으면 `[acp] max_concurrent_workers` 슬롯 부족 — config에서 증설.

## 첫 진단 한 방

- `aoe-doctor.sh` — serve·watcher·워커수·DB 신선도·큐/STATE를 일괄 점검(읽기 전용).
  교대 직후·이상 의심 시 첫 명령.
