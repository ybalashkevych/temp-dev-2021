# Automation Scripts

Background daemon that monitors GitHub PRs and invokes Cursor agent to respond to feedback.

## Architecture

```
daemon.sh → Monitors PRs (polls every 60s)
    ↓
Detects feedback → Builds context
    ↓
invoke-cursor-agent.sh → Invokes Cursor
    ↓
Agent processes → Makes changes, tests, commits
    ↓
Posts response to PR
```

## Components

**daemon.sh** - Main monitoring daemon, detects PRs with `awaiting-cursor-response` label  
**state.sh** - Tracks processed comments, thread mappings  
**thread.sh** - Manages conversation threads, builds context  
**agent.sh** - Invokes Cursor agent (mock or real mode)  
**invoke-cursor-agent.sh** - Cursor invocation helper (3 methods)  
**common.sh** - Shared logging utilities  
**test-automation.sh** - Test suite (10 tests)

## Usage

```bash
# Start daemon
./scripts/daemon-control.sh start

# Stop daemon
./scripts/daemon-control.sh stop

# Run tests
./scripts/automation/test-automation.sh

# Real Cursor mode (default)
./scripts/daemon-control.sh start

# Mock mode (for testing)
MOCK_AGENT=1 ./scripts/daemon-control.sh start
```

## How It Works

1. **Monitoring**: Daemon polls GitHub for PRs labeled `awaiting-cursor-response`
2. **Detection**: Finds unprocessed comments (PR-level, inline reviews)
3. **Guards**: Adds 👀 reaction to prevent duplicate processing
4. **Thread**: Creates/continues conversation thread with full context
5. **Invocation**: Calls Cursor agent with instructions + context
6. **Agent**: Makes changes, runs build/test loop (up to 10 attempts), commits
7. **Response**: Posts result to PR, adds 🤖 + ✅/❌ reactions

## Agent Modes

**ask** - Default mode, analyzes feedback and asks questions (no code changes)  
**plan** - Creates implementation plan (triggered by `@ybalashkevych plan`)  
**implement** - Makes changes, tests, commits (triggered by `@ybalashkevych implement` or `@ybalashkevych fix`)

## Retry Logic

Agent performs up to 10 attempts:
- Run build → If fails: analyze error, fix code, try again
- Run tests → If fails: analyze failures, fix code, try again
- Logs all attempts in `retry.log`
- Creates detailed failure report if exhausted

## Infinite Loop Prevention

Uses GitHub reactions:
- 👀 = Processing (prevents duplicate)
- 🤖 = Agent responded
- ✅ = Success
- ❌ = Failure

Works with same Git account (@ybalashkevych for both user and agent).

## State Files

All in `logs/` (gitignored):
- `automation-state.json` - Processed comments, thread registry
- `pr-{N}-thread-{T}.json` - Thread conversation history
- `.agent-work-{T}/` - Agent work directory with instructions, logs
- `pr-{N}-monitor.log` - Monitoring logs
- `comments/pr-{N}-{ID}.txt` - Comment bodies cache (persisted for debugging)

## Cursor Invocation

Three fallback methods:
1. `cursor composer instructions.md` - Composer mode
2. `cursor agent --file instructions.md` - Agent mode
3. Manual mode - Opens instructions in Cursor

## Logs

```bash
logs/cursor-daemon.log              # Main daemon log
logs/pr-{N}-monitor.log             # Per-PR monitoring
logs/pr-{N}-agent-{T}.log           # Agent invocations
logs/.agent-work-{T}/retry.log      # Build/test attempts
```

## Configuration

Edit `daemon.sh`:
```bash
REPO_OWNER="ybalashkevych"
REPO_NAME="temp-dev-2021"
POLL_INTERVAL=60  # seconds
```

Environment variables:
```bash
MOCK_AGENT=1         # Enable mock mode (no real Cursor invocation)
CURSOR_MODEL=...     # Override Cursor model (default: claude-4.5-sonnet)
DEBUG=1              # Enable debug logging
```

Note: Work directories are always preserved in `logs/.agent-work-*/` for debugging.

## Troubleshooting

**Daemon not starting**: Check `gh auth status`  
**Comments not detected**: Verify PR has `awaiting-cursor-response` label  
**Duplicate processing**: Check reactions on comments  
**Agent failures**: Review `logs/.agent-work-*/retry.log`  

Enable debug: `DEBUG=1 ./scripts/daemon-control.sh restart`
