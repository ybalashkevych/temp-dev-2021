//
//  TranscriptionParagraph.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/13/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// A paragraph grouping multiple related transcription segments.
struct TranscriptionParagraph: Identifiable, Sendable {
    /// Unique identifier for the paragraph.
    let id: UUID

    /// The segments that make up this paragraph.
    let segments: [TranscriptionSegment]

    /// The speaker/source of this paragraph.
    let speaker: SpeakerType

    /// The start time of the first segment.
    var startTime: TimeInterval {
        segments.first?.startTime ?? 0
    }

    /// The end time of the last segment.
    var endTime: TimeInterval {
        segments.last?.endTime ?? 0
    }

    /// Combined text from all segments.
    var text: String {
        segments.map { $0.text }.joined(separator: " ")
    }

    /// Whether all segments in this paragraph are final.
    var isFinal: Bool {
        segments.allSatisfy { $0.isFinal }
    }

    /// Average confidence across all segments.
    var averageConfidence: Double {
        guard !segments.isEmpty else { return 0 }
        let sum = segments.reduce(0.0) { $0 + $1.confidence }
        return sum / Double(segments.count)
    }

    /// Whether this paragraph contains any questions.
    var hasQuestion: Bool {
        segments.contains { $0.isQuestion }
    }

    /// Duration of the paragraph.
    var duration: TimeInterval {
        endTime - startTime
    }

    init(id: UUID = UUID(), segments: [TranscriptionSegment], speaker: SpeakerType) {
        self.id = id
        self.segments = segments
        self.speaker = speaker
    }
}

extension TranscriptionParagraph: Equatable {
    static func == (lhs: TranscriptionParagraph, rhs: TranscriptionParagraph) -> Bool {
        lhs.id == rhs.id
    }
}

extension TranscriptionParagraph: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
