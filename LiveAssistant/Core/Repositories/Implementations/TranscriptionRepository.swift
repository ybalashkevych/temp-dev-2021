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
    private nonisolated(unsafe) var qualityMetrics: [SpeakerType: [TranscriptionResult]] = [:]
    private nonisolated(unsafe) var sessionStartTime: Date?

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
        print("🎙️ [Repository] startMicrophone() called")

        // Ensure we have a session
        if currentSession == nil {
            currentSession = TranscriptionSession()
            sessionStartTime = Date()
            print("📝 [Repository] Created new transcription session")
        }

        // Initialize quality tracking
        if qualityMetrics[.microphone] == nil {
            qualityMetrics[.microphone] = []
        }

        // Start microphone capture
        print("🎙️ [Repository] Starting microphone capture...")
        let audioStream = try await microphoneService.startCapture()
        print("✅ [Repository] Microphone capture started")

        // Start transcription for microphone
        print("🎙️ [Repository] Starting transcription service for microphone...")
        let transcriptionStream = await transcriptionService.startTranscription(
            source: .microphone,
            audioStream: audioStream
        )
        print("✅ [Repository] Transcription service started for microphone")

        // Process transcription results
        let task = Task {
            print("🎙️ [Repository] Waiting for transcription results from microphone...")
            var resultCount = 0
            for await result in transcriptionStream {
                resultCount += 1
                if resultCount == 1 {
                    print("🎙️ [Repository] Received first transcription result from microphone!")
                }
                await processTranscriptionResult(result, speaker: .microphone)
            }
            print("🎙️ [Repository] Microphone transcription stream ended, total results: \(resultCount)")
        }

        activeTasks.append(task)
        currentSession?.activeSources.insert(.microphone)
        print("✅ [Repository] Microphone is now active")
    }

    func startSystemAudio() async throws {
        // Ensure we have a session
        if currentSession == nil {
            currentSession = TranscriptionSession()
            sessionStartTime = Date()
        }

        // Initialize quality tracking
        if qualityMetrics[.systemAudio] == nil {
            qualityMetrics[.systemAudio] = []
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
                Task { @MainActor [weak self] in
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
        qualityMetrics.removeAll()
        sessionStartTime = nil
    }

    // MARK: - Private Methods

    private func processTranscriptionResult(_ result: TranscriptionResult, speaker: SpeakerType) async {
        print("🔄 [Repository] Processing result for [\(speaker)]: \"\(result.text)\" (isFinal: \(result.isFinal))")

        // Track result for quality metrics
        if qualityMetrics[speaker] != nil {
            qualityMetrics[speaker]?.append(result)
        }

        // Analyze the text
        let analyzed = await textAnalysisService.analyze(text: result.text)
        print("🔍 [Repository] After analysis: \"\(analyzed.normalizedText)\" (isQuestion: \(analyzed.isQuestion))")

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
            print("✅ [Repository] Added FINAL segment to session")
        } else {
            print("⏳ [Repository] Partial segment, not adding to session yet")
        }

        // Broadcast to all listeners
        let listenerCount = segmentContinuations.count
        print("📢 [Repository] Broadcasting segment to \(listenerCount) listeners")
        for continuation in segmentContinuations.values {
            continuation.yield(segment)
        }
    }

    /// Gets quality metrics for a specific speaker.
    func getQualityMetrics(for speaker: SpeakerType) -> TranscriptionQuality? {
        guard let results = qualityMetrics[speaker],
            !results.isEmpty,
            let startTime = sessionStartTime
        else {
            return nil
        }

        return TranscriptionQuality.from(
            results: results,
            recognitionMode: "Cloud-First",  // Dynamically set from TranscriptionService
            startTime: startTime,
            endTime: Date()
        )
    }

    /// Gets combined quality metrics for all active speakers.
    func getCombinedQualityMetrics() -> TranscriptionQuality? {
        let allResults = qualityMetrics.values.flatMap { $0 }
        guard !allResults.isEmpty, let startTime = sessionStartTime else {
            return nil
        }

        return TranscriptionQuality.from(
            results: allResults,
            recognitionMode: "Cloud-First",
            startTime: startTime,
            endTime: Date()
        )
    }
}
