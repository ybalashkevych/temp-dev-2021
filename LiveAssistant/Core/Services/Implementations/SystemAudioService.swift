//
//  SystemAudioService.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

@preconcurrency import AVFoundation
import Foundation
import ScreenCaptureKit

/// Service for capturing system audio output using ScreenCaptureKit.
final class SystemAudioService: SystemAudioServiceProtocol, @unchecked Sendable {
    private nonisolated(unsafe) var stream: SCStream?
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

        // Get available content
        let availableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = availableContent.displays.first else {
            throw AudioServiceError.captureSessionFailed
        }

        // Configure stream to capture only audio
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.sampleRate = 16000  // 16kHz for speech recognition
        configuration.channelCount = 1  // Mono

        // Create the stream
        let captureStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        stream = captureStream

        // Create async stream for audio buffers
        let audioBufferStream = AsyncStream<AudioBuffer> { continuation in
            self.audioStream = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopCapture()
                }
            }
        }

        // Add audio output handler
        try captureStream.addStreamOutput(
            SystemAudioStreamOutput(continuation: audioStream),
            type: .audio,
            sampleHandlerQueue: DispatchQueue(label: "com.liveassistant.systemaudio")
        )

        // Start the stream
        try await captureStream.startCapture()
        _isCapturing = true

        return audioBufferStream
    }

    func stopCapture() async {
        guard _isCapturing else { return }

        if let stream = stream {
            do {
                try await stream.stopCapture()
            } catch {
                // Ignore errors during stop
            }
        }

        audioStream?.finish()
        audioStream = nil
        stream = nil
        _isCapturing = false
    }
}

// MARK: - Stream Output Handler

private final class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    var continuation: AsyncStream<AudioBuffer>.Continuation?

    init(continuation: AsyncStream<AudioBuffer>.Continuation?) {
        self.continuation = continuation
        super.init()
    }

    func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // Convert CMSampleBuffer to AVAudioPCMBuffer
        guard
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        else {
            return
        }

        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: asbd.mSampleRate,
                channels: AVAudioChannelCount(asbd.mChannelsPerFrame),
                interleaved: false
            )
        else {
            return
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let dataPointer = dataPointer else {
            return
        }

        let frameCount = AVAudioFrameCount(length) / format.streamDescription.pointee.mBytesPerFrame
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }

        pcmBuffer.frameLength = frameCount
        memcpy(pcmBuffer.audioBufferList.pointee.mBuffers.mData, dataPointer, Int(length))

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let audioBuffer = AudioBuffer(buffer: pcmBuffer, timestamp: timestamp)

        continuation?.yield(audioBuffer)
    }
}
