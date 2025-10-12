//
//  SystemAudioServiceProtocol.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Defines the interface for capturing system audio output.
protocol SystemAudioServiceProtocol: Sendable {
    /// Starts capturing system audio and returns a stream of audio buffers.
    /// - Returns: An async stream of audio buffers.
    /// - Throws: AudioServiceError if screen capture fails to start.
    func startCapture() async throws -> AsyncStream<AudioBuffer>

    /// Stops capturing system audio.
    func stopCapture() async

    /// Whether the service is currently capturing audio.
    var isCapturing: Bool { get async }
}
