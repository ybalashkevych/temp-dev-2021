//
//  TextAnalysisServiceProtocol.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Defines the interface for text analysis services.
protocol TextAnalysisServiceProtocol: Sendable {
    /// Analyzes a text segment to detect sentences, questions, and normalize punctuation.
    /// - Parameter text: The text to analyze.
    /// - Returns: An analyzed segment with linguistic features.
    func analyze(text: String) async -> AnalyzedSegment
}
