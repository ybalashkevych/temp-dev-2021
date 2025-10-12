//
//  TranscriptionServiceProtocol.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Defines the interface for speech transcription services.
protocol TranscriptionServiceProtocol: Sendable {
    /// Starts transcription for the given audio stream.
    /// - Parameters:
    ///   - source: The speaker type (microphone or system audio).
    ///   - audioStream: An async stream of audio buffers to transcribe.
    /// - Returns: An async stream of transcription results (partial and final).
    func startTranscription(
        source: SpeakerType,
        audioStream: AsyncStream<AudioBuffer>
    ) async -> AsyncStream<TranscriptionResult>

    /// Stops transcription for the given source.
    /// - Parameter source: The speaker type to stop transcribing.
    func stopTranscription(source: SpeakerType) async

    /// Stops all active transcriptions.
    func stopAll() async
}

/// Errors that can occur during transcription.
enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case recognitionFailed(String)
    case audioProcessingFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is unavailable"
        case let .recognitionFailed(message):
            return "Recognition failed: \(message)"
        case .audioProcessingFailed:
            return "Failed to process audio"
        case .permissionDenied:
            return "Speech recognition permission denied"
        }
    }
}
