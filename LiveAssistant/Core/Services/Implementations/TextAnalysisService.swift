//
//  TextAnalysisService.swift
//  LiveAssistant
//
//  Created by Yurii Balashkevych on 10/12/25
//  Copyright © 2025. All rights reserved.
//

import Foundation
import NaturalLanguage

/// Service for analyzing transcribed text using Natural Language framework.
final class TextAnalysisService: TextAnalysisServiceProtocol {
    func analyze(text: String) async -> AnalyzedSegment {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Detect sentences
        let sentences = detectSentences(in: trimmedText)

        // Detect if it's a question
        let isQuestion = detectQuestion(in: trimmedText)

        // Normalize text (already done by Speech framework, but we can enhance)
        let normalizedText = normalizeText(trimmedText)

        return AnalyzedSegment(
            text: trimmedText,
            sentences: sentences,
            isQuestion: isQuestion,
            normalizedText: normalizedText
        )
    }

    // MARK: - Private Methods

    private func detectSentences(in text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            sentences.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        }

        return sentences.isEmpty ? [text] : sentences
    }

    private func detectQuestion(in text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for question mark
        if trimmedText.hasSuffix("?") {
            return true
        }

        // Check for question words at the beginning
        let questionWords = [
            "what", "where", "when", "why", "who", "whom", "whose",
            "which", "how", "can", "could", "would", "should", "is",
            "are", "do", "does", "did", "will", "shall", "may", "might",
        ]

        let lowercased = trimmedText.lowercased()
        for word in questionWords where lowercased.hasPrefix(word + " ") {
            return true
        }

        return false
    }

    private func normalizeText(_ text: String) -> String {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure proper sentence ending
        if !normalized.isEmpty && !normalized.hasSuffix(".") && !normalized.hasSuffix("?") && !normalized.hasSuffix("!") {
            // Add period if it looks like a complete sentence
            if detectQuestion(in: normalized) {
                normalized += "?"
            } else if normalized.split(separator: " ").count > 2 {
                normalized += "."
            }
        }

        // Capitalize first letter
        if let first = normalized.first {
            normalized = first.uppercased() + normalized.dropFirst()
        }

        return normalized
    }
}
