# Launchd Documents Folder Permission Issue

## Problem

The cursor-monitor daemon cannot access the git repository in `/Users/yurii/Documents/LiveAssistant` due to macOS security restrictions on the Documents folder.

**Error seen:**
```
fatal: Unable to read current working directory: Operation not permitted
/bin/bash: /Users/yurii/Documents/LiveAssistant/scripts/cursor-process-pr.sh: Operation not permitted
```

## Why This Happens

- macOS Big Sur and later have strict privacy protections for user folders (Documents, Desktop, Downloads)
- Launch agents (background daemons) run in a security context that doesn't have access to these protected folders
- Even though your user account has access, the launchd process does not

## Solutions

### Option 1: Grant Full Disk Access (Recommended for Development)

1. Open **System Settings** (or System Preferences)
2. Go to **Privacy & Security** → **Full Disk Access**
3. Click the **+** button
4. Add `/bin/bash` (the shell that runs the daemon)
   - Or add `/usr/local/bin/gh` if you want to be more specific
5. Restart the daemon:
   ```bash
   launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
   ```

**Note:** Granting Full Disk Access to bash is a security trade-off. Only do this on your development machine.

### Option 2: Move Repository Out of Documents (Cleanest Solution)

Move your git repository to a location that launchd can access:

```bash
# Move the repository
mv ~/Documents/LiveAssistant ~/Projects/LiveAssistant

# Update the daemon script
nano ~/Library/LiveAssistant/scripts/cursor-daemon.sh
# Change: PROJECT_DIR="/Users/yurii/Documents/LiveAssistant"
# To:     PROJECT_DIR="/Users/yurii/Projects/LiveAssistant"

# Restart the daemon
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

**Locations that work well:**
- `~/Projects/` ✅
- `~/Developer/` ✅
- `~/Code/` ✅
- `~/src/` ✅
- `/usr/local/src/` ✅

**Locations that are restricted:**
- `~/Documents/` ❌
- `~/Desktop/` ❌
- `~/Downloads/` ❌

### Option 3: Use a Different Automation Approach

Instead of a background daemon, use:

1. **Manual triggering**: Run scripts manually when needed
2. **GitHub Actions**: Let GitHub Actions handle PR processing entirely in the cloud
3. **Cron jobs**: Run as a regular cron job (which has more permissions)
4. **Interactive scripts**: Run scripts in an interactive terminal session

### Option 4: Create a Wrapper Script (Workaround)

Create a wrapper that copies the repo to `/tmp` for processing:

```bash
#!/bin/bash
# Copy repo to tmp for processing
rsync -a ~/Documents/LiveAssistant/ /tmp/LiveAssistant-work/
cd /tmp/LiveAssistant-work
# Do work here
# Copy changes back
rsync -a /tmp/LiveAssistant-work/ ~/Documents/LiveAssistant/
```

**⚠️ Not recommended** - complex and error-prone

## Current Status

### What's Working ✅
- Daemon starts and runs successfully
- Logs are being written to `~/Library/LiveAssistant/logs/`
- GitHub API authentication works
- PR detection works (found PR #2)
- Scripts execute from `~/Library/LiveAssistant/scripts/`

### What's Not Working ❌
- Git operations in `~/Documents/LiveAssistant/` 
- Checking out PR branches
- Running scripts that access the Documents folder

## Recommended Next Steps

**For Development:**
1. **Best**: Move the repository to `~/Projects/LiveAssistant`
2. **Alternative**: Grant Full Disk Access to `/bin/bash`

**For Production/Sharing:**
- Document that the repository must not be in Documents folder
- Update setup instructions to create repo in `~/Projects/` or similar
- Update the plist template to use a non-Documents path

## Testing After Fix

```bash
# Check logs
tail -f ~/Library/LiveAssistant/logs/cursor-daemon.log

# You should see:
# ✅ "Processing PR #2"
# ✅ "Fetching PR details..."
# ✅ "Checking out branch..."
# ✅ "Successfully processed PR #2"
```

## Documentation Updates Needed

1. **BACKGROUND_AUTOMATION.md**:
   - Add warning about Documents folder
   - Recommend using ~/Projects/ instead
   
2. **README.md**:
   - Update installation instructions
   - Note the Documents folder limitation
   
3. **Template plist**:
   - Use `~/Projects/LiveAssistant` as example path
   - Add comment about avoiding Documents folder

## Related Apple Documentation

- [TCC (Transparency, Consent, and Control)](https://developer.apple.com/documentation/security/app_sandbox)
- [File System Permissions Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/)
- [Launch Services](https://developer.apple.com/documentation/coreservices/launch_services)

---

**Date Identified:** October 16, 2025  
**Status:** 🔶 Issue Identified - Solution Available  
**Impact:** High - Blocks PR automation from working
**Effort to Fix:** Low - 5 minutes to move repository or grant permissions

