# Automation Setup Guide

Guide for setting up the background automation system for PR monitoring and automated responses.

## Overview

The automation system enables Cursor to automatically:
- Monitor GitHub PRs for feedback
- Process PR comments and reviews
- Create comprehensive feedback files
- Post inline code comments
- Update PR labels and status

## Architecture

```
GitHub PR Comment
       ↓
GitHub Action detects comment
       ↓
Adds "needs-changes" label
       ↓
Background Daemon polls GitHub
       ↓
Processes PR (fetches details, comments, CI results)
       ↓
Creates .cursor-feedback.txt
       ↓
Cursor reads feedback & makes changes
       ↓
Runs self-review & pushes updates
       ↓
Posts response comment & updates labels
```

## Components

### 1. Background Daemon

**Script:** `scripts/cursor-daemon.sh`

Runs continuously, checking GitHub every 60 seconds for PRs with "needs-changes" label.

### 2. GitHub Actions

**Workflows:**
- `.github/workflows/pr-checks.yml` - CI checks (lint, build, test, coverage)
- `.github/workflows/pr-comment-monitor.yml` - Adds label when comments posted

### 3. Automation Scripts

- `cursor-pr.sh` - Multi-purpose PR tool (create, merge, process, respond)
- `cursor-quality.sh` - Quality checks and verification (review, verify, test)
- `setup.sh` - Setup and configuration (install, update)
- `post-inline-swiftlint-comments.py` - Posts inline code comments

## Installation

### Prerequisites

1. **GitHub CLI authenticated:**
   ```bash
   gh auth status
   ```

2. **Python 3 with requests library:**
   ```bash
   pip3 install requests
   ```

3. **jq for JSON parsing:**
   ```bash
   brew install jq
   ```

### Step 1: Make Scripts Executable

```bash
cd /Users/yurii/Desktop/Projects/LiveAssistant

chmod +x scripts/cursor-daemon.sh
chmod +x scripts/cursor-pr.sh
chmod +x scripts/cursor-quality.sh
chmod +x scripts/setup.sh
chmod +x scripts/post-inline-swiftlint-comments.py
```

### Step 2: Create Log Directory

```bash
mkdir -p logs
```

### Step 3: Test Scripts Manually

Before automating, verify scripts work:

```bash
# Test PR processing (replace 123 with actual PR number)
./scripts/cursor-pr.sh process 123

# Check if feedback file was created
cat .cursor-feedback.txt

# Test response script
./scripts/cursor-pr.sh respond 123 "Test message"
```

### Step 4: Choose Automation Method

You have two options:

#### Option A: Launch Daemon (Background Service) - Recommended

**Pros:**
- Runs automatically on startup
- Restarts if crashes
- Minimal manual intervention

**Cons:**
- More complex setup
- Requires correct file paths
- Can't access protected folders (Documents, Desktop)

#### Option B: Screen/Tmux Session - Simpler

**Pros:**
- Easy to start/stop
- Can see live output
- No path restrictions

**Cons:**
- Manual start required
- Stops when Mac sleeps
- Requires keeping terminal session

## Setup Option A: Launch Daemon

### 1. Create Launch Agent plist

```bash
# Copy template
cp scripts/com.liveassistant.cursor-monitor.plist.template \
   ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### 2. Edit Paths

Open the plist and update **YOUR_USERNAME** with your actual username:

```bash
nano ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

**Important:** Use absolute paths, no `~` or relative paths:
- ✅ `/Users/yourusername/Desktop/Projects/LiveAssistant`
- ❌ `~/Desktop/Projects/LiveAssistant`

**Paths to update:**
- `ProgramArguments` - Path to cursor-daemon.sh
- `WorkingDirectory` - Project root directory
- `StandardOutPath` - Log file path
- `StandardErrorPath` - Error log path

### 3. Verify Paths Exist

```bash
# Check script exists
ls -la /Users/yourusername/Desktop/Projects/LiveAssistant/scripts/cursor-daemon.sh

# Check log directory exists
ls -ld /Users/yourusername/Desktop/Projects/LiveAssistant/logs
```

### 4. Load Launch Agent

```bash
# Bootstrap (load and start)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Verify it's running
launchctl list | grep cursor-monitor

# Should show: -    PID    com.liveassistant.cursor-monitor
```

### 5. Check Logs

```bash
tail -f logs/cursor-daemon.log
```

Should see:
```
[2025-10-17 10:30:00] Cursor daemon started
[2025-10-17 10:30:00] Polling every 60 seconds...
```

### Launch Daemon Management

**Start:**
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

**Stop:**
```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

**Restart:**
```bash
launchctl kickstart -k gui/$(id -u)/com.liveassistant.cursor-monitor
```

**Check status:**
```bash
launchctl list | grep cursor-monitor
```

**View detailed info:**
```bash
launchctl print gui/$(id -u)/com.liveassistant.cursor-monitor
```

### Troubleshooting Launch Daemon

**"Input/output error":**
- Check paths in plist are absolute and correct
- Verify all paths exist
- Ensure script is executable

**Starts then immediately stops:**
- Check `logs/cursor-daemon.error.log`
- Verify GitHub CLI is authenticated
- Check for missing dependencies (jq)

**Can't access project in Documents/Desktop:**
- Move project to unrestricted location (`~/Projects/`)
- Or use screen/tmux method instead

## Setup Option B: Screen/Tmux Session

### Using screen (recommended)

```bash
cd /Users/yurii/Desktop/Projects/LiveAssistant

# Start in screen session
screen -S cursor-daemon ./scripts/cursor-daemon.sh

# Detach from session: Ctrl+A, then D

# Reattach later
screen -r cursor-daemon

# Kill session
screen -X -S cursor-daemon quit
```

### Using tmux

```bash
cd /Users/yurii/Desktop/Projects/LiveAssistant

# Start in tmux session
tmux new -s cursor-daemon ./scripts/cursor-daemon.sh

# Detach from session: Ctrl+B, then D

# Reattach later
tmux attach -t cursor-daemon

# Kill session
tmux kill-session -t cursor-daemon
```

## GitHub Actions Setup

The GitHub Actions workflows are already configured in `.github/workflows/`.

### Verify Workflows

1. Go to repository on GitHub
2. Click "Actions" tab
3. Should see:
   - "PR Quality Checks" workflow
   - "PR Comment Monitor" workflow

### Test Workflows

1. Create a test PR
2. Add a comment to the PR
3. Check that "needs-changes" label is added
4. Verify daemon detects and processes PR

## Usage

### Normal Operation

Once set up, the system works automatically:

1. Reviewer adds comment to PR
2. GitHub Action adds "needs-changes" label (instantly)
3. Daemon detects label within 60 seconds
4. Daemon fetches PR details, comments, CI results
5. Daemon creates `.cursor-feedback.txt`
6. Cursor (you) reads feedback file
7. Make changes to address feedback
8. Run response script: `./scripts/cursor-pr.sh respond PR_NUMBER "Summary"`
9. Script runs checks, pushes, comments on PR

### Manual Processing

Process a specific PR manually:

```bash
# Process PR
./scripts/cursor-pr.sh process 123

# Read feedback
cat .cursor-feedback.txt

# Make changes...

# Respond
./scripts/cursor-pr.sh respond 123 "Fixed all issues"
```

### Monitoring

**View daemon logs:**
```bash
tail -f logs/cursor-daemon.log
```

**View PR processing logs:**
```bash
tail -f logs/pr-123.log
```

**Check daemon status:**
```bash
# If using launch agent
launchctl list | grep cursor-monitor

# If using screen
screen -ls | grep cursor-daemon

# If using tmux
tmux ls | grep cursor-daemon
```

## Configuration

### Polling Interval

Default: 60 seconds

To change, edit `scripts/cursor-daemon.sh`:
```bash
POLL_INTERVAL=60  # Change to desired seconds
```

After changing, restart daemon.

### Labels

The system uses these labels:
- `needs-changes` - PR needs attention (added by GitHub Action)
- `cursor-processing` - (Optional) daemon is processing PR
- `ready-for-review` - Changes complete, ready for review

Create labels if they don't exist:
```bash
gh label create "needs-changes" --color red --description "PR needs changes from review feedback"
gh label create "ready-for-review" --color green --description "Ready for human review"
```

### CI Integration

The daemon automatically fetches CI check results:
- SwiftLint violations
- Build errors
- Test failures
- Code coverage

These are included in `.cursor-feedback.txt` with priority.

## Advanced Features

### Inline Code Comments

SwiftLint violations are posted as inline comments:

```bash
# Manually post violations
swiftlint lint --reporter json > violations.json
python3 scripts/post-inline-swiftlint-comments.py PR_NUMBER violations.json
```

This happens automatically during CI via GitHub Actions.

### Conflict Resolution

If rebase conflicts occur during processing:
- Daemon creates `.cursor-conflicts.txt` with conflict details
- Pauses for manual resolution
- Includes both versions and resolution strategies

### Custom Feedback Processing

Extend `cursor-pr.sh process` to:
- Filter comments by author
- Prioritize certain feedback
- Send notifications (Slack, email)
- Integrate with other tools

## Updating Scripts

Scripts are version controlled, so updates are easy:

1. Make changes to scripts
2. Test manually
3. Commit and push
4. Restart daemon to pick up changes:
   ```bash
   launchctl kickstart -k gui/$(id -u)/com.liveassistant.cursor-monitor
   ```

## Uninstalling

### Remove Launch Daemon

```bash
# Stop and unload
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Remove plist
rm ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### Keep Scripts

Scripts remain in repository for manual use even without automation.

## Security

- Daemon uses GitHub CLI which stores tokens securely
- Runs as your user account with same permissions
- Logs may contain sensitive information - don't commit them
- Use branch protection rules to prevent unauthorized changes

## Best Practices

1. **Test scripts manually** before automating
2. **Monitor logs regularly** for errors
3. **Use screen/tmux** if launch daemon has issues
4. **Keep polling interval reasonable** (60s default is good)
5. **Review .cursor-feedback.txt** before making changes
6. **Run self-review** before pushing
7. **Don't skip quality checks**

## FAQ

**Q: Does daemon run when Mac is asleep?**  
A: No, it pauses and resumes when Mac wakes.

**Q: Can I run this on Linux/Windows?**  
A: Scripts work anywhere, but launch agent is macOS-specific. Use systemd (Linux) or Task Scheduler (Windows).

**Q: How much resources does it use?**  
A: Minimal - <10MB RAM, negligible CPU when idle.

**Q: Can multiple people use this?**  
A: Yes, but coordinate to avoid processing same PR simultaneously.

**Q: What if I want to pause automation?**  
A: Stop the daemon - PRs will wait until you restart.

## Related Documentation

- [Setup Guide](SETUP.md) - Main setup documentation
- [Troubleshooting Guide](../troubleshooting/TROUBLESHOOTING.md) - Common issues
- [Workflow Guide](../../WORKFLOW.md) - Development workflow

---

**Automation setup complete!** The system will now monitor and process PRs automatically.

**Last Updated:** October 2025


