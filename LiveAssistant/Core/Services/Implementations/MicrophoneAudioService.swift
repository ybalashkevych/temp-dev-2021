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
    private nonisolated(unsafe) var audioConverter: AVAudioConverter?

    private var _isCapturing = false

    var isCapturing: Bool {
        get async {
            _isCapturing
        }
    }

    func startCapture() async throws -> AsyncStream<AudioBuffer> {
        print("🎤 [Microphone] startCapture() called")

        guard !_isCapturing else {
            print("❌ [Microphone] Already capturing")
            throw AudioServiceError.engineStartFailed
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        try validateInputFormat(inputFormat)

        let outputFormat = try createOutputFormat()
        let converter = try createAudioConverter(from: inputFormat, to: outputFormat)

        let stream = createAudioStream(inputNode: inputNode, inputFormat: inputFormat, outputFormat: outputFormat, converter: converter)

        try startAudioEngine()

        return stream
    }

    private func validateInputFormat(_ format: AVAudioFormat) throws {
        print("🎤 [Microphone] Input format: sampleRate=\(format.sampleRate), channels=\(format.channelCount)")

        guard format.sampleRate > 0 else {
            print("❌ [Microphone] Invalid sample rate")
            throw AudioServiceError.inputNodeUnavailable
        }
    }

    private func createOutputFormat() throws -> AVAudioFormat {
        guard
            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            )
        else {
            print("❌ [Microphone] Failed to create output format")
            throw AudioServiceError.engineStartFailed
        }
        return format
    }

    private func createAudioConverter(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) throws -> AVAudioConverter {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            print("❌ [Microphone] Failed to create audio converter")
            throw AudioServiceError.engineStartFailed
        }

        audioConverter = converter
        print("🎤 [Microphone] Created audio converter: \(inputFormat.sampleRate)Hz → 16000Hz")

        return converter
    }

    private func createAudioStream(
        inputNode: AVAudioInputNode,
        inputFormat: AVAudioFormat,
        outputFormat: AVAudioFormat,
        converter: AVAudioConverter
    ) -> AsyncStream<AudioBuffer> {
        var bufferCount = 0

        return AsyncStream<AudioBuffer> { continuation in
            self.audioStream = continuation

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
                guard let self = self else { return }

                bufferCount += 1
                self.logBufferCapture(count: bufferCount)

                guard let convertedBuffer = self.convertAndLogBuffer(buffer, count: bufferCount, using: converter, to: outputFormat) else {
                    return
                }

                let audioBuffer = AudioBuffer(buffer: convertedBuffer, timestamp: time.audioTimeStamp.mSampleTime)
                continuation.yield(audioBuffer)
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopCapture()
                }
            }
        }
    }

    private func logBufferCapture(count: Int) {
        if count == 1 {
            print("🎤 [Microphone] First audio buffer captured!")
        }
        if count % 100 == 0 {
            print("🎤 [Microphone] Captured \(count) audio buffers")
        }
    }

    private func convertAndLogBuffer(
        _ buffer: AVAudioPCMBuffer,
        count: Int,
        using converter: AVAudioConverter,
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard let convertedBuffer = convertBuffer(buffer, using: converter, to: outputFormat) else {
            if count <= 3 {
                print("⚠️ [Microphone] Failed to convert buffer #\(count)")
            }
            return nil
        }

        if count == 1 {
            print("✅ [Microphone] First buffer converted successfully to 16kHz")
        }

        return convertedBuffer
    }

    private func startAudioEngine() throws {
        print("🎤 [Microphone] Preparing audio engine...")
        audioEngine.prepare()
        print("🎤 [Microphone] Starting audio engine...")
        try audioEngine.start()
        _isCapturing = true
        print("✅ [Microphone] Audio engine started successfully")
    }

    private func convertBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        // Calculate output frame count based on sample rate ratio
        let ratio = outputFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)

        guard
            let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: outputFrameCapacity
            )
        else {
            return nil
        }

        var error: NSError?
        var inputConsumed = false

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let error = error {
            print("❌ [Microphone] Conversion error: \(error.localizedDescription)")
            return nil
        }

        return outputBuffer
    }

    func stopCapture() async {
        print("🔴 [Microphone] stopCapture() called")
        guard _isCapturing else {
            print("⚠️ [Microphone] Not currently capturing")
            return
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioStream?.finish()
        audioStream = nil
        audioConverter = nil
        _isCapturing = false
        print("✅ [Microphone] Capture stopped")
    }
}
