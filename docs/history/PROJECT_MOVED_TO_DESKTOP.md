# Project Moved to Desktop/Projects

**Date:** October 16, 2025

## What Happened

The LiveAssistant project has been moved from `/Users/yurii/Documents/LiveAssistant` to `/Users/yurii/Desktop/Projects/LiveAssistant`.

## Why the Move

### The Problem
macOS has strict security protections on certain folders:
- **Documents** (protected)
- **Desktop** (protected) 
- **Downloads** (protected)

Launch agents (background daemons like our cursor-monitor) cannot access these folders without Full Disk Access permission, which is a broad security privilege.

### The Solution
Moving the project to `/Users/yurii/Desktop/Projects/` resolves this because:
- ✅ The `Projects` subfolder is not restricted
- ✅ Launch agents can access it without special permissions
- ✅ Better organization for development projects
- ✅ Common practice in the development community

## What Was Updated

### 1. Launchd Configuration
- **File:** `~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist`
- **Updated paths:**
  - Script: `/Users/yurii/Desktop/Projects/LiveAssistant/scripts/cursor-daemon.sh`
  - Logs: `/Users/yurii/Desktop/Projects/LiveAssistant/logs/`
  - Working directory: `/Users/yurii/Desktop/Projects/LiveAssistant`

### 2. Template File
- **File:** `scripts/com.liveassistant.cursor-monitor.plist.template`
- Updated example paths to use `Desktop/Projects` instead of `Documents`
- Added warning about avoiding protected folders

### 3. Documentation
Updated paths in:
- `BACKGROUND_AUTOMATION.md` - Installation and setup instructions
- `DEBUG_PERMISSIONS.md` - Debugging paths
- Added notes about macOS folder restrictions

### 4. Cleanup
- Removed temporary copy from `~/Library/LiveAssistant/`
- All scripts now run from the main project location

## Next Steps After Mac Restart

1. **Verify the daemon starts:**
   ```bash
   launchctl list | grep cursor-monitor
   ```

2. **Check logs are working:**
   ```bash
   tail -f ~/Desktop/Projects/LiveAssistant/logs/cursor-daemon.log
   ```

3. **Verify PR detection:**
   - The daemon should automatically detect PRs with "needs-changes" label
   - Watch logs to see it processing PR #2

## If Issues Persist After Restart

If the daemon still has permission issues after restarting your Mac:

### Option 1: Try Without Full Disk Access First
Since the project is now in a non-restricted location, try removing bash from Full Disk Access:
1. Open System Settings → Privacy & Security → Full Disk Access
2. Remove `bash` if it's there
3. Restart the daemon

### Option 2: Keep Full Disk Access
If you've already granted it and want to keep it:
- This is fine for a development machine
- The daemon should work immediately after restart

## File Locations Reference

**Old Location (Documents - protected):**
```
/Users/yurii/Documents/LiveAssistant/
```

**New Location (Projects - not restricted):**
```
/Users/yurii/Desktop/Projects/LiveAssistant/
```

**Daemon Configuration:**
```
~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

**Daemon Logs:**
```
~/Desktop/Projects/LiveAssistant/logs/cursor-daemon.log
~/Desktop/Projects/LiveAssistant/logs/cursor-daemon.error.log
```

## Testing After Restart

```bash
# Check daemon is running
launchctl list | grep cursor-monitor
# Should show: -    PID    com.liveassistant.cursor-monitor

# Watch logs live
tail -f ~/Desktop/Projects/LiveAssistant/logs/cursor-daemon.log

# You should see:
# - Daemon starting
# - Prerequisites check passing
# - PR monitoring starting
# - Finding PR #2
# - Processing PR #2
```

## Related Documentation

- `LAUNCHD_DOCUMENTS_PERMISSION_ISSUE.md` - Detailed explanation of the original issue
- `BACKGROUND_AUTOMATION.md` - Complete daemon setup guide
- `WORKFLOW.md` - Overall development workflow

---

**Status:** ✅ Ready for Mac restart and testing

