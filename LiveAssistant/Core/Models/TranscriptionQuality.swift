//
//  TranscriptionQuality.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Metrics tracking the quality of speech recognition.
struct TranscriptionQuality: Sendable, Codable {
    /// Recognition mode used (cloud/on-device).
    let recognitionMode: String

    /// Average confidence score (0.0 - 1.0).
    let averageConfidence: Double

    /// Minimum confidence score recorded.
    let minimumConfidence: Double

    /// Maximum confidence score recorded.
    let maximumConfidence: Double

    /// Total number of segments processed.
    let totalSegments: Int

    /// Number of final segments (completed sentences).
    let finalSegments: Int

    /// Number of partial segments.
    let partialSegments: Int

    /// Average segment duration in seconds.
    let averageSegmentDuration: TimeInterval

    /// Total duration of transcribed audio in seconds.
    let totalDuration: TimeInterval

    /// Timestamp when quality tracking started.
    let startTime: Date

    /// Timestamp when quality tracking ended.
    let endTime: Date

    /// Sentence completion rate (0.0 - 1.0).
    var sentenceCompletionRate: Double {
        guard totalSegments > 0 else { return 0.0 }
        return Double(finalSegments) / Double(totalSegments)
    }

    /// Creates a quality summary from a collection of transcription results.
    static func from(
        results: [TranscriptionResult],
        recognitionMode: String,
        startTime: Date,
        endTime: Date
    ) -> TranscriptionQuality {
        guard !results.isEmpty else {
            return TranscriptionQuality(
                recognitionMode: recognitionMode,
                averageConfidence: 0.0,
                minimumConfidence: 0.0,
                maximumConfidence: 0.0,
                totalSegments: 0,
                finalSegments: 0,
                partialSegments: 0,
                averageSegmentDuration: 0.0,
                totalDuration: 0.0,
                startTime: startTime,
                endTime: endTime
            )
        }

        let confidences = results.map { $0.confidence }
        let averageConfidence = confidences.reduce(0.0, +) / Double(confidences.count)
        let minimumConfidence = confidences.min() ?? 0.0
        let maximumConfidence = confidences.max() ?? 0.0

        let finalCount = results.filter { $0.isFinal }.count
        let partialCount = results.count - finalCount

        let durations = results.map { $0.endTime - $0.startTime }
        let averageDuration = durations.isEmpty ? 0.0 : durations.reduce(0.0, +) / Double(durations.count)
        let totalDuration = results.map { $0.endTime }.max() ?? 0.0

        return TranscriptionQuality(
            recognitionMode: recognitionMode,
            averageConfidence: averageConfidence,
            minimumConfidence: minimumConfidence,
            maximumConfidence: maximumConfidence,
            totalSegments: results.count,
            finalSegments: finalCount,
            partialSegments: partialCount,
            averageSegmentDuration: averageDuration,
            totalDuration: totalDuration,
            startTime: startTime,
            endTime: endTime
        )
    }
}
