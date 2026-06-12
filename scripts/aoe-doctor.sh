#!/bin/bash
# aoe-doctor — 오케스트레이터 1분 점검. 교대/재무장/이상감지 시 첫 명령.
# 출력만 한다(읽기 전용). 각 항목: OK / WARN / FAIL.
H=$HOME/.agent-of-empires
ORC=$H/orchestrator
SKILL_DIR=${AOE_SKILL_DIR:-$HOME/.claude/skills/aoe-orchestrator}
ok(){ echo "  OK   $1"; }; warn(){ echo "  WARN $1"; }; fail(){ echo "  FAIL $1"; }

echo "== aoe doctor $(date '+%F %T') =="

# 1. serve 데몬
if url=$(aoe url 2>/dev/null) && [ -n "$url" ]; then ok "serve 데몬: $url"
else fail "serve 데몬 응답 없음 — aoe serve 기동 또는 watchdog 확인"; fi

# 2. watcher (launchd + 최근 이벤트)
wpid=$(pgrep -f 'aoe-watch.*\.py' | head -1)
if [ -n "$wpid" ]; then ok "watcher 가동 (pid $wpid)"
else fail "watcher 죽음 — launchctl kickstart -k gui/\$(id -u)/<watcher 라벨>"; fi
last_ev=$(tail -1 "$ORC/events.log" 2>/dev/null)
[ -n "$last_ev" ] && echo "       마지막 이벤트: $last_ev"

# 3. ACP 워커 수 vs sessions.json vs 슬롯 한도
att=$(aoe acp ps 2>/dev/null | grep -c attached)
tot=$(python3 -c "import json;d=json.load(open('$H/profiles/main/sessions.json'));print(len(d) if isinstance(d,list) else len(d.get('sessions',[])))" 2>/dev/null)
cap=$(grep -E '^max_concurrent_workers' "$H/config.toml" 2>/dev/null | grep -o '[0-9]*')
if [ -n "$tot" ] && [ "$att" = "$tot" ]; then ok "워커 attached $att/$tot (슬롯 한도 ${cap:-?})"
else warn "워커 attached $att / 세션 ${tot:-?} — 차이 확인: aoe acp ps (슬롯 한도 ${cap:-?})"; fi

# 4. 이벤트 DB 신선도
age=$(sqlite3 "file:$H/acp_events.db?mode=ro" "SELECT CAST(strftime('%s','now') AS INT)-MAX(created_at)/1000 FROM acp_events" 2>/dev/null)
if [ -n "$age" ] && [ "$age" -lt 86400 ]; then ok "events DB 마지막 이벤트 ${age}초 전"
elif [ -n "$age" ]; then warn "events DB 마지막 이벤트 ${age}초 전 (하루 이상 정적)"
else fail "events DB 조회 실패"; fi

# 5. 큐/STATE 정합 (열린 결정 + 신선도)
if [ -f "$ORC/report-queue.md" ]; then
  open=$(sed -n '/^## 열린 결정/,/^## /p' "$ORC/report-queue.md" | grep -cv '^#\|^(\|^$')
  qage=$(( ($(date +%s) - $(stat -f %m "$ORC/report-queue.md")) / 3600 ))
  msg="열린 결정 ${open}건 | 큐 갱신 ${qage}h 전"
  if [ -f "$SKILL_DIR/ORCHESTRATOR-STATE.md" ]; then
    sage=$(( ($(date +%s) - $(stat -f %m "$SKILL_DIR/ORCHESTRATOR-STATE.md")) / 3600 ))
    msg="$msg, STATE 갱신 ${sage}h 전"
    [ "$sage" -gt 48 ] && warn "STATE가 48h 이상 미갱신 — 인수인계 가치 저하"
  fi
  ok "$msg"
else warn "report-queue.md 없음 — templates/에서 복사"; fi

# 6. watcher state 파일 무결성
sf=$(ls "$ORC"/state/*.json 2>/dev/null | head -1)
if [ -n "$sf" ]; then
  python3 -c "import json;json.load(open('$sf'))" 2>/dev/null \
    && ok "watcher state JSON 정상" || fail "watcher state JSON 손상 — 삭제 후 watcher 재시작(베이스라인 자동 재설정)"
else warn "watcher state 파일 없음 (첫 기동 전이면 정상)"; fi

echo "== 끝 =="
