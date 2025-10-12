//
//  MockTranscriptionRepository.swift
//  LiveAssistantTests
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation
@testable import LiveAssistant

/// Mock implementation of TranscriptionRepositoryProtocol for testing.
final class MockTranscriptionRepository: TranscriptionRepositoryProtocol {
    var startMicrophoneCallCount = 0
    var startSystemAudioCallCount = 0
    var stopAllCallCount = 0
    var stopMicrophoneCallCount = 0
    var stopSystemAudioCallCount = 0
    var clearSessionCallCount = 0

    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "test", code: -1)

    private var segmentContinuation: AsyncStream<TranscriptionSegment>.Continuation?
    var mockSession: TranscriptionSession?

    func startMicrophone() async throws {
        startMicrophoneCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
    }

    func startSystemAudio() async throws {
        startSystemAudioCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
    }

    func stopAll() async {
        stopAllCallCount += 1
    }

    func stopMicrophone() async {
        stopMicrophoneCallCount += 1
    }

    func stopSystemAudio() async {
        stopSystemAudioCallCount += 1
    }

    func streamSegments() -> AsyncStream<TranscriptionSegment> {
        AsyncStream { continuation in
            self.segmentContinuation = continuation
        }
    }

    func getCurrentSession() async -> TranscriptionSession? {
        mockSession
    }

    func clearSession() async {
        clearSessionCallCount += 1
        mockSession = nil
    }

    // Test helper to emit segments
    func emitSegment(_ segment: TranscriptionSegment) {
        segmentContinuation?.yield(segment)
    }
}
