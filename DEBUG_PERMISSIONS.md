# Debug Permission Request Issue

## Added Debug Logging

I've added detailed logging to help diagnose why microphone permissions aren't being requested.

## How to Test

### 1. Run the App from Xcode

Make sure you run the app **from Xcode** (not from Finder) so you can see the console output.

```bash
# In Xcode: Product → Run (Cmd+R)
```

### 2. Open Debug Console

In Xcode, make sure the **Debug Area** is visible:
- Press **Cmd+Shift+Y** to show/hide debug console
- Or click the bottom panel toggle button

### 3. Click "Grant Permissions"

When you click the "Grant Permissions" button, you should see detailed logs like:

```
🎤 Requesting microphone permission...
🎤 PermissionService: Checking current microphone status...
🎤 PermissionService: Current status = notDetermined
🎤 PermissionService: Requesting microphone access from system...
🎤 PermissionService: System returned granted = true/false
🎤 Microphone permission result: authorized/denied
🗣️ Requesting speech recognition permission...
...
```

### 4. What to Look For

**If you see the logs:**
- ✅ The permission request code IS running
- Check what status is returned
- Check if system permission dialog appears

**If you DON'T see the logs:**
- ❌ The button click isn't working
- ❌ The async task isn't executing
- We need to fix the button/task wiring

### 5. Check System Dialogs

When requesting permissions, macOS should show:

**Microphone:**
- System dialog saying "LiveAssistant would like to access the microphone"
- Shows the usage description from Info.plist
- Has "Don't Allow" and "OK" buttons

**Speech Recognition:**
- System dialog for speech recognition
- Similar format

**Screen Recording:**
- May need to open System Settings
- User must manually enable in Privacy & Security

## Common Issues

### Issue 1: No Console Output

**Problem:** You don't see any debug logs when clicking "Grant Permissions"

**Solution:** The button's async task might not be executing properly. Check:
```swift
Button {
    Task { await onRequestPermissions() }  // ← This must be called
}
```

### Issue 2: Status Already Determined

**Problem:** Logs show "Status already determined, returning denied"

**Solution:** Permission was previously denied. Reset it:
```bash
# Reset microphone permission
tccutil reset Microphone fundamental.LiveAssistant

# Reset speech recognition
tccutil reset SpeechRecognition fundamental.LiveAssistant

# Reset screen recording
tccutil reset ScreenCapture fundamental.LiveAssistant
```

### Issue 3: System Dialog Doesn't Appear

**Problem:** Logs show request is made but no dialog appears

**Possible Causes:**
1. **Info.plist not embedded:** Check that usage descriptions are in the built app
2. **App not signed correctly:** Check code signing
3. **macOS caching:** Kill and restart the app
4. **System bug:** Try logging out and back in

**Verify Info.plist is embedded:**
```bash
plutil -p LiveAssistant.app/Contents/Info.plist | grep NSMicrophone
```

Should show:
```
"NSMicrophoneUsageDescription" => "LiveAssistant needs access..."
```

## Detailed Debugging Steps

### Step 1: Verify Build

```bash
cd /Users/yurii/Desktop/Projects/LiveAssistant

# Check Info.plist in source
cat LiveAssistant/Info.plist

# Build
xcodebuild build -project LiveAssistant.xcodeproj -scheme LiveAssistant

# Check Info.plist in built app
plutil -p ~/Library/Developer/Xcode/DerivedData/LiveAssistant-*/Build/Products/Debug/LiveAssistant.app/Contents/Info.plist | grep NS
```

### Step 2: Reset All TCC Permissions

```bash
# Reset all permissions for the app
tccutil reset All fundamental.LiveAssistant

# Or reset specific ones
tccutil reset Microphone fundamental.LiveAssistant
tccutil reset SpeechRecognition fundamental.LiveAssistant
tccutil reset ScreenCapture fundamental.LiveAssistant
```

### Step 3: Clean Launch

```bash
# Kill the app if running
killall LiveAssistant

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/LiveAssistant-*

# Rebuild
cd /Users/yurii/Desktop/Projects/LiveAssistant
xcodebuild clean -project LiveAssistant.xcodeproj -scheme LiveAssistant
xcodebuild build -project LiveAssistant.xcodeproj -scheme LiveAssistant

# Run from Xcode (Cmd+R)
```

### Step 4: Check System Settings

Open **System Settings > Privacy & Security** and check:
- **Microphone:** Is LiveAssistant listed? What's its status?
- **Speech Recognition:** Is it listed?
- **Screen Recording:** Is it listed?

## Expected Console Output

### Successful Permission Request:

```
🎤 Requesting microphone permission...
🎤 PermissionService: Checking current microphone status...
🎤 PermissionService: Current status = notDetermined
🎤 PermissionService: Requesting microphone access from system...
[System shows permission dialog]
🎤 PermissionService: System returned granted = true
🎤 Microphone permission result: authorized
🗣️ Requesting speech recognition permission...
🗣️ Speech recognition permission result: authorized
🖥️ Requesting screen recording permission...
🖥️ Screen recording permission result: denied (expected - needs System Settings)
✅ All permissions granted: false (expected - screen recording needs manual enable)
```

### Previously Denied:

```
🎤 Requesting microphone permission...
🎤 PermissionService: Checking current microphone status...
🎤 PermissionService: Current status = denied
🎤 PermissionService: Status already determined, returning denied
🎤 Microphone permission result: denied
[No system dialog - already denied]
```

### Permission Already Granted:

```
🎤 Requesting microphone permission...
🎤 PermissionService: Checking current microphone status...
🎤 PermissionService: Current status = authorized
🎤 PermissionService: Status already determined, returning authorized
🎤 Microphone permission result: authorized
[No system dialog - already granted]
```

## Next Steps

1. **Run the app from Xcode** (Cmd+R)
2. **Watch the console** when you click "Grant Permissions"
3. **Copy the console output** and share it
4. **Check System Settings** → Privacy & Security → Microphone
5. **Report what you see:**
   - What logs appear in console?
   - Does system dialog appear?
   - Is app listed in System Settings?
   - What's the permission status?

## Quick Test Command

Run this to see if the app is properly signed and has Info.plist:

```bash
# Check code signature
codesign -dvv ~/Library/Developer/Xcode/DerivedData/LiveAssistant-*/Build/Products/Debug/LiveAssistant.app

# Check Info.plist
plutil -p ~/Library/Developer/Xcode/DerivedData/LiveAssistant-*/Build/Products/Debug/LiveAssistant.app/Contents/Info.plist | grep -A 1 "NS.*Usage"
```

Should show all three usage descriptions.

---

**After running the test, please share:**
1. Console output from clicking "Grant Permissions"
2. Whether system permission dialog appeared
3. Whether app appears in System Settings → Privacy & Security → Microphone

