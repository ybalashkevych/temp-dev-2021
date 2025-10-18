# Background Cursor Automation

This document describes the background automation system that enables Cursor to monitor GitHub PRs and respond to feedback automatically.

## Overview

The background automation system consists of:

1. **Background Daemon** - Runs continuously on your Mac, monitoring GitHub for PR activity
2. **GitHub Workflows** - Detect PR comments and label PRs needing attention
3. **Automation Scripts** - Process PRs, respond to feedback, post inline comments
4. **Cursor Rules** - Guide Cursor's behavior when processing feedback

## Architecture

```
GitHub PR Comment
       ↓
GitHub Action (pr-comment-monitor.yml)
       ↓
Adds "needs-changes" label
       ↓
Background Daemon (cursor-daemon.sh)
       ↓
Processes PR (cursor-process-pr.sh)
       ↓
Creates .cursor-feedback.txt
       ↓
Cursor Reads Feedback & Makes Changes
       ↓
Responds (cursor-respond-to-feedback.sh)
       ↓
Updates PR & Labels
```

## Components

### 1. Background Daemon

**File:** `scripts/cursor-daemon.sh`

Runs continuously as a macOS Launch Agent, checking GitHub every 60 seconds for PRs labeled "needs-changes".

**What it does:**
- Polls GitHub for open PRs with "needs-changes" label
- Calls `cursor-process-pr.sh` for each PR found
- Updates PR labels after processing
- Logs all activity to `logs/cursor-daemon.log`

### 2. PR Comment Monitor

**File:** `.github/workflows/pr-comment-monitor.yml`

GitHub Action that triggers on PR comments and reviews.

**What it does:**
- Listens for new comments on PRs
- Listens for code review submissions
- Adds "needs-changes" label to notify the daemon
- Runs instantly when feedback is added

### 3. PR Processing Script

**File:** `scripts/cursor-process-pr.sh`

Processes individual PRs that need attention.

**What it does:**
- Fetches PR details (branch, comments, reviews)
- Checks out the PR branch locally
- Extracts feedback from comments and reviews
- Creates `.cursor-feedback.txt` with all feedback
- Prepares environment for Cursor to make changes

### 4. Feedback Response Script

**File:** `scripts/cursor-respond-to-feedback.sh`

Called after Cursor makes changes to respond to feedback.

**What it does:**
- Runs self-review checks
- Pushes changes if checks pass
- Comments on PR with summary
- Updates labels appropriately

### 5. Inline Comment Posting

**File:** `scripts/post-inline-swiftlint-comments.py`

Posts SwiftLint violations as inline PR comments.

**What it does:**
- Parses SwiftLint JSON output
- Posts each violation as an inline comment on the specific line
- Creates a review with all violations grouped
- Helps Cursor see exactly where fixes are needed

### 6. Cursor Automation Rules

**File:** `.cursor/rules/workflow-automation.mdc` (previously `pr-monitoring.mdc`)

Defines how Cursor should behave when processing PR feedback and automating development workflow.

**What it defines:**
- How to read and prioritize feedback
- Architecture compliance requirements
- Self-review process
- Automated workflow guidance
- Error handling procedures

## Installation

### Prerequisites

- macOS (for background daemon)
- GitHub CLI (`gh`) installed and authenticated
- Python 3 (for inline comment script)
- `jq` for JSON parsing: `brew install jq`

### Step 1: Ensure Scripts are Executable

```bash
chmod +x scripts/cursor-daemon.sh
chmod +x scripts/cursor-process-pr.sh
chmod +x scripts/cursor-respond-to-feedback.sh
chmod +x scripts/post-inline-swiftlint-comments.py
```

### Step 2: Create Log Directory

```bash
mkdir -p logs
```

### Step 3: Install Python Dependencies (if needed)

```bash
pip3 install requests
```

### Step 4: Create Launch Agent

Copy the template and customize for your system:

```bash
# Copy template
cp scripts/com.liveassistant.cursor-monitor.plist.template \
   ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Edit to match your actual project path
# Replace YOUR_USERNAME with your macOS username
# The default path structure is: /Users/YOUR_USERNAME/Desktop/Projects/LiveAssistant
# NOTE: Avoid using /Documents/, /Desktop/, or /Downloads/ folders as they are
#       restricted by macOS security and launchd cannot access them without Full Disk Access
nano ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### Step 5: Load and Start the Daemon

Use the modern `launchctl bootstrap` command (not the deprecated `load`):

```bash
# Bootstrap the launch agent (loads and starts it)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Verify it's running
launchctl list | grep cursor-monitor

# You should see output like: -    78    com.liveassistant.cursor-monitor
# The number is the process ID, indicating it's running
```

**Troubleshooting:**

If you get "Input/output error", verify your paths:
```bash
# Check the plist file has correct paths
cat ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist | grep "/Users/"

# All paths should match your actual project location
# Correct: /Users/yourusername/Desktop/Projects/LiveAssistant
# Wrong: /Users/YOUR_USERNAME/Desktop/Projects/LiveAssistant (template not updated)
# AVOID: /Users/yourusername/Documents/LiveAssistant (macOS protected folder)
```

### Step 6: Verify Installation

```bash
# Check logs
tail -f logs/cursor-daemon.log

# You should see: "[timestamp] Cursor daemon started"
```

## Usage

### Normal Operation

Once installed, the system runs automatically:

1. When someone adds a comment to a PR, GitHub Actions adds "needs-changes" label
2. Background daemon detects the label within 60 seconds
3. Daemon processes the PR and creates feedback file
4. Cursor reads feedback and makes changes (manual or automated)
5. After changes, Cursor calls response script
6. Response script runs checks, pushes, and comments on PR

### Manual Triggering

You can manually trigger processing for a specific PR:

```bash
# Process a specific PR
./scripts/cursor-process-pr.sh <PR_NUMBER>

# After making changes, respond
./scripts/cursor-respond-to-feedback.sh <PR_NUMBER> "Summary of changes"
```

### Checking Status

```bash
# View daemon logs
tail -f logs/cursor-daemon.log

# Check if daemon is running
launchctl list | grep cursor-monitor

# View recent PR processing logs
ls -lt logs/pr-*.log | head
```

## Updating Scripts

Since all scripts are in the repository and version controlled:

### Update Process

1. **Make changes to scripts** in your working directory
2. **Test changes** manually before committing
3. **Commit and push** changes
4. **Restart daemon** to pick up changes:

```bash
# Restart the daemon (stop and start)
launchctl kickstart -k gui/$(id -u)/com.liveassistant.cursor-monitor

# Or reload completely (unload and reload)
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### Testing Script Changes

Before committing script changes:

```bash
# Test PR processing manually
./scripts/cursor-process-pr.sh <TEST_PR_NUMBER>

# Check if feedback file was created correctly
cat .cursor-feedback.txt

# Test response script
./scripts/cursor-respond-to-feedback.sh <TEST_PR_NUMBER> "Test changes"
```

## Troubleshooting

### Daemon Not Starting

**Check if it's loaded:**
```bash
launchctl list | grep cursor-monitor
```

**View error logs:**
```bash
cat logs/cursor-daemon.error.log
```

**Common issues:**
- Path in plist doesn't match actual script location
- Script not executable (`chmod +x`)
- GitHub CLI not authenticated (`gh auth status`)

### Daemon Not Detecting PRs

**Check GitHub authentication:**
```bash
gh auth status
gh pr list
```

**Verify labels exist:**
```bash
gh label list
```

**Check daemon logs:**
```bash
tail -f logs/cursor-daemon.log
```

### Script Fails to Process PR

**Run manually with verbose output:**
```bash
bash -x ./scripts/cursor-process-pr.sh <PR_NUMBER>
```

**Common issues:**
- Branch conflicts (fetch and merge)
- Permission issues (check GitHub token scopes)
- `jq` not installed (`brew install jq`)

### Python Script Fails

**Check Python and dependencies:**
```bash
python3 --version
pip3 list | grep requests
```

**Test inline comment script:**
```bash
# Create test violations file
echo '[{"file":"test.swift","line":10,"rule_id":"force_unwrapping","reason":"test","severity":"warning"}]' > test-violations.json

# Test script (will fail without proper PR, but checks imports)
python3 scripts/post-inline-swiftlint-comments.py 1 test-violations.json
```

### Daemon Using Too Many Resources

**Check polling interval:**
```bash
grep POLL_INTERVAL scripts/cursor-daemon.sh
```

**Adjust if needed** (default 60 seconds):
```bash
# Edit script
nano scripts/cursor-daemon.sh
# Change: POLL_INTERVAL=60 to POLL_INTERVAL=300 (5 minutes)

# Restart daemon
launchctl stop com.liveassistant.cursor-monitor
launchctl start com.liveassistant.cursor-monitor
```

### Too Many GitHub API Calls

**Check rate limit:**
```bash
gh api rate_limit
```

**If hitting limits:**
- Increase polling interval
- Process fewer PRs per cycle
- Use conditional requests (ETags)

## Maintenance

### Daily

- Monitor `logs/cursor-daemon.log` for errors
- Check daemon is still running: `launchctl list | grep cursor-monitor`

### Weekly

- Review and archive old logs
- Check GitHub API rate limit usage
- Verify automation is processing PRs correctly

### Monthly

- Update scripts based on learnings
- Review and optimize polling interval
- Update documentation with new patterns

### Log Rotation

Prevent logs from growing too large:

```bash
# Add to crontab (replace with your actual project path)
0 0 * * 0 /usr/bin/find /Users/yourusername/Desktop/Projects/LiveAssistant/logs -name "*.log" -mtime +30 -delete
```

## Security Considerations

### GitHub Token

- Daemon uses `gh` CLI which stores token securely in keychain
- Token should have `repo` scope for full access
- Never commit tokens to repository

### Launch Agent Security

- Launch agent runs as your user account
- Has same permissions as your terminal
- Can access files you can access
- Logs may contain sensitive information

### Best Practices

- Keep logs directory in `.gitignore`
- Don't commit `.cursor-feedback.txt`
- Regularly review daemon activity
- Use branch protection rules

## Advanced Configuration

### Multiple Repositories

To monitor multiple repositories:

1. Clone this setup to each repository
2. Use different launch agent labels
3. Adjust ports if running webhooks

### Custom Feedback Processing

Extend `cursor-process-pr.sh` to:
- Filter comments by author
- Prioritize certain types of feedback
- Integrate with other tools
- Send notifications (Slack, email)

### Integration with CI/CD

The inline comment script can be called from any CI system:

```yaml
# In GitHub Actions
- name: Post violations as comments
  run: |
    swiftlint lint --reporter json > violations.json
    python3 scripts/post-inline-swiftlint-comments.py \
      ${{ github.event.pull_request.number }} \
      violations.json
```

## Uninstalling

To remove the background automation:

```bash
# Stop and unload daemon
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Remove launch agent
rm ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Remove logs (optional)
rm -rf logs/

# Scripts remain in repository for manual use
```

## FAQ

**Q: Does the daemon run when my Mac is asleep?**  
A: No, launchd agents pause when the Mac sleeps and resume when it wakes.

**Q: Can I run this on Linux/Windows?**  
A: The scripts are bash/Python and can run anywhere, but the launch agent is macOS-specific. Use systemd (Linux) or Task Scheduler (Windows) equivalents.

**Q: How much resources does it use?**  
A: Minimal when idle. Only active when processing PRs. Typically <10MB RAM, negligible CPU.

**Q: Can multiple people use this on the same repository?**  
A: Yes, but coordinate to avoid processing the same PR simultaneously. Use different labels or assign PRs.

**Q: What if I want to pause automation temporarily?**  
A: `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist` - restart with `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist`

**Q: Can Cursor automatically make changes without human review?**  
A: Currently, Cursor prepares feedback but requires human interaction to make changes. Full automation possible with additional integration.

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review daemon logs
3. Test scripts manually
4. Create an issue on GitHub

## Version History

- **v1.0** - Initial implementation with basic PR monitoring
- Background daemon with launchd
- PR comment monitoring workflow
- Inline comment posting
- Comprehensive documentation

## CI Check Integration

The daemon automatically fetches results from GitHub Actions CI checks and includes them in the feedback file.

### Optimized Workflow Architecture

The CI checks use an **optimized multi-job workflow** that eliminates redundant builds:

**PR Checks Workflow:**
1. **Job 1 (Code Quality)**: SwiftLint + swift-format run in parallel
2. **Job 2 (Build)**: Builds once, uploads artifacts *(skipped if Job 1 fails)*
3. **Job 3 (Tests & Coverage)**: Downloads artifacts, tests with coverage *(skipped if Job 2 fails)*

**Benefits:**
- ~66% reduction in build time (1 build instead of 3)
- Fail-fast: dependent jobs skip automatically on failure
- Single combined PR comment with all results
- Build artifacts cached between workflow runs

### Supported Checks

1. **SwiftLint** - Code style violations with line numbers
2. **swift-format** - Code formatting issues
3. **Build Status** - Compilation errors
4. **Unit Tests** - Test failures with error messages  
5. **Code Coverage** - Coverage percentage and threshold status (90% minimum)

### How It Works

1. Daemon fetches latest commit SHA from PR branch
2. Queries GitHub API for check runs on that commit
3. Parses results from each check (SwiftLint, swift-format, Build, Tests, Coverage)
4. Extracts detailed output (violations, failures, errors)
5. Includes in `.cursor-feedback.txt` with priority ordering

### Feedback Priority

The feedback file prioritizes issues:
1. **Build errors** (blocks everything)
2. **Test failures** (code quality)
3. **SwiftLint violations** (style)
4. **Coverage below 90%** (completeness)
5. **Human review comments** (feature correctness)

This ensures Cursor addresses blocking issues first.

### Example Feedback Output

When CI checks fail, the feedback file includes:

```markdown
## CI Check Results

### Automated Checks Status

| Check | Status |
|-------|--------|
| SwiftLint | ❌ failure |
| Build | ✅ Passed |
| Tests | ❌ failure |
| Coverage | ❌ Below 90% |

### SwiftLint Violations

```
Linting 'ContentViewModel.swift' (1/10)
LiveAssistant/Features/Chat/ViewModels/ContentViewModel.swift:15:1: warning: Line Length Violation: Line should be 140 characters or less: currently 157 characters (line_length)
```

**Action Required:** Fix these linting violations before proceeding.

### Test Failures

```
Test Case '-[LiveAssistantTests.TranscriptionViewModelTests testStartTranscription]' failed (0.023 seconds).
    <unknown>:0: error: -[LiveAssistantTests.TranscriptionViewModelTests testStartTranscription] : XCTAssertEqual failed: ("started") is not equal to ("stopped")
```

**Action Required:** Fix failing tests.

## Action Items

### Priority 1: CI Failures
- [ ] Fix failing tests
- [ ] Fix SwiftLint violations
- [ ] Increase test coverage to ≥90%

### Priority 2: Code Review Feedback
1. **Address each review comment** - Make the requested changes
...
```

This prioritized structure helps Cursor know what to fix first.

---

Last updated: 2025-10-16

