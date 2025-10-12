//
//  TranscriptionRepository.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Repository for managing transcription sessions and coordinating audio/transcription services.
final class TranscriptionRepository: TranscriptionRepositoryProtocol, @unchecked Sendable {
    private let microphoneService: MicrophoneAudioServiceProtocol
    private let systemAudioService: SystemAudioServiceProtocol
    private let transcriptionService: TranscriptionServiceProtocol
    private let textAnalysisService: TextAnalysisServiceProtocol

    private nonisolated(unsafe) var currentSession: TranscriptionSession?
    private nonisolated(unsafe) var segmentContinuations: [UUID: AsyncStream<TranscriptionSegment>.Continuation] = [:]
    private nonisolated(unsafe) var activeTasks: [Task<Void, Never>] = []

    init(
        microphoneService: MicrophoneAudioServiceProtocol,
        systemAudioService: SystemAudioServiceProtocol,
        transcriptionService: TranscriptionServiceProtocol,
        textAnalysisService: TextAnalysisServiceProtocol
    ) {
        self.microphoneService = microphoneService
        self.systemAudioService = systemAudioService
        self.transcriptionService = transcriptionService
        self.textAnalysisService = textAnalysisService
    }

    func startMicrophone() async throws {
        // Ensure we have a session
        if currentSession == nil {
            currentSession = TranscriptionSession()
        }

        // Start microphone capture
        let audioStream = try await microphoneService.startCapture()

        // Start transcription for microphone
        let transcriptionStream = await transcriptionService.startTranscription(
            source: .microphone,
            audioStream: audioStream
        )

        // Process transcription results
        let task = Task {
            for await result in transcriptionStream {
                await processTranscriptionResult(result, speaker: .microphone)
            }
        }

        activeTasks.append(task)
        currentSession?.activeSources.insert(.microphone)
    }

    func startSystemAudio() async throws {
        // Ensure we have a session
        if currentSession == nil {
            currentSession = TranscriptionSession()
        }

        // Start system audio capture
        let audioStream = try await systemAudioService.startCapture()

        // Start transcription for system audio
        let transcriptionStream = await transcriptionService.startTranscription(
            source: .systemAudio,
            audioStream: audioStream
        )

        // Process transcription results
        let task = Task {
            for await result in transcriptionStream {
                await processTranscriptionResult(result, speaker: .systemAudio)
            }
        }

        activeTasks.append(task)
        currentSession?.activeSources.insert(.systemAudio)
    }

    func stopAll() async {
        await stopMicrophone()
        await stopSystemAudio()

        // Cancel all processing tasks
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    func stopMicrophone() async {
        await microphoneService.stopCapture()
        await transcriptionService.stopTranscription(source: .microphone)
        currentSession?.activeSources.remove(.microphone)
    }

    func stopSystemAudio() async {
        await systemAudioService.stopCapture()
        await transcriptionService.stopTranscription(source: .systemAudio)
        currentSession?.activeSources.remove(.systemAudio)
    }

    func streamSegments() -> AsyncStream<TranscriptionSegment> {
        AsyncStream { continuation in
            let id = UUID()
            self.segmentContinuations[id] = continuation

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in
                    self?.segmentContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    func getCurrentSession() async -> TranscriptionSession? {
        currentSession
    }

    func clearSession() async {
        await stopAll()
        currentSession = nil
    }

    // MARK: - Private Methods

    private func processTranscriptionResult(_ result: TranscriptionResult, speaker: SpeakerType) async {
        // Analyze the text
        let analyzed = await textAnalysisService.analyze(text: result.text)

        // Create transcription segment
        let segment = TranscriptionSegment(
            text: analyzed.normalizedText,
            startTime: result.startTime,
            endTime: result.endTime,
            confidence: result.confidence,
            isFinal: result.isFinal,
            speaker: speaker,
            isQuestion: analyzed.isQuestion
        )

        // Add to session
        if result.isFinal {
            currentSession?.segments.append(segment)
        }

        // Broadcast to all listeners
        for continuation in segmentContinuations.values {
            continuation.yield(segment)
        }
    }
}
