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
        // Create recognizer for this source if needed
        if recognizers[source] == nil {
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            recognizer?.defaultTaskHint = .dictation
            recognizers[source] = recognizer
        }

        guard let recognizer = recognizers[source], recognizer.isAvailable else {
            return AsyncStream { continuation in
                continuation.finish()
            }
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        request.addsPunctuation = true
        recognitionRequests[source] = request

        // Create result stream
        let resultStream = AsyncStream<TranscriptionResult> { continuation in
            // Start recognition task
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let transcription = result.bestTranscription
                    let text = transcription.formattedString
                    let confidence = transcription.segments.first?.confidence ?? 0.0

                    // Calculate timing
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

                    continuation.yield(transcriptionResult)

                    if result.isFinal {
                        continuation.finish()
                    }
                }

                if let error = error {
                    print("Recognition error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }

            self.recognitionTasks[source] = task

            // Feed audio buffers to the request
            Task {
                for await audioBuffer in audioStream {
                    request.append(audioBuffer.buffer)
                }
                request.endAudio()
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopTranscription(source: source)
                }
            }
        }

        return resultStream
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
