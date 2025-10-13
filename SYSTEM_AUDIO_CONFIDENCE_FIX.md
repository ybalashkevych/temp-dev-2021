# System Audio Confidence Threshold Fix

## Problem
System audio transcription was showing warnings like:
```
⚠️ [systemAudio] [partial] Low confidence (0.00) below threshold (0.30), skipping: "Training and exercise for food preparation for int"
```

Only at the end of the session would a single result appear with higher confidence (0.61).

## Root Cause
System audio partial results often start with **0.00 confidence** initially, but the confidence scores improve as more audio is processed. The previous threshold of 0.30 for partial results was filtering out all these early partial results, preventing real-time transcription updates.

## Solution
Modified the confidence threshold strategy to be more lenient for system audio partial results:

### Changed File
`LiveAssistant/Core/Services/Implementations/TranscriptionService.swift`

### Key Changes

1. **Extracted confidence threshold logic into a helper method** for better maintainability:
   ```swift
   private func confidenceThreshold(for source: SpeakerType, isFinal: Bool) -> Float {
       if source == .systemAudio {
           if isFinal {
               // Keep reasonable threshold for final results
               return configuration.finalResultConfidenceThreshold * 0.6
           } else {
               // Allow all partial results for system audio (confidence improves over time)
               return 0.0
           }
       } else {
           return isFinal ? configuration.finalResultConfidenceThreshold : configuration.partialResultConfidenceThreshold
       }
   }
   ```

2. **Threshold values**:
   - **Microphone partial**: 0.5
   - **Microphone final**: 0.3
   - **System audio partial**: **0.0** (allow all)
   - **System audio final**: 0.18

### Rationale
- System audio partial results start with very low or zero confidence
- Confidence improves as the recognition system processes more audio
- By allowing all partial results (threshold 0.0), users get real-time feedback
- Final results still have a quality threshold (0.18) to filter out poor transcriptions

## Expected Behavior
Now you should see:
- ✅ Real-time partial transcription updates for system audio
- ✅ Low confidence partial results (0.00) will be accepted
- ✅ Confidence will improve as more audio is processed
- ✅ Console logs will show all partial results being processed

## Testing
1. Start the app
2. Enable system audio transcription
3. Play audio (e.g., YouTube video with speech)
4. **Expected**: You should see partial transcriptions appear immediately, even with low confidence
5. **Expected**: Console logs will show partial results being accepted instead of skipped

## Related Files
- `LiveAssistant/Core/Services/Implementations/TranscriptionService.swift` - Main fix
- `SYSTEM_AUDIO_FIX.md` - Original fix documentation

