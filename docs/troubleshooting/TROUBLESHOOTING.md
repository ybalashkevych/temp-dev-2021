# Troubleshooting Guide

This guide consolidates solutions to common issues encountered during development of LiveAssistant.

## Table of Contents

- [Launch & Crash Issues](#launch--crash-issues)
- [Permission Issues](#permission-issues)
- [Audio & Transcription Issues](#audio--transcription-issues)
- [Build & Configuration Issues](#build--configuration-issues)
- [Launch Daemon Issues](#launch-daemon-issues)

## Launch & Crash Issues

### App Crashes on Launch with Sandbox Error

**Symptoms:**
- App crashes immediately with `libsecinit_appsandbox.cold.6` error
- dyld4 initialization errors in crash log

**Root Cause:**
App Sandbox enabled without proper entitlements.

**Solution:**

1. **Check if entitlements file exists:**
   ```bash
   ls -la LiveAssistant/LiveAssistant.entitlements
   ```

2. **Verify entitlements are configured in Xcode:**
   - Open project settings → Build Settings
   - Search for "Code Sign Entitlements"
   - Should be: `LiveAssistant/LiveAssistant.entitlements`

3. **For development, consider disabling sandbox:**
   - Build Settings → `ENABLE_APP_SANDBOX = NO`
   - Keep Hardened Runtime enabled for security
   - Re-enable before App Store submission

4. **Verify embedded entitlements:**
   ```bash
   codesign -d --entitlements - path/to/LiveAssistant.app
   ```

**Related:** See `docs/setup/configuration.md` for entitlements setup.

---

### App Crashes When Requesting Permissions

**Symptoms:**
- App terminates with `__TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION__`
- Crash occurs when tapping "Grant Permissions"

**Root Cause:**
Missing privacy usage descriptions in Info.plist.

**Solution:**

1. **Ensure Info.plist is not auto-generated:**
   - Build Settings → `GENERATE_INFOPLIST_FILE = NO`
   - Build Settings → `INFOPLIST_FILE = LiveAssistant/Info.plist`

2. **Verify required privacy keys exist:**
   ```bash
   plutil -p LiveAssistant/Info.plist | grep -E "NS.*UsageDescription"
   ```

   Should show:
   - `NSMicrophoneUsageDescription`
   - `NSSpeechRecognitionUsageDescription`
   - `NSSystemExtensionUsageDescription` (for system audio)

3. **Clean and rebuild:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/LiveAssistant-*
   xcodebuild clean
   ```

4. **Verify Info.plist in built app:**
   ```bash
   plutil -p ~/Library/Developer/Xcode/DerivedData/LiveAssistant-*/Build/Products/Debug/LiveAssistant.app/Contents/Info.plist | grep NSMicrophone
   ```

---

## Permission Issues

### Microphone Permission Dialog Doesn't Appear

**Symptoms:**
- Click "Grant Permissions" but no system dialog appears
- Console shows entitlement errors

**Root Cause:**
Missing entitlements for Hardened Runtime.

**Solution:**

1. **Add required entitlements** to `LiveAssistant.entitlements`:
   ```xml
   <key>com.apple.security.device.audio-input</key>
   <true/>
   <key>com.apple.security.device.microphone</key>
   <true/>
   ```

2. **Verify entitlements are embedded:**
   ```bash
   codesign -d --entitlements - LiveAssistant.app | grep microphone
   ```

3. **Check Console.app for TCC errors:**
   - Open Console.app
   - Filter by "LiveAssistant"
   - Look for messages about missing entitlements

4. **Reset permissions and retry:**
   ```bash
   # Reset microphone permission
   tccutil reset Microphone fundamental.LiveAssistant
   
   # Kill and restart app
   killall LiveAssistant
   ```

---

### Permission Already Denied

**Symptoms:**
- Debug logs show "Status already determined, returning denied"
- No system dialog appears

**Solution:**

Reset the permission and retry:

```bash
# Reset specific permissions
tccutil reset Microphone fundamental.LiveAssistant
tccutil reset SpeechRecognition fundamental.LiveAssistant
tccutil reset ScreenCapture fundamental.LiveAssistant

# Or reset all for the app
tccutil reset All fundamental.LiveAssistant
```

Then restart the app and request permissions again.

---

### Debug Permission Issues

**Enable detailed logging:**

The app includes debug logging for permission requests. To view:

1. **Run from Xcode** (not Finder) - Cmd+R
2. **Show Debug Console** - Cmd+Shift+Y
3. **Click "Grant Permissions"**

**Expected output:**
```
🎤 Requesting microphone permission...
🎤 PermissionService: Checking current microphone status...
🎤 PermissionService: Current status = notDetermined
🎤 PermissionService: Requesting microphone access from system...
🎤 PermissionService: System returned granted = true
🎤 Microphone permission result: authorized
```

**If no logs appear:** Button click isn't working - check SwiftUI async task wiring.

**If status is already determined:** Permission was previously denied/granted - reset if needed.

---

## Audio & Transcription Issues

### System Audio Transcription Not Working

**Symptoms:**
- Microphone transcription works, but system audio doesn't
- No transcriptions appear for system audio

**Root Cause:**
Confidence threshold too strict for system audio.

**Understanding the Issue:**

System audio typically has lower confidence scores than microphone because:
- Audio captured through system output (speakers)
- Audio quality is lower than direct microphone input
- Compression and processing reduce confidence

**Solution:**

The confidence thresholds have been adjusted:
- **Microphone partial:** 0.5
- **Microphone final:** 0.3  
- **System audio partial:** 0.0 (allow all)
- **System audio final:** 0.18

System audio partial results start with 0.00 confidence but improve as more audio is processed.

**Verify the fix:**

Check console logs when transcribing system audio:
```
[systemAudio] [partial] Confidence: 0.00, Threshold: 0.00, Accepted: "..."
[systemAudio] [partial] Confidence: 0.15, Threshold: 0.00, Accepted: "..."
[systemAudio] [final] Confidence: 0.61, Threshold: 0.18, Accepted: "..."
```

Partial results should be accepted (not skipped).

**Related File:** `Core/Services/Implementations/TranscriptionService.swift`

---

### Real-time Transcription Updates Too Slow

**Symptoms:**
- Transcriptions appear only after long pauses
- Partial results not showing up

**Possible Causes:**

1. **Confidence filtering too strict** - See system audio section above
2. **Empty results not filtered** - Check logs for empty strings
3. **Network issues** - If using cloud-based recognition

**Debug:**

Check console for:
```
⚠️ Low confidence (...) below threshold (...), skipping: "..."
```

If you see this frequently, thresholds may need adjustment.

---

## Build & Configuration Issues

### SwiftLint or SwiftFormat Plugin Errors

**Symptoms:**
- Build fails with plugin errors
- Can't find SwiftLint/SwiftFormat tools

**Solution:**

1. **Install tools via Homebrew:**
   ```bash
   brew install swiftlint swift-format
   ```

2. **For macOS 26 compatibility:**
   - Ensure Xcode 26.0.1 or later
   - Update Package.swift to use latest plugin versions

3. **Verify tools are accessible:**
   ```bash
   which swiftlint
   which swift-format
   ```

---

### SwiftGen Not Generating Files

**Symptoms:**
- `Strings` or `Asset` types not found
- Build errors in `Core/Generated/`

**Solution:**

1. **Run SwiftGen code generation:**
   ```bash
   swift package --allow-writing-to-package-directory generate-code-for-resources
   ```

2. **Verify generated files:**
   ```bash
   ls -la LiveAssistant/Core/Generated/
   ```

   Should contain:
   - `Strings.swift`
   - `Assets.swift`

3. **Check swiftgen.yml configuration:**
   - Ensure paths are correct
   - Verify exclusions don't block needed files

---

## Launch Daemon Issues

### Daemon Fails to Load with I/O Error

**Symptoms:**
```
Load failed: 5: Input/output error
```

**Root Cause:**
Incorrect paths in plist file or paths don't exist.

**Solution:**

1. **Verify all paths in plist match your project location:**
   ```bash
   cat ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist | grep "/Users/"
   ```

2. **Check each path exists:**
   ```bash
   # Script
   ls -la /path/to/your/project/scripts/cursor-daemon.sh
   
   # Working directory
   ls -ld /path/to/your/project/
   
   # Log directory
   ls -ld /path/to/your/project/logs/
   ```

3. **Ensure script is executable:**
   ```bash
   chmod +x scripts/cursor-daemon.sh
   ```

4. **Use modern launchctl commands:**
   ```bash
   # Load (modern way)
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist
   
   # Check status
   launchctl list | grep cursor-monitor
   ```

**Avoid deprecated commands:**
- ❌ `launchctl load` (old, deprecated)
- ✅ `launchctl bootstrap` (modern)

---

### Daemon Starts But Immediately Stops

**Check error logs:**
```bash
tail -50 logs/cursor-daemon.error.log
```

**Common issues:**

1. **GitHub CLI not authenticated:**
   ```bash
   gh auth status
   gh auth login
   ```

2. **Missing dependencies:**
   ```bash
   # Check jq is installed
   which jq
   brew install jq
   ```

3. **Permission issues:**
   - Check script can read/write to working directory
   - Verify GitHub token has correct scopes

4. **Script errors:**
   - Run script manually to test
   ```bash
   cd /path/to/project
   ./scripts/cursor-daemon.sh
   ```

---

### Daemon Can't Access Project in Protected Folders

**Symptoms:**
- Daemon fails when project is in Documents/Desktop/Downloads

**Root Cause:**
macOS security restrictions prevent launchd from accessing protected folders.

**Solution:**

**Option 1 - Move project** (recommended):
```bash
# Move to a non-protected location
mv ~/Desktop/Projects/LiveAssistant ~/Projects/LiveAssistant
```

**Option 2 - Grant Full Disk Access:**
1. System Settings → Privacy & Security → Full Disk Access
2. Add Terminal or launchd
3. Not recommended for security reasons

**Option 3 - Use screen/tmux instead:**
```bash
screen -S cursor-daemon ./scripts/cursor-daemon.sh
# Detach: Ctrl+A, D
# Reattach: screen -r cursor-daemon
```

---

## Quick Reference

### Common Commands

**Reset Permissions:**
```bash
tccutil reset Microphone fundamental.LiveAssistant
tccutil reset SpeechRecognition fundamental.LiveAssistant
tccutil reset ScreenCapture fundamental.LiveAssistant
```

**Clean Build:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/LiveAssistant-*
xcodebuild clean
xcodebuild build
```

**Check Code Signing:**
```bash
codesign -dvv LiveAssistant.app
codesign -d --entitlements - LiveAssistant.app
```

**Daemon Management:**
```bash
# Start
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Restart
launchctl kickstart -k gui/$(id -u)/com.liveassistant.cursor-monitor

# Stop
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.liveassistant.cursor-monitor.plist

# Check status
launchctl list | grep cursor-monitor
```

---

## Getting Help

If you're still experiencing issues:

1. **Check Console.app** for system errors
2. **Review logs:** `tail -f logs/*.log`
3. **Run with verbose debugging:**
   ```bash
   bash -x scripts/cursor-daemon.sh
   ```
4. **Create an issue** with:
   - Symptoms and error messages
   - Console output
   - Steps to reproduce
   - macOS version and Xcode version

---

**Last Updated:** October 2025


