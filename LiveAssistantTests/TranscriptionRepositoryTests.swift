//
//  TranscriptionRepositoryTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 18/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Testing

@testable import LiveAssistant

/// Tests for TranscriptionRepository.
@Suite
struct TranscriptionRepositoryTests {
    // MARK: - Helper Methods

    private func createRepository() -> (
        TranscriptionRepository, MockMicrophoneAudioService, MockSystemAudioService, MockTranscriptionService,
        MockTextAnalysisService
    ) {
        let mockMicService = MockMicrophoneAudioService()
        let mockSystemService = MockSystemAudioService()
        let mockTranscriptionService = MockTranscriptionService()
        let mockTextAnalysisService = MockTextAnalysisService()

        let repository = TranscriptionRepository(
            microphoneService: mockMicService,
            systemAudioService: mockSystemService,
            transcriptionService: mockTranscriptionService,
            textAnalysisService: mockTextAnalysisService
        )

        return (repository, mockMicService, mockSystemService, mockTranscriptionService, mockTextAnalysisService)
    }

    // MARK: - Microphone Tests

    @Test
    func startMicrophoneCreatesSession() async throws {
        let (repository, mockMic, _, mockTranscription, _) = createRepository()

        try await repository.startMicrophone()

        let session = await repository.getCurrentSession()
        #expect(session != nil)
        #expect(session?.activeSources.contains(.microphone) == true)
        #expect(mockMic.startCaptureCallCount == 1)
        #expect(mockTranscription.startTranscriptionCallCount == 1)
    }

    @Test
    func stopMicrophoneStopsServices() async throws {
        let (repository, mockMic, _, mockTranscription, _) = createRepository()

        try await repository.startMicrophone()
        await repository.stopMicrophone()

        #expect(mockMic.stopCaptureCallCount == 1)
        #expect(mockTranscription.stopTranscriptionCallCount == 1)
    }

    // MARK: - System Audio Tests

    @Test
    func startSystemAudioCreatesSession() async throws {
        let (repository, _, mockSystem, _, _) = createRepository()

        try await repository.startSystemAudio()

        let session = await repository.getCurrentSession()
        #expect(session != nil)
        #expect(session?.activeSources.contains(.systemAudio) == true)
        #expect(mockSystem.startCaptureCallCount == 1)
    }

    @Test
    func stopSystemAudioStopsServices() async throws {
        let (repository, _, mockSystem, _, _) = createRepository()

        try await repository.startSystemAudio()
        await repository.stopSystemAudio()

        #expect(mockSystem.stopCaptureCallCount == 1)
    }

    // MARK: - Session Management Tests

    @Test
    func clearSessionRemovesData() async throws {
        let (repository, _, _, _, _) = createRepository()

        try await repository.startMicrophone()
        await repository.clearSession()

        let session = await repository.getCurrentSession()
        #expect(session == nil)
    }

    @Test
    func stopAllStopsAllServices() async throws {
        let (repository, mockMic, mockSystem, _, _) = createRepository()

        try await repository.startMicrophone()
        try await repository.startSystemAudio()
        await repository.stopAll()

        #expect(mockMic.stopCaptureCallCount == 1)
        #expect(mockSystem.stopCaptureCallCount == 1)
    }
}

// MARK: - Mock Services

final class MockMicrophoneAudioService: MicrophoneAudioServiceProtocol {
    var startCaptureCallCount = 0
    var stopCaptureCallCount = 0
    var isCapturing: Bool { false }

    func startCapture() async throws -> AsyncStream<AudioBuffer> {
        startCaptureCallCount += 1
        return AsyncStream { _ in }
    }

    func stopCapture() async {
        stopCaptureCallCount += 1
    }
}

final class MockSystemAudioService: SystemAudioServiceProtocol {
    var startCaptureCallCount = 0
    var stopCaptureCallCount = 0
    var isCapturing: Bool { false }

    func startCapture() async throws -> AsyncStream<AudioBuffer> {
        startCaptureCallCount += 1
        return AsyncStream { _ in }
    }

    func stopCapture() async {
        stopCaptureCallCount += 1
    }
}

final class MockTranscriptionService: TranscriptionServiceProtocol {
    var startTranscriptionCallCount = 0
    var stopTranscriptionCallCount = 0
    var stopAllCallCount = 0

    func startTranscription(source: SpeakerType, audioStream: AsyncStream<AudioBuffer>) async -> AsyncStream<TranscriptionResult> {
        startTranscriptionCallCount += 1
        return AsyncStream { _ in }
    }

    func stopTranscription(source: SpeakerType) async {
        stopTranscriptionCallCount += 1
    }

    func stopAll() async {
        stopAllCallCount += 1
    }
}

final class MockTextAnalysisService: TextAnalysisServiceProtocol {
    var analyzeCallCount = 0
    var textToReturn = "Analyzed text"

    func analyze(text: String) async -> AnalyzedSegment {
        analyzeCallCount += 1
        return AnalyzedSegment(
            text: text,
            sentences: [text],
            isQuestion: false,
            normalizedText: textToReturn
        )
    }
}
