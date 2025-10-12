//
//  TranscriptionResult.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Represents a transcription result from the speech recognition service.
struct TranscriptionResult: Sendable {
    /// The transcribed text.
    let text: String

    /// The start time of the transcription relative to the session start.
    let startTime: TimeInterval

    /// The end time of the transcription relative to the session start.
    let endTime: TimeInterval

    /// Confidence score (0.0 to 1.0).
    let confidence: Double

    /// Whether this is a final result (true) or partial/interim (false).
    let isFinal: Bool
}
