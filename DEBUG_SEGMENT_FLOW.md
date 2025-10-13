# Debug: Segment Flow Tracing

## Issue
System audio transcription is being recognized (visible in logs) but segments are not appearing in the UI.

## Added Debug Logging

I've added comprehensive logging throughout the entire data flow to help identify where segments are getting lost.

### 1. TranscriptionService
**File:** `TranscriptionService.swift`

Already has detailed logging showing:
- Recognition results with confidence scores
- Threshold comparisons
- Whether results are final or partial

Example log:
```
📝 [systemAudio] [Cloud-First] [FINAL] [complete] "Hello world" (confidence: 0.45, threshold: 0.18)
```

### 2. TranscriptionRepository
**File:** `TranscriptionRepository.swift` - `processTranscriptionResult()`

Added logging to track:
- When results are received from TranscriptionService
- Text before and after analysis
- Whether segment is added to session (final only)
- Number of listeners being notified

Example logs:
```
🔄 [Repository] Processing result for [systemAudio]: "Hello world" (isFinal: true)
🔍 [Repository] After analysis: "Hello world" (isQuestion: false)
✅ [Repository] Added FINAL segment to session
📢 [Repository] Broadcasting segment to 1 listeners
```

### 3. TranscriptionViewModel
**File:** `TranscriptionViewModel.swift`

#### `startListeningToSegments()`
Added logging for stream setup:
```
🎧 [ViewModel] Starting to listen for segments
✅ [ViewModel] Got segment stream, waiting for segments...
```

#### `handleNewSegment()`
Added logging for segment processing:
```
📥 [ViewModel] Received [FINAL] segment from [systemAudio]: "Hello world"
📊 [ViewModel] Current segments count before: 0
➕ [ViewModel] Appending new FINAL segment
📊 [ViewModel] Current segments count after: 1
```

## How to Debug

### Step 1: Run the app with system audio
1. Start the app
2. Enable system audio transcription
3. Play some audio

### Step 2: Check Console for Log Sequence

**Expected flow (if working correctly):**
1. `📝 [systemAudio]` - TranscriptionService yields result
2. `🔄 [Repository]` - Repository receives result
3. `🔍 [Repository]` - Text analyzed
4. `📢 [Repository]` - Broadcasting to X listeners (should be >= 1)
5. `🔔 [ViewModel]` - Stream receives segment
6. `📥 [ViewModel]` - ViewModel processes segment
7. `📊 [ViewModel]` - Count increases

**Common issues to look for:**

#### Issue A: No repository logs
If you see `📝` but not `🔄`:
- Problem: TranscriptionService results not reaching Repository
- Check: Task setup in `TranscriptionRepository.startSystemAudio()`

#### Issue B: Zero listeners
If you see `📢 [Repository] Broadcasting segment to 0 listeners`:
- Problem: ViewModel not subscribed to stream
- Check: `startListeningToSegments()` is called
- Check: Stream setup in `start()` method

#### Issue C: Segment never received
If you see `📢` but not `🔔`:
- Problem: AsyncStream not yielding to ViewModel
- Check: Stream continuation is active
- Check: No async context issues

#### Issue D: Count not increasing
If you see `📥` but count stays at 0:
- Problem: Segment matching/replacement logic
- Check: `startTime` values
- Check: `speaker` comparison
- Check: `isFinal` status

## Next Steps

1. **Run the app** and enable system audio transcription
2. **Play some audio** (YouTube, music, etc.)
3. **Copy all console logs** that match the patterns above
4. **Share the logs** so we can identify exactly where the flow breaks

## Files Modified for Debugging
- `Core/Services/Implementations/TranscriptionService.swift` (already had logs)
- `Core/Repositories/Implementations/TranscriptionRepository.swift` (added detailed logs)
- `Features/Transcription/ViewModels/TranscriptionViewModel.swift` (added detailed logs)

