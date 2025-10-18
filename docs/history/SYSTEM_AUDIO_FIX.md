# System Audio Transcription Fix

## Issue
System audio transcription was not working - no transcriptions were appearing for system audio capture.

## Root Cause
The enhanced speech recognition implementation introduced confidence filtering that was too strict for system audio. System audio typically has lower confidence scores than microphone audio because:

1. Audio is captured through the system's audio output (speakers)
2. Audio quality is often lower than direct microphone input
3. Audio may have compression or other processing applied

The default confidence thresholds were:
- Partial results: 0.5
- Final results: 0.3

These thresholds were filtering out all system audio transcriptions.

## Solution
Adjusted the confidence threshold calculation to be more lenient for system audio:

### Changed File
`LiveAssistant/Core/Services/Implementations/TranscriptionService.swift`

### Key Changes

1. **Dynamic threshold for system audio based on result type**:
   ```swift
   let threshold: Float
   if source == .systemAudio {
       if result.isFinal {
           threshold = configuration.finalResultConfidenceThreshold * 0.6  // 0.18
       } else {
           threshold = 0.0  // Allow all partial results
       }
   } else {
       let baseThreshold = result.isFinal ? 
           configuration.finalResultConfidenceThreshold : 
           configuration.partialResultConfidenceThreshold
       threshold = baseThreshold
   }
   ```
   
   This means:
   - **Microphone partial**: 0.5 threshold
   - **Microphone final**: 0.3 threshold
   - **System audio partial**: 0.0 threshold (allow all - confidence improves over time)
   - **System audio final**: 0.18 threshold
   
   **Rationale**: System audio partial results often start with 0.00 confidence but improve as more audio is processed. Allowing all partial results provides real-time feedback while still filtering low-quality final results.

2. **Skip empty results**:
   ```swift
   guard !text.isEmpty else { return }
   ```

3. **Enhanced logging** to help debug future issues:
   - Shows confidence scores and thresholds for both filtered and accepted results
   - Includes text preview for filtered results
   - Shows final/partial status in logs

## Expected Behavior
- System audio transcription should now work properly
- Lower quality audio will still be transcribed
- Console logs will show confidence scores and thresholds for debugging

## Testing
Build succeeds and compiles correctly. Test by:
1. Starting the app
2. Enabling system audio transcription
3. Playing audio through system speakers
4. Verifying transcriptions appear in the UI
5. Checking console logs for confidence scores

## Related Files
- `LiveAssistant/Core/Services/Implementations/TranscriptionService.swift` - Main fix
- `LiveAssistant/Core/Services/Implementations/TranscriptionConfiguration.swift` - Threshold configuration

