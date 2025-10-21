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
    // MARK: - Helper Types

    struct TestContext {
        let repository: TranscriptionRepository
        let mockMicService: MockMicrophoneAudioService
        let mockSystemService: MockSystemAudioService
        let mockTranscriptionService: MockTranscriptionService
        let mockTextAnalysisService: MockTextAnalysisService
    }

    // MARK: - Helper Methods

    private func createRepository() -> TestContext {
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

        return TestContext(
            repository: repository,
            mockMicService: mockMicService,
            mockSystemService: mockSystemService,
            mockTranscriptionService: mockTranscriptionService,
            mockTextAnalysisService: mockTextAnalysisService
        )
    }

    // MARK: - Microphone Tests

    @Test
    func startMicrophoneCreatesSession() async throws {
        let context = createRepository()

        try await context.repository.startMicrophone()

        let session = await context.repository.getCurrentSession()
        #expect(session != nil)
        #expect(session?.activeSources.contains(.microphone) == true)
        #expect(context.mockMicService.startCaptureCallCount == 1)
        #expect(context.mockTranscriptionService.startTranscriptionCallCount == 1)
    }

    @Test
    func stopMicrophoneStopsServices() async throws {
        let context = createRepository()

        try await context.repository.startMicrophone()
        await context.repository.stopMicrophone()

        #expect(context.mockMicService.stopCaptureCallCount == 1)
        #expect(context.mockTranscriptionService.stopTranscriptionCallCount == 1)
    }

    // MARK: - System Audio Tests

    @Test
    func startSystemAudioCreatesSession() async throws {
        let context = createRepository()

        try await context.repository.startSystemAudio()

        let session = await context.repository.getCurrentSession()
        #expect(session != nil)
        #expect(session?.activeSources.contains(.systemAudio) == true)
        #expect(context.mockSystemService.startCaptureCallCount == 1)
    }

    @Test
    func stopSystemAudioStopsServices() async throws {
        let context = createRepository()

        try await context.repository.startSystemAudio()
        await context.repository.stopSystemAudio()

        #expect(context.mockSystemService.stopCaptureCallCount == 1)
    }

    // MARK: - Session Management Tests

    @Test
    func clearSessionRemovesData() async throws {
        let context = createRepository()

        try await context.repository.startMicrophone()
        await context.repository.clearSession()

        let session = await context.repository.getCurrentSession()
        #expect(session == nil)
    }

    @Test
    func stopAllStopsAllServices() async throws {
        let context = createRepository()

        try await context.repository.startMicrophone()
        try await context.repository.startSystemAudio()
        await context.repository.stopAll()

        #expect(context.mockMicService.stopCaptureCallCount == 1)
        #expect(context.mockSystemService.stopCaptureCallCount == 1)
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
