# Transcription Session Entry Point

## Overview

LiveAssistant now has a fully functional entry point for starting transcription sessions. The app opens directly to the Transcription tab, making it easy to start recording immediately.

## User Interface

### Main View
The app uses a tabbed interface with two tabs:
- **Transcription** (default): Main feature for real-time audio transcription
- **Demo Items**: Sample data management view

### Transcription View Components

#### 1. Recording Controls
Located at the top of the view:
- **Start/Stop Button**: Begin or end the transcription session
- **Microphone Toggle**: Enable/disable microphone input
- **System Audio Toggle**: Enable/disable system audio capture
- **Clear Button**: Remove all transcription segments

#### 2. Permission Request
On first launch, users will see a permission request screen asking for:
- **Microphone Access**: Required to transcribe user's voice
- **Speech Recognition**: Required to convert speech to text
- **Screen Recording**: Required to capture system audio (for interviewer's voice)

#### 3. Transcription Display
- Real-time display of transcription segments
- Shows speaker type (Microphone/System Audio)
- Indicates partial vs. final transcription
- Auto-scrolls to latest segment
- Color-coded by speaker

#### 4. Error Handling
- Orange banner displays errors with dismiss button
- Graceful error messages using localized strings

## How to Start a Transcription Session

### Step 1: Launch the App
The app opens directly on the Transcription tab.

### Step 2: Grant Permissions (First Time Only)
1. Click "Grant Permissions" button
2. Approve each permission request in macOS System Settings
3. Wait for all permissions to be granted

### Step 3: Configure Audio Sources
- Toggle **Microphone** on to capture your voice
- Toggle **System Audio** on to capture interviewer/system audio
- At least one source must be enabled

### Step 4: Start Recording
1. Click the **Start** button
2. Transcription begins in real-time
3. Segments appear as they are recognized

### Step 5: Monitor Transcription
- Partial segments show in progress text (lighter color)
- Final segments show confirmed text
- Speaker labels indicate audio source

### Step 6: Stop Recording
1. Click the **Stop** button
2. Session ends, segments remain visible
3. Use **Clear** to remove all segments

## Architecture

### Dependency Injection
The app uses Swinject for dependency injection:
```swift
// ViewModel is automatically resolved from AppComponent
TranscriptionView()
```

### MVVM Pattern
- **View**: `TranscriptionView` - UI display only
- **ViewModel**: `TranscriptionViewModel` - Business logic and state
- **Repository**: `TranscriptionRepository` - Data coordination
- **Services**: Audio capture, transcription, text analysis

### Data Flow
```
User Action → ViewModel → Repository → Services → Repository → ViewModel → View
```

### Async/Await
All operations use modern async/await patterns:
- Non-blocking UI
- Proper error handling
- MainActor isolation for UI updates

## Localization

All user-facing strings are localized:
- Tab labels: `Strings.App.Tab.transcription`
- UI controls: `Strings.Ui.dismiss`
- Permissions: `Strings.Permissions.*`
- Errors: `Strings.Transcription.Error.*`

## Permissions

### Required Permissions
1. **Microphone**: `NSMicrophoneUsageDescription`
   - Used for: Voice input transcription
   
2. **Speech Recognition**: `NSSpeechRecognitionUsageDescription`
   - Used for: Converting audio to text
   
3. **Screen Recording**: `NSSystemExtensionUsageDescription`
   - Used for: Capturing system audio

### Permission States
- **Not Determined**: Permission not yet requested
- **Authorized**: Permission granted, feature available
- **Denied**: Permission denied, feature unavailable
- **Restricted**: Permission restricted by system policy

## Testing

### Unit Tests
Test the ViewModel with mock repository:
```swift
let mockRepo = MockTranscriptionRepository()
let vm = TranscriptionViewModel(
    transcriptionRepository: mockRepo,
    permissionService: MockPermissionService()
)
```

### Manual Testing Checklist
- [ ] App launches to Transcription tab
- [ ] Permission request appears on first launch
- [ ] Microphone toggle works
- [ ] System audio toggle works
- [ ] Start/Stop button works
- [ ] Real-time segments appear
- [ ] Clear button removes all segments
- [ ] Error banner shows and dismisses
- [ ] Auto-scroll to latest segment works

## Troubleshooting

### No Microphone Input
- Check microphone permissions in System Settings
- Verify microphone toggle is enabled
- Check macOS microphone privacy settings

### No System Audio
- Grant Screen Recording permission
- macOS may require app restart after granting permission
- Check system audio output device is working

### Speech Recognition Not Working
- Verify internet connection (required for some languages)
- Check Speech Recognition permission
- Ensure device supports speech recognition

### App Crashes on Launch
- Check all dependencies are registered in `AppComponent`
- Verify SwiftData model schema
- Review console logs for specific errors

## Future Enhancements

Potential improvements:
- Export transcription to text file
- Search within transcriptions
- Speaker identification/diarization
- Custom vocabulary support
- Offline speech recognition
- Session history and replay
- Integration with note-taking apps

