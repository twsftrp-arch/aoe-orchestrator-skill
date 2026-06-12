#!/usr/bin/env python3
"""aoe 함대 감시기 — aoe의 ACP 이벤트 DB를 폴링해 워커 이벤트를 events.log에 기록.

기록 이벤트: TURN_DONE(턴 정상 완료) / STOPPED_<사유> / ERROR / LONG_RUN(장시간 턴, 반복 알림).
타이틀에 '(HQ)'가 포함된 세션(오케스트레이터)은 제외.
오케스트레이터는 이 로그를 tail해서 변화가 있는 워커만 들여다보면 된다.
"""
import sqlite3, json, time, os

HOME = os.path.expanduser('~')
DB = f'{HOME}/.agent-of-empires/acp_events.db'
SESS = f'{HOME}/.agent-of-empires/profiles/main/sessions.json'
LOG = f'{HOME}/.agent-of-empires/orchestrator/events.log'
STATE = f'{HOME}/.agent-of-empires/orchestrator/state/watch.json'
LONG_RUN = int(os.environ.get('AOE_WATCH_LONG_RUN', '1200'))  # 초; 이 간격마다 LONG_RUN 재알림
POLL = 20

os.makedirs(os.path.dirname(STATE), exist_ok=True)

def titles():
    try:
        d = json.load(open(SESS)); items = d if isinstance(d, list) else d.get('sessions')
        return {e['id']: e.get('title', '?') for e in (items if isinstance(items, list) else items.values()) if isinstance(e, dict)}
    except Exception:
        return {}

def emit(kind, sid, title, detail=''):
    with open(LOG, 'a') as f:
        f.write(f"{time.strftime('%F %T')} | {kind} | {title}({sid[:8]}) | {detail}\n")

st = {'rowid': 0, 'turns': {}, 'alerted': {}}
try: st.update(json.load(open(STATE)))
except Exception: pass
if not st['rowid']:
    # 상태 파일 없는 첫 기동: 과거 이벤트 재방출 방지 — 현재 max(rowid)를 베이스라인으로
    try:
        con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True)
        st['rowid'] = con.execute('SELECT COALESCE(MAX(rowid),0) FROM acp_events').fetchone()[0]
        con.close()
    except Exception: pass
emit('START', 'watch', 'watcher', f"acp-db poll {POLL}s, baseline rowid={st['rowid']}")

while True:
    try:
        tmap = titles()
        con = sqlite3.connect(f'file:{DB}?mode=ro', uri=True); con.execute('PRAGMA busy_timeout=3000')
        rows = con.execute('SELECT rowid,session_id,event_json FROM acp_events WHERE rowid>? ORDER BY rowid', (st['rowid'],)).fetchall()
        con.close()
        for rid, sid, ej in rows:
            st['rowid'] = rid
            t = tmap.get(sid, sid[:8])
            if '(HQ)' in t: continue
            try: ev = json.loads(ej)
            except Exception: continue
            if 'UserPromptSent' in ev:
                st['turns'][sid] = time.time(); st['alerted'][sid] = 0
            elif 'Stopped' in ev:
                r = (ev['Stopped'] or {}).get('reason', '?')
                st['turns'].pop(sid, None)
                emit('TURN_DONE' if r == 'prompt_complete' else f'STOPPED_{r}', sid, t)
            elif 'SessionError' in ev or '"Error"' in ej:
                emit('ERROR', sid, t, ej[:120])
        now = time.time()
        for sid, t0 in list(st['turns'].items()):
            dur = now - t0; a = st['alerted'].get(sid, 0)
            if dur >= (a + 1) * LONG_RUN:
                emit('LONG_RUN', sid, tmap.get(sid, sid[:8]), f'{int(dur)}s')
                st['alerted'][sid] = a + 1
        json.dump(st, open(STATE + '.tmp', 'w')); os.replace(STATE + '.tmp', STATE)
    except Exception as e:
        with open(LOG, 'a') as f: f.write(f"{time.strftime('%F %T')} | WATCHER_ERR | watch | {e}\n")
    time.sleep(POLL)
