//
//  AudioBuffer.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

@preconcurrency import AVFoundation
import Foundation

/// A wrapper for audio buffer data with format information.
struct AudioBuffer: Sendable {
    /// The audio PCM buffer containing audio samples.
    nonisolated(unsafe) let buffer: AVAudioPCMBuffer

    /// The timestamp when this buffer was captured.
    let timestamp: TimeInterval

    /// The audio format of this buffer.
    var format: AVAudioFormat {
        buffer.format
    }

    /// The number of frames in the buffer.
    var frameLength: AVAudioFrameCount {
        buffer.frameLength
    }

    init(buffer: AVAudioPCMBuffer, timestamp: TimeInterval) {
        self.buffer = buffer
        self.timestamp = timestamp
    }
}
