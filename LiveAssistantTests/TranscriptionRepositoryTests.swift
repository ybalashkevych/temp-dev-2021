//
//  TranscriptionRepositoryTests.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 12/10/2025.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Testing

@testable import LiveAssistant

/// Tests for TranscriptionRepository demonstrating complex repository testing.
@Suite
struct TranscriptionRepositoryTests {
    
    // MARK: - Test Setup
    
    private func createMockServices() -> (
        microphoneService: MockMicrophoneAudioService,
        systemAudioService: MockSystemAudioService,
        transcriptionService: MockTranscriptionService,
        textAnalysisService: MockTextAnalysisService
    ) {
        return (
            microphoneService: MockMicrophoneAudioService(),
            systemAudioService: MockSystemAudioService(),
            transcriptionService: MockTranscriptionService(),
            textAnalysisService: MockTextAnalysisService()
        )
    }
    
    // MARK: - Microphone Tests
    
    @Test
    func startMicrophoneSuccessfully() async throws {
        // Arrange
        let mocks = createMockServices()
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        // Act
        try await repository.startMicrophone()
        
        // Assert
        #expect(mocks.microphoneService.startCallCount == 1)
        #expect(mocks.transcriptionService.startCallCount == 1)
    }
    
    @Test
    func startMicrophoneWithError() async throws {
        // Arrange
        let mocks = createMockServices()
        mocks.microphoneService.shouldThrowError = true
        mocks.microphoneService.errorToThrow = AudioServiceError.microphoneAccessDenied
        
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        // Act & Assert
        do {
            try await repository.startMicrophone()
            #expect(Bool(false), "Expected AudioServiceError to be thrown")
        } catch let error as AudioServiceError {
            #expect(error == .microphoneAccessDenied)
        } catch {
            #expect(Bool(false), "Expected AudioServiceError, got \(type(of: error))")
        }
    }
    
    @Test
    func stopMicrophoneSuccessfully() async throws {
        // Arrange
        let mocks = createMockServices()
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        // Act
        await repository.stopMicrophone()
        
        // Assert
        #expect(mocks.microphoneService.stopCallCount == 1)
        #expect(mocks.transcriptionService.stopCallCount == 1)
    }
    
    // MARK: - System Audio Tests
    
    @Test
    func startSystemAudioSuccessfully() async throws {
        // Arrange
        let mocks = createMockServices()
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        // Act
        try await repository.startSystemAudio()
        
        // Assert
        #expect(mocks.systemAudioService.startCallCount == 1)
        #expect(mocks.transcriptionService.startCallCount == 1)
    }
    
    @Test
    func stopSystemAudioSuccessfully() async throws {
        // Arrange
        let mocks = createMockServices()
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        // Act
        await repository.stopSystemAudio()
        
        // Assert
        #expect(mocks.systemAudioService.stopCallCount == 1)
        #expect(mocks.transcriptionService.stopCallCount == 1)
    }
    
    // MARK: - Stop All Tests
    
    @Test
    func stopAllSuccessfully() async throws {
        // Arrange
        let mocks = createMockServices()
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        // Act
        await repository.stopAll()
        
        // Assert
        #expect(mocks.microphoneService.stopCallCount == 1)
        #expect(mocks.systemAudioService.stopCallCount == 1)
        #expect(mocks.transcriptionService.stopCallCount == 1)
    }
    
    // MARK: - Segment Streaming Tests
    
    @Test
    func streamSegmentsSuccessfully() async throws {
        // Arrange
        let mocks = createMockServices()
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        let expectedSegment = TranscriptionSegment(
            text: "Test transcription",
            startTime: 0.0,
            endTime: 1.0,
            confidence: 0.95,
            isFinal: true,
            speaker: .microphone
        )
        
        // Act
        let stream = repository.streamSegments()
        
        // Simulate segment emission
        mocks.transcriptionService.emitSegment(expectedSegment)
        
        // Collect segments
        var receivedSegments: [TranscriptionSegment] = []
        for await segment in stream {
            receivedSegments.append(segment)
            if receivedSegments.count >= 1 {
                break // Stop after receiving one segment
            }
        }
        
        // Assert
        #expect(receivedSegments.count == 1)
        #expect(receivedSegments.first?.text == expectedSegment.text)
    }
    
    // MARK: - Session Management Tests
    
    @Test
    func clearSessionSuccessfully() async throws {
        // Arrange
        let mocks = createMockServices()
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        // Act
        await repository.clearSession()
        
        // Assert
        #expect(mocks.transcriptionService.clearCallCount == 1)
    }
    
    // MARK: - Quality Metrics Tests
    
    @Test
    func getQualityMetricsSuccessfully() async throws {
        // Arrange
        let mocks = createMockServices()
        let repository = TranscriptionRepository(
            microphoneService: mocks.microphoneService,
            systemAudioService: mocks.systemAudioService,
            transcriptionService: mocks.transcriptionService,
            textAnalysisService: mocks.textAnalysisService
        )
        
        let expectedMetrics: [SpeakerType: [TranscriptionResult]] = [
            .microphone: [
                TranscriptionResult(text: "Test", confidence: 0.95, isFinal: true)
            ]
        ]
        mocks.transcriptionService.qualityMetricsToReturn = expectedMetrics
        
        // Act
        let metrics = await repository.getQualityMetrics()
        
        // Assert
        #expect(metrics.count == 1)
        #expect(metrics[.microphone]?.count == 1)
    }
}

// MARK: - Mock Services

private class MockMicrophoneAudioService: MicrophoneAudioServiceProtocol {
    var startCallCount = 0
    var stopCallCount = 0
    var shouldThrowError = false
    var errorToThrow: Error = AudioServiceError.microphoneAccessDenied
    
    func start() async throws {
        startCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    func stop() async {
        stopCallCount += 1
    }
}

private class MockSystemAudioService: SystemAudioServiceProtocol {
    var startCallCount = 0
    var stopCallCount = 0
    var shouldThrowError = false
    var errorToThrow: Error = AudioServiceError.systemAudioAccessDenied
    
    func start() async throws {
        startCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
    }
    
    func stop() async {
        stopCallCount += 1
    }
}

private class MockTranscriptionService: TranscriptionServiceProtocol {
    var startCallCount = 0
    var stopCallCount = 0
    var clearCallCount = 0
    var qualityMetricsToReturn: [SpeakerType: [TranscriptionResult]] = [:]
    
    private var segmentContinuation: AsyncStream<TranscriptionSegment>.Continuation?
    private var segmentStream: AsyncStream<TranscriptionSegment>?
    
    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: TranscriptionSegment.self)
        self.segmentStream = stream
        self.segmentContinuation = continuation
    }
    
    func start() async throws {
        startCallCount += 1
    }
    
    func stop() async {
        stopCallCount += 1
    }
    
    func clear() async {
        clearCallCount += 1
    }
    
    func streamSegments() -> AsyncStream<TranscriptionSegment> {
        return segmentStream!
    }
    
    func getQualityMetrics() async -> [SpeakerType: [TranscriptionResult]] {
        return qualityMetricsToReturn
    }
    
    func emitSegment(_ segment: TranscriptionSegment) {
        segmentContinuation?.yield(segment)
    }
}

private class MockTextAnalysisService: TextAnalysisServiceProtocol {
    var analyzeCallCount = 0
    var textToAnalyze: String = ""
    
    func analyze(_ text: String) async -> TextAnalysisResult {
        analyzeCallCount += 1
        textToAnalyze = text
        return TextAnalysisResult(
            sentiment: .neutral,
            keywords: [],
            confidence: 0.8
        )
    }
}

// MARK: - Error Types

private enum AudioServiceError: Error {
    case microphoneAccessDenied
    case systemAudioAccessDenied
}