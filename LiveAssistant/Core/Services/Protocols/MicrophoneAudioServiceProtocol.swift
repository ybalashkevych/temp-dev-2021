//
//  MicrophoneAudioServiceProtocol.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Defines the interface for capturing microphone audio.
protocol MicrophoneAudioServiceProtocol: Sendable {
    /// Starts capturing audio from the microphone and returns a stream of audio buffers.
    /// - Returns: An async stream of audio buffers.
    /// - Throws: AudioServiceError if the audio engine fails to start.
    func startCapture() async throws -> AsyncStream<AudioBuffer>

    /// Stops capturing audio from the microphone.
    func stopCapture() async

    /// Whether the service is currently capturing audio.
    var isCapturing: Bool { get async }
}

/// Errors that can occur during audio capture.
enum AudioServiceError: LocalizedError {
    case engineStartFailed
    case inputNodeUnavailable
    case formatConversionFailed
    case captureSessionFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .engineStartFailed:
            return "Failed to start audio engine"
        case .inputNodeUnavailable:
            return "Microphone input is unavailable"
        case .formatConversionFailed:
            return "Failed to convert audio format"
        case .captureSessionFailed:
            return "Failed to start capture session"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}
