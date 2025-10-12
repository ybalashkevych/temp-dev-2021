//
//  AnalyzedSegment.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Represents an analyzed text segment with linguistic features.
struct AnalyzedSegment: Sendable {
    /// The original text.
    let text: String

    /// Detected sentences in the text.
    let sentences: [String]

    /// Whether the text appears to be a question.
    let isQuestion: Bool

    /// The normalized text with improved punctuation.
    let normalizedText: String
}
