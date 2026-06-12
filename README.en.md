[한국어](README.md) | **English**

# aoe-orchestrator-skill

A workflow guide + orchestration skill + monitoring infrastructure for running a "fleet" of AI coding agents as a single person.

**The full workflow** = [agent-of-empires (aoe)](https://github.com/njbrake/agent-of-empires) + multiple subscriptions (Claude / Codex / Gemini / Cursor…) + structured view + tailscale for mobile control. The rationale lives in [docs/WORKFLOW.md](docs/WORKFLOW.md) and the step-by-step adoption path in [docs/SETUP.md](docs/SETUP.md) — **both currently in Korean**; the summaries below cover the essentials.

The code part of this repo is the orchestration layer: operating rules (SKILL.md, a Claude Code skill) plus scripts that make **one orchestrator session monitor and relay for all worker sessions**, adapted from [steipete's maintainer-orchestrator](https://github.com/steipete/agent-scripts) pattern for a personal multi-subscription setup.

## Who this is for

- People running **two or more** AI coding subscriptions (Claude / ChatGPT+Codex / …)
- People running (or wanting to run) 5+ concurrent agent sessions in a terminal on macOS
- People drowning in "which session finished? which one is stuck? too many reports"

If you run 1–2 sessions, this is overkill — read steipete's original repo for the concepts instead.

## What's inside

```
docs/WORKFLOW.md              The full stack — why multiple subscriptions,
                              strength-based routing, daily rhythm, cost intuition (Korean)
docs/SETUP.md                 0→1 adoption in 5 standalone steps (Korean)
SKILL.md                      Orchestrator operating rules (Claude Code skill, Korean)
scripts/aoe-watch.py          Event watcher — polls aoe's ACP event DB and logs
                              TURN_DONE / STOPPED / ERROR / LONG_RUN to events.log
scripts/aoe-doctor.sh         1-minute health check — daemon, watcher, worker count,
                              DB freshness, queue consistency; FAIL lines include the fix
launchd/com.example.aoe-watch.plist   launchd registration example
templates/                    Handoff doc + report queue blanks
```

## Core operating rules (SKILL.md digest)

1. **The orchestrator never implements** — it watches, classifies, relays, reports. Workers implement.
2. **No judgment before reading** — never produce a message before reading the event log, session list, and queue.
3. **Report queue: one open decision in front of the human at a time** — everything else waits in the queue file.
4. **Decision readiness** — never ask the human to choose from an unfinished state. Evidence (tests, live runs) + tradeoffs + exact options first.
5. **Documented-gate idle rule** — an idle worker is fine if *why it's idle* is written down (waiting on human-only work, on hold, done). Only undocumented idleness gets new work assigned.
6. **Minimal intervention** — a working session with a coherent plan is left alone. Intervene only on blockers, exhaustion, repeated failure, or dangerous actions.
7. **No sub-delegation** — workers never spawn workers. Session creation/assignment goes through the orchestrator (i.e., the human).

## Install (short version)

Prereqs: macOS, [aoe](https://github.com/njbrake/agent-of-empires) 1.11+ (structured/ACP workers), Claude Code or Codex CLI.

```bash
git clone https://github.com/twsftrp-arch/aoe-orchestrator-skill
cd aoe-orchestrator-skill

# 1. the skill (Claude Code)
mkdir -p ~/.claude/skills/aoe-orchestrator
cp SKILL.md templates/ORCHESTRATOR-STATE.md ~/.claude/skills/aoe-orchestrator/

# 2. watcher + doctor
mkdir -p ~/.agent-of-empires/orchestrator
cp scripts/aoe-watch.py scripts/aoe-doctor.sh ~/.agent-of-empires/orchestrator/
chmod +x ~/.agent-of-empires/orchestrator/aoe-doctor.sh
cp templates/report-queue.md ~/.agent-of-empires/orchestrator/

# 3. register the watcher with launchd
sed "s/YOUR_USERNAME/$(whoami)/g" launchd/com.example.aoe-watch.plist \
  > ~/Library/LaunchAgents/com.example.aoe-watch.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.aoe-watch.plist

# 4. verify
~/.agent-of-empires/orchestrator/aoe-doctor.sh
```

Give your orchestrator session a title containing `(HQ)` — the watcher excludes HQ sessions from notifications. Then tell it: *"Orchestrator mode. Read SKILL.md and do one patrol of the fleet."*

## Lessons hard-coded into this repo

- **Run large-context compactions outside the aoe UI**: aoe's silent-orphan watchdog (120s default) kills long no-output compactions. Resume the session with the agent CLI directly, compact there, then `aoe acp restart <ID>`.
- **No long-blocking background tools inside a structured incarnation**: if your orchestrator itself runs as an aoe structured session, a tool that occupies the turn blocks the adapter's turn-complete signal and orphans the worker. Use short polls + cron.
- **Baseline on first watcher start**: with no state file, start from max(rowid) — prevents replaying the entire event history (already implemented here).
- **Restart daemons only when the fleet is idle**: ACP workers survive a serve restart, but in-flight turns can be orphaned.
- **Two-HQ mutual review ("tiki-taka")**: keep a standby HQ and have the two evaluate each other's skill/infra — it converges fast, but set a convergence cap ("stop at 90+ or nits-only") or they'll burn tokens praising each other.

## Credits

- Orchestration pattern: [steipete/agent-scripts](https://github.com/steipete/agent-scripts) (maintainer-orchestrator)
- Session manager: [njbrake/agent-of-empires](https://github.com/njbrake/agent-of-empires)

## License

MIT
