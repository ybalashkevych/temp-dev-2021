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
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        // Explicitly disable video capture (audio only)
        configuration.width = 1
        configuration.height = 1
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false

        print("🎵 Configured for audio-only capture (video disabled)")

        print("🎵 System audio configuration: sampleRate=\(configuration.sampleRate), channels=\(configuration.channelCount)")

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

        // Add audio output handler - must retain the output handler!
        let outputHandler = SystemAudioStreamOutput(continuation: audioStream)
        streamOutput = outputHandler
        try captureStream.addStreamOutput(
            outputHandler,
            type: .audio,
            sampleHandlerQueue: DispatchQueue(label: "com.liveassistant.systemaudio")
        )
        print("✅ Stream output handler added and retained")

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
            print("⚠️ Non-audio buffer received: \(type)")
            return
        }

        print("🎵 Audio sample buffer received")

        guard let pcmBuffer = convertToAudioBuffer(sampleBuffer) else {
            return
        }

        verifyAndLogAudioLevel(pcmBuffer)

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let audioBuffer = AudioBuffer(buffer: pcmBuffer, timestamp: timestamp)

        continuation?.yield(audioBuffer)
        print("✅ Audio buffer yielded to stream")
    }

    private func convertToAudioBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        else {
            print("❌ Failed to get format description")
            return nil
        }

        print("🎵 Audio format: sampleRate=\(asbd.mSampleRate), channels=\(asbd.mChannelsPerFrame), bitsPerChannel=\(asbd.mBitsPerChannel)")

        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: asbd.mSampleRate,
                channels: AVAudioChannelCount(asbd.mChannelsPerFrame),
                interleaved: false
            )
        else {
            print("❌ Failed to create AVAudioFormat")
            return nil
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            print("❌ Failed to get block buffer from sample buffer")
            return nil
        }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let dataPointer = dataPointer else {
            print("❌ Failed to get data pointer from block buffer")
            return nil
        }

        print("🎵 Block buffer length: \(length) bytes")

        let frameCount = AVAudioFrameCount(length) / format.streamDescription.pointee.mBytesPerFrame
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("❌ Failed to create PCM buffer with frameCapacity: \(frameCount)")
            return nil
        }

        pcmBuffer.frameLength = frameCount
        memcpy(pcmBuffer.audioBufferList.pointee.mBuffers.mData, dataPointer, Int(length))

        return pcmBuffer
    }

    private func verifyAndLogAudioLevel(_ pcmBuffer: AVAudioPCMBuffer) {
        guard pcmBuffer.frameLength > 0,
            let channelData = pcmBuffer.floatChannelData
        else {
            print("⚠️ Empty or invalid audio buffer")
            return
        }

        let firstSamples = UnsafeBufferPointer(start: channelData[0], count: min(Int(pcmBuffer.frameLength), 100))
        let avgAmplitude = firstSamples.reduce(0.0) { $0 + abs($1) } / Float(firstSamples.count)

        if avgAmplitude > 0.001 {
            print("🔊 Audio detected: amplitude=\(avgAmplitude), frames=\(pcmBuffer.frameLength)")
        } else {
            print("🔇 Silent audio: amplitude=\(avgAmplitude), frames=\(pcmBuffer.frameLength)")
        }
    }
}
