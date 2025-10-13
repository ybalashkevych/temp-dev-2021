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

    private nonisolated(unsafe) var recognizers: [SpeakerType: SFSpeechRecognizer] = [:]
    private nonisolated(unsafe) var recognitionTasks: [SpeakerType: SFSpeechRecognitionTask] = [:]
    private nonisolated(unsafe) var recognitionRequests: [SpeakerType: SFSpeechAudioBufferRecognitionRequest] = [:]
    private nonisolated(unsafe) var lastPartialYieldTime: [SpeakerType: Date] = [:]
    private nonisolated(unsafe) var currentRecognitionMode: [SpeakerType: String] = [:]

    init(configuration: TranscriptionConfiguration = .default) {
        self.configuration = configuration
    }

    func startTranscription(
        source: SpeakerType,
        audioStream: AsyncStream<AudioBuffer>
    ) async -> AsyncStream<TranscriptionResult> {
        print("🎙️ [\(source)] Starting transcription service with configuration: \(configuration.recognitionMode.rawValue)")

        guard let recognizer = createOrGetRecognizer(for: source) else {
            print("❌ [\(source)] Speech recognizer not available")
            return AsyncStream { continuation in
                continuation.finish()
            }
        }

        print("✅ [\(source)] Speech recognizer is available")

        let request = createRecognitionRequest(for: source, recognizer: recognizer)

        return createResultStream(for: source, recognizer: recognizer, request: request, audioStream: audioStream)
    }

    private func createOrGetRecognizer(for source: SpeakerType) -> SFSpeechRecognizer? {
        if recognizers[source] == nil {
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            // Use .unspecified for better conversation handling instead of .dictation
            recognizer?.defaultTaskHint = configuration.taskHint
            recognizers[source] = recognizer
            print("🎙️ [\(source)] Created speech recognizer for locale: en-US with task hint: \(configuration.taskHint.rawValue)")
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

        // Determine recognition mode based on configuration and device capabilities
        let (useOnDevice, modeDescription) = selectRecognitionMode(for: recognizer)
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

    /// Selects the appropriate recognition mode based on configuration and device capabilities.
    private func selectRecognitionMode(for recognizer: SFSpeechRecognizer) -> (useOnDevice: Bool, description: String) {
        let supportsOnDevice = recognizer.supportsOnDeviceRecognition

        switch configuration.recognitionMode {
        case .cloudFirst:
            // Try cloud first, can fallback to on-device if needed
            return (false, "Cloud-First")

        case .onDeviceFirst:
            // Prefer on-device if available
            if supportsOnDevice {
                return (true, "On-Device")
            } else {
                print("⚠️ On-device recognition not supported, falling back to cloud")
                return (false, "Cloud (Fallback)")
            }

        case .cloudOnly:
            return (false, "Cloud-Only")

        case .onDeviceOnly:
            if supportsOnDevice {
                return (true, "On-Device")
            } else {
                print("⚠️ On-device recognition not supported and cloud disabled")
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
            let transcription = result.bestTranscription
            let text = transcription.formattedString

            // Skip empty results
            guard !text.isEmpty else {
                return
            }

            // Calculate better average confidence across all segments
            let confidence = normalizeConfidence(from: transcription.segments)

            let startTime = result.speechRecognitionMetadata?.speechStartTimestamp ?? 0.0
            let duration = result.speechRecognitionMetadata?.speechDuration ?? 0.0
            let endTime = startTime + duration

            // Apply confidence filtering based on configuration
            let threshold = confidenceThreshold(for: source, isFinal: result.isFinal)

            if confidence < threshold {
                let finalStatus = result.isFinal ? "FINAL" : "partial"
                let confidenceStr = String(format: "%.2f", confidence)
                let thresholdStr = String(format: "%.2f", threshold)
                print(
                    """
                    ⚠️ [\(source)] [\(finalStatus)] Low confidence (\(confidenceStr)) \
                    below threshold (\(thresholdStr)), skipping: "\(text.prefix(50))"
                    """
                )
                return
            }

            // Apply throttling for partial results to avoid UI spam
            if !result.isFinal {
                if !shouldYieldPartialResult(for: source) {
                    return
                }
                lastPartialYieldTime[source] = Date()
            }

            let transcriptionResult = TranscriptionResult(
                text: text,
                startTime: startTime,
                endTime: endTime,
                confidence: Double(confidence),
                isFinal: result.isFinal
            )

            let finalIndicator = result.isFinal ? "FINAL" : "partial"
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

            continuation.yield(transcriptionResult)

            if result.isFinal {
                print("🏁 [\(source)] Recognition task completed with final result")
                continuation.finish()
            }
        }

        if let error = error {
            print("❌ [\(source)] Recognition error: \(error.localizedDescription)")
            continuation.finish()
        }
    }

    /// Calculates average confidence across all transcription segments.
    private func normalizeConfidence(from segments: [SFTranscriptionSegment]) -> Float {
        guard !segments.isEmpty else { return 0.0 }

        let totalConfidence = segments.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(segments.count)
    }

    /// Determines the confidence threshold for a given source and result type.
    /// System audio typically has lower confidence scores than microphone, so use lower thresholds.
    /// For system audio partial results, allow very low confidence as they improve over time.
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

    /// Checks if a sentence appears complete based on punctuation.
    private func isSentenceComplete(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let lastChar = trimmed.last else { return false }

        let sentenceEndings: Set<Character> = [".", "!", "?"]
        return sentenceEndings.contains(lastChar)
    }

    /// Determines if enough time has passed to yield another partial result.
    private func shouldYieldPartialResult(for source: SpeakerType) -> Bool {
        guard let lastYield = lastPartialYieldTime[source] else {
            return true  // First partial result
        }

        let timeSinceLastYield = Date().timeIntervalSince(lastYield)
        return timeSinceLastYield >= configuration.partialResultThrottleInterval
    }

    private func feedAudioBuffers(
        to request: SFSpeechAudioBufferRecognitionRequest,
        from audioStream: AsyncStream<AudioBuffer>,
        source: SpeakerType
    ) {
        Task {
            var bufferCount = 0
            for await audioBuffer in audioStream {
                bufferCount += 1
                if bufferCount == 1 {
                    print("🎙️ [\(source)] First audio buffer appended to recognition request")
                }
                if bufferCount % 10 == 0 {
                    print("🎙️ [\(source)] Appended \(bufferCount) audio buffers to recognition request")
                }
                request.append(audioBuffer.buffer)
            }
            print("🎙️ [\(source)] Audio stream ended, total buffers: \(bufferCount)")
            request.endAudio()
        }
    }

    func stopTranscription(source: SpeakerType) async {
        recognitionTasks[source]?.cancel()
        recognitionTasks[source] = nil

        recognitionRequests[source]?.endAudio()
        recognitionRequests[source] = nil

        recognizers[source] = nil
    }

    func stopAll() async {
        for source in SpeakerType.allCases {
            await stopTranscription(source: source)
        }
    }
}
