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
    private nonisolated(unsafe) var streamOutput: SystemAudioStreamOutput?
    private nonisolated(unsafe) var videoOutput: SystemVideoStreamOutput?
    private nonisolated(unsafe) var streamDelegate: SystemAudioStreamDelegate?
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

        // Audio-specific configuration
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true  // Prevent feedback
        configuration.sampleRate = 16000  // 16kHz for speech recognition
        configuration.channelCount = 1  // Mono

        // Don't configure video properties - we only want audio
        print("🎵 Configured for audio-only capture")

        print("🎵 System audio configuration: sampleRate=\(configuration.sampleRate), channels=\(configuration.channelCount)")

        // Create async stream for audio buffers
        let audioBufferStream = AsyncStream<AudioBuffer> { continuation in
            self.audioStream = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopCapture()
                }
            }
        }

        // Create and retain delegate
        let delegate = SystemAudioStreamDelegate()
        streamDelegate = delegate

        // Create the stream with delegate
        let captureStream = SCStream(filter: filter, configuration: configuration, delegate: delegate)
        stream = captureStream

        // Add audio output handler - must retain the output handler!
        let audioOutputHandler = SystemAudioStreamOutput(continuation: audioStream)
        streamOutput = audioOutputHandler
        try captureStream.addStreamOutput(
            audioOutputHandler,
            type: .audio,
            sampleHandlerQueue: DispatchQueue(label: "com.liveassistant.systemaudio.audio")
        )
        print("✅ Audio output handler added and retained")

        // Add video output handler to consume and discard video frames
        let videoOutputHandler = SystemVideoStreamOutput()
        videoOutput = videoOutputHandler
        try captureStream.addStreamOutput(
            videoOutputHandler,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "com.liveassistant.systemaudio.video")
        )
        print("✅ Video output handler added (will discard frames)")

        // Start the stream
        try await captureStream.startCapture()
        _isCapturing = true
        print("✅ System audio stream started successfully")

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
        streamOutput = nil
        videoOutput = nil
        streamDelegate = nil
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
        guard type == .audio else {
            return
        }

        guard let pcmBuffer = convertToAudioBuffer(sampleBuffer) else {
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let audioBuffer = AudioBuffer(buffer: pcmBuffer, timestamp: timestamp)

        continuation?.yield(audioBuffer)
    }

    private func convertToAudioBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        else {
            return nil
        }

        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: asbd.mSampleRate,
                channels: AVAudioChannelCount(asbd.mChannelsPerFrame),
                interleaved: false
            )
        else {
            return nil
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let dataPointer = dataPointer else {
            return nil
        }

        let frameCount = AVAudioFrameCount(length) / format.streamDescription.pointee.mBytesPerFrame
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        pcmBuffer.frameLength = frameCount
        memcpy(pcmBuffer.audioBufferList.pointee.mBuffers.mData, dataPointer, Int(length))

        return pcmBuffer
    }
}

// MARK: - Video Output Handler (Discards frames)

private final class SystemVideoStreamOutput: NSObject, SCStreamOutput {
    func stream(_: SCStream, didOutputSampleBuffer _: CMSampleBuffer, of type: SCStreamOutputType) {
        // Silently discard video frames - we only want audio
        if type == .screen {
            // Video frame received and discarded
        }
    }
}

// MARK: - Stream Delegate

private final class SystemAudioStreamDelegate: NSObject, SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("⚠️ SCStream stopped with error: \(error.localizedDescription)")
    }
}
