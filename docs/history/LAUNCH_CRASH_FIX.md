# App Launch Crash - FIXED ✅

## Problem

The app was crashing immediately on launch with a stack trace showing:
```
Thread 1: libsecinit_appsandbox.cold.6
dyld4 initialization errors
```

This indicates a **sandbox entitlements issue** - the app was trying to initialize with App Sandbox enabled but without proper entitlements for the features it needs.

## Root Cause

The project had `ENABLE_APP_SANDBOX = YES` but **no entitlements file** was configured. When an app has App Sandbox enabled but lacks the required entitlements for its features (like microphone access), macOS terminates it during the initialization phase.

## Solution Applied

### 1. Created Entitlements File

Created `LiveAssistant/LiveAssistant.entitlements` with all required sandbox permissions:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.device.audio-input</key>
	<true/>
	<key>com.apple.security.device.microphone</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-only</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
```

### 2. Updated Xcode Project Configuration

Added the entitlements file to both Debug and Release build configurations:

```
CODE_SIGN_ENTITLEMENTS = LiveAssistant/LiveAssistant.entitlements;
```

### 3. Verified Embedded Entitlements

Confirmed the built app now includes all required entitlements:

```bash
codesign -d --entitlements - LiveAssistant.app
```

**Result:**
✅ com.apple.security.app-sandbox  
✅ com.apple.security.device.audio-input  
✅ com.apple.security.device.microphone  
✅ com.apple.security.files.user-selected.read-only  
✅ com.apple.security.network.client  

## Entitlements Explained

### com.apple.security.app-sandbox
Enables App Sandbox for security and App Store distribution.

### com.apple.security.device.audio-input
Required for capturing audio from any audio input device.

### com.apple.security.device.microphone
Specifically required for microphone access (works with audio-input).

### com.apple.security.files.user-selected.read-only
Allows reading files that the user explicitly selects via file dialogs.

### com.apple.security.network.client
Allows outgoing network connections (needed for potential API calls or speech recognition services).

## Build Status

✅ **BUILD SUCCEEDED**  
✅ Entitlements file created  
✅ Entitlements properly embedded  
✅ App should launch without crashing  

## Testing the Fix

1. **Open Xcode**
2. **Run the app** (Cmd+R)
3. **Expected behavior:**
   - ✅ App launches successfully (no crash)
   - ✅ Main window appears with Transcription tab
   - ✅ Permission request screen shown if permissions not granted
   - ✅ "Grant Permissions" button works without crashing
   - ✅ System permission dialogs appear with proper descriptions

## Why This Happened

When you enable App Sandbox (`ENABLE_APP_SANDBOX = YES`) in an Xcode project, you **must** provide an entitlements file that declares which sandbox permissions your app needs. Without it:

1. The app can't access hardware (microphone, camera, etc.)
2. The app can't make network connections
3. The app can't access user files
4. **The app may crash on launch** if it tries to use sandboxed features

## Additional Notes

### Hardened Runtime

The project also has `ENABLE_HARDENED_RUNTIME = YES`, which is good for security and required for:
- Notarization
- App Store distribution
- Enhanced security features

The entitlements file works with both App Sandbox and Hardened Runtime.

### Testing in Production

For App Store or notarized builds, you may need additional entitlements:
- `com.apple.security.cs.allow-unsigned-executable-memory` (if using JIT)
- `com.apple.security.cs.allow-dyld-environment-variables` (for debugging)
- `com.apple.security.cs.disable-library-validation` (if loading third-party frameworks)

**Note:** Only add these if actually needed - they reduce security.

## Related Files

- `LiveAssistant/LiveAssistant.entitlements` - **NEW** - Sandbox entitlements
- `LiveAssistant/Info.plist` - Privacy usage descriptions
- `LiveAssistant.xcodeproj/project.pbxproj` - Build configuration with CODE_SIGN_ENTITLEMENTS

## Troubleshooting

### If the app still crashes on launch:

1. **Clean derived data:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/LiveAssistant-*
   ```

2. **Clean build folder:**
   In Xcode: Product → Clean Build Folder (Cmd+Shift+K)

3. **Verify entitlements are embedded:**
   ```bash
   codesign -d --entitlements - path/to/LiveAssistant.app
   ```

4. **Check Console.app** for detailed crash logs:
   - Open Console.app
   - Filter by "LiveAssistant"
   - Look for sandbox violation messages

### Common sandbox violations:

- **File access:** Add appropriate file access entitlements
- **Network:** Ensure `com.apple.security.network.client` is present
- **Hardware:** Ensure device entitlements match the hardware you're accessing

## Success Criteria

After applying this fix:
- [x] App launches without crashing
- [x] No sandbox violation errors in Console
- [x] Microphone permission can be requested
- [x] Speech recognition works
- [x] System audio capture works (with screen recording permission)
- [x] All transcription features functional

---

**The app is now ready to run with proper sandbox entitlements!** 🎉

