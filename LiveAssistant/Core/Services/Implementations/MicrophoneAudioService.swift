//
//  MicrophoneAudioService.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

@preconcurrency import AVFoundation
import Foundation

/// Service for capturing audio from the microphone using AVAudioEngine.
final class MicrophoneAudioService: MicrophoneAudioServiceProtocol, @unchecked Sendable {
    private nonisolated(unsafe) let audioEngine = AVAudioEngine()
    private nonisolated(unsafe) var audioStream: AsyncStream<AudioBuffer>.Continuation?

    private var _isCapturing = false

    var isCapturing: Bool {
        get async {
            _isCapturing
        }
    }

    func startCapture() async throws -> AsyncStream<AudioBuffer> {
        guard !_isCapturing else {
            throw AudioServiceError.engineStartFailed
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioServiceError.inputNodeUnavailable
        }

        // Create the stream
        let stream = AsyncStream<AudioBuffer> { continuation in
            self.audioStream = continuation

            // Install tap on the input node
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, time in
                let audioBuffer = AudioBuffer(buffer: buffer, timestamp: time.audioTimeStamp.mSampleTime)
                continuation.yield(audioBuffer)
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopCapture()
                }
            }
        }

        // Start the audio engine
        audioEngine.prepare()
        try audioEngine.start()
        _isCapturing = true

        return stream
    }

    func stopCapture() async {
        guard _isCapturing else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioStream?.finish()
        audioStream = nil
        _isCapturing = false
    }
}
