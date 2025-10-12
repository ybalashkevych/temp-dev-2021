//
//  TranscriptionSession.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Represents a transcription session containing multiple segments.
struct TranscriptionSession: Identifiable, Sendable {
    /// Unique identifier for the session.
    let id: UUID

    /// The timestamp when the session was created.
    let createdAt: Date

    /// All transcription segments in this session.
    var segments: [TranscriptionSegment]

    /// Currently active audio sources being transcribed.
    var activeSources: Set<SpeakerType>

    /// Computed total duration of the session.
    var duration: TimeInterval {
        guard let lastSegment = segments.last else { return 0 }
        return lastSegment.endTime
    }

    /// Whether the session is currently recording.
    var isRecording: Bool {
        !activeSources.isEmpty
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        segments: [TranscriptionSegment] = [],
        activeSources: Set<SpeakerType> = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.segments = segments
        self.activeSources = activeSources
    }
}
