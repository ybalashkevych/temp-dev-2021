//
//  TranscriptionSegment.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// A single segment of transcribed speech with timing and confidence information.
struct TranscriptionSegment: Identifiable, Sendable {
    /// Unique identifier for the segment.
    let id: UUID

    /// The transcribed text content.
    let text: String

    /// The start time of the segment relative to the session start.
    let startTime: TimeInterval

    /// The end time of the segment relative to the session start.
    let endTime: TimeInterval

    /// Confidence score from the speech recognizer (0.0 to 1.0).
    let confidence: Double

    /// Whether this is a final result or a partial/interim result.
    let isFinal: Bool

    /// The speaker/source of this audio segment.
    let speaker: SpeakerType

    /// Whether this segment is likely a question (detected by analysis).
    var isQuestion: Bool = false

    /// Computed duration of the segment.
    var duration: TimeInterval {
        endTime - startTime
    }

    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Double,
        isFinal: Bool,
        speaker: SpeakerType,
        isQuestion: Bool = false
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.isFinal = isFinal
        self.speaker = speaker
        self.isQuestion = isQuestion
    }
}

extension TranscriptionSegment: Equatable {
    static func == (lhs: TranscriptionSegment, rhs: TranscriptionSegment) -> Bool {
        lhs.id == rhs.id
    }
}

extension TranscriptionSegment: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
