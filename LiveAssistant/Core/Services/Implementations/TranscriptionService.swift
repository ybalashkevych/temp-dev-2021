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
    private nonisolated(unsafe) var recognizers: [SpeakerType: SFSpeechRecognizer] = [:]
    private nonisolated(unsafe) var recognitionTasks: [SpeakerType: SFSpeechRecognitionTask] = [:]
    private nonisolated(unsafe) var recognitionRequests: [SpeakerType: SFSpeechAudioBufferRecognitionRequest] = [:]

    func startTranscription(
        source: SpeakerType,
        audioStream: AsyncStream<AudioBuffer>
    ) async -> AsyncStream<TranscriptionResult> {
        print("🎙️ [\(source)] Starting transcription service")

        guard let recognizer = createOrGetRecognizer(for: source) else {
            print("❌ [\(source)] Speech recognizer not available")
            return AsyncStream { continuation in
                continuation.finish()
            }
        }

        print("✅ [\(source)] Speech recognizer is available")

        let request = createRecognitionRequest(for: source)

        return createResultStream(for: source, recognizer: recognizer, request: request, audioStream: audioStream)
    }

    private func createOrGetRecognizer(for source: SpeakerType) -> SFSpeechRecognizer? {
        if recognizers[source] == nil {
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            recognizer?.defaultTaskHint = .dictation
            recognizers[source] = recognizer
            print("🎙️ [\(source)] Created speech recognizer for locale: en-US")
        }

        guard let recognizer = recognizers[source], recognizer.isAvailable else {
            return nil
        }

        return recognizer
    }

    private func createRecognitionRequest(for source: SpeakerType) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        request.addsPunctuation = true
        recognitionRequests[source] = request
        print("🎙️ [\(source)] Created recognition request (partialResults=true, onDevice=false, punctuation=true)")
        return request
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
            let confidence = transcription.segments.first?.confidence ?? 0.0

            let startTime = result.speechRecognitionMetadata?.speechStartTimestamp ?? 0.0
            let duration = result.speechRecognitionMetadata?.speechDuration ?? 0.0
            let endTime = startTime + duration

            let transcriptionResult = TranscriptionResult(
                text: text,
                startTime: startTime,
                endTime: endTime,
                confidence: Double(confidence),
                isFinal: result.isFinal
            )

            let finalIndicator = result.isFinal ? "FINAL" : "partial"
            print("📝 [\(source)] [\(finalIndicator)] Transcription: \"\(text)\" (confidence: \(confidence))")

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
