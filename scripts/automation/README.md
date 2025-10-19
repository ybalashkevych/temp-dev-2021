# Automation Scripts

This directory contains the cursor automation daemon and supporting utilities for monitoring and responding to PR feedback.

## Overview

The automation system monitors GitHub PRs for feedback and automatically invokes the cursor agent to respond. It prevents infinite loops using reaction-based guards and maintains conversation context across multiple interactions.

## Architecture

```
┌─────────────┐
│  daemon.sh  │  ← Main monitoring loop
└──────┬──────┘
       │
       ├─► state.sh   ← Track processed comments & threads
       ├─► thread.sh  ← Manage conversation threads
       └─► agent.sh   ← Invoke cursor agent
```

## Scripts

### daemon.sh
Main monitoring daemon that:
- Polls GitHub for PRs with `awaiting-cursor-response` label
- Detects unprocessed feedback (PR comments, inline reviews)
- Uses reaction guards (👀 processing, 🤖 responded)
- Invokes agent with full context
- Posts responses back to PR

**Usage:**
```bash
# Start daemon (via control script)
./scripts/daemon-control.sh start

# Stop daemon
./scripts/daemon-control.sh stop

# Check status
./scripts/daemon-control.sh status

# Restart
./scripts/daemon-control.sh restart
```

**Environment:**
- `DEBUG=1` - Enable debug logging
- `MOCK_AGENT=1` - Use mock agent (default for testing)
- `MOCK_AGENT=0` - Use real cursor agent

### state.sh
State management utilities:
- `init_state()` - Initialize state file
- `is_comment_processed()` - Check if comment already processed
- `mark_comment_processed()` - Mark comment as processed
- `get_thread_for_comment()` - Get thread ID for comment
- `register_thread()` - Create new thread
- `update_thread_status()` - Update thread status (active/completed/failed)
- `get_active_threads()` - List active threads for PR

### thread.sh
Thread conversation management:
- `get_or_create_thread()` - Get existing or create new thread
- `add_to_thread()` - Add message to thread
- `build_agent_context()` - Build full context for agent
- `get_thread_status()` - Get thread status
- `set_thread_status()` - Update thread status
- `get_message_count()` - Get message count
- `list_pr_threads()` - List all threads for PR

### agent.sh
Cursor agent invocation:
- `invoke_agent()` - Main entry point (mock or real)
- `invoke_agent_mock()` - Mock agent for testing
- `invoke_agent_real()` - Real cursor invocation (TODO)
- `update_pr_description()` - Update PR with changes summary

## Workflow

### 1. Detection
Daemon polls every 60 seconds for PRs with `awaiting-cursor-response` label.

### 2. Comment Processing
For each unprocessed comment:
1. Add 👀 reaction (prevents duplicate processing)
2. Get or create thread for comment
3. Add feedback to thread context
4. Build full context (PR metadata + thread history)
5. Invoke agent with context

### 3. Agent Modes
- **ask** (default) - Analyze feedback, ask clarifying questions
- **plan** - Create implementation plan (triggered by `@ybalashkevych plan`)
- **implement** - Make changes, test, commit, push (triggered by `@ybalashkevych implement` or `@ybalashkevych fix`)

### 4. Response Posting
After agent completes:
1. Add agent response to thread
2. Post formatted comment to PR
3. Add 🤖 reaction (marks as responded)
4. Add ✅/❌ reaction (success/failure)

### 5. Commit Convention
When agent commits:
```
type(scope): subject

Addresses feedback in PR #<number> thread <thread-id>
```

Examples:
- `feat(transcription): add speaker identification`
- `fix(audio): resolve buffer overflow issue`

## Infinite Loop Prevention

### Reaction-Based Guards
- **👀 (eyes)** - Comment is being processed
- **🤖 (robot)** - Agent has responded
- Skip comments with BOTH reactions

### Resolved Conversations
- Skip all comments in resolved conversation threads
- Logged for visibility

### Same Account Limitation
Currently, user and cursor agent share the same Git account (@ybalashkevych). The daemon uses reactions to prevent responding to its own comments.

**Future:** Separate computer/account for cursor agent to simplify logic.

## State Files

All state files stored in `logs/` (gitignored):

- `automation-state.json` - Global state (processed comments, threads)
- `pr-{number}-thread-{timestamp}.json` - Thread conversation history
- `pr-{number}-monitor.log` - Per-PR monitoring logs
- `pr-{number}-agent-{thread-id}.log` - Agent invocation logs
- `pr-{number}-agent-mock-{thread-id}.log` - Mock agent logs

## Testing

### Mock Mode (Default)
```bash
MOCK_AGENT=1 ./scripts/automation/daemon.sh
```

Mock agent:
- Logs what would be sent to real agent
- Returns simulated responses
- Useful for testing detection, parsing, threading

### Real Mode
```bash
MOCK_AGENT=0 ./scripts/automation/daemon.sh
```

⚠️ **Note:** Real cursor invocation not yet implemented. Currently placeholder only.

## Configuration

Edit `daemon.sh` to change:
- `POLL_INTERVAL=60` - Polling interval (seconds)
- `REPO_OWNER` - GitHub repository owner
- `REPO_NAME` - GitHub repository name

## Logs

Monitor daemon activity:
```bash
# Main daemon log
tail -f logs/cursor-daemon.log

# Error log
tail -f logs/cursor-daemon.error.log

# Per-PR monitoring
tail -f logs/pr-5-monitor.log

# Agent invocations
tail -f logs/pr-5-agent-mock-pr-5-thread-*.log
```

## Troubleshooting

### Daemon won't start
- Check GitHub CLI: `gh auth status`
- Verify scripts are executable: `chmod +x scripts/automation/*.sh`
- Check logs: `cat logs/cursor-daemon.error.log`

### Comments not detected
- Verify PR has `awaiting-cursor-response` label
- Check comment doesn't have both 👀 and 🤖 reactions
- Enable debug: `DEBUG=1 ./scripts/daemon-control.sh restart`
- Check monitor log: `logs/pr-{number}-monitor.log`

### Duplicate processing
- Verify reaction guards are working
- Check `logs/automation-state.json` for processed comments
- Restart daemon: `./scripts/daemon-control.sh restart`

### Thread not found
- Check thread file exists: `ls logs/pr-*-thread-*.json`
- Verify thread registered in state: `cat logs/automation-state.json | jq .threads`

## Development

### Adding New Functionality

1. **New detection logic** → Edit `daemon.sh`, `get_pr_feedback()`
2. **New state tracking** → Edit `state.sh`
3. **New thread features** → Edit `thread.sh`
4. **New agent modes** → Edit `agent.sh`, `invoke_agent()`

### Testing Changes

1. Set `MOCK_AGENT=1`
2. Create test PR with feedback
3. Add `awaiting-cursor-response` label
4. Start daemon: `./scripts/daemon-control.sh start`
5. Monitor logs: `tail -f logs/cursor-daemon.log`
6. Verify reactions added correctly
7. Check thread files created
8. Review mock agent logs

## Future Enhancements

- [ ] Real cursor CLI integration
- [ ] Separate Git account for cursor agent
- [ ] Web dashboard for monitoring
- [ ] Metrics and analytics
- [ ] Multi-repository support
- [ ] Configurable polling strategies
- [ ] Advanced conversation threading (reply detection)
- [ ] Automatic PR description updates
- [ ] Build/test retry logic visualization

