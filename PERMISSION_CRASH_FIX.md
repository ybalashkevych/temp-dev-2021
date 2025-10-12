# Permission Request Crash - FIXED ✅

## Problem

The app was crashing with `__TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION__` when the "Grant Permissions" button was tapped.

### Root Cause

The Xcode project was configured to auto-generate the Info.plist file (`GENERATE_INFOPLIST_FILE = YES`), which meant our custom `Info.plist` containing the required privacy usage descriptions was being ignored.

macOS requires these usage description strings to be present in the app's Info.plist **before** requesting permissions. Without them, the system terminates the app immediately for privacy violation.

## Solution Applied

### 1. Updated Project Configuration

Changed the Xcode build settings to use our custom Info.plist:

**Before:**
```
GENERATE_INFOPLIST_FILE = YES;
```

**After:**
```
GENERATE_INFOPLIST_FILE = NO;
INFOPLIST_FILE = LiveAssistant/Info.plist;
```

This change was applied to both Debug and Release configurations.

### 2. Verified Info.plist Contents

The custom Info.plist contains all required privacy usage descriptions:

- **NSMicrophoneUsageDescription**: "LiveAssistant needs access to your microphone to transcribe your voice during interviews."
- **NSSpeechRecognitionUsageDescription**: "LiveAssistant uses speech recognition to convert your speech and system audio into text for real-time transcription."
- **NSSystemExtensionUsageDescription**: "LiveAssistant needs access to system audio to transcribe the interviewer's voice and questions."

### 3. Clean Build

Performed a clean build to ensure the new Info.plist is properly embedded in the app bundle.

## Verification

Verified the built app contains the required keys:

```bash
plutil -p LiveAssistant.app/Contents/Info.plist | grep -E "NS.*UsageDescription"
```

Output confirms all three permission descriptions are present ✅

## How to Test

1. **Clean existing permissions** (optional, to test fresh):
   ```bash
   tccutil reset Microphone fundamental.LiveAssistant
   tccutil reset SpeechRecognition fundamental.LiveAssistant
   ```

2. **Launch the app** from Xcode or the built app

3. **Tap "Grant Permissions"** button

4. **Expected behavior:**
   - App should NOT crash ✅
   - macOS system dialogs should appear asking for each permission
   - Each dialog should display the custom usage description text
   - After granting, the permission status should update in the UI

## Testing Checklist

- [ ] App launches without crashing
- [ ] Permission request view appears if permissions not granted
- [ ] Tapping "Grant Permissions" does NOT crash the app
- [ ] System permission dialogs appear with custom descriptions
- [ ] After granting microphone permission, status updates to "Authorized"
- [ ] After granting speech recognition permission, status updates to "Authorized"
- [ ] After granting screen recording permission (for system audio), status updates to "Authorized"
- [ ] All permissions granted → Permission view disappears
- [ ] Transcription controls become available

## Technical Details

### TCC (Transparency, Consent, and Control)

macOS uses TCC to protect user privacy. For sensitive permissions like:
- Microphone
- Camera
- Speech Recognition
- Screen Recording
- Contacts, Calendar, etc.

**The app MUST include usage description strings in Info.plist BEFORE requesting access.**

If these strings are missing, macOS will:
1. Immediately terminate the app
2. Log a crash with `__TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION__`
3. Not show any permission dialog

### Permission Flow

```
User taps "Grant Permissions"
    ↓
App calls AVCaptureDevice.requestAccess(for: .audio)
    ↓
macOS checks Info.plist for NSMicrophoneUsageDescription
    ↓
If FOUND: Show dialog with description
If MISSING: Crash app immediately (Privacy Violation)
```

## Additional Notes

### Screen Recording Permission

For system audio capture, we request "Screen Recording" permission using ScreenCaptureKit:
- This is the correct approach for macOS 13+
- The usage description key is `NSSystemExtensionUsageDescription`
- User must grant this permission in System Settings > Privacy & Security > Screen Recording

### Permission Persistence

Once permissions are granted:
- They are stored in the TCC database
- Persist across app launches
- Can only be revoked by the user in System Settings
- Or programmatically using `tccutil reset` (for testing)

### App Sandbox

The app has sandboxing enabled (`ENABLE_APP_SANDBOX = YES`), which provides an additional layer of security but also requires explicit entitlements for certain capabilities.

## Related Files

- `LiveAssistant/Info.plist` - Contains privacy usage descriptions
- `LiveAssistant.xcodeproj/project.pbxproj` - Build configuration
- `LiveAssistant/Core/Services/Implementations/PermissionService.swift` - Permission handling logic
- `LiveAssistant/Features/Transcription/Components/PermissionRequestView.swift` - Permission UI

## Build Status

✅ **BUILD SUCCEEDED**  
✅ Info.plist properly configured  
✅ All permission descriptions included  
✅ Ready for testing

