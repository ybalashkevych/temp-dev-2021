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
    // MARK: - Start/Stop Microphone Tests

    @Test
    func startMicrophoneCreatesSession() async throws {
        // Arrange
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

        // Act
        try await repository.startMicrophone()

        // Assert
        let session = await repository.getCurrentSession()
        #expect(session != nil)
        #expect(session?.activeSources.contains(.microphone) == true)
        #expect(mockMicService.startCaptureCallCount == 1)
        #expect(mockTranscriptionService.startTranscriptionCallCount == 1)
    }

    @Test
    func stopMicrophoneStopsServices() async throws {
        // Arrange
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

        try await repository.startMicrophone()

        // Act
        await repository.stopMicrophone()

        // Assert
        #expect(mockMicService.stopCaptureCallCount == 1)
        #expect(mockTranscriptionService.stopTranscriptionCallCount == 1)
    }

    // MARK: - Start/Stop System Audio Tests

    @Test
    func startSystemAudioCreatesSession() async throws {
        // Arrange
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

        // Act
        try await repository.startSystemAudio()

        // Assert
        let session = await repository.getCurrentSession()
        #expect(session != nil)
        #expect(session?.activeSources.contains(.systemAudio) == true)
        #expect(mockSystemService.startCaptureCallCount == 1)
    }

    @Test
    func stopSystemAudioStopsServices() async throws {
        // Arrange
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

        try await repository.startSystemAudio()

        // Act
        await repository.stopSystemAudio()

        // Assert
        #expect(mockSystemService.stopCaptureCallCount == 1)
    }

    // MARK: - Clear Session Tests

    @Test
    func clearSessionRemovesData() async throws {
        // Arrange
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

        try await repository.startMicrophone()

        // Act
        await repository.clearSession()

        // Assert
        let session = await repository.getCurrentSession()
        #expect(session == nil)
    }

    // MARK: - Stop All Tests

    @Test
    func stopAllStopsAllServices() async throws {
        // Arrange
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

        try await repository.startMicrophone()
        try await repository.startSystemAudio()

        // Act
        await repository.stopAll()

        // Assert
        #expect(mockMicService.stopCaptureCallCount == 1)
        #expect(mockSystemService.stopCaptureCallCount == 1)
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

    func startTranscription(source: SpeakerType, audioStream: AsyncStream<AudioBuffer>) async -> AsyncStream<
        TranscriptionResult
    > {
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
