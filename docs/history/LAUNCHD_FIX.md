# Launchd Configuration Fix

## Issue

The background daemon for monitoring GitHub PRs was failing to load with the error:
```
Load failed: 5: Input/output error
```

## Root Causes

### 1. Incorrect Paths in plist File

The `~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist` file contained outdated paths:
- **Incorrect**: `/Users/yurii/Desktop/Projects/LiveAssistant`
- **Correct**: `/Users/yurii/Documents/LiveAssistant`

This caused launchd to fail because it couldn't find:
- The script to execute (`cursor-daemon.sh`)
- The log file directories
- The working directory

### 2. Deprecated launchctl Commands

Documentation was using deprecated `launchctl load` command instead of the modern `launchctl bootstrap` command.

## Solution

### 1. Fixed plist File

Updated all paths in the plist file to point to the correct location:

```xml
<key>ProgramArguments</key>
<array>
    <string>/Users/yurii/Documents/LiveAssistant/scripts/cursor-daemon.sh</string>
</array>

<key>StandardOutPath</key>
<string>/Users/yurii/Documents/LiveAssistant/logs/cursor-daemon.log</string>

<key>StandardErrorPath</key>
<string>/Users/yurii/Documents/LiveAssistant/logs/cursor-daemon.error.log</string>

<key>WorkingDirectory</key>
<string>/Users/yurii/Documents/LiveAssistant</string>
```

### 2. Used Modern launchctl Commands

Instead of:
```bash
launchctl load ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

Use:
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

## Updated Files

### 1. Template File
**File**: `scripts/com.liveassistant.cursor-monitor.plist.template`

**Changes**:
- Updated example paths to use generic `/Users/YOUR_USERNAME/Documents/LiveAssistant`
- Added clear placeholders for users to replace

### 2. Documentation
**File**: `BACKGROUND_AUTOMATION.md`

**Changes**:
- Updated installation instructions to use `launchctl bootstrap`
- Added troubleshooting section for path verification
- Updated all daemon management commands:
  - Start: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist`
  - Restart: `launchctl kickstart -k gui/$(id -u)/com.liveassistant.cursor-monitor`
  - Stop: `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist`

**File**: `DEBUG_PERMISSIONS.md`

**Changes**:
- Updated all example commands to use correct project path
- Changed from `/Users/yurii/Desktop/Projects/LiveAssistant` to `/Users/yurii/Documents/LiveAssistant`

## Verification

After the fix, the daemon loaded successfully:

```bash
$ launchctl list | grep cursor-monitor
-	78	com.liveassistant.cursor-monitor
```

Output shows:
- `-` (no exit status, still running)
- `78` (process ID)
- `com.liveassistant.cursor-monitor` (service label)

## Modern launchctl Commands Reference

### Load and Start
```bash
# Bootstrap (load and start)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### Check Status
```bash
# List running services
launchctl list | grep cursor-monitor

# Get detailed info
launchctl print gui/$(id -u)/com.liveassistant.cursor-monitor
```

### Restart
```bash
# Quick restart (keeps it loaded)
launchctl kickstart -k gui/$(id -u)/com.liveassistant.cursor-monitor

# Full reload (unload and reload)
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### Stop and Unload
```bash
# Bootout (stop and unload)
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

## Best Practices for Launch Agents

### 1. Always Use Absolute Paths

✅ **Good**:
```xml
<string>/Users/yurii/Documents/LiveAssistant/scripts/cursor-daemon.sh</string>
```

❌ **Bad**:
```xml
<string>~/Documents/LiveAssistant/scripts/cursor-daemon.sh</string>
<string>./scripts/cursor-daemon.sh</string>
```

### 2. Verify Paths Exist Before Loading

```bash
# Check script exists and is executable
ls -la /Users/yurii/Documents/LiveAssistant/scripts/cursor-daemon.sh

# Check log directory exists
ls -ld /Users/yurii/Documents/LiveAssistant/logs/
```

### 3. Test Script Manually First

```bash
# Run the script directly to verify it works
cd /Users/yurii/Documents/LiveAssistant
./scripts/cursor-daemon.sh
```

### 4. Use Template Files

Keep a template with placeholder values:
- `YOUR_USERNAME` instead of actual username
- Clear comments indicating what needs changing
- Version controlled template, not the actual plist

### 5. Validate plist Syntax

```bash
# Check plist syntax
plutil -lint ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Should output: OK
```

## Troubleshooting Similar Issues

### Error: "Input/output error"

**Likely causes**:
1. Paths in plist don't exist
2. Script is not executable
3. Working directory doesn't exist
4. Log directories don't exist

**Solution**:
```bash
# Verify all paths
cat ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist | grep "/Users/"

# Check each path exists
```

### Error: "Service is disabled"

**Cause**: Service was previously disabled by user or system

**Solution**:
```bash
# Enable the service
launchctl enable gui/$(id -u)/com.liveassistant.cursor-monitor

# Then bootstrap it
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### Error: "Could not find service"

**Cause**: Service was never loaded or already unloaded

**Solution**:
```bash
# Just bootstrap it (don't try to bootout first)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### Service Loads But Immediately Exits

**Cause**: Script has an error or missing dependency

**Check logs**:
```bash
tail -50 /Users/yurii/Documents/LiveAssistant/logs/cursor-daemon.error.log
```

**Common issues**:
- GitHub CLI not authenticated
- Missing `jq` command
- Script errors
- Permission issues

## Impact

This fix enables:
- ✅ Automatic monitoring of GitHub PRs for feedback
- ✅ Background daemon that runs continuously
- ✅ Automatic processing of PR comments
- ✅ Proper logging and error tracking

The daemon will now:
1. Start automatically on user login (RunAtLoad = true)
2. Restart if it crashes (KeepAlive = true)
3. Log all activity to the correct location
4. Run from the correct working directory

## Related Documentation

- `BACKGROUND_AUTOMATION.md` - Complete background automation guide
- `AUTOMATED_WORKFLOW_SETUP.md` - Initial workflow setup
- `WORKFLOW.md` - General workflow documentation

---

**Date Fixed**: October 16, 2025  
**Status**: ✅ Resolved and verified

