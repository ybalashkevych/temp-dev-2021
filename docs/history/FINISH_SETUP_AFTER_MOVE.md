# Final Setup Steps After Project Move

## ✅ What's Been Done

1. **Project moved** from `/Users/yurii/Documents/LiveAssistant` → `/Users/yurii/Desktop/Projects/LiveAssistant`
2. **Launchd plist updated** to point to new location
3. **Documentation updated** with correct paths
4. **Template file updated** for future reference
5. **Daemon stopped** (not currently running)

## 📋 What You Need to Do

### 1. Commit the Path Updates

```bash
cd ~/Desktop/Projects/LiveAssistant

# Check what changed
git status

# Stage all changes
git add -A

# Commit
git commit -m "refactor: Move project to Desktop/Projects and update all paths

- Move from Documents (macOS protected folder) to Desktop/Projects
- Update launchd plist to new location
- Update documentation with correct paths  
- Add notes about macOS folder restrictions
- Desktop/Projects location doesn't require Full Disk Access"

# Push to remote
git push origin feat/issue-1-automated-workflow
```

### 2. Optional: Clean Up Full Disk Access

Since the project is no longer in a restricted folder, you can remove bash from Full Disk Access if you want:

1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Find `bash` in the list
3. Toggle it **OFF** or click **-** to remove it
4. This is optional - keeping it won't hurt

### 3. Restart Your Mac

```bash
# Save all your work first!
sudo shutdown -r now
```

### 4. After Restart, Test the Daemon

```bash
# Check if daemon is running
launchctl list | grep cursor-monitor
# Should show: -    PID    com.liveassistant.cursor-monitor

# Watch the logs
tail -f ~/Desktop/Projects/LiveAssistant/logs/cursor-daemon.log

# You should see:
# ✅ Daemon starting
# ✅ All prerequisites met
# ✅ Starting PR monitoring  
# ✅ Found 1 PR(s) needing attention
# ✅ Processing PR #2
```

## 🔧 If Daemon Doesn't Start After Restart

### Check Status
```bash
launchctl print gui/$(id -u)/com.liveassistant.cursor-monitor
```

### Manually Start
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
```

### Check for Errors
```bash
cat ~/Desktop/Projects/LiveAssistant/logs/cursor-daemon.error.log
```

### Test Script Manually
```bash
cd ~/Desktop/Projects/LiveAssistant
./scripts/cursor-daemon.sh
# Press Ctrl+C after you see it working
```

## 📝 File Locations Quick Reference

| Item | Location |
|------|----------|
| **Project** | `/Users/yurii/Desktop/Projects/LiveAssistant/` |
| **Daemon Script** | `~/Desktop/Projects/LiveAssistant/scripts/cursor-daemon.sh` |
| **Daemon Config** | `~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist` |
| **Logs** | `~/Desktop/Projects/LiveAssistant/logs/cursor-daemon.log` |
| **PR Logs** | `~/Desktop/Projects/LiveAssistant/logs/pr-*.log` |

## 🎯 Expected Behavior

Once working, the daemon will:
1. ✅ Start automatically when you log in
2. ✅ Check GitHub every 60 seconds for PRs with "needs-changes" label
3. ✅ Find your PR #2
4. ✅ Process it by checking out the branch and extracting feedback
5. ✅ Create `.cursor-feedback.txt` for you to review
6. ✅ Log all activity to `logs/cursor-daemon.log`

## 📚 Documentation

- `PROJECT_MOVED_TO_DESKTOP.md` - Details about the move
- `LAUNCHD_DOCUMENTS_PERMISSION_ISSUE.md` - Why we had to move
- `BACKGROUND_AUTOMATION.md` - Complete daemon setup guide
- `WORKFLOW.md` - Overall development workflow

---

**Current Status:** Ready for commit, restart, and testing! 🚀

