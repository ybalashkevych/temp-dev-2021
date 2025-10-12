//
//  TranscriptionRepositoryProtocol.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Defines the interface for managing transcription sessions and audio sources.
protocol TranscriptionRepositoryProtocol: Sendable {
    /// Starts capturing and transcribing microphone audio.
    func startMicrophone() async throws

    /// Starts capturing and transcribing system audio.
    func startSystemAudio() async throws

    /// Stops all active transcriptions and audio capture.
    func stopAll() async

    /// Stops microphone transcription.
    func stopMicrophone() async

    /// Stops system audio transcription.
    func stopSystemAudio() async

    /// Returns a stream of transcription segments as they are recognized.
    func streamSegments() -> AsyncStream<TranscriptionSegment>

    /// Returns the current transcription session.
    func getCurrentSession() async -> TranscriptionSession?

    /// Clears the current session and all segments.
    func clearSession() async
}
