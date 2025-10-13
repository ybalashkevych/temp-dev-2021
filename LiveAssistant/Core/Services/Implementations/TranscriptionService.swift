//
//  TranscriptionService.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

@preconcurrency import AVFoundation
import Foundation
import Speech

/// Service for transcribing audio streams using Apple's Speech framework.
final class TranscriptionService: TranscriptionServiceProtocol, @unchecked Sendable {
    private let configuration: TranscriptionConfiguration

    // Separate recognizers per source for true isolation with different recognition modes
    private nonisolated(unsafe) var recognizers: [SpeakerType: SFSpeechRecognizer] = [:]
    private nonisolated(unsafe) var recognitionTasks: [SpeakerType: SFSpeechRecognitionTask] = [:]
    private nonisolated(unsafe) var recognitionRequests: [SpeakerType: SFSpeechAudioBufferRecognitionRequest] = [:]
    private nonisolated(unsafe) var lastPartialYieldTime: [SpeakerType: Date] = [:]
    private nonisolated(unsafe) var currentRecognitionMode: [SpeakerType: String] = [:]

    init(configuration: TranscriptionConfiguration = .default) {
        self.configuration = configuration
        print("🎙️ [TranscriptionService] Initialized with hybrid recognition strategy")
    }

    func startTranscription(
        source: SpeakerType,
        audioStream: AsyncStream<AudioBuffer>
    ) async -> AsyncStream<TranscriptionResult> {
        print("🎙️ [\(source)] Starting transcription service with configuration: \(configuration.recognitionMode.rawValue)")

        guard let recognizer = getOrCreateRecognizer(for: source) else {
            print("❌ [\(source)] Speech recognizer not available")
            return AsyncStream { continuation in
                continuation.finish()
            }
        }

        print("✅ [\(source)] Speech recognizer is available")

        let request = createRecognitionRequest(for: source, recognizer: recognizer)

        return createResultStream(for: source, recognizer: recognizer, request: request, audioStream: audioStream)
    }

    private func getOrCreateRecognizer(for source: SpeakerType) -> SFSpeechRecognizer? {
        // Create separate recognizer per source if it doesn't exist
        if recognizers[source] == nil {
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            recognizer?.defaultTaskHint = configuration.taskHint
            recognizers[source] = recognizer
            print("🎙️ [\(source)] Created dedicated speech recognizer for locale: en-US")
        }

        guard let recognizer = recognizers[source], recognizer.isAvailable else {
            return nil
        }

        return recognizer
    }

    private func createRecognitionRequest(
        for source: SpeakerType,
        recognizer: SFSpeechRecognizer
    ) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = configuration.shouldReportPartialResults
        request.addsPunctuation = configuration.addsPunctuation

        // Set task hint at request level for optimal sentence detection
        request.taskHint = configuration.taskHint

        // Determine recognition mode based on source, configuration, and device capabilities
        let (useOnDevice, modeDescription) = selectRecognitionMode(for: source, recognizer: recognizer)
        request.requiresOnDeviceRecognition = useOnDevice
        currentRecognitionMode[source] = modeDescription

        // Add custom vocabulary for technical terms (macOS 14.0+)
        if #available(macOS 14.0, *) {
            if !configuration.customVocabulary.isEmpty {
                request.contextualStrings = configuration.customVocabulary
                print("🎙️ [\(source)] Added \(configuration.customVocabulary.count) custom vocabulary terms")
            }
        }

        recognitionRequests[source] = request
        print(
            """
            🎙️ [\(source)] Created recognition request \
            (mode: \(modeDescription), partialResults: \(configuration.shouldReportPartialResults), \
            punctuation: \(configuration.addsPunctuation))
            """
        )
        return request
    }

    /// Selects the appropriate recognition mode based on source, configuration, and device capabilities.
    /// Checks for source-specific mode overrides first, then falls back to general configuration.
    private func selectRecognitionMode(
        for source: SpeakerType,
        recognizer: SFSpeechRecognizer
    ) -> (useOnDevice: Bool, description: String) {
        let supportsOnDevice = recognizer.supportsOnDeviceRecognition

        // Check for source-specific mode override
        let modeToUse = configuration.sourceSpecificModes?[source] ?? configuration.recognitionMode

        if configuration.sourceSpecificModes?[source] != nil {
            print("🎯 [\(source)] Using source-specific recognition mode: \(modeToUse.rawValue)")
        }

        switch modeToUse {
        case .cloudFirst:
            // Try cloud first, can fallback to on-device if needed
            return (false, "Cloud-First")

        case .onDeviceFirst:
            // Prefer on-device if available
            if supportsOnDevice {
                return (true, "On-Device")
            } else {
                print("⚠️ [\(source)] On-device recognition not supported, falling back to cloud")
                return (false, "Cloud (Fallback)")
            }

        case .cloudOnly:
            return (false, "Cloud-Only")

        case .onDeviceOnly:
            if supportsOnDevice {
                return (true, "On-Device")
            } else {
                print("⚠️ [\(source)] On-device recognition not supported and cloud disabled")
                return (false, "Unavailable")
            }
        }
    }

    private func createResultStream(
        for source: SpeakerType,
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        audioStream: AsyncStream<AudioBuffer>
    ) -> AsyncStream<TranscriptionResult> {
        AsyncStream<TranscriptionResult> { continuation in
            print("🎙️ [\(source)] Starting recognition task")
            let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                self?.handleRecognitionResult(result, error: error, source: source, continuation: continuation)
            }

            self.recognitionTasks[source] = task
            self.feedAudioBuffers(to: request, from: audioStream, source: source)

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopTranscription(source: source)
                }
            }
        }
    }

    private func handleRecognitionResult(
        _ result: SFSpeechRecognitionResult?,
        error: Error?,
        source: SpeakerType,
        continuation: AsyncStream<TranscriptionResult>.Continuation
    ) {
        if let result = result {
            processRecognitionResult(result, source: source, continuation: continuation)
        }

        if let error = error {
            handleRecognitionError(error, source: source, continuation: continuation)
        }
    }

    private func processRecognitionResult(
        _ result: SFSpeechRecognitionResult,
        source: SpeakerType,
        continuation: AsyncStream<TranscriptionResult>.Continuation
    ) {
        let transcription = result.bestTranscription
        let text = transcription.formattedString

        // Skip empty results
        guard !text.isEmpty else {
            return
        }

        let confidence = normalizeConfidence(from: transcription.segments)
        let threshold = confidenceThreshold(for: source, isFinal: result.isFinal)

        // Check if result should be skipped
        if shouldSkipResult(text: text, confidence: confidence, threshold: threshold, isFinal: result.isFinal, source: source) {
            return
        }

        // Create and yield the transcription result
        let transcriptionResult = createTranscriptionResult(
            from: result,
            text: text,
            confidence: confidence
        )

        logTranscriptionResult(
            text: text,
            confidence: confidence,
            threshold: threshold,
            isFinal: result.isFinal,
            source: source
        )

        continuation.yield(transcriptionResult)

        if result.isFinal {
            print("🏁 [\(source)] Recognition task completed with final result")
            continuation.finish()
        }
    }

    private func shouldSkipResult(
        text: String,
        confidence: Float,
        threshold: Float,
        isFinal: Bool,
        source: SpeakerType
    ) -> Bool {
        // Check confidence threshold
        if confidence < threshold {
            let finalStatus = isFinal ? "FINAL" : "partial"
            let confidenceStr = String(format: "%.2f", confidence)
            let thresholdStr = String(format: "%.2f", threshold)
            print(
                """
                ⚠️ [\(source)] [\(finalStatus)] Low confidence (\(confidenceStr)) \
                below threshold (\(thresholdStr)), skipping: "\(text.prefix(50))"
                """
            )
            return true
        }

        // Apply throttling for partial results
        if !isFinal {
            if !shouldYieldPartialResult(for: source) {
                return true
            }
            lastPartialYieldTime[source] = Date()
        }

        return false
    }

    private func createTranscriptionResult(
        from result: SFSpeechRecognitionResult,
        text: String,
        confidence: Float
    ) -> TranscriptionResult {
        let startTime = result.speechRecognitionMetadata?.speechStartTimestamp ?? 0.0
        let duration = result.speechRecognitionMetadata?.speechDuration ?? 0.0
        let endTime = startTime + duration

        return TranscriptionResult(
            text: text,
            startTime: startTime,
            endTime: endTime,
            confidence: Double(confidence),
            isFinal: result.isFinal
        )
    }

    private func logTranscriptionResult(
        text: String,
        confidence: Float,
        threshold: Float,
        isFinal: Bool,
        source: SpeakerType
    ) {
        let finalIndicator = isFinal ? "FINAL" : "partial"
        let sentenceStatus = isSentenceComplete(text) ? "complete" : "incomplete"
        let mode = currentRecognitionMode[source] ?? "unknown"
        let confidenceStr = String(format: "%.2f", confidence)
        let thresholdStr = String(format: "%.2f", threshold)
        print(
            """
            📝 [\(source)] [\(mode)] [\(finalIndicator)] [\(sentenceStatus)] "\(text)" \
            (confidence: \(confidenceStr), threshold: \(thresholdStr))
            """
        )
    }

    private func handleRecognitionError(
        _ error: Error,
        source: SpeakerType,
        continuation: AsyncStream<TranscriptionResult>.Continuation
    ) {
        let errorDescription = error.localizedDescription
        print("❌ [\(source)] Recognition error: \(errorDescription)")

        // Check if this is a "No speech detected" error (not fatal)
        if errorDescription.contains("No speech detected") {
            print("⚠️ [\(source)] No speech detected - this is normal, continuing to listen...")
            return
        }

        // For other errors, finish the stream
        continuation.finish()
    }

    func stopTranscription(source: SpeakerType) async {
        print("🛑 [\(source)] Stopping transcription")

        recognitionTasks[source]?.cancel()
        recognitionTasks[source] = nil

        recognitionRequests[source]?.endAudio()
        recognitionRequests[source] = nil

        // Remove the recognizer for this source
        recognizers[source] = nil

        print("✅ [\(source)] Transcription stopped, recognizer released")
    }

    func stopAll() async {
        print("🛑 Stopping all transcription tasks")
        for source in SpeakerType.allCases {
            recognitionTasks[source]?.cancel()
            recognitionTasks[source] = nil
            recognitionRequests[source]?.endAudio()
            recognitionRequests[source] = nil
            recognizers[source] = nil
        }
        print("✅ All transcription stopped, all recognizers released")
    }
}

// MARK: - Helper Methods
extension TranscriptionService {
    /// Calculates average confidence across all transcription segments.
    fileprivate func normalizeConfidence(from segments: [SFTranscriptionSegment]) -> Float {
        guard !segments.isEmpty else { return 0.0 }

        let totalConfidence = segments.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(segments.count)
    }

    /// Determines the confidence threshold for a given source and result type.
    /// System audio typically has lower confidence scores than microphone, so use lower thresholds.
    /// For partial results, allow very low confidence as they improve over time.
    fileprivate func confidenceThreshold(for source: SpeakerType, isFinal: Bool) -> Float {
        if isFinal {
            // Different final thresholds for each source
            return source == .systemAudio
                ? configuration.finalResultConfidenceThreshold * 0.6
                : configuration.finalResultConfidenceThreshold
        } else {
            // Allow all partial results for both sources (confidence improves over time)
            return 0.0
        }
    }

    /// Checks if a sentence appears complete based on punctuation.
    fileprivate func isSentenceComplete(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let lastChar = trimmed.last else { return false }

        let sentenceEndings: Set<Character> = [".", "!", "?"]
        return sentenceEndings.contains(lastChar)
    }

    /// Determines if enough time has passed to yield another partial result.
    fileprivate func shouldYieldPartialResult(for source: SpeakerType) -> Bool {
        guard let lastYield = lastPartialYieldTime[source] else {
            return true  // First partial result
        }

        let timeSinceLastYield = Date().timeIntervalSince(lastYield)
        return timeSinceLastYield >= configuration.partialResultThrottleInterval
    }

    fileprivate func feedAudioBuffers(
        to request: SFSpeechAudioBufferRecognitionRequest,
        from audioStream: AsyncStream<AudioBuffer>,
        source: SpeakerType
    ) {
        Task {
            var bufferCount = 0
            print("🎙️ [\(source)] Starting to feed audio buffers to recognition request")
            for await audioBuffer in audioStream {
                bufferCount += 1
                if bufferCount == 1 {
                    print("🎙️ [\(source)] Appending first audio buffer to recognition request")
                }
                if bufferCount % 100 == 0 {
                    print("🎙️ [\(source)] Appended \(bufferCount) buffers to recognition request")
                }
                request.append(audioBuffer.buffer)
            }
            print("🎙️ [\(source)] Audio stream ended, total buffers fed: \(bufferCount)")
            request.endAudio()
        }
    }
}
