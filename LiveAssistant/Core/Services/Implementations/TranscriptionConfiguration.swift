//
//  TranscriptionConfiguration.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Speech

/// Recognition mode for speech transcription.
enum RecognitionMode: String, Sendable {
    case cloudFirst = "Cloud-First"
    case onDeviceFirst = "On-Device First"
    case cloudOnly = "Cloud Only"
    case onDeviceOnly = "On-Device Only"
}

/// Configuration for speech recognition transcription.
struct TranscriptionConfiguration: Sendable {
    /// Recognition mode (cloud vs on-device).
    let recognitionMode: RecognitionMode

    /// Task hint for the speech recognizer.
    let taskHint: SFSpeechRecognitionTaskHint

    /// Minimum confidence threshold for partial results (0.0 - 1.0).
    let partialResultConfidenceThreshold: Float

    /// Minimum confidence threshold for final results (0.0 - 1.0).
    let finalResultConfidenceThreshold: Float

    /// Minimum time between partial result yields (seconds).
    let partialResultThrottleInterval: TimeInterval

    /// Minimum segment duration to consider complete (seconds).
    let minimumSegmentDuration: TimeInterval

    /// Whether to add punctuation automatically.
    let addsPunctuation: Bool

    /// Whether to report partial results.
    let shouldReportPartialResults: Bool

    /// Custom vocabulary for technical terms.
    let customVocabulary: [String]

    /// Default configuration optimized for technical interviews and meetings.
    static let `default` = TranscriptionConfiguration(
        recognitionMode: .cloudFirst,
        taskHint: .unspecified,
        partialResultConfidenceThreshold: 0.5,
        finalResultConfidenceThreshold: 0.3,
        partialResultThrottleInterval: 0.3,
        minimumSegmentDuration: 1.5,
        addsPunctuation: true,
        shouldReportPartialResults: true,
        customVocabulary: VocabularyService.shared.allVocabulary
    )

    /// Configuration optimized for accuracy (cloud-only, higher thresholds).
    static let highAccuracy = TranscriptionConfiguration(
        recognitionMode: .cloudOnly,
        taskHint: .unspecified,
        partialResultConfidenceThreshold: 0.7,
        finalResultConfidenceThreshold: 0.5,
        partialResultThrottleInterval: 0.5,
        minimumSegmentDuration: 2.0,
        addsPunctuation: true,
        shouldReportPartialResults: true,
        customVocabulary: VocabularyService.shared.allVocabulary
    )

    /// Configuration optimized for speed (cloud-only, lower thresholds).
    static let highSpeed = TranscriptionConfiguration(
        recognitionMode: .cloudOnly,
        taskHint: .unspecified,
        partialResultConfidenceThreshold: 0.3,
        finalResultConfidenceThreshold: 0.2,
        partialResultThrottleInterval: 0.1,
        minimumSegmentDuration: 1.0,
        addsPunctuation: true,
        shouldReportPartialResults: true,
        customVocabulary: VocabularyService.shared.allVocabulary
    )

    /// Configuration for privacy-focused on-device recognition.
    static let privacy = TranscriptionConfiguration(
        recognitionMode: .onDeviceOnly,
        taskHint: .unspecified,
        partialResultConfidenceThreshold: 0.5,
        finalResultConfidenceThreshold: 0.3,
        partialResultThrottleInterval: 0.3,
        minimumSegmentDuration: 1.5,
        addsPunctuation: true,
        shouldReportPartialResults: true,
        customVocabulary: VocabularyService.shared.allVocabulary
    )
}
